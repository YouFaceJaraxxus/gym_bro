import { sql } from "npm:kysely@^0.27";

// ── Logged drops, resolved to their exercise ──────────────────────────────────
// Weights and reps live on session_drop_log. The exercise a drop belongs to is:
//   1. session_set_log.exercise_id            (free / ad-hoc sets), else
//   2. the planned drop's slot                (drop → training_set_drop →
//      training_set_exercise.exercise_id), else
//   3. the planned set's only exercise        (set log → training_set with a
//      single training_set_exercise row; ambiguous supersets stay NULL).
//
// Each row: session_id, started_at, set_log_id, exercise_id, rep_type, reps,
// weight_kg, e1rm (Epley, count reps ≥ 1 with a weight), volume_kg
// (weight × reps for count sets), counted_reps.

/** SELECT producing one row per logged drop of `userId`, usable in a CTE. */
export function userDropRows(userId: string) {
  return sql`
    SELECT
      ts.id          AS session_id,
      ts.started_at  AS started_at,
      sl.id          AS set_log_id,
      COALESCE(
        sl.exercise_id,
        tse.exercise_id,
        (SELECT CASE WHEN COUNT(*) = 1 THEN (ARRAY_AGG(x.exercise_id))[1] END
           FROM training_set_exercise x
          WHERE x.training_set_id = sl.training_set_id)
      )                       AS exercise_id,
      dl.rep_type_actual      AS rep_type,
      dl.rep_count_actual     AS reps,
      dl.weight_kg_actual     AS weight_kg,
      CASE
        WHEN dl.rep_type_actual = 'count' AND dl.rep_count_actual >= 1 AND dl.weight_kg_actual > 0
        THEN dl.weight_kg_actual * (1 + dl.rep_count_actual / 30.0)
      END                     AS e1rm,
      CASE
        WHEN dl.rep_type_actual = 'count' AND dl.rep_count_actual > 0 AND dl.weight_kg_actual IS NOT NULL
        THEN dl.weight_kg_actual * dl.rep_count_actual
        ELSE 0
      END                     AS volume_kg,
      CASE
        WHEN dl.rep_type_actual = 'count' AND dl.rep_count_actual > 0 THEN dl.rep_count_actual
        ELSE 0
      END                     AS counted_reps
    FROM training_session ts
    JOIN session_set_log sl        ON sl.session_id = ts.id
    JOIN session_drop_log dl       ON dl.session_set_log_id = sl.id
    LEFT JOIN training_set_drop tsd     ON tsd.id = dl.training_set_drop_id
    LEFT JOIN training_set_exercise tse ON tse.id = tsd.training_set_exercise_id
    WHERE ts.user_id = ${userId}
  `;
}

/** Epley estimated one-rep max; null unless reps ≥ 1 and weight > 0. */
export function epley(weightKg: number | null | undefined, reps: number | null | undefined): number | null {
  if (weightKg == null || reps == null || reps < 1 || weightKg <= 0) return null;
  return weightKg * (1 + reps / 30);
}
