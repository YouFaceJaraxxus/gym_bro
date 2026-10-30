-- ── Planned workouts & meals, typed posts, tags ──────────────────────────────

ALTER TYPE notification_type ADD VALUE IF NOT EXISTS 'mention';
ALTER TYPE notification_type ADD VALUE IF NOT EXISTS 'photo_tag';

-- ── Plan entries ──────────────────────────────────────────────────────────────
-- One planned workout or meal on someone's calendar, generated from their
-- routine / meal plan assignments (plan-entries function, lazily per
-- requested window, like class sessions). Each one can then be edited on its
-- own (time, length, training, note) or skipped; regeneration never touches
-- an existing row, so edits stick.
-- * slot_key: the generation key within the assignment —
--   'YYYY-MM-DD:<routine_training.id>' or 'YYYY-MM-DD:<meal_slot_type>'.
-- * Done = confirmed by logging it: a training_session with this
--   plan_entry_id (workouts) or food_log rows with it (meals).
-- * Assignments carry the timezone (and a workout time) the entries are
--   generated in.

ALTER TABLE routine_assignment
  ADD COLUMN IF NOT EXISTS timezone     TEXT,
  ADD COLUMN IF NOT EXISTS workout_time TIME NOT NULL DEFAULT '18:00';
ALTER TABLE meal_plan_assignment ADD COLUMN IF NOT EXISTS timezone TEXT;

CREATE TABLE IF NOT EXISTS plan_entry (
  id                      UUID           PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id                 UUID           NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  kind                    TEXT           NOT NULL CHECK (kind IN ('workout', 'meal')),
  routine_assignment_id   UUID           REFERENCES routine_assignment(id)   ON DELETE CASCADE,
  meal_plan_assignment_id UUID           REFERENCES meal_plan_assignment(id) ON DELETE CASCADE,
  slot_key                TEXT           NOT NULL,
  plan_date               DATE           NOT NULL,
  starts_at               TIMESTAMPTZ    NOT NULL,
  duration_minutes        INT            NOT NULL DEFAULT 60 CHECK (duration_minutes BETWEEN 5 AND 600),
  training_id             UUID           REFERENCES training(id)        ON DELETE SET NULL,
  daily_meal_plan_id      UUID           REFERENCES daily_meal_plan(id) ON DELETE SET NULL,
  meal_slot               meal_slot_type,
  note                    TEXT           CHECK (char_length(note) <= 1000),
  skipped                 BOOLEAN        NOT NULL DEFAULT FALSE,
  edited                  BOOLEAN        NOT NULL DEFAULT FALSE,
  created_at              TIMESTAMPTZ    NOT NULL DEFAULT NOW(),
  updated_at              TIMESTAMPTZ    NOT NULL DEFAULT NOW(),
  CONSTRAINT plan_entry_source CHECK (
    (kind = 'workout' AND routine_assignment_id IS NOT NULL AND meal_plan_assignment_id IS NULL)
    OR (kind = 'meal' AND meal_plan_assignment_id IS NOT NULL AND routine_assignment_id IS NULL
        AND meal_slot IS NOT NULL)
  )
);
CREATE UNIQUE INDEX IF NOT EXISTS plan_entry_routine_slot_idx
  ON plan_entry (routine_assignment_id, slot_key) WHERE routine_assignment_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS plan_entry_meal_slot_idx
  ON plan_entry (meal_plan_assignment_id, slot_key) WHERE meal_plan_assignment_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS plan_entry_user_time_idx ON plan_entry (user_id, starts_at);

ALTER TABLE training_session
  ADD COLUMN IF NOT EXISTS plan_entry_id UUID REFERENCES plan_entry(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS training_session_plan_entry_idx
  ON training_session (plan_entry_id) WHERE plan_entry_id IS NOT NULL;

-- Food logs get a time of day (for the calendar) and the plan entry they
-- confirmed. eaten_at NULL = older rows; the app places those at the slot's
-- usual time.
ALTER TABLE food_log
  ADD COLUMN IF NOT EXISTS eaten_at      TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS plan_entry_id UUID REFERENCES plan_entry(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS food_log_plan_entry_idx ON food_log (plan_entry_id) WHERE plan_entry_id IS NOT NULL;

-- ── Post types ────────────────────────────────────────────────────────────────
-- A post can share something: a logged workout (training_session) or meal
-- (food logs of one day + slot), or a library item. `attachment` is a
-- snapshot built by the server when posting (title, stats, …), so the post
-- shows what was shared even if the source later changes or is private;
-- ref_id points at the source for opening it (null for meals).

ALTER TABLE post
  ADD COLUMN IF NOT EXISTS post_type  TEXT  NOT NULL DEFAULT 'generic',
  ADD COLUMN IF NOT EXISTS ref_id     UUID,
  ADD COLUMN IF NOT EXISTS attachment JSONB;
DO $$ BEGIN
  ALTER TABLE post ADD CONSTRAINT post_type_check CHECK (post_type IN (
    'generic', 'workout', 'meal', 'exercise', 'training', 'routine',
    'recipe', 'food_item', 'daily_meal_plan', 'meal_plan'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  ALTER TABLE post ADD CONSTRAINT post_attachment_present
    CHECK ((post_type = 'generic') = (attachment IS NULL));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ── Tags ──────────────────────────────────────────────────────────────────────
-- Instagram-style:
-- * mentions — "@[Name](user:<id>)" (or business:/shop_item:) markup in a
--   caption (comment_id NULL) or a comment; the posts function keeps these
--   rows in sync with the text.
-- * photo tags — a person pinned on one photo/video at (x, y), each 0–1 from
--   the top-left. The tagged person can remove themself.
-- A person tagged either way can see the post, whatever its visibility.

CREATE TABLE IF NOT EXISTS post_tag (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id       UUID        NOT NULL REFERENCES post(id)         ON DELETE CASCADE,
  post_image_id UUID        REFERENCES post_image(id)            ON DELETE CASCADE,
  comment_id    UUID        REFERENCES post_comment(id)          ON DELETE CASCADE,
  kind          TEXT        NOT NULL CHECK (kind IN ('user', 'business', 'shop_item')),
  user_id       UUID        REFERENCES users(id)                 ON DELETE CASCADE,
  business_id   UUID        REFERENCES business(id)              ON DELETE CASCADE,
  shop_item_id  UUID        REFERENCES shop_item(id)             ON DELETE CASCADE,
  x             REAL        CHECK (x BETWEEN 0 AND 1),
  y             REAL        CHECK (y BETWEEN 0 AND 1),
  created_by    UUID        REFERENCES users(id)                 ON DELETE SET NULL,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT post_tag_target CHECK (
    (kind = 'user'      AND user_id IS NOT NULL AND business_id IS NULL AND shop_item_id IS NULL) OR
    (kind = 'business'  AND business_id IS NOT NULL AND user_id IS NULL AND shop_item_id IS NULL) OR
    (kind = 'shop_item' AND shop_item_id IS NOT NULL AND user_id IS NULL AND business_id IS NULL)
  ),
  -- A pin is a person on a photo; a mention is in the caption or a comment.
  CONSTRAINT post_tag_shape CHECK (
    (post_image_id IS NOT NULL AND comment_id IS NULL AND kind = 'user' AND x IS NOT NULL AND y IS NOT NULL) OR
    (post_image_id IS NULL AND x IS NULL AND y IS NULL)
  )
);
CREATE INDEX IF NOT EXISTS post_tag_post_idx    ON post_tag (post_id);
CREATE INDEX IF NOT EXISTS post_tag_user_idx    ON post_tag (user_id, created_at DESC) WHERE user_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS post_tag_comment_idx ON post_tag (comment_id) WHERE comment_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS post_tag_pin_idx
  ON post_tag (post_image_id, user_id) WHERE post_image_id IS NOT NULL;

ALTER TABLE plan_entry ENABLE ROW LEVEL SECURITY;
ALTER TABLE post_tag   ENABLE ROW LEVEL SECURITY;
