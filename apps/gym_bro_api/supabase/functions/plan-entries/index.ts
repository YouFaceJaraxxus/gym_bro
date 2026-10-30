import { type Insertable, sql } from "npm:kysely@^0.27";
import { db } from "../_shared/config.ts";
import {
  type Caller,
  coachesUser,
  forbidden,
  isSuperUser,
  json,
  jsonError,
  requireCaller,
} from "../_shared/auth.ts";
import { dailyPlanSlots } from "../_shared/nutrition.ts";
import { generateEntries, isTimezone, MAX_WINDOW_DAYS } from "../_shared/plans.ts";
import { type LibraryKind, libraryAccess } from "../_shared/shares.ts";
import type { FoodLogTable } from "../../types/schema/public.ts";

// Planned workouts and meals on someone's calendar, from the routines and
// meal plans assigned to them (see _shared/plans.ts for how they're made).
// Each entry is the user's own once generated: move it, change its length,
// swap the training, add a note, skip it — or confirm it, which logs it.
//
//   GET    /plan-entries?from=&to=&tz=&user_id=   entries starting in [from, to) (ISO
//                                                 instants), generated as needed; tz is
//                                                 the viewer's IANA zone
//   GET    /plan-entries/:id                      + planned items (meals) or the
//                                                 training's exercises (workouts) and
//                                                 what was logged against it
//   PUT    /plan-entries/:id                      {starts_at?, duration_minutes?,
//                                                 training_id?, note?, skipped?}
//   DELETE /plan-entries/:id                      skips it (it would be regenerated)
//   POST   /plan-entries/:id/confirm {started_at?}
//          workout → a finished session with the training's sets as planned;
//          meal    → the slot's planned items in the food diary.
//          Logging differently goes through training-sessions / food-logs with
//          plan_entry_id instead.
//
// Row: { id, user_id, kind, status ('planned' | 'done' | 'skipped'), starts_at,
//        ends_at, duration_minutes, plan_date, note, edited, skipped,
//        training_id, training_name, routine_assignment_id, routine_id,
//        routine_name, meal_plan_assignment_id, meal_plan_id, meal_plan_name,
//        daily_meal_plan_id, daily_meal_plan_name, meal_slot,
//        training_session_id, logged_count,
//        source_status ('active' | 'left' | 'removed' | 'ended' | 'deleted'), left_at,
//        source_access, training_access, daily_meal_plan_access
//        ('ok' | 'private' | 'unavailable' for this viewer; null = no such link) }
// Entries outlive their enrolment: leaving keeps the past ones (names are
// kept even if the routine / training is deleted), so the app can say why a
// link no longer opens.
// Reads: the user, super, or a coach of theirs. Writes: the user or super.

type FoodLogInsert = Insertable<FoodLogTable>;

function parsePath(pathname: string): { id: string | null; action: "confirm" | null } {
  const confirm = pathname.match(/^\/plan-entries\/([^/]+)\/confirm\/?$/);
  if (confirm) return { id: confirm[1], action: "confirm" };
  const withId = pathname.match(/^\/plan-entries\/([^/]+)\/?$/);
  return { id: withId ? withId[1] : null, action: null };
}

function parseInstant(v: unknown): Date | null {
  if (typeof v !== "string") return null;
  const d = new Date(v);
  return Number.isNaN(d.getTime()) ? null : d;
}

/** The calendar date of [at] in [tz], 'YYYY-MM-DD'. */
function localDate(at: Date, tz: string): string {
  return new Intl.DateTimeFormat("en-CA", { timeZone: tz, year: "numeric", month: "2-digit", day: "2-digit" })
    .format(at);
}

function addDays(date: string, days: number): string {
  const d = new Date(`${date}T00:00:00Z`);
  d.setUTCDate(d.getUTCDate() + days);
  return d.toISOString().slice(0, 10);
}

function entryQuery() {
  return db.selectFrom("plan_entry as e")
    .leftJoin("training as t", "t.id", "e.training_id")
    .leftJoin("routine_assignment as ra", "ra.id", "e.routine_assignment_id")
    .leftJoin("routine as r", (j) => j.onRef("r.id", "=", "e.source_id").on("e.kind", "=", "workout"))
    .leftJoin("meal_plan_assignment as ma", "ma.id", "e.meal_plan_assignment_id")
    .leftJoin("meal_plan as mp", (j) => j.onRef("mp.id", "=", "e.source_id").on("e.kind", "=", "meal"))
    .leftJoin("daily_meal_plan as dmp", "dmp.id", "e.daily_meal_plan_id")
    .select([
      "e.id", "e.user_id", "e.kind", "e.starts_at",
      sql<string>`e.starts_at + make_interval(mins => e.duration_minutes)`.as("ends_at"),
      "e.duration_minutes",
      sql<string>`to_char(e.plan_date, 'YYYY-MM-DD')`.as("plan_date"),
      "e.note", "e.edited", "e.skipped",
      "e.training_id", sql<string | null>`COALESCE(t.name, e.training_name)`.as("training_name"),
      "e.routine_assignment_id", "r.id as routine_id",
      sql<string | null>`CASE WHEN e.kind = 'workout' THEN COALESCE(r.name, e.source_name) END`.as("routine_name"),
      "e.meal_plan_assignment_id", "mp.id as meal_plan_id",
      sql<string | null>`CASE WHEN e.kind = 'meal' THEN COALESCE(mp.name, e.source_name) END`.as("meal_plan_name"),
      "e.daily_meal_plan_id",
      sql<string | null>`COALESCE(dmp.name, e.daily_meal_plan_name)`.as("daily_meal_plan_name"), "e.meal_slot",
      sql<SourceStatus>`CASE
        WHEN COALESCE(r.id, mp.id) IS NULL THEN 'deleted'
        WHEN COALESCE(ra.left_at, ma.left_at) IS NOT NULL THEN
          CASE WHEN COALESCE(ra.left_by, ma.left_by) = e.user_id THEN 'left' ELSE 'removed' END
        WHEN COALESCE(ra.id, ma.id) IS NULL THEN 'ended'
        ELSE 'active' END`.as("source_status"),
      sql<string | null>`COALESCE(ra.left_at, ma.left_at)`.as("left_at"),
      sql<string | null>`(SELECT s.id FROM training_session s WHERE s.plan_entry_id = e.id
                          ORDER BY s.started_at DESC LIMIT 1)`.as("training_session_id"),
      sql<number>`(SELECT count(*)::int FROM food_log f WHERE f.plan_entry_id = e.id)`.as("logged_count"),
    ]);
}

/**
 * The enrolment an entry came from: still on, left by the user, removed by
 * whoever assigned it, gone, or the routine / meal plan itself deleted.
 */
type SourceStatus = "active" | "left" | "removed" | "ended" | "deleted";

type EntryRow = Awaited<ReturnType<ReturnType<typeof entryQuery>["executeTakeFirstOrThrow"]>>;
type Access = "ok" | "private" | "unavailable";

/**
 * Adds status and, for the viewer, whether the links still open:
 * source_access (routine / meal plan), training_access, daily_meal_plan_access
 * — "ok", "private" (no access, e.g. a private routine they left) or
 * "unavailable" (deleted); null when the entry never had that link.
 */
async function shape(rows: EntryRow[], viewer: Caller) {
  const memo = new Map<string, Promise<Access>>();
  const access = (kind: LibraryKind, id: string | null, name: string | null): Promise<Access | null> => {
    if (!id) return Promise.resolve(name ? "unavailable" : null);
    const key = `${kind}:${id}`;
    if (!memo.has(key)) memo.set(key, libraryAccess(viewer, kind, id));
    return memo.get(key)!;
  };
  return await Promise.all(rows.map(async (e) => {
    const done = e.kind === "workout" ? e.training_session_id !== null : e.logged_count > 0;
    const [source, training, day] = await Promise.all([
      e.kind === "workout"
        ? access("routine", e.routine_id, e.routine_name)
        : access("meal_plan", e.meal_plan_id, e.meal_plan_name),
      e.kind === "workout" ? access("training", e.training_id, e.training_name) : null,
      e.kind === "meal" ? access("daily_meal_plan", e.daily_meal_plan_id, e.daily_meal_plan_name) : null,
    ]);
    return {
      ...e,
      status: done ? "done" : e.skipped ? "skipped" : "planned",
      source_access: source,
      training_access: training,
      daily_meal_plan_access: day,
    };
  }));
}

async function fetchEntry(id: string, viewer: Caller) {
  const row = await entryQuery().where("e.id", "=", id).executeTakeFirst();
  return row ? (await shape([row], viewer))[0] : null;
}

/** Loads an entry the caller may read (or write); a Response otherwise. */
async function loadEntry(caller: Caller, id: string, write: boolean) {
  const entry = await db.selectFrom("plan_entry").selectAll()
    .select(sql<string>`to_char(plan_date, 'YYYY-MM-DD')`.as("plan_day"))
    .where("id", "=", id).executeTakeFirst()
    .catch(() => undefined);
  if (!entry) return jsonError("Plan entry not found", 404);
  if (entry.user_id === caller.id || isSuperUser(caller)) return entry;
  if (!write && (await coachesUser(caller, entry.user_id))) return entry;
  return write ? forbidden() : jsonError("Plan entry not found", 404);
}

/** Trainings a planned workout may use: public, the user's or caller's own, or in the routine. */
async function canUseTraining(trainingId: string, entry: { user_id: string; routine_assignment_id: string | null }, caller: Caller) {
  const res = await sql<{ ok: boolean }>`
    SELECT EXISTS (
      SELECT 1 FROM training t
       WHERE t.id = ${trainingId}
         AND (t.is_public OR t.author_id IN (${entry.user_id}, ${caller.id})
              OR EXISTS (SELECT 1 FROM routine_training rt
                           JOIN routine_assignment ra ON ra.routine_id = rt.routine_id
                          WHERE rt.training_id = t.id AND ra.id = ${entry.routine_assignment_id}))
    ) AS ok
  `.execute(db);
  return res.rows[0]?.ok === true;
}

/** A training's planned sets as session set logs (one per exercise slot). */
async function plannedSets(trainingId: string) {
  const slots = await db.selectFrom("training_set as ts")
    .innerJoin("training_set_exercise as tse", "tse.training_set_id", "ts.id")
    .select(["ts.id as training_set_id", "tse.id as tse_id", "tse.exercise_id", "ts.position as set_position",
      "tse.position as ex_position"])
    .where("ts.training_id", "=", trainingId)
    .orderBy("ts.position").orderBy("tse.position")
    .execute();
  const drops = slots.length
    ? await db.selectFrom("training_set_drop").selectAll()
      .where("training_set_exercise_id", "in", slots.map((s) => s.tse_id))
      .orderBy("drop_number").execute()
    : [];
  return slots.map((s) => ({
    training_set_id: s.training_set_id,
    exercise_id: s.exercise_id,
    drops: drops.filter((d) => d.training_set_exercise_id === s.tse_id),
  }));
}

function pgErrorResponse(e: unknown): Response {
  const err = e as { code?: string; message?: string } | null;
  switch (err?.code) {
    case "23503":
      return jsonError("Referenced record does not exist", 400);
    case "23514":
    case "22P02":
    case "22007":
    case "22008":
      return jsonError(err.message ?? "Invalid value", 400);
  }
  throw e;
}

async function handler(req: Request): Promise<Response> {
  const url = new URL(req.url);
  const { id, action } = parsePath(url.pathname.replace(/\/+$/, ""));

  const { caller, response } = await requireCaller(req);
  if (!caller) return response;

  // ── GET /plan-entries?from=&to=&tz=&user_id= ─────────────────────────────────
  if (req.method === "GET" && !id) {
    const from = parseInstant(url.searchParams.get("from"));
    const to = parseInstant(url.searchParams.get("to"));
    if (!from || !to) return jsonError("from and to must be ISO timestamps", 400);
    if (to <= from) return jsonError("to must be after from", 400);
    if (to.getTime() - from.getTime() > MAX_WINDOW_DAYS * 86_400_000) {
      return jsonError(`The window can't exceed ${MAX_WINDOW_DAYS} days`, 400);
    }
    const tz = url.searchParams.get("tz") || "UTC";
    if (!isTimezone(tz)) return jsonError("tz must be an IANA zone", 400);

    const userId = url.searchParams.get("user_id") || caller.id;
    if (userId !== caller.id && !isSuperUser(caller) && !(await coachesUser(caller, userId))) return forbidden();

    // A day either side covers assignments kept in another zone.
    await generateEntries(userId, addDays(localDate(from, tz), -1), addDays(localDate(to, tz), 1), tz);

    const rows = await entryQuery()
      .where("e.user_id", "=", userId)
      .where("e.starts_at", ">=", from.toISOString())
      .where("e.starts_at", "<", to.toISOString())
      .orderBy("e.starts_at")
      .execute();
    return json(await shape(rows, caller));
  }

  // ── GET /plan-entries/:id ─────────────────────────────────────────────────────
  if (req.method === "GET" && id && !action) {
    const entry = await loadEntry(caller, id, false);
    if (entry instanceof Response) return entry;
    const row = (await fetchEntry(id, caller))!;
    if (entry.kind === "meal") {
      const slots = entry.daily_meal_plan_id ? await dailyPlanSlots(entry.daily_meal_plan_id) : [];
      const slot = slots.find((s) => s.slot_type === entry.meal_slot);
      const logs = await db.selectFrom("food_log")
        .select(["id", "name", "amount", "kcal", "protein", "carb", "fat", "fiber", "eaten_at"])
        .where("plan_entry_id", "=", id).orderBy("created_at").execute();
      return json({ ...row, items: slot?.entries ?? [], slot_note: slot?.note ?? null, logs });
    }
    const exercises = entry.training_id
      ? await db.selectFrom("training_set as ts")
        .innerJoin("training_set_exercise as tse", "tse.training_set_id", "ts.id")
        .innerJoin("exercise as x", "x.id", "tse.exercise_id")
        .select(["x.id", "x.name", "ts.type as set_type",
          sql<number>`(SELECT count(*)::int FROM training_set_drop d WHERE d.training_set_exercise_id = tse.id)`
            .as("drop_count")])
        .where("ts.training_id", "=", entry.training_id)
        .orderBy("ts.position").orderBy("tse.position")
        .execute()
      : [];
    const sessions = await db.selectFrom("training_session")
      .select(["id", "started_at", "ended_at"])
      .where("plan_entry_id", "=", id).orderBy("started_at", "desc").execute();
    return json({ ...row, exercises, sessions });
  }

  // ── PUT /plan-entries/:id ─────────────────────────────────────────────────────
  if (req.method === "PUT" && id && !action) {
    const entry = await loadEntry(caller, id, true);
    if (entry instanceof Response) return entry;
    const body = await req.json().catch(() => null);
    if (!body || typeof body !== "object" || Array.isArray(body)) return jsonError("Body must be an object", 400);

    const update: Record<string, unknown> = {};
    if (body.starts_at !== undefined) {
      const at = parseInstant(body.starts_at);
      if (!at) return jsonError("starts_at must be an ISO timestamp", 400);
      update.starts_at = at.toISOString();
    }
    if (body.duration_minutes !== undefined) {
      const m = Number(body.duration_minutes);
      if (!Number.isInteger(m) || m < 5 || m > 600) return jsonError("duration_minutes must be 5–600", 400);
      update.duration_minutes = m;
    }
    if (body.note !== undefined) {
      const note = typeof body.note === "string" ? body.note.trim() : "";
      if (note.length > 1000) return jsonError("note is limited to 1000 characters", 400);
      update.note = note || null;
    }
    if (body.skipped !== undefined) {
      if (typeof body.skipped !== "boolean") return jsonError("skipped must be a boolean", 400);
      update.skipped = body.skipped;
    }
    if (body.training_id !== undefined) {
      if (entry.kind !== "workout") return jsonError("Only planned workouts have a training", 400);
      if (body.training_id !== null) {
        if (typeof body.training_id !== "string" || !(await canUseTraining(body.training_id, entry, caller))) {
          return jsonError("Training not found", 404);
        }
      }
      update.training_id = body.training_id;
      update.training_name = body.training_id
        ? (await db.selectFrom("training").select("name").where("id", "=", body.training_id).executeTakeFirst())?.name
        : null;
    }
    if (!Object.keys(update).length) return jsonError("Nothing to update", 400);

    await db.updateTable("plan_entry")
      .set({ ...update, edited: true, updated_at: new Date().toISOString() })
      .where("id", "=", id).execute();
    return json(await fetchEntry(id, caller));
  }

  // ── DELETE /plan-entries/:id — skip ──────────────────────────────────────────
  if (req.method === "DELETE" && id && !action) {
    const entry = await loadEntry(caller, id, true);
    if (entry instanceof Response) return entry;
    await db.updateTable("plan_entry").set({ skipped: true, updated_at: new Date().toISOString() })
      .where("id", "=", id).execute();
    return new Response(null, { status: 204 });
  }

  // ── POST /plan-entries/:id/confirm {started_at?} ─────────────────────────────
  if (req.method === "POST" && id && action === "confirm") {
    const entry = await loadEntry(caller, id, true);
    if (entry instanceof Response) return entry;
    if (entry.user_id !== caller.id) return forbidden("Only the person it's planned for can log it");
    const body = await req.json().catch(() => ({}));
    const startedAt = body?.started_at == null ? new Date(entry.starts_at) : parseInstant(body.started_at);
    if (!startedAt) return jsonError("started_at must be an ISO timestamp", 400);
    const endedAt = new Date(startedAt.getTime() + entry.duration_minutes * 60_000);

    if (entry.kind === "workout") {
      const sets = entry.training_id ? await plannedSets(entry.training_id) : [];
      const sessionId = await db.transaction().execute(async (trx) => {
        const session = await trx.insertInto("training_session").values({
          user_id: caller.id,
          training_id: entry.training_id,
          plan_entry_id: entry.id,
          started_at: startedAt.toISOString(),
          ended_at: endedAt.toISOString(),
          notes: entry.note,
        }).returning("id").executeTakeFirstOrThrow();
        for (const [i, s] of sets.entries()) {
          const log = await trx.insertInto("session_set_log").values({
            session_id: session.id,
            training_set_id: s.training_set_id,
            exercise_id: s.exercise_id,
            position: i,
          }).returning("id").executeTakeFirstOrThrow();
          if (s.drops.length) {
            await trx.insertInto("session_drop_log").values(s.drops.map((d) => ({
              session_set_log_id: log.id,
              training_set_drop_id: d.id,
              drop_number: d.drop_number,
              rep_type_actual: d.rep_type,
              rep_count_actual: d.rep_count,
              weight_kg_actual: d.weight_kg,
              side: d.side,
            }))).execute();
          }
        }
        return session.id;
      });
      return json({ ...(await fetchEntry(id, caller)), training_session_id: sessionId }, 201);
    }

    const slots = entry.daily_meal_plan_id ? await dailyPlanSlots(entry.daily_meal_plan_id) : [];
    const items = slots.filter((s) => s.slot_type === entry.meal_slot).flatMap((s) => s.entries);
    if (!items.length) return jsonError("Nothing is planned for this meal", 404);
    const base = Date.now();
    await db.insertInto("food_log").values(items.map((e, i) => ({
      created_at: new Date(base + i).toISOString(), // keeps the plan's order
      user_id: caller.id,
      log_date: entry.plan_day,
      slot_type: entry.meal_slot!,
      food_item_id: e.food_item_id,
      recipe_id: e.recipe_id,
      name: e.name,
      amount: e.amount,
      kcal: e.kcal,
      protein: e.protein,
      carb: e.carb,
      fat: e.fat,
      fiber: e.fiber,
      note: e.note,
      eaten_at: startedAt.toISOString(),
      plan_entry_id: entry.id,
    })) as unknown as FoodLogInsert[]).execute();
    return json(await fetchEntry(id, caller), 201);
  }

  return jsonError("Not found", 404);
}

Deno.serve(async (req: Request) => {
  try {
    return await handler(req);
  } catch (e) {
    return pgErrorResponse(e);
  }
});
