-- ── Goals and daily targets ───────────────────────────────────────────────────
-- What onboarding asks and the Today screen measures against:
-- * fitness_goal and goal_weight_kg (the weight chart's goal line);
-- * water_goal_ml (NULL = worked out from body weight) and the quick-add
--   cup sizes, plus opt-in water reminders;
-- * onboarded_at: set when the first-run flow is finished or skipped. Everyone
--   who signed up before this migration counts as onboarded.

ALTER TABLE user_settings
  ADD COLUMN IF NOT EXISTS fitness_goal    TEXT,
  ADD COLUMN IF NOT EXISTS goal_weight_kg  NUMERIC(5, 1),
  ADD COLUMN IF NOT EXISTS water_goal_ml   INT,
  ADD COLUMN IF NOT EXISTS water_cups      INT[]   NOT NULL DEFAULT '{250,500}',
  ADD COLUMN IF NOT EXISTS water_reminders BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS onboarded_at    TIMESTAMPTZ;
DO $$ BEGIN
  ALTER TABLE user_settings ADD CONSTRAINT user_settings_fitness_goal
    CHECK (fitness_goal IN ('lose_fat', 'build_muscle', 'get_stronger', 'stay_fit', 'endurance'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  ALTER TABLE user_settings ADD CONSTRAINT user_settings_goal_weight
    CHECK (goal_weight_kg BETWEEN 20 AND 400);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  ALTER TABLE user_settings ADD CONSTRAINT user_settings_water_goal
    CHECK (water_goal_ml BETWEEN 500 AND 8000);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  ALTER TABLE user_settings ADD CONSTRAINT user_settings_water_cups
    CHECK (cardinality(water_cups) BETWEEN 1 AND 4 AND 50 <= ALL (water_cups) AND 2000 >= ALL (water_cups));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

INSERT INTO user_settings (user_id, onboarded_at)
SELECT id, NOW() FROM users
ON CONFLICT (user_id) DO UPDATE SET onboarded_at = COALESCE(user_settings.onboarded_at, NOW());
