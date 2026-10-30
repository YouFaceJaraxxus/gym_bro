import { type Kysely, sql } from "npm:kysely@^0.27";
import { db } from "./config.ts";
import { jsonError } from "./auth.ts";
import type { Database } from "../../types/schema/public.ts";

// Planned workouts and meals (plan_entry), generated from routine and meal
// plan assignments the way class sessions are generated from a timetable:
// lazily, for the window someone looks at, keyed by (assignment, slot_key) so
// a row is created once and then belongs to the user — edits and skips stick.
//
// * Workouts: a fixed-weeks routine's routine_training rows. week_number
//   counts Monday-based weeks since the start week, mod num_weeks (so the
//   routine repeats until end_date); day_of_week is the ISO weekday. Several
//   trainings on one day are spaced 90 minutes apart from workout_time.
// * Meals: each slot of the day's daily meal plan, at the slot's usual time.
//   Only the most recently started meal plan active on a day counts (as in
//   the food diary).

/** Usual time and length of each meal slot. */
const MEAL_SLOT_TIMES = sql`(VALUES
  ('breakfast'::meal_slot_type,       '08:00'::time, 30),
  ('morning_snack'::meal_slot_type,   '10:30'::time, 15),
  ('lunch'::meal_slot_type,           '13:00'::time, 45),
  ('afternoon_snack'::meal_slot_type, '16:00'::time, 15),
  ('pre_workout'::meal_slot_type,     '17:00'::time, 15),
  ('post_workout'::meal_slot_type,    '19:30'::time, 15),
  ('dinner'::meal_slot_type,          '20:00'::time, 45),
  ('evening_snack'::meal_slot_type,   '21:30'::time, 15)
) AS slot_time(slot, at, minutes)`;

export const DEFAULT_WORKOUT_MINUTES = 60;

/** Longest window generated in one go. */
export const MAX_WINDOW_DAYS = 62;

/** An IANA zone from a body: undefined when absent, null to clear. */
export function readTimezone(v: unknown): string | null | undefined | Response {
  if (v === undefined) return undefined;
  if (v === null || v === "") return null;
  if (typeof v !== "string" || !isTimezone(v)) return jsonError("timezone must be an IANA zone, e.g. Europe/Belgrade", 400);
  return v;
}

export function isTimezone(v: string): boolean {
  try {
    new Intl.DateTimeFormat("en-US", { timeZone: v });
    return v.length <= 64;
  } catch {
    return false;
  }
}

/** 'HH:MM' from a body: undefined when absent. */
export function readTimeOfDay(v: unknown, field: string): string | undefined | Response {
  if (v === undefined || v === null) return undefined;
  if (typeof v !== "string" || !/^([01]\d|2[0-3]):[0-5]\d$/.test(v)) return jsonError(`${field} must be HH:MM`, 400);
  return v;
}

/**
 * After an assignment's dates or times change: drops its planned entries
 * still to come that the user hasn't edited, skipped or logged, so the next
 * read regenerates them from the new settings.
 */
export async function forgetUntouchedEntries(
  trx: Kysely<Database>,
  source: { routineAssignmentId?: string; mealPlanAssignmentId?: string },
) {
  let q = trx.deleteFrom("plan_entry")
    .where("edited", "=", false)
    .where("skipped", "=", false)
    .where("starts_at", ">", sql<string>`now()`)
    .where(sql<boolean>`NOT EXISTS (SELECT 1 FROM training_session s WHERE s.plan_entry_id = plan_entry.id)`)
    .where(sql<boolean>`NOT EXISTS (SELECT 1 FROM food_log f WHERE f.plan_entry_id = plan_entry.id)`);
  if (source.routineAssignmentId) q = q.where("routine_assignment_id", "=", source.routineAssignmentId);
  if (source.mealPlanAssignmentId) q = q.where("meal_plan_assignment_id", "=", source.mealPlanAssignmentId);
  await q.execute();
}

/**
 * Ends an assignment (the user left, or the assigner removed it) instead of
 * deleting it: its past entries and what was logged against them stay; the
 * ones still to come that nothing was logged against are dropped.
 */
export async function endAssignment(
  trx: Kysely<Database>,
  source: { routineAssignmentId?: string; mealPlanAssignmentId?: string },
  byUserId: string,
) {
  const set = { left_at: sql<string>`now()`, left_by: byUserId };
  if (source.routineAssignmentId) {
    await trx.updateTable("routine_assignment").set(set).where("id", "=", source.routineAssignmentId).execute();
  }
  if (source.mealPlanAssignmentId) {
    await trx.updateTable("meal_plan_assignment").set(set).where("id", "=", source.mealPlanAssignmentId).execute();
  }
  let q = trx.deleteFrom("plan_entry")
    .where("starts_at", ">", sql<string>`now()`)
    .where(sql<boolean>`NOT EXISTS (SELECT 1 FROM training_session s WHERE s.plan_entry_id = plan_entry.id)`)
    .where(sql<boolean>`NOT EXISTS (SELECT 1 FROM food_log f WHERE f.plan_entry_id = plan_entry.id)`);
  if (source.routineAssignmentId) q = q.where("routine_assignment_id", "=", source.routineAssignmentId);
  if (source.mealPlanAssignmentId) q = q.where("meal_plan_assignment_id", "=", source.mealPlanAssignmentId);
  await q.execute();
}

/**
 * Creates the missing plan entries of [userId] for local dates
 * [fromDate, toDate] (inclusive, 'YYYY-MM-DD'). [tz] is used for assignments
 * that don't name their own zone.
 */
export async function generateEntries(userId: string, fromDate: string, toDate: string, tz: string) {
  await sql`
    INSERT INTO plan_entry (user_id, kind, routine_assignment_id, source_id, source_name, slot_key, plan_date,
                            starts_at, duration_minutes, training_id, training_name)
    SELECT a.user_id, 'workout', a.id, r.id, r.name, to_char(d.day, 'YYYY-MM-DD') || ':' || rt.id, d.day,
           ((d.day + a.workout_time)
             + (row_number() OVER (PARTITION BY a.id, d.day ORDER BY rt.position, rt.id) - 1) * INTERVAL '90 minutes')
             AT TIME ZONE COALESCE(a.timezone, ${tz}),
           ${DEFAULT_WORKOUT_MINUTES}, rt.training_id, t.name
      FROM routine_assignment a
      JOIN routine r ON r.id = a.routine_id AND r.schedule_type = 'fixed_weeks' AND r.num_weeks >= 1
      CROSS JOIN LATERAL (
        SELECT g::date AS day FROM generate_series(
          GREATEST(${fromDate}::date, COALESCE(a.start_date, a.created_at::date)),
          LEAST(${toDate}::date, COALESCE(a.end_date, ${toDate}::date)),
          INTERVAL '1 day') g
      ) d
      JOIN routine_training rt ON rt.routine_id = r.id
       AND rt.day_of_week = EXTRACT(ISODOW FROM d.day)
       AND rt.week_number = ((date_trunc('week', d.day)::date
             - date_trunc('week', COALESCE(a.start_date, a.created_at::date))::date) / 7) % r.num_weeks + 1
      JOIN training t ON t.id = rt.training_id
     WHERE a.user_id = ${userId} AND a.left_at IS NULL
    ON CONFLICT (routine_assignment_id, slot_key) WHERE routine_assignment_id IS NOT NULL DO NOTHING
  `.execute(db);

  await sql`
    INSERT INTO plan_entry (user_id, kind, meal_plan_assignment_id, source_id, source_name, slot_key, plan_date,
                            starts_at, duration_minutes, daily_meal_plan_id, daily_meal_plan_name, meal_slot)
    SELECT DISTINCT ON (a.id, d.day, s.slot_type)
           a.user_id, 'meal', a.id, mp.id, mp.name, to_char(d.day, 'YYYY-MM-DD') || ':' || s.slot_type, d.day,
           (d.day + slot_time.at) AT TIME ZONE COALESCE(a.timezone, ${tz}),
           slot_time.minutes, mpd.daily_meal_plan_id, dmp.name, s.slot_type
      FROM meal_plan_assignment a
      JOIN meal_plan mp ON mp.id = a.meal_plan_id
      CROSS JOIN LATERAL (
        SELECT g::date AS day FROM generate_series(
          GREATEST(${fromDate}::date, COALESCE(a.start_date, a.created_at::date)),
          LEAST(${toDate}::date, COALESCE(a.end_date, ${toDate}::date)),
          INTERVAL '1 day') g
      ) d
      JOIN meal_plan_day mpd ON mpd.meal_plan_id = mp.id
       AND mpd.day_of_week = EXTRACT(ISODOW FROM d.day)
       AND mpd.week_number = ((date_trunc('week', d.day)::date
             - date_trunc('week', COALESCE(a.start_date, a.created_at::date))::date) / 7) % GREATEST(mp.num_weeks, 1) + 1
      JOIN daily_meal_plan dmp ON dmp.id = mpd.daily_meal_plan_id
      JOIN daily_meal_plan_slot s ON s.daily_meal_plan_id = mpd.daily_meal_plan_id
      JOIN ${MEAL_SLOT_TIMES} ON slot_time.slot = s.slot_type
     WHERE a.user_id = ${userId} AND a.left_at IS NULL
       AND EXISTS (SELECT 1 FROM daily_meal_plan_slot_entry e WHERE e.daily_meal_plan_slot_id = s.id)
       -- the day belongs to the most recently started plan active on it
       AND NOT EXISTS (
         SELECT 1 FROM meal_plan_assignment b
          WHERE b.user_id = a.user_id AND b.id <> a.id AND b.left_at IS NULL
            AND COALESCE(b.start_date, b.created_at::date) <= d.day
            AND (b.end_date IS NULL OR b.end_date >= d.day)
            AND (COALESCE(b.start_date, b.created_at::date), b.created_at)
              > (COALESCE(a.start_date, a.created_at::date), a.created_at))
     ORDER BY a.id, d.day, s.slot_type, s.position
    ON CONFLICT (meal_plan_assignment_id, slot_key) WHERE meal_plan_assignment_id IS NOT NULL DO NOTHING
  `.execute(db);
}
