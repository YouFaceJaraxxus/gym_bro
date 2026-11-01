-- ── Roles and business profiles ───────────────────────────────────────────────
-- Nobody has a single "user type" any more:
-- * Everyone is a plain user (memberships, programmes, meal plans).
-- * users.is_trainer: switched on by the user (or by accepting a gym's trainer
--   invite). Gives the trainer tools; no gym needed.
-- * users.is_super_user: platform admin; reviews businesses.
-- * business_member: what someone is *at a business* — owner, staff (front
--   desk / shop staff) or trainer. Anyone added must accept the invite first.
--   Replaces gym_owner, shop_owner, employee, employee_trainer, trainer and
--   shop_vendor.
-- * A business is a gym, a shop or both (has_gym / has_shop) and must be
--   approved by a super user before its owner tools work (status).
-- * Businesses are profiles people can follow (business_follow).
-- gym and shop were id-only subtables; everything now references business.

ALTER TYPE notification_type ADD VALUE IF NOT EXISTS 'business_invite';
ALTER TYPE notification_type ADD VALUE IF NOT EXISTS 'business_join';
ALTER TYPE notification_type ADD VALUE IF NOT EXISTS 'business_review';

BEGIN;

DO $$ BEGIN
  CREATE TYPE business_status AS ENUM ('pending', 'approved', 'rejected', 'blocked');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE TYPE business_role AS ENUM ('owner', 'staff', 'trainer');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ── Users ─────────────────────────────────────────────────────────────────────

ALTER TABLE users
  ADD COLUMN IF NOT EXISTS is_super_user BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS is_trainer    BOOLEAN NOT NULL DEFAULT FALSE;

-- ── Businesses ────────────────────────────────────────────────────────────────

ALTER TABLE business
  ADD COLUMN IF NOT EXISTS has_gym     BOOLEAN         NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS has_shop    BOOLEAN         NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS status      business_status NOT NULL DEFAULT 'pending',
  ADD COLUMN IF NOT EXISTS review_note TEXT,
  ADD COLUMN IF NOT EXISTS reviewed_by UUID            REFERENCES users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS reviewed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS bio         TEXT,
  ADD COLUMN IF NOT EXISTS website     TEXT,
  ADD COLUMN IF NOT EXISTS phone       TEXT,
  ADD COLUMN IF NOT EXISTS created_by  UUID            REFERENCES users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS created_at  TIMESTAMPTZ     NOT NULL DEFAULT NOW();
DO $$ BEGIN
  ALTER TABLE business ADD CONSTRAINT business_bio_length CHECK (char_length(bio) <= 500);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  ALTER TABLE business ADD CONSTRAINT business_website_format
    CHECK (website ~ '^https?://' AND char_length(website) <= 200);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  ALTER TABLE business ADD CONSTRAINT business_phone_length CHECK (char_length(phone) <= 40);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
CREATE INDEX IF NOT EXISTS business_status_idx ON business (status, created_at);

-- Who does what at a business. A person can hold several roles at one
-- business (staff who also trains); each is invited and accepted separately.
CREATE TABLE IF NOT EXISTS business_member (
  business_id UUID          NOT NULL REFERENCES business(id) ON DELETE CASCADE,
  user_id     UUID          NOT NULL REFERENCES users(id)    ON DELETE CASCADE,
  role        business_role NOT NULL,
  status      TEXT          NOT NULL DEFAULT 'invited' CHECK (status IN ('invited', 'active')),
  invited_by  UUID          REFERENCES users(id) ON DELETE SET NULL,
  created_at  TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  joined_at   TIMESTAMPTZ,
  PRIMARY KEY (business_id, user_id, role)
);
CREATE INDEX IF NOT EXISTS business_member_user_idx ON business_member (user_id, status);

CREATE TABLE IF NOT EXISTS business_follow (
  user_id     UUID        NOT NULL REFERENCES users(id)    ON DELETE CASCADE,
  business_id UUID        NOT NULL REFERENCES business(id) ON DELETE CASCADE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (user_id, business_id)
);
CREATE INDEX IF NOT EXISTS business_follow_business_idx ON business_follow (business_id);

-- ── Move the old model over (only while its tables still exist) ───────────────

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns
             WHERE table_schema = 'public' AND table_name = 'users' AND column_name = 'role') THEN
    UPDATE users SET is_super_user = TRUE WHERE role::text = 'super_user';
  END IF;

  IF EXISTS (SELECT 1 FROM information_schema.columns
             WHERE table_schema = 'public' AND table_name = 'business' AND column_name = 'type') THEN
    -- Everything that exists today was set up by hand: approve it.
    UPDATE business SET has_gym = (type::text = 'gym'), has_shop = (type::text = 'shop'), status = 'approved';
  END IF;

  IF to_regclass('public.gym_owner') IS NOT NULL THEN
    INSERT INTO business_member (business_id, user_id, role, status, joined_at)
    SELECT gym_id,  user_id, 'owner'::business_role,   'active', NOW() FROM gym_owner
    UNION SELECT shop_id, user_id, 'owner',   'active', NOW() FROM shop_owner
    UNION SELECT gym_id,  user_id, 'staff',   'active', NOW() FROM employee
    UNION SELECT gym_id,  user_id, 'staff',   'active', NOW() FROM employee_trainer
    UNION SELECT gym_id,  user_id, 'trainer', 'active', NOW() FROM employee_trainer
    UNION SELECT gym_id,  user_id, 'trainer', 'active', NOW() FROM trainer
    UNION SELECT shop_id, user_id, 'staff',   'active', NOW() FROM shop_vendor
    ON CONFLICT DO NOTHING;

    UPDATE users SET is_trainer = TRUE
    WHERE id IN (SELECT user_id FROM business_member WHERE role = 'trainer')
       OR id IN (SELECT trainer_id FROM trainer_customer);

    UPDATE business b SET created_by = (
      SELECT m.user_id FROM business_member m
      WHERE m.business_id = b.id AND m.role = 'owner' ORDER BY m.user_id LIMIT 1
    ) WHERE b.created_by IS NULL;

    -- Gym members and the team follow their gym's profile.
    INSERT INTO business_follow (user_id, business_id)
    SELECT user_id, gym_id FROM member
    UNION SELECT user_id, business_id FROM business_member
    ON CONFLICT DO NOTHING;

    -- Old-style invites can't be accepted any more.
    DELETE FROM notification
    WHERE type IN ('employee_gym_invite', 'vendor_shop_invite')
      AND metadata->>'invite_status' = 'pending';
  END IF;
END $$;

DO $$ BEGIN
  ALTER TABLE business ADD CONSTRAINT business_has_side CHECK (has_gym OR has_shop);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Point every gym_id / shop_id foreign key at business, then drop the subtables.
DO $$
DECLARE r record;
BEGIN
  IF to_regclass('public.gym') IS NULL THEN RETURN; END IF;
  FOR r IN
    SELECT c.conrelid::regclass AS tbl, c.conname, pg_get_constraintdef(c.oid) AS def
    FROM pg_constraint c
    WHERE c.contype = 'f' AND c.confrelid IN ('public.gym'::regclass, 'public.shop'::regclass)
  LOOP
    EXECUTE format('ALTER TABLE %s DROP CONSTRAINT %I', r.tbl, r.conname);
    EXECUTE format('ALTER TABLE %s ADD CONSTRAINT %I %s', r.tbl, r.conname,
      regexp_replace(r.def, 'REFERENCES (public\.)?(gym|shop)\(id\)', 'REFERENCES business(id)'));
  END LOOP;
END $$;

DROP TABLE IF EXISTS employee_trainer, employee, trainer, gym_owner, shop_owner, shop_vendor;
DROP TABLE IF EXISTS gym, shop;

ALTER TABLE business DROP COLUMN IF EXISTS type;
DROP TYPE IF EXISTS business_type;
ALTER TABLE users DROP COLUMN IF EXISTS role;
DROP TYPE IF EXISTS user_role;

ALTER TABLE business_member ENABLE ROW LEVEL SECURITY;
ALTER TABLE business_follow ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON business_member, business_follow FROM anon, authenticated;

COMMIT;
