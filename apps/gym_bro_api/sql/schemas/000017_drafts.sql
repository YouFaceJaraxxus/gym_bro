-- ── Drafts ────────────────────────────────────────────────────────────────────
-- An unfinished post, exercise, training, … saved when its author leaves the
-- create screen. Only the author ever sees a draft (the drafts function is
-- the only reader); publishing creates the real row through the usual
-- endpoint and deletes the draft.
-- * data: the form's own state, as the app serialized it (opaque here).
-- * scope_id: what the draft belongs to when a kind has several homes, e.g.
--   the business of a business post. NULL otherwise.
-- * media: photos/videos already uploaded to user-media through upload slots
--   ([{path, mime_type, file_name, size_bytes, width, height, duration_ms,
--   edit}], edit being the app's non-destructive filter/adjust/trim state).
--   Those slots stay unclaimed (a post can still claim them on publish) but
--   are held by the draft (media_upload.draft_id), so the daily sweep skips
--   them; deleting the draft releases them.

CREATE TABLE IF NOT EXISTS draft (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  kind          TEXT        NOT NULL CHECK (kind IN (
                  'post', 'business_post', 'exercise', 'training', 'routine',
                  'recipe', 'food_item', 'daily_meal_plan', 'meal_plan')),
  scope_id      UUID,
  title         TEXT        CHECK (char_length(title) <= 200),
  thumbnail_url TEXT        CHECK (char_length(thumbnail_url) <= 2048),
  data          JSONB       NOT NULL DEFAULT '{}'::jsonb,
  media         JSONB       NOT NULL DEFAULT '[]'::jsonb CHECK (jsonb_typeof(media) = 'array'),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS draft_user_kind_idx ON draft (user_id, kind, updated_at DESC);

ALTER TABLE media_upload ADD COLUMN IF NOT EXISTS draft_id UUID REFERENCES draft(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS media_upload_draft_idx ON media_upload (draft_id) WHERE draft_id IS NOT NULL;

ALTER TABLE draft ENABLE ROW LEVEL SECURITY;
