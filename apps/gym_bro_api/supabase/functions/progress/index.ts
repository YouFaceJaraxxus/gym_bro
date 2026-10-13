import { sql } from "npm:kysely@^0.27";
import { db } from "../_shared/config.ts";
import { coachesUser, forbidden, json, jsonError, requireCaller } from "../_shared/auth.ts";
import { userDropRows } from "../_shared/progress.ts";

// Training progress for one user: summary, per-exercise bests and series.
// Readable by the user themself, anyone who coaches them, or a super user.
// All weights are kilograms; e1RM is Epley (w × (1 + reps/30)) over count
// sets with reps ≥ 1. Weeks are ISO weeks in UTC.

// ── Path helpers ──────────────────────────────────────────────────────────────

// /progress/summary                 → { route: 'summary' }
// /progress/exercises               → { route: 'exercises' }
// /progress/exercises/:exerciseId   → { route: 'exercise', id }

type Route = { route: "summary" | "exercises" | "exercise" | null; id?: string };

function parsePath(pathname: string): Route {
  if (/^\/progress\/summary\/?$/.test(pathname)) return { route: "summary" };
  if (/^\/progress\/exercises\/?$/.test(pathname)) return { route: "exercises" };
  const one = pathname.match(/^\/progress\/exercises\/([^/]+)$/);
  if (one) return { route: "exercise", id: one[1] };
  return { route: null };
}

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function parseDateParam(v: string | null): string | null | "invalid" {
  if (!v) return null;
  return Number.isNaN(Date.parse(v)) ? "invalid" : v;
}

// ── Queries ───────────────────────────────────────────────────────────────────

type PrRow = {
  exercise_id: string;
  exercise_name: string;
  session_id: string;
  date: string;
  e1rm: number;
  previous_e1rm: number;
  weight_kg: number;
  reps: number;
};

/** Sessions whose best e1RM for an exercise beat every earlier session's. */
async function recentPrs(userId: string, days: number, limit: number): Promise<PrRow[]> {
  const res = await sql<PrRow>`
    WITH d AS (${userDropRows(userId)}),
    per AS (
      SELECT DISTINCT ON (session_id, exercise_id)
             session_id, started_at, exercise_id, e1rm, weight_kg, reps
        FROM d
       WHERE exercise_id IS NOT NULL AND e1rm IS NOT NULL
       ORDER BY session_id, exercise_id, e1rm DESC
    ),
    ranked AS (
      SELECT per.*,
             MAX(e1rm) OVER (
               PARTITION BY exercise_id ORDER BY started_at, session_id
               ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
             ) AS prev_best
        FROM per
    )
    SELECT r.exercise_id,
           e.name                         AS exercise_name,
           r.session_id,
           r.started_at                   AS date,
           ROUND(r.e1rm, 2)::float8       AS e1rm,
           ROUND(r.prev_best, 2)::float8  AS previous_e1rm,
           r.weight_kg::float8            AS weight_kg,
           r.reps
      FROM ranked r
      JOIN exercise e ON e.id = r.exercise_id
     WHERE r.started_at >= NOW() - make_interval(days => ${days})
       AND r.prev_best IS NOT NULL
       AND r.e1rm > r.prev_best
     ORDER BY r.started_at DESC, e.name
     LIMIT ${limit}
  `.execute(db);
  return res.rows;
}

// ── Handler ───────────────────────────────────────────────────────────────────

async function handler(req: Request): Promise<Response> {
  const url = new URL(req.url);
  const { route, id } = parsePath(url.pathname);

  const { caller, response } = await requireCaller(req);
  if (!caller) return response;

  if (req.method !== "GET" || !route) return jsonError("Not found", 404);

  const userId = url.searchParams.get("user_id") ?? caller.id;
  if (!UUID_RE.test(userId)) return jsonError("user_id must be a UUID", 400);
  if (userId !== caller.id && !(await coachesUser(caller, userId))) return forbidden();

  // ── GET /progress/summary ─────────────────────────────────────────────────────
  // { user_id, sessions_7d, sessions_30d, volume_30d_kg, streak_weeks,
  //   trained_this_week, last_session_at, recent_prs: PrRow[] }
  if (route === "summary") {
    const counts = await sql<{
      sessions_7d: number;
      sessions_30d: number;
      sessions_total: number;
      last_session_at: string | null;
    }>`
      SELECT
        COUNT(*) FILTER (WHERE started_at >= NOW() - INTERVAL '7 days')::int  AS sessions_7d,
        COUNT(*) FILTER (WHERE started_at >= NOW() - INTERVAL '30 days')::int AS sessions_30d,
        COUNT(*)::int                                                         AS sessions_total,
        MAX(started_at)                                                       AS last_session_at
      FROM training_session
      WHERE user_id = ${userId}
    `.execute(db);

    const volume = await sql<{ volume_30d_kg: number }>`
      WITH d AS (${userDropRows(userId)})
      SELECT ROUND(COALESCE(SUM(volume_kg), 0), 2)::float8 AS volume_30d_kg
        FROM d
       WHERE started_at >= NOW() - INTERVAL '30 days'
    `.execute(db);

    // Gaps-and-islands over distinct ISO weeks, newest first: consecutive weeks
    // share wk + (rn - 1) * 7. The streak counts while the latest island ends
    // this week or last week (a streak isn't broken until a full week is missed).
    const streak = await sql<{ streak_weeks: number; trained_this_week: boolean }>`
      WITH w AS (
        SELECT DISTINCT date_trunc('week', started_at AT TIME ZONE 'UTC')::date AS wk
          FROM training_session
         WHERE user_id = ${userId}
      ),
      r AS (
        SELECT wk, wk + ((ROW_NUMBER() OVER (ORDER BY wk DESC) - 1) * 7)::int AS grp FROM w
      ),
      cur AS (SELECT date_trunc('week', NOW() AT TIME ZONE 'UTC')::date AS wk)
      SELECT
        CASE WHEN (SELECT MAX(wk) FROM w) >= (SELECT wk FROM cur) - 7
             THEN (SELECT COUNT(*) FROM r WHERE grp = (SELECT MAX(wk) FROM w))::int
             ELSE 0 END                                              AS streak_weeks,
        COALESCE((SELECT MAX(wk) FROM w) = (SELECT wk FROM cur), false) AS trained_this_week
    `.execute(db);

    const c = counts.rows[0];
    return json({
      user_id: userId,
      sessions_7d: c?.sessions_7d ?? 0,
      sessions_30d: c?.sessions_30d ?? 0,
      sessions_total: c?.sessions_total ?? 0,
      last_session_at: c?.last_session_at ?? null,
      volume_30d_kg: volume.rows[0]?.volume_30d_kg ?? 0,
      streak_weeks: streak.rows[0]?.streak_weeks ?? 0,
      trained_this_week: streak.rows[0]?.trained_this_week ?? false,
      recent_prs: await recentPrs(userId, 30, 20),
    });
  }

  // ── GET /progress/exercises ───────────────────────────────────────────────────
  // [{ id, name, primary_muscles, session_count, last_performed, best_weight_kg,
  //    best_e1rm, trend: number[] (per-session best e1RM, else best weight;
  //    last 12 sessions, oldest first) }] — most recently performed first.
  if (route === "exercises") {
    const res = await sql`
      WITH d AS (${userDropRows(userId)}),
      per AS (
        SELECT exercise_id, session_id, started_at,
               MAX(e1rm) AS e1rm, MAX(weight_kg) AS weight_kg,
               ROW_NUMBER() OVER (PARTITION BY exercise_id ORDER BY started_at DESC) AS rn
          FROM d
         WHERE exercise_id IS NOT NULL
         GROUP BY exercise_id, session_id, started_at
      ),
      trend AS (
        SELECT exercise_id,
               ARRAY_AGG(ROUND(COALESCE(e1rm, weight_kg), 2)::float8 ORDER BY started_at)
                 FILTER (WHERE COALESCE(e1rm, weight_kg) IS NOT NULL) AS trend
          FROM per
         WHERE rn <= 12
         GROUP BY exercise_id
      )
      SELECT e.id,
             e.name,
             e.primary_muscles::text[]             AS primary_muscles,
             COUNT(DISTINCT d.session_id)::int     AS session_count,
             MAX(d.started_at)                     AS last_performed,
             MAX(d.weight_kg)::float8              AS best_weight_kg,
             ROUND(MAX(d.e1rm), 2)::float8         AS best_e1rm,
             COALESCE(t.trend, '{}')               AS trend
        FROM d
        JOIN exercise e    ON e.id = d.exercise_id
        LEFT JOIN trend t  ON t.exercise_id = e.id
       GROUP BY e.id, e.name, e.primary_muscles, t.trend
       ORDER BY MAX(d.started_at) DESC, e.name
    `.execute(db);
    return json(res.rows);
  }

  // ── GET /progress/exercises/:exerciseId?from=&to= ─────────────────────────────
  // { exercise: {id, name, primary_muscles},
  //   series: [{session_id, date, best_weight_kg, best_e1rm, volume_kg, total_reps}],
  //   prs: { best_weight_kg, best_e1rm, best_volume_kg: {value, session_id, date} | null } }
  // `series` honours from/to; `prs` are all-time.
  if (route === "exercise" && id) {
    if (!UUID_RE.test(id)) return jsonError("Invalid exercise id", 400);
    const from = parseDateParam(url.searchParams.get("from"));
    const to = parseDateParam(url.searchParams.get("to"));
    if (from === "invalid" || to === "invalid") return jsonError("from/to must be dates", 400);

    const exercise = await db
      .selectFrom("exercise")
      .select(["id", "name", sql<string[]>`primary_muscles::text[]`.as("primary_muscles")])
      .where("id", "=", id)
      .executeTakeFirst();
    if (!exercise) return jsonError("Exercise not found", 404);

    const perSession = sql`
      SELECT session_id,
             started_at                             AS date,
             MAX(weight_kg)::float8                 AS best_weight_kg,
             ROUND(MAX(e1rm), 2)::float8            AS best_e1rm,
             ROUND(SUM(volume_kg), 2)::float8       AS volume_kg,
             SUM(counted_reps)::int                 AS total_reps
        FROM (${userDropRows(userId)}) d
       WHERE exercise_id = ${id}
       GROUP BY session_id, started_at
    `;

    const series = await sql`
      SELECT * FROM (${perSession}) s
       WHERE (${from}::timestamptz IS NULL OR s.date >= ${from}::timestamptz)
         AND (${to}::timestamptz IS NULL OR s.date <= ${to}::timestamptz)
       ORDER BY s.date
    `.execute(db);

    const prs = await sql<{
      best_weight_kg: unknown;
      best_e1rm: unknown;
      best_volume_kg: unknown;
    }>`
      WITH s AS (${perSession})
      SELECT
        (SELECT json_build_object('value', best_weight_kg, 'session_id', session_id, 'date', date)
           FROM s WHERE best_weight_kg IS NOT NULL
          ORDER BY best_weight_kg DESC, date LIMIT 1) AS best_weight_kg,
        (SELECT json_build_object('value', best_e1rm, 'session_id', session_id, 'date', date)
           FROM s WHERE best_e1rm IS NOT NULL
          ORDER BY best_e1rm DESC, date LIMIT 1)      AS best_e1rm,
        (SELECT json_build_object('value', volume_kg, 'session_id', session_id, 'date', date)
           FROM s WHERE volume_kg > 0
          ORDER BY volume_kg DESC, date LIMIT 1)      AS best_volume_kg
    `.execute(db);

    return json({
      exercise,
      series: series.rows,
      prs: prs.rows[0] ?? { best_weight_kg: null, best_e1rm: null, best_volume_kg: null },
    });
  }

  return jsonError("Not found", 404);
}

Deno.serve(async (req: Request) => {
  try {
    return await handler(req);
  } catch (e) {
    const err = e as { code?: string; message?: string } | null;
    if (err?.code === "22P02" || err?.code === "22007" || err?.code === "22008") {
      return jsonError(err.message ?? "Invalid value", 400);
    }
    throw e;
  }
});
