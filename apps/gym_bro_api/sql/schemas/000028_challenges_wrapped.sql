-- ── Challenges and the yearly Wrapped recap ──────────────────────────────────
--
-- A challenge is a time-boxed goal people join together: N workouts, active
-- days, training minutes, kilograms lifted or (gym challenges only) check-ins
-- between two local dates. business_id NULL = a platform-wide challenge (made
-- by super users, or automatically each month: auto_key 'monthly:YYYY-MM:<metric>'),
-- otherwise a gym challenge made by the gym's team and open to its active
-- members and team.
--
-- Progress is computed from real data with the streak engine's rules (finished
-- workouts with at least one set, logged by the end of the next day; days are
-- local to each participant) and cached in challenge_participant.progress.
-- completed_at is set once, when progress first reaches the target.
-- Rules live in supabase/functions/_shared/challenges.ts.
--
-- wrapped_notice remembers who was told their yearly recap is ready.

-- Enum values can't be added and used in one transaction: these run on their
-- own (migrate.sh doesn't wrap files in a transaction).
ALTER TYPE notification_type ADD VALUE IF NOT EXISTS 'challenge';
ALTER TYPE notification_type ADD VALUE IF NOT EXISTS 'wrapped';

CREATE TABLE IF NOT EXISTS challenge (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  -- NULL: platform-wide. Otherwise the gym (a business with has_gym).
  business_id UUID        REFERENCES business(id) ON DELETE CASCADE,
  created_by  UUID        REFERENCES users(id) ON DELETE SET NULL,
  title       TEXT        NOT NULL CHECK (char_length(title) BETWEEN 1 AND 80),
  description TEXT        CHECK (char_length(description) <= 1000),
  metric      TEXT        NOT NULL
                          CHECK (metric IN ('workouts', 'active_days', 'minutes', 'volume_kg', 'check_ins')),
  target      INT         NOT NULL CHECK (target BETWEEN 1 AND 10000000),
  -- Inclusive local dates.
  starts_on   DATE        NOT NULL,
  ends_on     DATE        NOT NULL,
  -- Automatic monthly challenges: one per key, however often the job runs.
  auto_key    TEXT        UNIQUE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT challenge_window CHECK (ends_on >= starts_on AND ends_on - starts_on <= 366),
  CONSTRAINT challenge_check_ins_need_gym CHECK (metric <> 'check_ins' OR business_id IS NOT NULL)
);
CREATE INDEX IF NOT EXISTS challenge_business_idx ON challenge (business_id, ends_on DESC);
CREATE INDEX IF NOT EXISTS challenge_window_idx   ON challenge (ends_on DESC, starts_on);

CREATE TABLE IF NOT EXISTS challenge_participant (
  challenge_id UUID        NOT NULL REFERENCES challenge(id) ON DELETE CASCADE,
  user_id      UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  joined_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  -- Cached; recomputed while the challenge is live (see _shared/challenges.ts).
  progress     INT         NOT NULL DEFAULT 0,
  completed_at TIMESTAMPTZ,
  PRIMARY KEY (challenge_id, user_id)
);
CREATE INDEX IF NOT EXISTS challenge_participant_user_idx
  ON challenge_participant (user_id, completed_at DESC NULLS LAST);

-- One "your Wrapped is ready" notification per user and year.
CREATE TABLE IF NOT EXISTS wrapped_notice (
  user_id UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  year    SMALLINT    NOT NULL,
  sent_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (user_id, year)
);

ALTER TABLE challenge             ENABLE ROW LEVEL SECURITY;
ALTER TABLE challenge_participant ENABLE ROW LEVEL SECURITY;
ALTER TABLE wrapped_notice        ENABLE ROW LEVEL SECURITY;
