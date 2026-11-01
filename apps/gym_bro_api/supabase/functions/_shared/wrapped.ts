import { sql } from "npm:kysely@^0.27";
import { db } from "./config.ts";
import { notify } from "./notify.ts";
import { userDropRows } from "./progress.ts";
import { SESSION_MINUTES_CAP } from "./challenges.ts";

// Gym Bro Wrapped: someone's year in training (GET /wrapped/:year).
//
// Computed on request from the raw data, in the user's zone (their saved
// zone, else their streak's, else UTC):
// * workouts are finished sessions (ended, started in the past) with at
//   least one logged set, started in the year. Unlike streaks and challenges
//   late logging counts: it's a recap, not a competition;
// * minutes cap one workout at SESSION_MINUTES_CAP; volume is kg × reps over
//   counted sets (see _shared/progress.ts); sets are logged sets;
// * a PR is a workout whose best e1RM (Epley) for an exercise beat every
//   earlier workout's, earlier years included (as on the progress screen);
// * the longest streak is the longest the streak engine reached during the
//   year: the highest streak recorded by a streak_event that year (breaks,
//   freezes, badges), or the live streak where it was running at the year's
//   end (its workouts up to Dec 31). A streak that began the year before
//   counts with its full length.
//
// The current year opens on December 1 (local); a past year whenever it has
// workouts or check-ins. Otherwise {available: false, available_from}.

export const WRAPPED_OPENS_MONTH = 12;
/** Local hour from which the "your Wrapped is ready" push goes out on Dec 1. */
export const WRAPPED_NOTICE_HOUR = 10;
export const FIRST_YEAR = 2000;

export type Availability = {
  year: number;
  available: boolean;
  /** When the year opens; null for a past year without data. */
  available_from: string | null;
  reason?: "not_yet" | "no_data";
};

/** Pure: whether [year] can be shown on [today] (the user's local date). */
export function availability(year: number, today: string, hasData: boolean, preview = false): Availability {
  const currentYear = Number(today.slice(0, 4));
  const opens = `${year}-12-01`;
  if (year > currentYear) return { year, available: false, available_from: opens, reason: "not_yet" };
  if (year === currentYear) {
    const open = today >= opens || preview;
    return open ? { year, available: true, available_from: opens } : { year, available: false, available_from: opens, reason: "not_yet" };
  }
  return hasData ? { year, available: true, available_from: null } : { year, available: false, available_from: null, reason: "no_data" };
}

/** Pure: index of the largest value (first on ties), or null when all are 0. */
export function argMax(xs: number[]): number | null {
  let best: number | null = null;
  xs.forEach((x, i) => {
    if (x > 0 && (best === null || x > xs[best])) best = i;
  });
  return best;
}

/** Pure: the jobs step only does anything from Nov 30 to Dec 31 (UTC), when someone's local date can be in December. */
export function inNoticeSeason(now: Date): boolean {
  const m = now.getUTCMonth() + 1;
  return m === 12 || (m === 11 && now.getUTCDate() === 30);
}

// ── Queries ───────────────────────────────────────────────────────────────────

/** The user's counted workouts started in [year] (a CTE body). */
function workoutsIn(userId: string, tz: string, year: number) {
  return sql`
    SELECT s.id, s.started_at, s.ended_at, (s.started_at AT TIME ZONE ${tz}) AS local_at
      FROM training_session s
     WHERE s.user_id = ${userId}
       AND s.ended_at IS NOT NULL
       AND s.started_at <= now()
       AND s.started_at >= (make_date(${year}::int, 1, 1)::timestamp AT TIME ZONE ${tz})
       AND s.started_at <  (make_date(${year}::int + 1, 1, 1)::timestamp AT TIME ZONE ${tz})
       AND EXISTS (SELECT 1 FROM session_set_log l WHERE l.session_id = s.id)`;
}

/** Years (local) in which [userId] has workouts or check-ins, newest first. */
export async function yearsWithData(userId: string, tz: string): Promise<number[]> {
  const rows = await sql<{ year: number }>`
    SELECT DISTINCT y AS year FROM (
      SELECT EXTRACT(YEAR FROM s.started_at AT TIME ZONE ${tz})::int AS y
        FROM training_session s
       WHERE s.user_id = ${userId} AND s.ended_at IS NOT NULL AND s.started_at <= now()
         AND EXISTS (SELECT 1 FROM session_set_log l WHERE l.session_id = s.id)
      UNION
      SELECT EXTRACT(YEAR FROM c.checked_in_at AT TIME ZONE ${tz})::int
        FROM check_in c WHERE c.user_id = ${userId} AND c.checked_in_at <= now()
    ) x
    ORDER BY year DESC
  `.execute(db);
  return rows.rows.map((r) => r.year);
}

type ExerciseRow = {
  exercise_id: string;
  name: string;
  image_url: string | null;
  sets: number;
  volume_kg: number;
  e1rm: number | null;
  weight_kg: number | null;
  reps: number | null;
  best_on: string | null;
};

/** The whole recap. Runs its aggregates side by side. */
export async function buildWrapped(userId: string, tz: string, year: number) {
  const yearStart = `${year}-01-01`;
  const yearEnd = `${year}-12-31`;
  const w = workoutsIn(userId, tz, year);

  const totalsQ = sql<{
    workouts: number;
    active_days: number;
    minutes: number;
    sets: number;
    first_workout_on: string | null;
    by_weekday: number[];
    by_hour: number[];
    by_month: number[];
  }>`
    WITH w AS (${w})
    SELECT
      (SELECT COUNT(*) FROM w)::int AS workouts,
      (SELECT COUNT(DISTINCT local_at::date) FROM w)::int AS active_days,
      (SELECT COALESCE(FLOOR(SUM(LEAST(GREATEST(EXTRACT(EPOCH FROM (ended_at - started_at)), 0) / 60,
                                       ${SESSION_MINUTES_CAP}))), 0) FROM w)::int AS minutes,
      (SELECT COUNT(*) FROM session_set_log l WHERE l.session_id IN (SELECT id FROM w))::int AS sets,
      (SELECT to_char(MIN(local_at), 'YYYY-MM-DD') FROM w) AS first_workout_on,
      ARRAY(SELECT (SELECT COUNT(*) FROM w WHERE EXTRACT(ISODOW FROM w.local_at) = d)::int
              FROM generate_series(1, 7) d ORDER BY d) AS by_weekday,
      ARRAY(SELECT (SELECT COUNT(*) FROM w WHERE EXTRACT(HOUR FROM w.local_at) = h)::int
              FROM generate_series(0, 23) h ORDER BY h) AS by_hour,
      ARRAY(SELECT (SELECT COUNT(*) FROM w WHERE EXTRACT(MONTH FROM w.local_at) = m)::int
              FROM generate_series(1, 12) m ORDER BY m) AS by_month
  `.execute(db);

  const liftsQ = sql<{ volume_kg: number; reps: number; exercises: ExerciseRow[] | null }>`
    WITH w AS (${w}),
    d AS (${userDropRows(userId)}),
    dd AS (SELECT * FROM d WHERE d.session_id IN (SELECT id FROM w)),
    best AS (
      SELECT DISTINCT ON (exercise_id) exercise_id, e1rm, weight_kg, reps, started_at
        FROM dd WHERE exercise_id IS NOT NULL AND e1rm IS NOT NULL
       ORDER BY exercise_id, e1rm DESC, started_at
    ),
    per AS (
      SELECT dd.exercise_id, COUNT(DISTINCT dd.set_log_id)::int AS sets, SUM(dd.volume_kg) AS volume_kg
        FROM dd WHERE dd.exercise_id IS NOT NULL GROUP BY dd.exercise_id
    )
    SELECT
      (SELECT ROUND(COALESCE(SUM(volume_kg), 0))::float8 FROM dd) AS volume_kg,
      (SELECT COALESCE(SUM(counted_reps), 0)::int FROM dd) AS reps,
      (SELECT json_agg(json_build_object(
                'exercise_id', per.exercise_id, 'name', e.name, 'image_url', e.image_url,
                'sets', per.sets, 'volume_kg', ROUND(per.volume_kg)::float8,
                'e1rm', ROUND(best.e1rm, 1)::float8, 'weight_kg', best.weight_kg::float8, 'reps', best.reps,
                'best_on', to_char(best.started_at AT TIME ZONE ${tz}, 'YYYY-MM-DD')))
         FROM per JOIN exercise e ON e.id = per.exercise_id
         LEFT JOIN best ON best.exercise_id = per.exercise_id) AS exercises
  `.execute(db);

  const prsQ = sql<{ prs: number }>`
    WITH d AS (${userDropRows(userId)}),
    per AS (
      SELECT DISTINCT ON (session_id, exercise_id) session_id, started_at, exercise_id, e1rm
        FROM d WHERE exercise_id IS NOT NULL AND e1rm IS NOT NULL
        -- only finished workouts
        AND session_id IN (SELECT id FROM training_session WHERE user_id = ${userId} AND ended_at IS NOT NULL)
       ORDER BY session_id, exercise_id, e1rm DESC
    ),
    ranked AS (
      SELECT per.*, MAX(e1rm) OVER (
               PARTITION BY exercise_id ORDER BY started_at, session_id
               ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS prev_best
        FROM per
    )
    SELECT COUNT(*)::int AS prs FROM ranked
     WHERE prev_best IS NOT NULL AND e1rm > prev_best
       AND started_at >= (make_date(${year}::int, 1, 1)::timestamp AT TIME ZONE ${tz})
       AND started_at <  (make_date(${year}::int + 1, 1, 1)::timestamp AT TIME ZONE ${tz})
  `.execute(db);

  const inYear = (col: string) =>
    sql`${sql.ref(col)} >= (make_date(${year}::int, 1, 1)::timestamp AT TIME ZONE ${tz})
        AND ${sql.ref(col)} < (make_date(${year}::int + 1, 1, 1)::timestamp AT TIME ZONE ${tz})`;

  const gymQ = sql<{
    check_ins: number;
    classes_attended: number;
    favourite: { id: string; name: string; logo: string | null; check_ins: number } | null;
  }>`
    SELECT
      (SELECT COUNT(*) FROM check_in ci WHERE ci.user_id = ${userId} AND ${inYear("ci.checked_in_at")})::int AS check_ins,
      (SELECT COUNT(*) FROM class_booking cb JOIN gym_class gc ON gc.id = cb.class_id
        WHERE cb.user_id = ${userId} AND cb.status = 'attended' AND ${inYear("gc.starts_at")})::int AS classes_attended,
      (SELECT json_build_object('id', b.id, 'name', b.name, 'logo', b.logo, 'check_ins', f.n)
         FROM (SELECT ci.gym_id, COUNT(*)::int AS n, MAX(ci.checked_in_at) AS last
                 FROM check_in ci WHERE ci.user_id = ${userId} AND ${inYear("ci.checked_in_at")}
                GROUP BY ci.gym_id ORDER BY n DESC, last DESC LIMIT 1) f
         JOIN business b ON b.id = f.gym_id) AS favourite
  `.execute(db);

  const streakQ = sql<{ from_events: number | null; at_year_end: number | null; best_ever: number | null }>`
    SELECT
      (SELECT MAX(streak) FROM streak_event
        WHERE user_id = ${userId} AND on_date BETWEEN ${yearStart}::date AND ${yearEnd}::date)::int AS from_events,
      (SELECT COUNT(*) FROM training_session s, workout_streak ws
        WHERE ws.user_id = ${userId} AND ws.since IS NOT NULL AND ws.current > 0
          AND ws.since <= ${yearEnd}::date
          AND s.user_id = ${userId} AND s.ended_at IS NOT NULL AND s.started_at <= now()
          AND s.started_at >= (ws.since::timestamp AT TIME ZONE ${tz})
          AND s.started_at <  (make_date(${year}::int + 1, 1, 1)::timestamp AT TIME ZONE ${tz})
          AND s.created_at < (((s.started_at AT TIME ZONE ${tz})::date + 2)::timestamp AT TIME ZONE ${tz})
          AND EXISTS (SELECT 1 FROM session_set_log l WHERE l.session_id = s.id))::int AS at_year_end,
      (SELECT best FROM workout_streak WHERE user_id = ${userId})::int AS best_ever
  `.execute(db);

  const badgesQ = sql<{ tier: string; on_date: string }>`
    SELECT tier, to_char(on_date, 'YYYY-MM-DD') AS on_date FROM streak_event
     WHERE user_id = ${userId} AND kind = 'tier' AND tier IS NOT NULL
       AND on_date BETWEEN ${yearStart}::date AND ${yearEnd}::date
     ORDER BY on_date, streak
  `.execute(db);

  const challengesQ = sql<{
    id: string;
    title: string;
    metric: string;
    target: number;
    auto_key: string | null;
    gym_name: string | null;
    completed_at: string;
  }>`
    SELECT c.id, c.title, c.metric, c.target, c.auto_key, b.name AS gym_name, cp.completed_at
      FROM challenge_participant cp
      JOIN challenge c ON c.id = cp.challenge_id
      LEFT JOIN business b ON b.id = c.business_id
     WHERE cp.user_id = ${userId} AND cp.completed_at IS NOT NULL AND ${inYear("cp.completed_at")}
     ORDER BY cp.completed_at
  `.execute(db);

  const [totals, lifts, prs, gym, streak, badges, challenges] = await Promise.all([
    totalsQ,
    liftsQ,
    prsQ,
    gymQ,
    streakQ,
    badgesQ,
    challengesQ,
  ]);

  const t = totals.rows[0];
  const l = lifts.rows[0];
  const exercises = (l?.exercises ?? []).map((e) => ({ ...e, volume_kg: Number(e.volume_kg ?? 0) }));
  const g = gym.rows[0];
  const s = streak.rows[0];
  const byWeekday = (t?.by_weekday ?? []).map(Number);
  const byHour = (t?.by_hour ?? []).map(Number);
  const byMonth = (t?.by_month ?? []).map(Number);
  const weekday = argMax(byWeekday);
  const month = argMax(byMonth);
  const exerciseOut = (e: ExerciseRow) => ({
    exercise_id: e.exercise_id,
    name: e.name,
    image_url: e.image_url,
    sets: e.sets,
    volume_kg: e.volume_kg,
  });

  return {
    year,
    timezone: tz,
    totals: {
      workouts: t?.workouts ?? 0,
      active_days: t?.active_days ?? 0,
      minutes: t?.minutes ?? 0,
      volume_kg: l?.volume_kg ?? 0,
      sets: t?.sets ?? 0,
      reps: l?.reps ?? 0,
    },
    first_workout_on: t?.first_workout_on ?? null,
    by_weekday: byWeekday,
    busiest_weekday: weekday === null ? null : weekday + 1,
    by_hour: byHour,
    favourite_hour: argMax(byHour),
    by_month: byMonth,
    best_month: month === null ? null : month + 1,
    top_exercises_by_sets: [...exercises].sort((a, b) => b.sets - a.sets || b.volume_kg - a.volume_kg).slice(0, 5)
      .map(exerciseOut),
    top_exercises_by_volume: [...exercises].filter((e) => e.volume_kg > 0)
      .sort((a, b) => b.volume_kg - a.volume_kg || b.sets - a.sets).slice(0, 5).map(exerciseOut),
    prs: {
      count: prs.rows[0]?.prs ?? 0,
      best_lifts: exercises.filter((e) => e.e1rm != null).sort((a, b) => (b.e1rm ?? 0) - (a.e1rm ?? 0)).slice(0, 5)
        .map((e) => ({
          exercise_id: e.exercise_id,
          name: e.name,
          e1rm: e.e1rm,
          weight_kg: e.weight_kg,
          reps: e.reps,
          on: e.best_on,
        })),
    },
    gym: {
      check_ins: g?.check_ins ?? 0,
      classes_attended: g?.classes_attended ?? 0,
      favourite: g?.favourite ?? null,
    },
    streak: {
      longest: Math.max(s?.from_events ?? 0, s?.at_year_end ?? 0),
      best_ever: s?.best_ever ?? 0,
    },
    badges: badges.rows,
    challenges: { completed: challenges.rows.length, items: challenges.rows },
  };
}

export type Wrapped = Awaited<ReturnType<typeof buildWrapped>>;

// ── Jobs ──────────────────────────────────────────────────────────────────────

/**
 * From 10:00 local on December 1 (or later in December, when a run was
 * missed): one `wrapped` notification per user who trained this year. Claimed
 * in wrapped_notice first, so it goes out once per user and year.
 */
export async function sendWrappedNotices(now = new Date(), limit = 500): Promise<number> {
  if (!inNoticeSeason(now)) return 0;
  const claimed = await sql<{ user_id: string; year: number }>`
    INSERT INTO wrapped_notice (user_id, year)
    SELECT x.user_id, x.yr
      FROM (
        SELECT u.id AS user_id, l.local, EXTRACT(YEAR FROM l.local)::int AS yr, z.tz
          FROM users u
          LEFT JOIN user_settings us  ON us.user_id = u.id
          LEFT JOIN workout_streak ws ON ws.user_id = u.id
          CROSS JOIN LATERAL (SELECT COALESCE(us.timezone, ws.timezone, 'UTC') AS tz) z
          CROSS JOIN LATERAL (SELECT ${now.toISOString()}::timestamptz AT TIME ZONE z.tz AS local) l
      ) x
     WHERE EXTRACT(MONTH FROM x.local) = ${WRAPPED_OPENS_MONTH}
       AND (EXTRACT(DAY FROM x.local) > 1 OR EXTRACT(HOUR FROM x.local) >= ${WRAPPED_NOTICE_HOUR})
       AND NOT EXISTS (SELECT 1 FROM wrapped_notice n WHERE n.user_id = x.user_id AND n.year = x.yr)
       AND EXISTS (
         SELECT 1 FROM training_session s
          WHERE s.user_id = x.user_id AND s.ended_at IS NOT NULL AND s.started_at <= now()
            AND s.started_at >= (make_date(x.yr, 1, 1)::timestamp AT TIME ZONE x.tz)
            AND EXISTS (SELECT 1 FROM session_set_log l WHERE l.session_id = s.id))
     LIMIT ${limit}
    ON CONFLICT DO NOTHING
    RETURNING user_id, year
  `.execute(db);
  const byYear = new Map<number, string[]>();
  for (const r of claimed.rows) byYear.set(r.year, [...(byYear.get(r.year) ?? []), r.user_id]);
  for (const [year, ids] of byYear) {
    await notify(ids, {
      type: "wrapped",
      title: `Your ${year} Wrapped is ready 🎁`,
      body: "Your year in training: workouts, lifts, streaks and more. Tap to relive it.",
      metadata: { year },
    });
  }
  return claimed.rows.length;
}
