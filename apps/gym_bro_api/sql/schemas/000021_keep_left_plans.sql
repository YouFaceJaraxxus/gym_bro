-- ── Leaving a routine / meal plan keeps its history ───────────────────────────
-- Leaving (or a coach removing an assignment) no longer deletes it: the
-- assignment is ended (left_at, left_by) and only its planned entries still
-- to come that weren't logged are dropped. Past entries — and the sessions
-- and food logs that confirmed them — keep their link.
-- * An ended assignment no longer grants access to a private routine / meal
--   plan, generates entries or shows in the "assigned" lists.
-- * Plan entries outlive their assignment, routine / meal plan and training:
--   those links become NULL on delete, and the entry keeps the names it was
--   planned with (source_id / source_name / training_name /
--   daily_meal_plan_name) so the app can still say what it was.

ALTER TABLE routine_assignment
  ADD COLUMN IF NOT EXISTS left_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS left_by UUID REFERENCES users(id) ON DELETE SET NULL;
ALTER TABLE meal_plan_assignment
  ADD COLUMN IF NOT EXISTS left_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS left_by UUID REFERENCES users(id) ON DELETE SET NULL;

ALTER TABLE plan_entry
  ADD COLUMN IF NOT EXISTS source_id            UUID,
  ADD COLUMN IF NOT EXISTS source_name          TEXT,
  ADD COLUMN IF NOT EXISTS training_name        TEXT,
  ADD COLUMN IF NOT EXISTS daily_meal_plan_name TEXT;

UPDATE plan_entry e SET source_id = r.id, source_name = r.name
  FROM routine_assignment a JOIN routine r ON r.id = a.routine_id
 WHERE a.id = e.routine_assignment_id AND e.source_id IS NULL;
UPDATE plan_entry e SET source_id = m.id, source_name = m.name
  FROM meal_plan_assignment a JOIN meal_plan m ON m.id = a.meal_plan_id
 WHERE a.id = e.meal_plan_assignment_id AND e.source_id IS NULL;
UPDATE plan_entry e SET training_name = t.name
  FROM training t WHERE t.id = e.training_id AND e.training_name IS NULL;
UPDATE plan_entry e SET daily_meal_plan_name = d.name
  FROM daily_meal_plan d WHERE d.id = e.daily_meal_plan_id AND e.daily_meal_plan_name IS NULL;

ALTER TABLE plan_entry DROP CONSTRAINT IF EXISTS plan_entry_routine_assignment_id_fkey;
ALTER TABLE plan_entry ADD CONSTRAINT plan_entry_routine_assignment_id_fkey
  FOREIGN KEY (routine_assignment_id) REFERENCES routine_assignment(id) ON DELETE SET NULL;
ALTER TABLE plan_entry DROP CONSTRAINT IF EXISTS plan_entry_meal_plan_assignment_id_fkey;
ALTER TABLE plan_entry ADD CONSTRAINT plan_entry_meal_plan_assignment_id_fkey
  FOREIGN KEY (meal_plan_assignment_id) REFERENCES meal_plan_assignment(id) ON DELETE SET NULL;

-- The source assignment may be gone now; the kind still decides which one it was.
ALTER TABLE plan_entry DROP CONSTRAINT IF EXISTS plan_entry_source;
ALTER TABLE plan_entry ADD CONSTRAINT plan_entry_source CHECK (
  (kind = 'workout' AND meal_plan_assignment_id IS NULL)
  OR (kind = 'meal' AND routine_assignment_id IS NULL AND meal_slot IS NOT NULL)
);
