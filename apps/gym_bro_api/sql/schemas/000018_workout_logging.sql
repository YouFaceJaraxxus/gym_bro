-- ── Workout logging ───────────────────────────────────────────────────────────
-- Sessions can now be logged after the fact (from a calendar slot), and a
-- training's exercises are frozen once any session used it: past sessions
-- resolve their exercises through training_set / training_set_drop, so
-- replacing the sets would orphan them. Only the training's metadata (name,
-- description, notes, images, visibility, routines) stays editable.
-- * training_session_training_idx: "has this training been used?" and the
--   caller's recently used trainings.
-- * ssl_training_set_idx: the same check for set logs pointing at a training's
--   sets (sessions started without a training_id).

CREATE INDEX IF NOT EXISTS training_session_training_idx
  ON training_session (training_id, user_id, started_at DESC)
  WHERE training_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS ssl_training_set_idx
  ON session_set_log (training_set_id)
  WHERE training_set_id IS NOT NULL;
