-- ── Product features: push, settings, payments, shop orders, classes, shifts,
--    progress, coaching, social, check-ins, food diary, micronutrients ────────
-- Every table created here gets RLS enabled at the bottom (see 000011).

-- ── Enums ─────────────────────────────────────────────────────────────────────

ALTER TYPE notification_type ADD VALUE IF NOT EXISTS 'post_comment';
ALTER TYPE notification_type ADD VALUE IF NOT EXISTS 'shift_assigned';
ALTER TYPE notification_type ADD VALUE IF NOT EXISTS 'order_update';
ALTER TYPE notification_type ADD VALUE IF NOT EXISTS 'payment_received';
ALTER TYPE notification_type ADD VALUE IF NOT EXISTS 'session_comment';

DO $$ BEGIN
  CREATE TYPE payment_status AS ENUM ('pending', 'succeeded', 'failed', 'cancelled', 'refunded');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE payment_kind AS ENUM ('invoice', 'order', 'membership');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE order_status AS ENUM ('pending', 'paid', 'fulfilled', 'cancelled');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE booking_status AS ENUM ('booked', 'waitlisted', 'cancelled', 'attended', 'no_show');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ── Push notifications & settings ─────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS device_token (
  id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token        TEXT        NOT NULL UNIQUE,
  platform     TEXT        NOT NULL CHECK (platform IN ('android', 'ios', 'web', 'macos')),
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  last_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS device_token_user_idx ON device_token (user_id);

CREATE TABLE IF NOT EXISTS user_settings (
  user_id      UUID                PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  push_enabled BOOLEAN             NOT NULL DEFAULT TRUE,
  muted_types  notification_type[] NOT NULL DEFAULT '{}',
  weight_unit  TEXT                NOT NULL DEFAULT 'kg'     CHECK (weight_unit IN ('kg', 'lb')),
  theme_mode   TEXT                NOT NULL DEFAULT 'system' CHECK (theme_mode IN ('system', 'light', 'dark')),
  locale       TEXT,
  updated_at   TIMESTAMPTZ         NOT NULL DEFAULT NOW()
);

-- Replaces the SUPER_ADMIN_PASS backdoor: impersonation is an explicit,
-- logged super-user action.
CREATE TABLE IF NOT EXISTS admin_audit_log (
  id             UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_id       UUID        REFERENCES users(id) ON DELETE SET NULL,
  action         TEXT        NOT NULL,
  target_user_id UUID        REFERENCES users(id) ON DELETE SET NULL,
  metadata       JSONB       NOT NULL DEFAULT '{}',
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── Shop orders (reuses invoice / invoice_item from 000003) ───────────────────

ALTER TABLE invoice
  ADD COLUMN IF NOT EXISTS user_id        UUID         REFERENCES users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS shop_id        UUID         REFERENCES shop(id)  ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS status         order_status NOT NULL DEFAULT 'pending',
  ADD COLUMN IF NOT EXISTS payment_method TEXT         NOT NULL DEFAULT 'pay_at_pickup'
                                          CHECK (payment_method IN ('card', 'pay_at_pickup')),
  ADD COLUMN IF NOT EXISTS note           TEXT,
  ADD COLUMN IF NOT EXISTS created_at     TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  ADD COLUMN IF NOT EXISTS paid_at        TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS fulfilled_at   TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS cancelled_at   TIMESTAMPTZ;
CREATE INDEX IF NOT EXISTS invoice_user_idx ON invoice (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS invoice_shop_idx ON invoice (shop_id, created_at DESC);

-- Price at the time of purchase, so later price changes don't rewrite history.
ALTER TABLE invoice_item ADD COLUMN IF NOT EXISTS unit_price NUMERIC(10, 2);

CREATE OR REPLACE FUNCTION recalc_invoice_total()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
  target_invoice_id UUID := COALESCE(NEW.invoice_id, OLD.invoice_id);
BEGIN
  UPDATE invoice
  SET total = COALESCE((
    SELECT SUM(ii.quantity * COALESCE(ii.unit_price, si.price))
    FROM   invoice_item ii
    JOIN   shop_item    si ON si.id = ii.shop_item_id
    WHERE  ii.invoice_id = target_invoice_id
  ), 0)
  WHERE id = target_invoice_id;
  RETURN NEW;
END;
$$;

-- ── Payments (Stripe) ─────────────────────────────────────────────────────────

ALTER TABLE membership
  ADD COLUMN IF NOT EXISTS auto_renew             BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS stripe_subscription_id TEXT;

CREATE TABLE IF NOT EXISTS payment (
  id                         UUID           PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id                    UUID           REFERENCES users(id) ON DELETE SET NULL,
  kind                       payment_kind   NOT NULL,
  membership_invoice_id      UUID           REFERENCES membership_invoice(id)  ON DELETE SET NULL,
  order_id                   UUID           REFERENCES invoice(id)             ON DELETE SET NULL,
  membership_type_id         UUID           REFERENCES gym_membership_type(id) ON DELETE SET NULL,
  membership_id              UUID           REFERENCES membership(id)          ON DELETE SET NULL,
  stripe_checkout_session_id TEXT           UNIQUE,
  stripe_payment_intent_id   TEXT,
  stripe_subscription_id     TEXT,
  amount                     NUMERIC(10, 2) NOT NULL,
  currency                   TEXT           NOT NULL DEFAULT 'usd',
  status                     payment_status NOT NULL DEFAULT 'pending',
  created_at                 TIMESTAMPTZ    NOT NULL DEFAULT NOW(),
  updated_at                 TIMESTAMPTZ    NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS payment_user_idx ON payment (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS payment_subscription_idx ON payment (stripe_subscription_id);

-- ── Classes & bookings ────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS gym_class (
  id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  gym_id           UUID        NOT NULL REFERENCES gym(id) ON DELETE CASCADE,
  trainer_id       UUID        REFERENCES users(id) ON DELETE SET NULL,
  title            TEXT        NOT NULL,
  description      TEXT,
  location         TEXT,
  starts_at        TIMESTAMPTZ NOT NULL,
  ends_at          TIMESTAMPTZ NOT NULL,
  capacity         INT         NOT NULL CHECK (capacity > 0),
  series_id        UUID,       -- shared by classes created together as a weekly series
  cancelled_at     TIMESTAMPTZ,
  reminder_sent_at TIMESTAMPTZ,
  created_by       UUID        REFERENCES users(id) ON DELETE SET NULL,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT gym_class_time_order CHECK (ends_at > starts_at)
);
CREATE INDEX IF NOT EXISTS gym_class_gym_time_idx ON gym_class (gym_id, starts_at);
CREATE INDEX IF NOT EXISTS gym_class_trainer_idx  ON gym_class (trainer_id, starts_at);

CREATE TABLE IF NOT EXISTS class_booking (
  id         UUID           PRIMARY KEY DEFAULT gen_random_uuid(),
  class_id   UUID           NOT NULL REFERENCES gym_class(id) ON DELETE CASCADE,
  user_id    UUID           NOT NULL REFERENCES users(id)     ON DELETE CASCADE,
  status     booking_status NOT NULL DEFAULT 'booked',
  created_at TIMESTAMPTZ    NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ    NOT NULL DEFAULT NOW(),
  UNIQUE (class_id, user_id)
);
CREATE INDEX IF NOT EXISTS class_booking_user_idx ON class_booking (user_id);

-- ── Staff shifts ──────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS staff_shift (
  id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  gym_id     UUID        NOT NULL REFERENCES gym(id)   ON DELETE CASCADE,
  user_id    UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  starts_at  TIMESTAMPTZ NOT NULL,
  ends_at    TIMESTAMPTZ NOT NULL,
  note       TEXT,
  created_by UUID        REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT staff_shift_time_order CHECK (ends_at > starts_at)
);
CREATE INDEX IF NOT EXISTS staff_shift_gym_time_idx  ON staff_shift (gym_id, starts_at);
CREATE INDEX IF NOT EXISTS staff_shift_user_time_idx ON staff_shift (user_id, starts_at);

-- ── Progress & coaching ───────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS body_measurement (
  id           UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID         NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  measured_on  DATE         NOT NULL DEFAULT CURRENT_DATE,
  weight_kg    NUMERIC(6,2),
  body_fat_pct NUMERIC(5,2),
  note         TEXT,
  created_at   TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  CONSTRAINT body_measurement_has_value CHECK (weight_kg IS NOT NULL OR body_fat_pct IS NOT NULL)
);
CREATE INDEX IF NOT EXISTS body_measurement_user_idx ON body_measurement (user_id, measured_on);

CREATE TABLE IF NOT EXISTS routine_assignment (
  id             UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  routine_id     UUID        NOT NULL REFERENCES routine(id) ON DELETE CASCADE,
  user_id        UUID        NOT NULL REFERENCES users(id)   ON DELETE CASCADE,
  assigned_by_id UUID        REFERENCES users(id)            ON DELETE SET NULL,
  start_date     DATE,
  end_date       DATE,
  note           TEXT,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT routine_assignment_date_order CHECK (end_date IS NULL OR start_date IS NULL OR end_date >= start_date)
);
CREATE INDEX IF NOT EXISTS routine_assignment_user_idx ON routine_assignment (user_id);

CREATE TABLE IF NOT EXISTS session_comment (
  id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID        NOT NULL REFERENCES training_session(id) ON DELETE CASCADE,
  author_id  UUID        REFERENCES users(id) ON DELETE SET NULL,
  body       TEXT        NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS session_comment_session_idx ON session_comment (session_id, created_at);

-- ── Community: comments & likes ───────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS post_comment (
  id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id    UUID        NOT NULL REFERENCES post(id) ON DELETE CASCADE,
  author_id  UUID        REFERENCES users(id) ON DELETE SET NULL,
  body       TEXT        NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS post_comment_post_idx ON post_comment (post_id, created_at);

CREATE TABLE IF NOT EXISTS post_like (
  post_id    UUID        NOT NULL REFERENCES post(id)  ON DELETE CASCADE,
  user_id    UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (post_id, user_id)
);

-- ── Gym check-ins ─────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS check_in (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  gym_id        UUID        NOT NULL REFERENCES gym(id)   ON DELETE CASCADE,
  user_id       UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  checked_in_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  checked_in_by UUID        REFERENCES users(id) ON DELETE SET NULL,
  method        TEXT        NOT NULL DEFAULT 'qr' CHECK (method IN ('qr', 'manual'))
);
CREATE INDEX IF NOT EXISTS check_in_gym_time_idx  ON check_in (gym_id, checked_in_at DESC);
CREATE INDEX IF NOT EXISTS check_in_user_time_idx ON check_in (user_id, checked_in_at DESC);

-- ── Food diary ────────────────────────────────────────────────────────────────
-- Macros are snapshotted at log time so the diary doesn't change when a food
-- item is edited later. `amount` is grams/ml for a food item, servings for a recipe.

CREATE TABLE IF NOT EXISTS food_log (
  id           UUID           PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID           NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  log_date     DATE           NOT NULL DEFAULT CURRENT_DATE,
  slot_type    meal_slot_type NOT NULL,
  food_item_id UUID           REFERENCES food_item(id) ON DELETE SET NULL,
  recipe_id    UUID           REFERENCES recipe(id)    ON DELETE SET NULL,
  name         TEXT           NOT NULL,
  amount       NUMERIC(8,2)   NOT NULL CHECK (amount > 0),
  kcal         NUMERIC(8,2)   NOT NULL DEFAULT 0,
  protein      NUMERIC(8,2)   NOT NULL DEFAULT 0,
  carb         NUMERIC(8,2)   NOT NULL DEFAULT 0,
  fat          NUMERIC(8,2)   NOT NULL DEFAULT 0,
  fiber        NUMERIC(8,2)   NOT NULL DEFAULT 0,
  note         TEXT,
  created_at   TIMESTAMPTZ    NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS food_log_user_date_idx ON food_log (user_id, log_date);

-- ── Micronutrient reference data ──────────────────────────────────────────────

INSERT INTO vitamin (name, symbol, default_unit) VALUES
  ('Vitamin A', 'A', 'µg'),
  ('Vitamin B1 (Thiamine)', 'B1', 'mg'),
  ('Vitamin B2 (Riboflavin)', 'B2', 'mg'),
  ('Vitamin B3 (Niacin)', 'B3', 'mg'),
  ('Vitamin B5 (Pantothenic acid)', 'B5', 'mg'),
  ('Vitamin B6', 'B6', 'mg'),
  ('Vitamin B7 (Biotin)', 'B7', 'µg'),
  ('Vitamin B9 (Folate)', 'B9', 'µg'),
  ('Vitamin B12', 'B12', 'µg'),
  ('Vitamin C', 'C', 'mg'),
  ('Vitamin D', 'D', 'µg'),
  ('Vitamin E', 'E', 'mg'),
  ('Vitamin K', 'K', 'µg')
ON CONFLICT (name) DO NOTHING;

INSERT INTO mineral (name, symbol, default_unit) VALUES
  ('Calcium', 'Ca', 'mg'),
  ('Iron', 'Fe', 'mg'),
  ('Magnesium', 'Mg', 'mg'),
  ('Phosphorus', 'P', 'mg'),
  ('Potassium', 'K', 'mg'),
  ('Sodium', 'Na', 'mg'),
  ('Zinc', 'Zn', 'mg'),
  ('Copper', 'Cu', 'mg'),
  ('Manganese', 'Mn', 'mg'),
  ('Selenium', 'Se', 'µg'),
  ('Iodine', 'I', 'µg')
ON CONFLICT (name) DO NOTHING;

-- ── Lock down everything created above ────────────────────────────────────────

DO $$
DECLARE
  t record;
BEGIN
  FOR t IN SELECT tablename FROM pg_tables WHERE schemaname = 'public' LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t.tablename);
  END LOOP;
END $$;

REVOKE ALL ON ALL TABLES    IN SCHEMA public FROM anon, authenticated;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM anon, authenticated;
