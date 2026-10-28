-- ── Social graph, chat, reactions and threaded comments ─────────────────────
-- * Profiles: bio, privacy, interests, coarse location for discovery.
-- * Follows (requests for private accounts), friendships, blocks, reports.
-- * Direct and group chat with attachments in a private storage bucket.
-- * One reaction set (10 types) shared by posts, comments and chat messages.
-- * Post comments become threads, up to 10 levels deep.
-- * Realtime: private channels authorized by RLS on realtime.messages.
-- Every table created here gets RLS enabled at the bottom (see 000011).

-- ── Enums ─────────────────────────────────────────────────────────────────────

ALTER TYPE notification_type ADD VALUE IF NOT EXISTS 'follow';
ALTER TYPE notification_type ADD VALUE IF NOT EXISTS 'follow_request';
ALTER TYPE notification_type ADD VALUE IF NOT EXISTS 'follow_accepted';
ALTER TYPE notification_type ADD VALUE IF NOT EXISTS 'friend_request';
ALTER TYPE notification_type ADD VALUE IF NOT EXISTS 'friend_accepted';
ALTER TYPE notification_type ADD VALUE IF NOT EXISTS 'chat_message';
ALTER TYPE notification_type ADD VALUE IF NOT EXISTS 'group_added';
ALTER TYPE notification_type ADD VALUE IF NOT EXISTS 'post_reaction';
ALTER TYPE notification_type ADD VALUE IF NOT EXISTS 'comment_reply';

DO $$ BEGIN
  CREATE TYPE reaction_type AS ENUM (
    'like', 'love', 'haha', 'wow', 'sad', 'angry', 'fire', 'strong', 'clap', 'celebrate'
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE follow_status AS ENUM ('pending', 'accepted');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE conversation_kind AS ENUM ('direct', 'group');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE participant_role AS ENUM ('owner', 'admin', 'member');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  -- 'request': a direct message from someone the recipient doesn't allow to
  -- message them yet (Instagram-style message request).
  CREATE TYPE participant_status AS ENUM ('active', 'request');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE message_kind AS ENUM ('text', 'media', 'system');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ── Profiles ──────────────────────────────────────────────────────────────────
-- Location is stored rounded (~1 km) and is never returned to other users;
-- discovery only exposes a rounded distance.

ALTER TABLE users
  ADD COLUMN IF NOT EXISTS bio                  TEXT,
  ADD COLUMN IF NOT EXISTS is_private           BOOLEAN     NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS discoverable         BOOLEAN     NOT NULL DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS interests            TEXT[]      NOT NULL DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS who_can_message      TEXT        NOT NULL DEFAULT 'everyone',
  ADD COLUMN IF NOT EXISTS show_activity_status BOOLEAN     NOT NULL DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS last_active_at       TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS location_lat         DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS location_lng         DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS location_updated_at  TIMESTAMPTZ;

DO $$ BEGIN
  ALTER TABLE users ADD CONSTRAINT users_bio_length CHECK (bio IS NULL OR char_length(bio) <= 300);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  ALTER TABLE users ADD CONSTRAINT users_who_can_message_check
    CHECK (who_can_message IN ('everyone', 'following', 'friends'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  ALTER TABLE users ADD CONSTRAINT users_location_pair
    CHECK ((location_lat IS NULL) = (location_lng IS NULL));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

ALTER TABLE business
  ADD COLUMN IF NOT EXISTS latitude  DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION;

-- Great-circle distance in km. IMMUTABLE so it can be inlined in ORDER BY.
CREATE OR REPLACE FUNCTION haversine_km(lat1 DOUBLE PRECISION, lng1 DOUBLE PRECISION,
                                        lat2 DOUBLE PRECISION, lng2 DOUBLE PRECISION)
RETURNS DOUBLE PRECISION LANGUAGE sql IMMUTABLE AS $$
  SELECT 2 * 6371 * asin(sqrt(
    power(sin(radians(lat2 - lat1) / 2), 2) +
    cos(radians(lat1)) * cos(radians(lat2)) * power(sin(radians(lng2 - lng1) / 2), 2)
  ))
$$;

-- ── Social graph ──────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS follow (
  follower_id UUID          NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  followee_id UUID          NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status      follow_status NOT NULL DEFAULT 'accepted',
  created_at  TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  accepted_at TIMESTAMPTZ,
  PRIMARY KEY (follower_id, followee_id),
  CONSTRAINT follow_not_self CHECK (follower_id <> followee_id)
);
CREATE INDEX IF NOT EXISTS follow_followee_idx ON follow (followee_id, status);

-- One row per pair, whoever asked first. Declining or unfriending deletes it.
CREATE TABLE IF NOT EXISTS friendship (
  requester_id UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  addressee_id UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status       follow_status NOT NULL DEFAULT 'pending',
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  accepted_at  TIMESTAMPTZ,
  PRIMARY KEY (requester_id, addressee_id),
  CONSTRAINT friendship_not_self CHECK (requester_id <> addressee_id)
);
CREATE UNIQUE INDEX IF NOT EXISTS friendship_pair_idx
  ON friendship (LEAST(requester_id, addressee_id), GREATEST(requester_id, addressee_id));
CREATE INDEX IF NOT EXISTS friendship_addressee_idx ON friendship (addressee_id, status);

CREATE TABLE IF NOT EXISTS user_block (
  blocker_id UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  blocked_id UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (blocker_id, blocked_id),
  CONSTRAINT user_block_not_self CHECK (blocker_id <> blocked_id)
);
CREATE INDEX IF NOT EXISTS user_block_blocked_idx ON user_block (blocked_id);

-- True when either user blocked the other.
CREATE OR REPLACE FUNCTION is_blocked_between(a UUID, b UUID) RETURNS BOOLEAN
LANGUAGE sql STABLE AS $$
  SELECT EXISTS (
    SELECT 1 FROM user_block
    WHERE (blocker_id = a AND blocked_id = b) OR (blocker_id = b AND blocked_id = a)
  )
$$;

CREATE TABLE IF NOT EXISTS user_report (
  id             UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id    UUID        REFERENCES users(id) ON DELETE SET NULL,
  target_user_id UUID        REFERENCES users(id) ON DELETE CASCADE,
  message_id     UUID,       -- FK added below, once `message` exists
  reason         TEXT        NOT NULL CHECK (reason IN ('spam', 'harassment', 'inappropriate', 'impersonation', 'other')),
  details        TEXT,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  resolved_at    TIMESTAMPTZ,
  resolved_by    UUID        REFERENCES users(id) ON DELETE SET NULL
);
CREATE INDEX IF NOT EXISTS user_report_open_idx ON user_report (created_at DESC) WHERE resolved_at IS NULL;

-- ── Chat ──────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS conversation (
  id              UUID              PRIMARY KEY DEFAULT gen_random_uuid(),
  kind            conversation_kind NOT NULL,
  title           VARCHAR(100),
  description     TEXT,
  avatar_url      TEXT,
  -- Direct chats only: "<smaller user id>:<larger user id>", so a pair has one chat.
  direct_key      TEXT              UNIQUE,
  created_by      UUID              REFERENCES users(id) ON DELETE SET NULL,
  created_at      TIMESTAMPTZ       NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ       NOT NULL DEFAULT NOW(),
  last_message_at TIMESTAMPTZ       NOT NULL DEFAULT NOW(),
  CONSTRAINT conversation_direct_key CHECK ((kind = 'direct') = (direct_key IS NOT NULL))
);

CREATE TABLE IF NOT EXISTS conversation_participant (
  conversation_id UUID               NOT NULL REFERENCES conversation(id) ON DELETE CASCADE,
  user_id         UUID               NOT NULL REFERENCES users(id)        ON DELETE CASCADE,
  role            participant_role   NOT NULL DEFAULT 'member',
  status          participant_status NOT NULL DEFAULT 'active',
  added_by        UUID               REFERENCES users(id) ON DELETE SET NULL,
  joined_at       TIMESTAMPTZ        NOT NULL DEFAULT NOW(),
  last_read_at    TIMESTAMPTZ,
  muted_until     TIMESTAMPTZ,
  archived_at     TIMESTAMPTZ,
  -- "Delete chat" for this user only: messages before this are hidden from them.
  cleared_at      TIMESTAMPTZ,
  PRIMARY KEY (conversation_id, user_id)
);
CREATE INDEX IF NOT EXISTS conversation_participant_user_idx ON conversation_participant (user_id);

CREATE TABLE IF NOT EXISTS message (
  id              UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID         NOT NULL REFERENCES conversation(id) ON DELETE CASCADE,
  sender_id       UUID         REFERENCES users(id) ON DELETE SET NULL,
  kind            message_kind NOT NULL DEFAULT 'text',
  body            TEXT,
  reply_to_id     UUID         REFERENCES message(id) ON DELETE SET NULL,
  -- Client-generated id so a retried send doesn't duplicate, and the sender
  -- can match its optimistic bubble to the realtime echo.
  client_id       TEXT,
  -- System messages: {event: 'created'|'added'|'removed'|'left'|'renamed'|..., ...}
  metadata        JSONB        NOT NULL DEFAULT '{}',
  created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  edited_at       TIMESTAMPTZ,
  deleted_at      TIMESTAMPTZ,
  CONSTRAINT message_body_length CHECK (body IS NULL OR char_length(body) <= 4000)
);
CREATE INDEX IF NOT EXISTS message_conversation_idx ON message (conversation_id, created_at DESC);
CREATE UNIQUE INDEX IF NOT EXISTS message_client_id_idx
  ON message (conversation_id, sender_id, client_id) WHERE client_id IS NOT NULL;

DO $$ BEGIN
  ALTER TABLE user_report ADD CONSTRAINT user_report_message_fk
    FOREIGN KEY (message_id) REFERENCES message(id) ON DELETE SET NULL;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Files live in the private `chat-media` bucket under <conversation_id>/.
-- The API hands out short-lived signed URLs to participants only.
CREATE TABLE IF NOT EXISTS message_attachment (
  id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id   UUID        NOT NULL REFERENCES message(id) ON DELETE CASCADE,
  storage_path TEXT        NOT NULL UNIQUE,
  mime_type    TEXT        NOT NULL,
  size_bytes   BIGINT      NOT NULL CHECK (size_bytes >= 0),
  file_name    TEXT,
  width        INT,
  height       INT,
  duration_ms  INT,
  position     INT         NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS message_attachment_message_idx ON message_attachment (message_id);

-- Upload slots handed out by the API (chat attachments, personal post media).
-- A message or post can only use a path its author reserved; slots never
-- claimed are swept, with their files, by the daily job.
CREATE TABLE IF NOT EXISTS media_upload (
  storage_path    TEXT        NOT NULL,
  bucket          TEXT        NOT NULL CHECK (bucket IN ('chat-media', 'user-media')),
  uploader_id     UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  conversation_id UUID        REFERENCES conversation(id) ON DELETE CASCADE,
  mime_type       TEXT        NOT NULL,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  claimed_at      TIMESTAMPTZ,
  PRIMARY KEY (bucket, storage_path),
  CONSTRAINT media_upload_chat_has_conversation CHECK ((bucket = 'chat-media') = (conversation_id IS NOT NULL))
);
CREATE INDEX IF NOT EXISTS media_upload_unclaimed_idx ON media_upload (created_at) WHERE claimed_at IS NULL;

CREATE TABLE IF NOT EXISTS message_reaction (
  message_id UUID          NOT NULL REFERENCES message(id) ON DELETE CASCADE,
  user_id    UUID          NOT NULL REFERENCES users(id)   ON DELETE CASCADE,
  reaction   reaction_type NOT NULL,
  created_at TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  PRIMARY KEY (message_id, user_id)
);

-- Both buckets are private: files are only reachable through signed URLs the
-- API issues to people allowed to see them. chat-media takes any file type.
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES
  ('chat-media', 'chat-media', FALSE, 52428800, NULL),
  ('user-media', 'user-media', FALSE, 52428800, ARRAY['image/*', 'video/*'])
ON CONFLICT (id) DO UPDATE
  SET public = FALSE,
      file_size_limit = EXCLUDED.file_size_limit,
      allowed_mime_types = EXCLUDED.allowed_mime_types;

-- ── Personal posts ────────────────────────────────────────────────────────────
-- A post without a business is a user's own post: it shows on their profile
-- grid and in feeds. Who can see it:
--   * the author and their accepted followers, always;
--   * everyone else only if the post is 'public' AND the account isn't private.
-- (A private account stays findable, and its comments and reactions on other
-- posts stay visible; only its own posts are hidden.) Business posts stay
-- public announcements.

ALTER TABLE post ALTER COLUMN business_id DROP NOT NULL;
ALTER TABLE post ADD COLUMN IF NOT EXISTS visibility TEXT NOT NULL DEFAULT 'public';
DO $$ BEGIN
  ALTER TABLE post ADD CONSTRAINT post_visibility_check
    CHECK (visibility IN ('public', 'followers'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  ALTER TABLE post ADD CONSTRAINT post_has_owner CHECK (business_id IS NOT NULL OR author_id IS NOT NULL);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
CREATE INDEX IF NOT EXISTS post_author_idx ON post (author_id, created_at DESC) WHERE business_id IS NULL;

-- Media on personal posts lives in user-media (storage_path set, url signed
-- per request); business post images keep their public url.
ALTER TABLE post_image
  ADD COLUMN IF NOT EXISTS media_type   TEXT NOT NULL DEFAULT 'image',
  ADD COLUMN IF NOT EXISTS storage_path TEXT,
  ADD COLUMN IF NOT EXISTS mime_type    TEXT,
  ADD COLUMN IF NOT EXISTS width        INT,
  ADD COLUMN IF NOT EXISTS height       INT,
  ADD COLUMN IF NOT EXISTS duration_ms  INT;
ALTER TABLE post_image ALTER COLUMN url DROP NOT NULL;
DO $$ BEGIN
  ALTER TABLE post_image ADD CONSTRAINT post_image_media_type_check CHECK (media_type IN ('image', 'video'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  ALTER TABLE post_image ADD CONSTRAINT post_image_has_source CHECK (url IS NOT NULL OR storage_path IS NOT NULL);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ── Post reactions (replace likes) ────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS post_reaction (
  post_id    UUID          NOT NULL REFERENCES post(id)  ON DELETE CASCADE,
  user_id    UUID          NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  reaction   reaction_type NOT NULL,
  created_at TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  PRIMARY KEY (post_id, user_id)
);

DO $$ BEGIN
  IF to_regclass('public.post_like') IS NOT NULL THEN
    INSERT INTO post_reaction (post_id, user_id, reaction, created_at)
    SELECT post_id, user_id, 'like', created_at FROM post_like
    ON CONFLICT DO NOTHING;
    DROP TABLE post_like;
  END IF;
END $$;

-- ── Threaded comments ─────────────────────────────────────────────────────────
-- depth 0 is a top-level comment; replies go at most 10 levels deep (0–9).
-- A comment with replies is soft-deleted (deleted_at) so the thread survives.

ALTER TABLE post_comment
  ADD COLUMN IF NOT EXISTS parent_id  UUID     REFERENCES post_comment(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS depth      SMALLINT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

DO $$ BEGIN
  ALTER TABLE post_comment ADD CONSTRAINT post_comment_depth_range CHECK (depth BETWEEN 0 AND 9);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE INDEX IF NOT EXISTS post_comment_parent_idx ON post_comment (parent_id);

CREATE OR REPLACE FUNCTION set_post_comment_depth() RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
  parent RECORD;
BEGIN
  IF NEW.parent_id IS NULL THEN
    NEW.depth := 0;
    RETURN NEW;
  END IF;
  SELECT post_id, depth INTO parent FROM post_comment WHERE id = NEW.parent_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'parent comment not found' USING ERRCODE = '23503';
  END IF;
  IF parent.post_id <> NEW.post_id THEN
    RAISE EXCEPTION 'reply must belong to the same post' USING ERRCODE = '23514';
  END IF;
  NEW.depth := parent.depth + 1;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS post_comment_depth ON post_comment;
CREATE TRIGGER post_comment_depth
  BEFORE INSERT OR UPDATE OF parent_id ON post_comment
  FOR EACH ROW EXECUTE FUNCTION set_post_comment_depth();

CREATE TABLE IF NOT EXISTS comment_reaction (
  comment_id UUID          NOT NULL REFERENCES post_comment(id) ON DELETE CASCADE,
  user_id    UUID          NOT NULL REFERENCES users(id)        ON DELETE CASCADE,
  reaction   reaction_type NOT NULL,
  created_at TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  PRIMARY KEY (comment_id, user_id)
);

-- ── Realtime authorization ────────────────────────────────────────────────────
-- Clients join *private* channels. Realtime asks Postgres (as `authenticated`,
-- with the user's JWT claims) whether the user may read/write the topic:
--   user:<users.id>        server → user: inbox updates, social events. Read only.
--   chat:<conversation id> server → participants: messages, edits, reactions,
--                          read receipts. Read only, so nobody can forge a
--                          message event.
--   chat-live:<conv id>    participants ↔ participants: typing + presence.
-- Server events are written with realtime.send() by the edge functions, in
-- the same transaction as the change they describe.

CREATE SCHEMA IF NOT EXISTS realtime_authz;
REVOKE ALL ON SCHEMA realtime_authz FROM PUBLIC;
GRANT USAGE ON SCHEMA realtime_authz TO authenticated;

CREATE OR REPLACE FUNCTION realtime_authz.can_use_topic(topic TEXT, write BOOLEAN)
RETURNS BOOLEAN
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  me UUID;
  conv TEXT;
BEGIN
  SELECT id INTO me FROM public.users WHERE auth_id = auth.uid();
  IF me IS NULL OR topic IS NULL THEN
    RETURN FALSE;
  END IF;

  IF topic = 'user:' || me::TEXT THEN
    RETURN NOT write;
  END IF;

  IF topic LIKE 'chat:%' THEN
    IF write THEN RETURN FALSE; END IF;
    conv := substr(topic, 6);
  ELSIF topic LIKE 'chat-live:%' THEN
    conv := substr(topic, 11);
  ELSE
    RETURN FALSE;
  END IF;

  IF conv !~ '^[0-9a-f-]{36}$' THEN
    RETURN FALSE;
  END IF;
  RETURN EXISTS (
    SELECT 1 FROM public.conversation_participant
    WHERE conversation_id = conv::UUID AND user_id = me
  );
END;
$$;

REVOKE ALL ON FUNCTION realtime_authz.can_use_topic(TEXT, BOOLEAN) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION realtime_authz.can_use_topic(TEXT, BOOLEAN) TO authenticated;

-- Hosted projects already have RLS on, and there realtime.messages is owned by
-- supabase_realtime_admin, so an unconditional ALTER fails for postgres.
DO $$
BEGIN
  IF NOT (SELECT relrowsecurity FROM pg_class WHERE oid = 'realtime.messages'::regclass) THEN
    ALTER TABLE realtime.messages ENABLE ROW LEVEL SECURITY;
  END IF;
END $$;

DROP POLICY IF EXISTS gym_bro_realtime_read ON realtime.messages;
CREATE POLICY gym_bro_realtime_read ON realtime.messages
  FOR SELECT TO authenticated
  USING (
    extension IN ('broadcast', 'presence')
    AND realtime_authz.can_use_topic(realtime.topic(), FALSE)
  );

DROP POLICY IF EXISTS gym_bro_realtime_write ON realtime.messages;
CREATE POLICY gym_bro_realtime_write ON realtime.messages
  FOR INSERT TO authenticated
  WITH CHECK (
    extension IN ('broadcast', 'presence')
    AND realtime_authz.can_use_topic(realtime.topic(), TRUE)
  );

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
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM anon, authenticated;
