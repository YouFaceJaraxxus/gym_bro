-- ── Body progress: tape measurements and progress photos ─────────────────────
-- * body_measurement gains optional circumferences (cm, one decimal). A row
--   now needs at least one value of any kind (weight, body fat or a tape
--   measurement), so a tape-only check-in is fine.
-- * progress_photo: private before/after photos. Files live in the private
--   `progress-photos` bucket under <user_id>/ and are uploaded through the
--   same upload slots as chat and post media (media_upload). Only the owner
--   ever sees them: no coach, feed or super-user read path.

ALTER TABLE body_measurement
  ADD COLUMN IF NOT EXISTS waist_cm NUMERIC(5, 1),
  ADD COLUMN IF NOT EXISTS chest_cm NUMERIC(5, 1),
  ADD COLUMN IF NOT EXISTS hips_cm  NUMERIC(5, 1),
  ADD COLUMN IF NOT EXISTS arm_cm   NUMERIC(5, 1),
  ADD COLUMN IF NOT EXISTS thigh_cm NUMERIC(5, 1),
  ADD COLUMN IF NOT EXISTS neck_cm  NUMERIC(5, 1);

DO $$ BEGIN
  ALTER TABLE body_measurement ADD CONSTRAINT body_measurement_tape_ranges CHECK (
    (waist_cm IS NULL OR waist_cm BETWEEN 30 AND 250) AND
    (chest_cm IS NULL OR chest_cm BETWEEN 40 AND 250) AND
    (hips_cm  IS NULL OR hips_cm  BETWEEN 40 AND 250) AND
    (arm_cm   IS NULL OR arm_cm   BETWEEN 10 AND 100) AND
    (thigh_cm IS NULL OR thigh_cm BETWEEN 20 AND 150) AND
    (neck_cm  IS NULL OR neck_cm  BETWEEN 15 AND 80)
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

ALTER TABLE body_measurement DROP CONSTRAINT IF EXISTS body_measurement_has_value;
ALTER TABLE body_measurement ADD CONSTRAINT body_measurement_has_value CHECK (
  weight_kg IS NOT NULL OR body_fat_pct IS NOT NULL OR waist_cm IS NOT NULL OR chest_cm IS NOT NULL OR
  hips_cm IS NOT NULL OR arm_cm IS NOT NULL OR thigh_cm IS NOT NULL OR neck_cm IS NOT NULL
);

-- ── Progress photos ───────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS progress_photo (
  id         UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID         NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  path       TEXT         NOT NULL UNIQUE,
  pose       TEXT         NOT NULL DEFAULT 'front' CHECK (pose IN ('front', 'side', 'back', 'other')),
  taken_on   DATE         NOT NULL DEFAULT CURRENT_DATE,
  -- Body weight when the photo was taken (given, or the nearest weigh-in).
  weight_kg  NUMERIC(6, 2) CHECK (weight_kg > 0 AND weight_kg < 1000),
  note       TEXT         CHECK (char_length(note) <= 500),
  created_at TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS progress_photo_user_idx ON progress_photo (user_id, taken_on DESC, created_at DESC);
ALTER TABLE progress_photo ENABLE ROW LEVEL SECURITY;

-- Upload slots may now be for the progress-photos bucket.
ALTER TABLE media_upload DROP CONSTRAINT IF EXISTS media_upload_bucket_check;
ALTER TABLE media_upload ADD CONSTRAINT media_upload_bucket_check
  CHECK (bucket IN ('chat-media', 'user-media', 'progress-photos'));

-- Private: files are only reachable through URLs the API signs for the owner.
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('progress-photos', 'progress-photos', FALSE, 20971520, ARRAY['image/*'])
ON CONFLICT (id) DO UPDATE
  SET public = FALSE,
      file_size_limit = EXCLUDED.file_size_limit,
      allowed_mime_types = EXCLUDED.allowed_mime_types;
