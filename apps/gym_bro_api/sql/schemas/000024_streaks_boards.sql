-- ── Workout streaks, freezes, badges and gym boards ──────────────────────────
--
-- A streak counts finished workouts (not days). It ends on a miss:
-- * a planned workout (plan_entry) whose day passed without a workout, or that
--   was skipped;
-- * in a week with no planned workouts, finishing the week under the user's
--   weekly target (prorated in the week the streak started).
-- A banked freeze absorbs a miss instead. One freeze is earned per perfect
-- week (no misses, at least one workout); at most two are banked.
-- A day's outcome is final at the end of the next day (late logging allowed);
-- workout_streak keeps the state as of `settled_through` plus the live view.
-- Rules live in supabase/functions/_shared/streaks.ts.

ALTER TYPE notification_type ADD VALUE IF NOT EXISTS 'streak';

ALTER TABLE user_settings
  ADD COLUMN IF NOT EXISTS weekly_workout_target SMALLINT NOT NULL DEFAULT 3,
  ADD COLUMN IF NOT EXISTS show_on_gym_boards    BOOLEAN  NOT NULL DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS timezone              TEXT;
DO $$ BEGIN
  ALTER TABLE user_settings ADD CONSTRAINT user_settings_weekly_target
    CHECK (weekly_workout_target BETWEEN 1 AND 14);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- The current streak's badge, shown next to avatars everywhere.
ALTER TABLE users ADD COLUMN IF NOT EXISTS streak_tier TEXT;
DO $$ BEGIN
  ALTER TABLE users ADD CONSTRAINT users_streak_tier_check
    CHECK (streak_tier IN ('bronze', 'silver', 'gold', 'ruby', 'emerald', 'sapphire', 'diamond'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE TABLE IF NOT EXISTS workout_streak (
  user_id         UUID        PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  -- As of settled_through (inclusive).
  settled_current INT         NOT NULL DEFAULT 0,
  settled_since   DATE,
  settled_through DATE,
  -- Live: settled + workouts on the days still open.
  current         INT         NOT NULL DEFAULT 0,
  since           DATE,
  best            INT         NOT NULL DEFAULT 0,
  freezes         SMALLINT    NOT NULL DEFAULT 0 CHECK (freezes BETWEEN 0 AND 2),
  timezone        TEXT        NOT NULL DEFAULT 'UTC',
  -- Last day a "streak at risk" reminder went out (local date).
  reminded_on     DATE,
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS workout_streak_current_idx ON workout_streak (current DESC);

-- What happened to a streak, for its history and pushes.
CREATE TABLE IF NOT EXISTS streak_event (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  kind          TEXT        NOT NULL CHECK (kind IN ('freeze_earned', 'freeze_used', 'broken', 'tier')),
  on_date       DATE        NOT NULL,
  -- The streak at that moment (for 'broken': the length that was lost).
  streak        INT         NOT NULL,
  tier          TEXT,
  plan_entry_id UUID        REFERENCES plan_entry(id) ON DELETE SET NULL,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS streak_event_user_idx ON streak_event (user_id, on_date DESC, created_at DESC);
CREATE UNIQUE INDEX IF NOT EXISTS streak_event_tier_idx ON streak_event (user_id, tier) WHERE kind = 'tier';

ALTER TABLE workout_streak ENABLE ROW LEVEL SECURITY;
ALTER TABLE streak_event   ENABLE ROW LEVEL SECURITY;
