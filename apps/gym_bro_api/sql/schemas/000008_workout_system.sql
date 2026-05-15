-- ── Enums ─────────────────────────────────────────────────────────────────────

CREATE TYPE muscle_group AS ENUM (
  -- Chest
  'chest_all', 'chest_upper', 'chest_lower',
  -- Back
  'back_all', 'back_upper', 'back_mid', 'back_lower',
  'back_rhomboids', 'back_traps', 'back_lats',
  -- Deltoids
  'delts_all', 'delts_front', 'delts_medial', 'delts_rear',
  -- Arms
  'biceps',
  'triceps_all', 'triceps_long', 'triceps_lateral', 'triceps_medial',
  'forearms_all', 'forearms_top', 'forearms_bottom',
  -- Core
  'abs_upper', 'abs_lower', 'abs_obliques',
  -- Lower body
  'quads_all', 'quads_medial', 'quads_lateral',
  'hamstrings',
  'glutes_all', 'glutes_medius', 'glutes_minimus', 'glutes_maximus',
  'calves',
  -- Other
  'neck'
);

CREATE TYPE workout_set_type AS ENUM (
  'standard',  -- single exercise, one or more straight sets
  'superset',  -- two or more exercises back-to-back with no rest between
  'dropset',   -- single exercise repeated with progressively reduced weight
  'circuit'    -- multiple exercises cycled with brief rest between each
);

CREATE TYPE rep_type AS ENUM (
  'count',       -- specific number of reps
  'failure',     -- go until muscular failure
  'unspecified'  -- no specific target (e.g. "move for 30 seconds")
);

CREATE TYPE body_side AS ENUM (
  'both',   -- both limbs simultaneously or symmetrically
  'left',   -- left side only
  'right'   -- right side only
);

CREATE TYPE routine_schedule_type AS ENUM (
  'fixed_weeks',  -- N-week rotating schedule; each day slot gets one training
  'wildcard'      -- unstructured list of trainings in any order
);

-- ── Exercise ──────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS exercise (
  id                UUID           PRIMARY KEY DEFAULT gen_random_uuid(),
  name              TEXT           NOT NULL,
  description       TEXT,
  note              TEXT,
  image_url         TEXT,
  video_url         TEXT,
  author_id         UUID           REFERENCES users(id) ON DELETE SET NULL,
  primary_muscles   muscle_group[] NOT NULL DEFAULT '{}',
  secondary_muscles muscle_group[] NOT NULL DEFAULT '{}',
  is_public         BOOLEAN        NOT NULL DEFAULT TRUE,
  created_at        TIMESTAMPTZ    NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ    NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS exercise_author_id_idx   ON exercise(author_id);
CREATE INDEX IF NOT EXISTS exercise_is_public_idx   ON exercise(is_public) WHERE is_public = TRUE;
CREATE INDEX IF NOT EXISTS exercise_name_search_idx ON exercise USING GIN (to_tsvector('english', name));

-- ── Training ──────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS training (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  name        TEXT        NOT NULL,
  description TEXT,
  notes       TEXT,
  author_id   UUID        REFERENCES users(id) ON DELETE SET NULL,
  is_public   BOOLEAN     NOT NULL DEFAULT FALSE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS training_author_id_idx ON training(author_id);
CREATE INDEX IF NOT EXISTS training_public_idx    ON training(is_public) WHERE is_public = TRUE;

CREATE TABLE IF NOT EXISTS training_image (
  id           UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
  training_id  UUID    NOT NULL REFERENCES training(id) ON DELETE CASCADE,
  url          TEXT    NOT NULL,
  is_thumbnail BOOLEAN NOT NULL DEFAULT FALSE,
  position     INT     NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS training_image_training_id_idx ON training_image(training_id);

-- ── Training sets (inline, owned by a training) ───────────────────────────────

CREATE TABLE IF NOT EXISTS training_set (
  id           UUID             PRIMARY KEY DEFAULT gen_random_uuid(),
  training_id  UUID             NOT NULL REFERENCES training(id) ON DELETE CASCADE,
  type         workout_set_type NOT NULL DEFAULT 'standard',
  position     INT              NOT NULL DEFAULT 0,
  rest_seconds INT,
  note         TEXT
);

CREATE INDEX IF NOT EXISTS training_set_training_id_idx ON training_set(training_id);

-- One exercise slot per row within a set.
-- Supersets have multiple rows (one per exercise); standard/dropsets have one.
CREATE TABLE IF NOT EXISTS training_set_exercise (
  id                         UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
  training_set_id            UUID    NOT NULL REFERENCES training_set(id) ON DELETE CASCADE,
  exercise_id                UUID    NOT NULL REFERENCES exercise(id) ON DELETE RESTRICT,
  position                   INT     NOT NULL DEFAULT 0,
  -- When true the user alternates sides each rep (e.g. left/right dumbbell curl)
  is_alternating             BOOLEAN NOT NULL DEFAULT FALSE,
  rest_between_drops_seconds INT,
  note                       TEXT
);

CREATE INDEX IF NOT EXISTS tse_set_id_idx ON training_set_exercise(training_set_id);

-- One drop per row within an exercise slot.
-- Standard sets have drop_number = 0; dropsets have drop_number 0, 1, 2, …
CREATE TABLE IF NOT EXISTS training_set_drop (
  id                       UUID      PRIMARY KEY DEFAULT gen_random_uuid(),
  training_set_exercise_id UUID      NOT NULL REFERENCES training_set_exercise(id) ON DELETE CASCADE,
  drop_number              INT       NOT NULL DEFAULT 0,
  rep_type                 rep_type  NOT NULL DEFAULT 'count',
  rep_count                INT,       -- NULL when rep_type != 'count'
  weight_kg                NUMERIC(7,2),
  side                     body_side NOT NULL DEFAULT 'both',
  note                     TEXT
);

CREATE INDEX IF NOT EXISTS tsd_exercise_id_idx ON training_set_drop(training_set_exercise_id);

-- ── Routine ───────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS routine (
  id            UUID                  PRIMARY KEY DEFAULT gen_random_uuid(),
  name          TEXT                  NOT NULL,
  description   TEXT,
  notes         TEXT,
  author_id     UUID                  REFERENCES users(id) ON DELETE SET NULL,
  is_public     BOOLEAN               NOT NULL DEFAULT FALSE,
  schedule_type routine_schedule_type NOT NULL DEFAULT 'wildcard',
  num_weeks     INT,                   -- NULL for wildcard routines
  created_at    TIMESTAMPTZ           NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ           NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS routine_author_id_idx ON routine(author_id);
CREATE INDEX IF NOT EXISTS routine_public_idx    ON routine(is_public) WHERE is_public = TRUE;

CREATE TABLE IF NOT EXISTS routine_image (
  id           UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
  routine_id   UUID    NOT NULL REFERENCES routine(id) ON DELETE CASCADE,
  url          TEXT    NOT NULL,
  is_thumbnail BOOLEAN NOT NULL DEFAULT FALSE,
  position     INT     NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS routine_image_routine_id_idx ON routine_image(routine_id);

-- Trainings assigned to a routine.
-- fixed_weeks: week_number + day_of_week define the slot; position used as tiebreak.
-- wildcard:    week_number and day_of_week are NULL; position defines order.
CREATE TABLE IF NOT EXISTS routine_training (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  routine_id  UUID NOT NULL REFERENCES routine(id) ON DELETE CASCADE,
  training_id UUID NOT NULL REFERENCES training(id) ON DELETE RESTRICT,
  week_number INT  CHECK (week_number >= 1),
  day_of_week INT  CHECK (day_of_week BETWEEN 1 AND 7),
  position    INT  NOT NULL DEFAULT 0,
  note        TEXT
);

CREATE INDEX IF NOT EXISTS routine_training_routine_id_idx ON routine_training(routine_id);

-- ── Training session ──────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS training_session (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  trainer_id  UUID        REFERENCES users(id) ON DELETE SET NULL,
  training_id UUID        REFERENCES training(id) ON DELETE SET NULL,
  started_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ended_at    TIMESTAMPTZ,
  notes       TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS session_user_id_idx ON training_session(user_id, started_at DESC);

-- One row per set group executed in a session.
-- training_set_id links to the planned set if following a training program;
-- exercise_id is set for ad-hoc (unplanned) single-exercise sets.
CREATE TABLE IF NOT EXISTS session_set_log (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id      UUID NOT NULL REFERENCES training_session(id) ON DELETE CASCADE,
  training_set_id UUID REFERENCES training_set(id) ON DELETE SET NULL,
  exercise_id     UUID REFERENCES exercise(id) ON DELETE SET NULL,
  position        INT  NOT NULL DEFAULT 0,
  note            TEXT
);

CREATE INDEX IF NOT EXISTS ssl_session_id_idx ON session_set_log(session_id);

-- Actual performance per drop.
-- training_set_drop_id links to the planned drop when following a program.
CREATE TABLE IF NOT EXISTS session_drop_log (
  id                   UUID      PRIMARY KEY DEFAULT gen_random_uuid(),
  session_set_log_id   UUID      NOT NULL REFERENCES session_set_log(id) ON DELETE CASCADE,
  training_set_drop_id UUID      REFERENCES training_set_drop(id) ON DELETE SET NULL,
  drop_number          INT       NOT NULL DEFAULT 0,
  rep_type_actual      rep_type  NOT NULL DEFAULT 'count',
  rep_count_actual     INT,
  weight_kg_actual     NUMERIC(7,2),
  side                 body_side NOT NULL DEFAULT 'both',
  note                 TEXT
);

CREATE INDEX IF NOT EXISTS sdl_set_log_id_idx ON session_drop_log(session_set_log_id);
