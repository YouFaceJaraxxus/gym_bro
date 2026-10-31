-- ── Instagram parity: saves, hashtags, pins, mutes, close friends, highlights,
--    story polls, notes, pinned chats, profile website ─────────────────────────

ALTER TYPE notification_type ADD VALUE IF NOT EXISTS 'story_mention';

-- ── Posts ─────────────────────────────────────────────────────────────────────
-- * pinned_at: up to three of the author's posts lead their profile grid.
-- * hide_like_count: only the author sees how many reacted.
-- * comments_disabled: nobody can add comments (existing ones stay).
-- * location_name: free text ("Ironclad Fitness", "Belgrade") — no geocoding.

ALTER TABLE post
  ADD COLUMN IF NOT EXISTS pinned_at         TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS hide_like_count   BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS comments_disabled BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS location_name     TEXT;
DO $$ BEGIN
  ALTER TABLE post ADD CONSTRAINT post_location_name_length CHECK (char_length(location_name) <= 100);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
CREATE INDEX IF NOT EXISTS post_pinned_idx ON post (author_id, pinned_at DESC) WHERE pinned_at IS NOT NULL;

-- Saved posts ("All posts"), optionally also filed into named collections.
-- Unsaving a post takes it out of every collection.
CREATE TABLE IF NOT EXISTS post_save (
  user_id    UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  post_id    UUID        NOT NULL REFERENCES post(id)  ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (user_id, post_id)
);
CREATE INDEX IF NOT EXISTS post_save_user_idx ON post_save (user_id, created_at DESC);

CREATE TABLE IF NOT EXISTS save_collection (
  id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name       TEXT        NOT NULL CHECK (char_length(name) BETWEEN 1 AND 50),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE UNIQUE INDEX IF NOT EXISTS save_collection_name_idx ON save_collection (user_id, lower(name));

CREATE TABLE IF NOT EXISTS save_collection_item (
  collection_id UUID        NOT NULL REFERENCES save_collection(id) ON DELETE CASCADE,
  post_id       UUID        NOT NULL REFERENCES post(id)            ON DELETE CASCADE,
  added_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (collection_id, post_id)
);
CREATE INDEX IF NOT EXISTS save_collection_item_post_idx ON save_collection_item (post_id);

-- Hashtags in a post's caption, lowercased, kept in sync on create/edit.
CREATE TABLE IF NOT EXISTS post_hashtag (
  post_id UUID NOT NULL REFERENCES post(id) ON DELETE CASCADE,
  tag     TEXT NOT NULL CHECK (tag = lower(tag) AND char_length(tag) BETWEEN 1 AND 50),
  PRIMARY KEY (post_id, tag)
);
CREATE INDEX IF NOT EXISTS post_hashtag_tag_idx ON post_hashtag (tag, post_id);
CREATE INDEX IF NOT EXISTS post_hashtag_tag_prefix_idx ON post_hashtag (tag text_pattern_ops);

-- Backfill tags from existing captions (the app keeps them current from here).
INSERT INTO post_hashtag (post_id, tag)
SELECT DISTINCT p.id, lower(m[1])
FROM post p, regexp_matches(p.content, '(?:^|[^[:alnum:]_&/#])#([[:alnum:]_]{1,50})', 'g') AS m
WHERE p.business_id IS NULL AND lower(m[1]) ~ '[[:alpha:]]'
ON CONFLICT DO NOTHING;

-- ── People ────────────────────────────────────────────────────────────────────

ALTER TABLE users ADD COLUMN IF NOT EXISTS website TEXT;
DO $$ BEGIN
  ALTER TABLE users ADD CONSTRAINT users_website_format CHECK (website ~ '^https?://' AND char_length(website) <= 200);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Mute someone's posts and/or stories without unfollowing. They aren't told.
CREATE TABLE IF NOT EXISTS user_mute (
  muter_id   UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  muted_id   UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  posts      BOOLEAN     NOT NULL DEFAULT FALSE,
  stories    BOOLEAN     NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (muter_id, muted_id),
  CONSTRAINT user_mute_not_self CHECK (muter_id <> muted_id),
  CONSTRAINT user_mute_something CHECK (posts OR stories)
);

-- My close friends: who sees my close-friends stories and notes. Private list.
CREATE TABLE IF NOT EXISTS close_friend (
  user_id    UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  friend_id  UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (user_id, friend_id),
  CONSTRAINT close_friend_not_self CHECK (user_id <> friend_id)
);
CREATE INDEX IF NOT EXISTS close_friend_friend_idx ON close_friend (friend_id);

-- ── Stories ───────────────────────────────────────────────────────────────────
-- * audience: 'close_friends' stories are seen only by the author's close
--   friends (on top of the usual follower rules) — the green ring.
-- * poll: {question, options: [2–4 strings]}; votes in story_poll_vote.

ALTER TABLE story
  ADD COLUMN IF NOT EXISTS audience TEXT NOT NULL DEFAULT 'everyone',
  ADD COLUMN IF NOT EXISTS poll     JSONB;
DO $$ BEGIN
  ALTER TABLE story ADD CONSTRAINT story_audience_check CHECK (audience IN ('everyone', 'close_friends'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
-- A poll can be the whole story, like a text card.
ALTER TABLE story DROP CONSTRAINT IF EXISTS story_content;
ALTER TABLE story ADD CONSTRAINT story_content
  CHECK (storage_path IS NOT NULL OR share_kind IS NOT NULL OR caption IS NOT NULL OR poll IS NOT NULL);

CREATE TABLE IF NOT EXISTS story_poll_vote (
  story_id   UUID        NOT NULL REFERENCES story(id) ON DELETE CASCADE,
  user_id    UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  option     SMALLINT    NOT NULL CHECK (option BETWEEN 0 AND 3),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (story_id, user_id)
);

-- Highlights: named sets of the author's stories kept on their profile after
-- the stories expire. Seen by whoever can see the author's posts (and, for
-- close-friends stories, only by close friends).
CREATE TABLE IF NOT EXISTS story_highlight (
  id             UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id        UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title          TEXT        NOT NULL CHECK (char_length(title) BETWEEN 1 AND 30),
  cover_story_id UUID        REFERENCES story(id) ON DELETE SET NULL,
  position       INT         NOT NULL DEFAULT 0,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS story_highlight_user_idx ON story_highlight (user_id, position);

CREATE TABLE IF NOT EXISTS story_highlight_item (
  highlight_id UUID        NOT NULL REFERENCES story_highlight(id) ON DELETE CASCADE,
  story_id     UUID        NOT NULL REFERENCES story(id)           ON DELETE CASCADE,
  added_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (highlight_id, story_id)
);
CREATE INDEX IF NOT EXISTS story_highlight_item_story_idx ON story_highlight_item (story_id);

-- ── Chat ──────────────────────────────────────────────────────────────────────

-- Pinned chats lead the inbox (up to three).
ALTER TABLE conversation_participant ADD COLUMN IF NOT EXISTS pinned_at TIMESTAMPTZ;

-- Notes: a short status above the inbox for 24 hours, one per person, seen by
-- people who follow each other with the author, or only close friends.
CREATE TABLE IF NOT EXISTS user_note (
  user_id    UUID        PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  body       TEXT        NOT NULL CHECK (char_length(body) BETWEEN 1 AND 60),
  audience   TEXT        NOT NULL DEFAULT 'mutuals' CHECK (audience IN ('mutuals', 'close_friends')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at TIMESTAMPTZ NOT NULL DEFAULT NOW() + INTERVAL '24 hours'
);

ALTER TABLE post_save            ENABLE ROW LEVEL SECURITY;
ALTER TABLE save_collection      ENABLE ROW LEVEL SECURITY;
ALTER TABLE save_collection_item ENABLE ROW LEVEL SECURITY;
ALTER TABLE post_hashtag         ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_mute            ENABLE ROW LEVEL SECURITY;
ALTER TABLE close_friend         ENABLE ROW LEVEL SECURITY;
ALTER TABLE story_poll_vote      ENABLE ROW LEVEL SECURITY;
ALTER TABLE story_highlight      ENABLE ROW LEVEL SECURITY;
ALTER TABLE story_highlight_item ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_note            ENABLE ROW LEVEL SECURITY;
