-- ── Stories, sharing in chat, archive ────────────────────────────────────────

ALTER TYPE notification_type ADD VALUE IF NOT EXISTS 'story_reaction';

-- ── Stories ───────────────────────────────────────────────────────────────────
-- Instagram-style: a photo/video (user-media bucket), a text card on a
-- background colour, or something shared (a post, a logged workout or meal,
-- a library item, a product) — people can't be shared to a story. Seen by
-- the author's audience for 24 hours (followers for a private account,
-- everyone for a public one), then kept as the author's archive.
-- * share_snapshot: for a logged workout / meal, the server-built summary
--   (like post.attachment); everything else is resolved per viewer when read,
--   so someone who can't see the shared thing gets "private"/"unavailable".

CREATE TABLE IF NOT EXISTS story (
  id             UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  author_id      UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  storage_path   TEXT,
  media_type     TEXT        CHECK (media_type IN ('image', 'video')),
  mime_type      TEXT,
  width          INT,
  height         INT,
  duration_ms    INT,
  caption        TEXT        CHECK (char_length(caption) <= 500),
  background     TEXT        CHECK (background ~ '^#[0-9a-fA-F]{6}$'),
  share_kind     TEXT        CHECK (share_kind IN (
                   'post', 'workout', 'meal', 'exercise', 'training', 'routine', 'recipe',
                   'food_item', 'daily_meal_plan', 'meal_plan', 'shop_item')),
  share_ref_id   UUID,
  share_snapshot JSONB,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at     TIMESTAMPTZ NOT NULL DEFAULT NOW() + INTERVAL '24 hours',
  CONSTRAINT story_media CHECK ((storage_path IS NULL) = (media_type IS NULL)),
  CONSTRAINT story_content CHECK (storage_path IS NOT NULL OR share_kind IS NOT NULL OR caption IS NOT NULL)
);
CREATE INDEX IF NOT EXISTS story_author_idx  ON story (author_id, created_at DESC);
CREATE INDEX IF NOT EXISTS story_active_idx  ON story (expires_at, author_id);

CREATE TABLE IF NOT EXISTS story_view (
  story_id   UUID        NOT NULL REFERENCES story(id) ON DELETE CASCADE,
  viewer_id  UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  viewed_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (story_id, viewer_id)
);
CREATE INDEX IF NOT EXISTS story_view_viewer_idx ON story_view (viewer_id, viewed_at DESC);

-- Likes and other reactions on a story, one per person (like post_reaction).
CREATE TABLE IF NOT EXISTS story_reaction (
  story_id   UUID          NOT NULL REFERENCES story(id) ON DELETE CASCADE,
  user_id    UUID          NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  reaction   reaction_type NOT NULL,
  created_at TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  PRIMARY KEY (story_id, user_id)
);

-- ── Sharing in chat ───────────────────────────────────────────────────────────
-- A message can share something (share_kind + share_ref_id, or a snapshot
-- for a logged workout / meal), and can answer a story: a text reply or an
-- emoji reaction ("Reacted 🔥 to your story"). story_id goes NULL when the
-- story is deleted; story_mode stays so the app can say it's gone.

ALTER TABLE message
  ADD COLUMN IF NOT EXISTS share_kind     TEXT,
  ADD COLUMN IF NOT EXISTS share_ref_id   UUID,
  ADD COLUMN IF NOT EXISTS share_snapshot JSONB,
  ADD COLUMN IF NOT EXISTS story_id       UUID REFERENCES story(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS story_mode     TEXT;
DO $$ BEGIN
  ALTER TABLE message ADD CONSTRAINT message_share_kind_check CHECK (share_kind IN (
    'post', 'story', 'user', 'business', 'shop_item', 'workout', 'meal', 'exercise', 'training',
    'routine', 'recipe', 'food_item', 'daily_meal_plan', 'meal_plan'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  ALTER TABLE message ADD CONSTRAINT message_story_mode_check CHECK (story_mode IN ('reply', 'reaction'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
CREATE INDEX IF NOT EXISTS message_story_idx ON message (story_id) WHERE story_id IS NOT NULL;

-- ── Post archive ──────────────────────────────────────────────────────────────
-- An archived post is hidden from everyone but its author (profile, feed,
-- shares) until it's shown again.

ALTER TABLE post ADD COLUMN IF NOT EXISTS archived_at TIMESTAMPTZ;
CREATE INDEX IF NOT EXISTS post_archived_idx ON post (author_id, created_at DESC) WHERE archived_at IS NOT NULL;

ALTER TABLE story          ENABLE ROW LEVEL SECURITY;
ALTER TABLE story_view     ENABLE ROW LEVEL SECURITY;
ALTER TABLE story_reaction ENABLE ROW LEVEL SECURITY;
