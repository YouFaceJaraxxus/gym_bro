-- ── Water tracking ───────────────────────────────────────────────────────────
-- One row per drink. Days are the user's local days (the app sends its IANA
-- zone, else user_settings.timezone, else UTC), so only the instant is stored.
-- The daily goal is not stored per day: user_settings.water_goal_ml, or ~35 ml
-- per kg of the latest body weight, plus 500 ml on a day with a finished
-- workout (rules in supabase/functions/water-logs/index.ts).

CREATE TABLE IF NOT EXISTS water_log (
  id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  ml         INT         NOT NULL CHECK (ml BETWEEN 1 AND 3000),
  logged_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS water_log_user_idx ON water_log (user_id, logged_at DESC);

ALTER TABLE water_log ENABLE ROW LEVEL SECURITY;
