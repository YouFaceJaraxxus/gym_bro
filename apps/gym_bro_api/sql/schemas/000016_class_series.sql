-- ── Class timetables, invites and trainer customers ─────────────────────────
-- * class_series: a class as trainers manage it — one or more start times per
--   day, once / daily / on chosen weekdays, in the timezone it was set up in.
--   Its gym_class rows (sessions) are generated 90 days ahead and topped up by
--   the jobs cron (see _shared/class_series.ts). Every gym_class belongs to one.
-- * gym_class.slot_at: the slot a session was generated for. Moving a single
--   session keeps it, so regeneration never re-creates a moved or cancelled one.
-- * gym_class.retired: cancelled because the timetable changed or was paused
--   (not by hand), so it comes back if the timetable fits it again.
-- * class_enrollment: a per-class invite (pending → accepted / declined). An
--   accepted enrollee is booked into every upcoming session of the class.
-- * trainer_customer: a trainer's clients. Pending until they accept an invite
--   (to be a customer, or to any of the trainer's classes); accepted customers
--   are coached like gym members (coachesUser).
-- Existing classes are backfilled: each weekly series becomes a weekly
-- class_series in UTC, each one-off class a one-off series with its own id.

CREATE TABLE IF NOT EXISTS class_series (
  id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  gym_id           UUID        NOT NULL REFERENCES gym(id) ON DELETE CASCADE,
  trainer_id       UUID        REFERENCES users(id) ON DELETE SET NULL,
  title            TEXT        NOT NULL,
  description      TEXT,
  location         TEXT,
  capacity         INT         NOT NULL CHECK (capacity > 0),
  duration_minutes INT         NOT NULL CHECK (duration_minutes BETWEEN 5 AND 1440),
  repeat           TEXT        NOT NULL CHECK (repeat IN ('none', 'daily', 'weekly')),
  weekdays         SMALLINT[]  NOT NULL DEFAULT '{}',   -- ISO: 1 = Monday … 7 = Sunday
  times            TIME[]      NOT NULL,                -- local start times, each day it runs
  timezone         TEXT        NOT NULL,                -- IANA name, e.g. Europe/Belgrade
  starts_on        DATE        NOT NULL,
  ends_on          DATE,                                -- NULL: keeps going
  active           BOOLEAN     NOT NULL DEFAULT TRUE,
  generated_until  DATE,                                -- last local date sessions exist for
  created_by       UUID        REFERENCES users(id) ON DELETE SET NULL,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT class_series_times CHECK (cardinality(times) BETWEEN 1 AND 12),
  CONSTRAINT class_series_weekdays CHECK (
    weekdays <@ ARRAY[1, 2, 3, 4, 5, 6, 7]::SMALLINT[] AND (repeat <> 'weekly' OR cardinality(weekdays) > 0)
  ),
  CONSTRAINT class_series_dates CHECK (ends_on IS NULL OR ends_on >= starts_on)
);
CREATE INDEX IF NOT EXISTS class_series_gym_idx     ON class_series (gym_id);
CREATE INDEX IF NOT EXISTS class_series_trainer_idx ON class_series (trainer_id);
CREATE INDEX IF NOT EXISTS class_series_topup_idx   ON class_series (generated_until) WHERE active;

ALTER TABLE gym_class ADD COLUMN IF NOT EXISTS slot_at TIMESTAMPTZ;
ALTER TABLE gym_class ADD COLUMN IF NOT EXISTS retired BOOLEAN NOT NULL DEFAULT FALSE;

-- ── Backfill ──────────────────────────────────────────────────────────────────

UPDATE gym_class SET slot_at = starts_at WHERE slot_at IS NULL;

INSERT INTO class_series (
  id, gym_id, trainer_id, title, description, location, capacity, duration_minutes,
  repeat, weekdays, times, timezone, starts_on, ends_on, generated_until, active, created_by, created_at
)
SELECT DISTINCT ON (c.series_id)
  c.series_id, c.gym_id, c.trainer_id, c.title, c.description, c.location, c.capacity,
  LEAST(1440, GREATEST(5, ROUND(EXTRACT(EPOCH FROM c.ends_at - c.starts_at) / 60)))::INT,
  'weekly',
  ARRAY[EXTRACT(ISODOW FROM c.starts_at AT TIME ZONE 'UTC')::SMALLINT],
  ARRAY[(c.starts_at AT TIME ZONE 'UTC')::TIME],
  'UTC',
  (MIN(c.starts_at) OVER w AT TIME ZONE 'UTC')::DATE,
  (MAX(c.starts_at) OVER w AT TIME ZONE 'UTC')::DATE,
  (MAX(c.starts_at) OVER w AT TIME ZONE 'UTC')::DATE,
  TRUE, c.created_by, c.created_at
FROM gym_class c
WHERE c.series_id IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM class_series s WHERE s.id = c.series_id)
WINDOW w AS (PARTITION BY c.series_id)
ORDER BY c.series_id, c.starts_at;

INSERT INTO class_series (
  id, gym_id, trainer_id, title, description, location, capacity, duration_minutes,
  repeat, weekdays, times, timezone, starts_on, ends_on, generated_until, active, created_by, created_at
)
SELECT
  c.id, c.gym_id, c.trainer_id, c.title, c.description, c.location, c.capacity,
  LEAST(1440, GREATEST(5, ROUND(EXTRACT(EPOCH FROM c.ends_at - c.starts_at) / 60)))::INT,
  'none', '{}', ARRAY[(c.starts_at AT TIME ZONE 'UTC')::TIME], 'UTC',
  (c.starts_at AT TIME ZONE 'UTC')::DATE, (c.starts_at AT TIME ZONE 'UTC')::DATE, (c.starts_at AT TIME ZONE 'UTC')::DATE,
  TRUE, c.created_by, c.created_at
FROM gym_class c
WHERE c.series_id IS NULL;

UPDATE gym_class SET series_id = id WHERE series_id IS NULL;

ALTER TABLE gym_class ALTER COLUMN series_id SET NOT NULL;
ALTER TABLE gym_class ALTER COLUMN slot_at SET NOT NULL;
DO $$ BEGIN
  ALTER TABLE gym_class ADD CONSTRAINT gym_class_series_fk
    FOREIGN KEY (series_id) REFERENCES class_series(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
CREATE UNIQUE INDEX IF NOT EXISTS gym_class_series_slot_idx ON gym_class (series_id, slot_at);

-- ── Invites and customers ─────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS class_enrollment (
  series_id    UUID        NOT NULL REFERENCES class_series(id) ON DELETE CASCADE,
  user_id      UUID        NOT NULL REFERENCES users(id)        ON DELETE CASCADE,
  status       TEXT        NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'declined')),
  invited_by   UUID        REFERENCES users(id) ON DELETE SET NULL,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  responded_at TIMESTAMPTZ,
  PRIMARY KEY (series_id, user_id)
);
CREATE INDEX IF NOT EXISTS class_enrollment_user_idx ON class_enrollment (user_id, status);

CREATE TABLE IF NOT EXISTS trainer_customer (
  trainer_id  UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  user_id     UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status      TEXT        NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted')),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  accepted_at TIMESTAMPTZ,
  PRIMARY KEY (trainer_id, user_id),
  CONSTRAINT trainer_customer_not_self CHECK (trainer_id <> user_id)
);
CREATE INDEX IF NOT EXISTS trainer_customer_user_idx ON trainer_customer (user_id, status);

ALTER TABLE class_series     ENABLE ROW LEVEL SECURITY;
ALTER TABLE class_enrollment ENABLE ROW LEVEL SECURITY;
ALTER TABLE trainer_customer ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON class_series, class_enrollment, trainer_customer FROM anon, authenticated;
