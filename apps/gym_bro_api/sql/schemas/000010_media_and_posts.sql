-- ── Avatars & product images ──────────────────────────────────────────────────

ALTER TABLE users     ADD COLUMN IF NOT EXISTS avatar_url TEXT;
ALTER TABLE shop_item ADD COLUMN IF NOT EXISTS image_url  TEXT;

-- ── Storage buckets ───────────────────────────────────────────────────────────
-- Uploads are proxied through the `uploads` edge function using the service-role
-- key (same app-side-authz pattern as the rest of the backend — no Storage RLS
-- policies needed since clients never talk to Storage directly).

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES
  ('avatars', 'avatars', TRUE, 5242880, ARRAY['image/png', 'image/jpeg', 'image/webp']),
  ('media',   'media',   TRUE, 10485760, ARRAY['image/png', 'image/jpeg', 'image/webp'])
ON CONFLICT (id) DO NOTHING;

-- ── Posts (gym/shop community feed) ───────────────────────────────────────────
-- A lightweight announcement/activity feed scoped to a business (gym or shop).
-- Owners/trainers/employees post updates; members/vendors/staff read them.

CREATE TABLE IF NOT EXISTS post (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID        NOT NULL REFERENCES business(id) ON DELETE CASCADE,
  author_id   UUID        REFERENCES users(id) ON DELETE SET NULL,
  content     TEXT        NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS post_business_id_idx  ON post(business_id);
CREATE INDEX IF NOT EXISTS post_created_at_idx   ON post(created_at DESC);

CREATE TABLE IF NOT EXISTS post_image (
  id       UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id  UUID    NOT NULL REFERENCES post(id) ON DELETE CASCADE,
  url      TEXT    NOT NULL,
  position INT     NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS post_image_post_id_idx ON post_image(post_id);

CREATE OR REPLACE FUNCTION set_post_updated_at() RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS post_updated_at ON post;
CREATE TRIGGER post_updated_at
  BEFORE UPDATE ON post
  FOR EACH ROW EXECUTE FUNCTION set_post_updated_at();
