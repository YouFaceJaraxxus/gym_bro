import { sql } from "npm:kysely@^0.27";
import { db } from "../_shared/config.ts";
import { json, jsonError, requireCaller } from "../_shared/auth.ts";
import { isTimezone } from "../_shared/plans.ts";
import { addDays, localDate } from "../_shared/streaks.ts";
import { baseGoalMl, dayGoalMl, readDays, readLoggedAt, readMl, WORKOUT_BONUS_ML } from "./rules.ts";

// Water tracking (sql/schemas/000026_water.sql). Days are local to `tz` (the
// app's IANA zone), else user_settings.timezone, else UTC.
//
// The goal: user_settings.water_goal_ml, else ~35 ml per kg of the latest
// body weight (rules.ts), plus 500 ml on a day with a finished workout (a
// session with an end and at least one logged set).
//
//   GET    /water-logs/today?tz=           today's drinks, total and goal
//   GET    /water-logs/history?days=30&tz= one row per local day (oldest first,
//                                          days without water included)
//   POST   /water-logs?tz=                 { ml, logged_at? } → { entry, today }
//   DELETE /water-logs/:id?tz=             one of my drinks (undo) → { today }

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

type Goal = { base: number; auto: boolean; weightKg: number | null };

/** The caller's zone: the query's, else the one the app last reported, else UTC. */
async function resolveTz(userId: string, param: string | null): Promise<string> {
  if (param) return param;
  const row = await db.selectFrom("user_settings").select("timezone").where("user_id", "=", userId)
    .executeTakeFirst();
  return row?.timezone && isTimezone(row.timezone) ? row.timezone : "UTC";
}

/** Midnight starting local day [day] in [tz], as an instant. */
const dayStart = (day: string, tz: string) => sql<string>`(${day}::date::timestamp AT TIME ZONE ${tz})`;

async function loadGoal(userId: string): Promise<Goal> {
  const [settings, weight] = await Promise.all([
    db.selectFrom("user_settings").select("water_goal_ml").where("user_id", "=", userId).executeTakeFirst(),
    db.selectFrom("body_measurement")
      .select(sql<number>`weight_kg::float8`.as("weight_kg"))
      .where("user_id", "=", userId)
      .where("weight_kg", "is not", null)
      .orderBy("measured_on", "desc")
      .orderBy("created_at", "desc")
      .limit(1)
      .executeTakeFirst(),
  ]);
  const chosen = settings?.water_goal_ml ?? null;
  const weightKg = weight?.weight_kg ?? null;
  return { base: baseGoalMl(chosen, weightKg), auto: chosen == null, weightKg };
}

/** Local days in [from, to] with a finished workout. */
async function workoutDays(userId: string, tz: string, from: string, to: string): Promise<Set<string>> {
  const { rows } = await sql<{ day: string }>`
    SELECT DISTINCT to_char((s.started_at AT TIME ZONE ${tz})::date, 'YYYY-MM-DD') AS day
      FROM training_session s
     WHERE s.user_id = ${userId}
       AND s.ended_at IS NOT NULL
       AND s.started_at >= ${dayStart(from, tz)}
       AND s.started_at <  ${dayStart(addDays(to, 1), tz)}
       AND EXISTS (SELECT 1 FROM session_set_log l WHERE l.session_id = s.id)
  `.execute(db);
  return new Set(rows.map((r) => r.day));
}

async function today(userId: string, tz: string) {
  const date = localDate(new Date(), tz);
  const [entries, goal, worked] = await Promise.all([
    db.selectFrom("water_log")
      .select(["id", "ml", "logged_at"])
      .where("user_id", "=", userId)
      .where("logged_at", ">=", dayStart(date, tz))
      .where("logged_at", "<", dayStart(addDays(date, 1), tz))
      .orderBy("logged_at", "desc")
      .orderBy("created_at", "desc")
      .execute(),
    loadGoal(userId),
    workoutDays(userId, tz, date, date),
  ]);
  const workedOut = worked.has(date);
  return {
    date,
    timezone: tz,
    total_ml: entries.reduce((sum, e) => sum + e.ml, 0),
    goal_ml: dayGoalMl(goal.base, workedOut),
    base_goal_ml: goal.base,
    workout_bonus_ml: workedOut ? WORKOUT_BONUS_ML : 0,
    auto_goal: goal.auto,
    weight_kg: goal.weightKg,
    worked_out: workedOut,
    entries: entries.map((e) => ({ ...e, logged_at: new Date(e.logged_at).toISOString() })),
  };
}

async function handler(req: Request): Promise<Response> {
  const { caller, response } = await requireCaller(req);
  if (!caller) return response;
  const url = new URL(req.url);
  const parts = url.pathname.replace(/^\/water-logs\/?/, "").split("/").filter(Boolean);
  const tzParam = url.searchParams.get("tz");
  if (tzParam && !isTimezone(tzParam)) return jsonError("tz must be an IANA zone", 400);

  // ── GET /water-logs/today ─────────────────────────────────────────────────────
  if (req.method === "GET" && parts.length === 1 && parts[0] === "today") {
    return json(await today(caller.id, await resolveTz(caller.id, tzParam)));
  }

  // ── GET /water-logs/history ───────────────────────────────────────────────────
  if (req.method === "GET" && parts.length === 1 && parts[0] === "history") {
    const days = readDays(url.searchParams.get("days"));
    if (typeof days === "string") return jsonError(days, 400);
    const tz = await resolveTz(caller.id, tzParam);
    const to = localDate(new Date(), tz);
    const from = addDays(to, 1 - days);
    const [totals, goal, worked] = await Promise.all([
      sql<{ day: string; total_ml: number }>`
        SELECT to_char((logged_at AT TIME ZONE ${tz})::date, 'YYYY-MM-DD') AS day, SUM(ml)::int AS total_ml
          FROM water_log
         WHERE user_id = ${caller.id}
           AND logged_at >= ${dayStart(from, tz)}
           AND logged_at <  ${dayStart(addDays(to, 1), tz)}
         GROUP BY 1
      `.execute(db).then((r) => new Map(r.rows.map((row) => [row.day, row.total_ml]))),
      loadGoal(caller.id),
      workoutDays(caller.id, tz, from, to),
    ]);
    const out = [];
    for (let day = from; day <= to; day = addDays(day, 1)) {
      const workedOut = worked.has(day);
      out.push({ date: day, total_ml: totals.get(day) ?? 0, goal_ml: dayGoalMl(goal.base, workedOut), worked_out: workedOut });
    }
    return json({ from, to, timezone: tz, base_goal_ml: goal.base, auto_goal: goal.auto, days: out });
  }

  // ── POST /water-logs ──────────────────────────────────────────────────────────
  if (req.method === "POST" && parts.length === 0) {
    const body = await req.json().catch(() => null);
    if (!body || typeof body !== "object") return jsonError("Body must be a JSON object", 400);
    const ml = readMl(body.ml);
    if (typeof ml === "string") return jsonError(ml, 400);
    const loggedAt = readLoggedAt(body.logged_at);
    if (typeof loggedAt === "string") return jsonError(loggedAt, 400);
    const row = await db.insertInto("water_log")
      .values({ user_id: caller.id, ml, ...(loggedAt ? { logged_at: loggedAt.toISOString() } : {}) })
      .returning(["id", "ml", "logged_at"])
      .executeTakeFirstOrThrow();
    const entry = { ...row, logged_at: new Date(row.logged_at).toISOString() };
    return json({ entry, today: await today(caller.id, await resolveTz(caller.id, tzParam)) }, 201);
  }

  // ── DELETE /water-logs/:id ────────────────────────────────────────────────────
  if (req.method === "DELETE" && parts.length === 1) {
    const id = parts[0];
    if (!UUID_RE.test(id)) return jsonError("Entry not found", 404);
    const gone = await db.deleteFrom("water_log").where("id", "=", id).where("user_id", "=", caller.id)
      .returning("id").executeTakeFirst();
    if (!gone) return jsonError("Entry not found", 404);
    return json({ today: await today(caller.id, await resolveTz(caller.id, tzParam)) });
  }

  return jsonError("Not found", 404);
}

Deno.serve(async (req: Request) => {
  try {
    return await handler(req);
  } catch (e) {
    console.error("water-logs", e);
    return jsonError("Something went wrong", 500);
  }
});
