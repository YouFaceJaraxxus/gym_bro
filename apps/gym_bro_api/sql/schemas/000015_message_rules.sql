-- ── Who can message whom ──────────────────────────────────────────────────────
-- Replaces the three-way who_can_message setting with Instagram-style rules
-- (see directMessageStatus in _shared/social.ts):
-- * Blocked either way → no messages.
-- * Approved followers (and friends) → inbox.
-- * Everyone else → inbox for public accounts, message requests for private
--   ones — unless the recipient turned allow_non_follower_messages off, in
--   which case they can't message at all.
-- People who had narrowed who_can_message start with the toggle off.

ALTER TABLE users
  ADD COLUMN IF NOT EXISTS allow_non_follower_messages BOOLEAN NOT NULL DEFAULT TRUE;

DO $$ BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'users' AND column_name = 'who_can_message'
  ) THEN
    UPDATE users SET allow_non_follower_messages = FALSE WHERE who_can_message <> 'everyone';
  END IF;
END $$;

ALTER TABLE users DROP CONSTRAINT IF EXISTS users_who_can_message_check;
ALTER TABLE users DROP COLUMN IF EXISTS who_can_message;
