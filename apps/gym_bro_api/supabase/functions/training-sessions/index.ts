import { type Kysely, sql } from "npm:kysely@^0.27";
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
import type {
  BodySide,
  Database,
  RepType,
  SessionDropLogInsert,
  SessionSetLogInsert,
  TrainingSessionInsert,
  TrainingSessionUpdate,
} from "../../types/schema/public.ts";

const SESSION_COLS = [
  "id", "user_id", "trainer_id", "training_id",
  "started_at", "ended_at", "notes", "created_at", "updated_at",
] as const;

const SET_LOG_COLS = [
  "id", "session_id", "training_set_id", "exercise_id", "position", "note",
] as const;

const DROP_LOG_COLS = [
  "id", "session_set_log_id", "training_set_drop_id",
  "drop_number", "rep_type_actual", "rep_count_actual",
  "weight_kg_actual", "side", "note",
] as const;

const VALID_REP_TYPES: RepType[] = ["count", "failure", "unspecified"];
const VALID_SIDES: BodySide[] = ["both", "left", "right"];

type DropPayload = {
  training_set_drop_id?: string;
  drop_number?: number;
  rep_type_actual?: RepType;
  rep_count_actual?: number;
  weight_kg_actual?: number;
  side?: BodySide;
  note?: string;
};

function toDropInserts(setLogId: string, drops: DropPayload[]): SessionDropLogInsert[] {
  return drops.map((d, i) => ({
    session_set_log_id: setLogId,
    training_set_drop_id: d.training_set_drop_id ?? null,
    drop_number: d.drop_number ?? i,
    rep_type_actual: VALID_REP_TYPES.includes(d.rep_type_actual!) ? d.rep_type_actual! : "count",
    rep_count_actual: d.rep_count_actual ?? null,
    weight_kg_actual: d.weight_kg_actual ?? null,
    side: VALID_SIDES.includes(d.side!) ? d.side! : "both",
    note: d.note ?? null,
  }));
}

// ── Path helpers ──────────────────────────────────────────────────────────────
// Set-log routes are matched first so "sets" is never parsed as a session id.

// /training-sessions                        → { id: null, action: null }
// /training-sessions/sets/:setLogId         → { id: setLogId, action: 'set_log' }
// /training-sessions/sets/:setLogId/drops   → { id: setLogId, action: 'drops' }
// /training-sessions/:id                    → { id, action: null }
// /training-sessions/:id/sets               → { id, action: 'sets' }
// /training-sessions/:id/end                → { id, action: 'end' }

type Action = "set_log" | "drops" | "sets" | "end" | null;

function parsePath(pathname: string): { id: string | null; action: Action } {
  const setLog = pathname.match(/^\/training-sessions\/sets\/([^/]+)$/);
  if (setLog) return { id: setLog[1], action: "set_log" };

  const setsDrops = pathname.match(/^\/training-sessions\/sets\/([^/]+)\/drops$/);
  if (setsDrops) return { id: setsDrops[1], action: "drops" };

  const withAction = pathname.match(/^\/training-sessions\/([^/]+)\/(sets|end)$/);
  if (withAction) return { id: withAction[1], action: withAction[2] as "sets" | "end" };

  const withId = pathname.match(/^\/training-sessions\/([^/]+)$/);
  if (withId) return { id: withId[1], action: null };

  return { id: null, action: null };
}

// ── Access ────────────────────────────────────────────────────────────────────

/** Owner, the session's trainer, anyone who coaches the owner, or super. */
async function canReadSession(
  caller: Caller,
  session: { user_id: string; trainer_id: string | null },
): Promise<boolean> {
  if (session.user_id === caller.id || isSuperUser(caller)) return true;
  if (session.trainer_id && session.trainer_id === caller.id) return true;
  return await coachesUser(caller, session.user_id);
}

function canWriteSession(caller: Caller, session: { user_id: string }): boolean {
  return session.user_id === caller.id || isSuperUser(caller);
}

/** Loads a set log together with the owner of its session. */
async function findSetLog(setLogId: string) {
  return await db
    .selectFrom("session_set_log")
    .innerJoin("training_session", "training_session.id", "session_set_log.session_id")
    .select(["session_set_log.id", "session_set_log.session_id", "training_session.user_id"])
    .where("session_set_log.id", "=", setLogId)
    .executeTakeFirst();
}

// ── Nested fetch ──────────────────────────────────────────────────────────────

async function fetchSetLogWithDrops(setLogId: string, executor: Kysely<Database> = db) {
  const setLog = await executor
    .selectFrom("session_set_log")
    .select(SET_LOG_COLS)
    .where("id", "=", setLogId)
    .executeTakeFirstOrThrow();
  const dropLogs = await executor
    .selectFrom("session_drop_log")
    .select(DROP_LOG_COLS)
    .where("session_set_log_id", "=", setLogId)
    .orderBy("drop_number", "asc")
    .execute();
  return { ...setLog, drop_logs: dropLogs };
}

async function fetchSessionDetail(sessionId: string) {
  const session = await db
    .selectFrom("training_session")
    .select(SESSION_COLS)
    .where("id", "=", sessionId)
    .executeTakeFirst();

  if (!session) return null;

  const setLogs = await db
    .selectFrom("session_set_log")
    .select(SET_LOG_COLS)
    .where("session_id", "=", sessionId)
    .orderBy("position", "asc")
    .execute();

  const setLogIds = setLogs.map((s) => s.id);
  const dropLogs = setLogIds.length
    ? await db
        .selectFrom("session_drop_log")
        .select(DROP_LOG_COLS)
        .where("session_set_log_id", "in", setLogIds)
        .orderBy("drop_number", "asc")
        .execute()
    : [];

  const dropsBySetLog = dropLogs.reduce(
    (acc, d) => {
      (acc[d.session_set_log_id] ??= []).push(d);
      return acc;
    },
    {} as Record<string, typeof dropLogs>,
  );

  return {
    ...session,
    set_logs: setLogs.map((s) => ({
      ...s,
      drop_logs: dropsBySetLog[s.id] ?? [],
    })),
  };
}

// ── Postgres error mapping ────────────────────────────────────────────────────

function pgErrorResponse(e: unknown): Response {
  const err = e as { code?: string; message?: string; detail?: string } | null;
  switch (err?.code) {
    case "23505":
      return jsonError("Already exists", 409, { detail: err.detail });
    case "23503":
      return jsonError("Referenced record does not exist", 400, { detail: err.detail });
    case "23502":
    case "23514":
    case "22P02":
    case "22007":
    case "22008":
      return jsonError(err.message ?? "Invalid value", 400);
  }
  throw e;
}

// ── Handler ───────────────────────────────────────────────────────────────────

async function handler(req: Request): Promise<Response> {
  const url = new URL(req.url);
  const { id, action } = parsePath(url.pathname);

  const { caller, response } = await requireCaller(req);
  if (!caller) return response;

  // ── GET /training-sessions — list sessions ────────────────────────────────────
  if (req.method === "GET" && !id) {
    const trainerId = url.searchParams.get("trainer_id");
    const trainingId = url.searchParams.get("training_id");
    const page = parseInt(url.searchParams.get("page") ?? "0");
    const pageSize = Math.min(parseInt(url.searchParams.get("page_size") ?? "20"), 100);

    let query = db.selectFrom("training_session").select(SESSION_COLS);

    if (trainerId) {
      // "Classes I'm running" view — only the trainer themself or super_user may read it.
      if (trainerId !== caller.id && !isSuperUser(caller)) return forbidden();
      query = query.where("trainer_id", "=", trainerId);
    } else {
      const targetUserId = url.searchParams.get("user_id") ?? caller.id;
      // Self, super user, or someone who coaches the user at one of their gyms.
      if (targetUserId !== caller.id && !(await coachesUser(caller, targetUserId))) {
        return forbidden();
      }
      query = query.where("user_id", "=", targetUserId);
    }

    if (trainingId) query = query.where("training_id", "=", trainingId);

    const sessions = await query
      .orderBy("started_at", "desc")
      .limit(pageSize)
      .offset(page * pageSize)
      .execute();

    return json(sessions);
  }

  // ── GET /training-sessions/:id — full detail ──────────────────────────────────
  if (req.method === "GET" && id && !action) {
    const detail = await fetchSessionDetail(id);
    if (!detail) return jsonError("Session not found", 404);
    if (!(await canReadSession(caller, detail))) return forbidden();
    return json(detail);
  }

  // ── POST /training-sessions — start a new session ─────────────────────────────
  if (req.method === "POST" && !id) {
    const body = await req.json().catch(() => null);
    const { training_id, trainer_id, notes } = body ?? {};

    if (trainer_id) {
      const [trainer, employeeTrainer] = await Promise.all([
        db.selectFrom("trainer").select("id").where("user_id", "=", trainer_id).executeTakeFirst(),
        db.selectFrom("employee_trainer").select("id").where("user_id", "=", trainer_id).executeTakeFirst(),
      ]);
      if (!trainer && !employeeTrainer) {
        return jsonError("trainer_id must be a user who is a trainer", 400);
      }
    }

    const insert: TrainingSessionInsert = {
      user_id: caller.id,
      training_id: training_id ?? null,
      trainer_id: trainer_id ?? null,
      notes: notes ?? null,
    };

    const session = await db
      .insertInto("training_session")
      .values(insert)
      .returning(SESSION_COLS)
      .executeTakeFirstOrThrow();

    return json(session, 201);
  }

  // ── PUT /training-sessions/:id — update session (end time, notes) ─────────────
  if (req.method === "PUT" && id && !action) {
    const session = await db
      .selectFrom("training_session")
      .select(["id", "user_id"])
      .where("id", "=", id)
      .executeTakeFirst();
    if (!session) return jsonError("Session not found", 404);
    if (!canWriteSession(caller, session)) return forbidden();

    const body = await req.json().catch(() => null);
    const update: TrainingSessionUpdate = {
      ...(body?.ended_at !== undefined && { ended_at: body.ended_at }),
      ...(body?.notes !== undefined && { notes: body.notes }),
      updated_at: new Date().toISOString(),
    };

    const updated = await db
      .updateTable("training_session")
      .set(update)
      .where("id", "=", id)
      .returning(SESSION_COLS)
      .executeTakeFirst();

    return json(updated);
  }

  // ── POST /training-sessions/:id/end — finish the session ──────────────────────
  if (req.method === "POST" && id && action === "end") {
    const session = await db
      .selectFrom("training_session")
      .select(["id", "user_id"])
      .where("id", "=", id)
      .executeTakeFirst();
    if (!session) return jsonError("Session not found", 404);
    if (!canWriteSession(caller, session)) return forbidden();

    // Idempotent: an already-ended session keeps its original ended_at.
    await db
      .updateTable("training_session")
      .set({ ended_at: sql<string>`now()`, updated_at: sql<string>`now()` })
      .where("id", "=", id)
      .where("ended_at", "is", null)
      .execute();

    return json(await fetchSessionDetail(id));
  }

  // ── POST /training-sessions/:id/sets — log a set ──────────────────────────────
  if (req.method === "POST" && id && action === "sets") {
    const session = await db
      .selectFrom("training_session")
      .select(["id", "user_id"])
      .where("id", "=", id)
      .executeTakeFirst();
    if (!session) return jsonError("Session not found", 404);
    if (!canWriteSession(caller, session)) return forbidden();

    const body = await req.json().catch(() => null);
    const { training_set_id, exercise_id, position, note, drops } = body ?? {};

    const setLogInsert: SessionSetLogInsert = {
      session_id: id,
      training_set_id: training_set_id ?? null,
      exercise_id: exercise_id ?? null,
      position: position ?? 0,
      note: note ?? null,
    };

    const result = await db.transaction().execute(async (trx) => {
      const setLog = await trx
        .insertInto("session_set_log")
        .values(setLogInsert)
        .returning(["id"])
        .executeTakeFirstOrThrow();

      if (Array.isArray(drops) && drops.length) {
        await trx.insertInto("session_drop_log").values(toDropInserts(setLog.id, drops)).execute();
      }

      return await fetchSetLogWithDrops(setLog.id, trx);
    });

    return json(result, 201);
  }

  // ── PUT /training-sessions/sets/:setLogId — edit a logged set ─────────────────
  // Body: any of { training_set_id, exercise_id, position, note, drops }.
  // When `drops` is an array it replaces all drop logs of the set.
  if (req.method === "PUT" && id && action === "set_log") {
    const setLog = await findSetLog(id);
    if (!setLog) return jsonError("Set log not found", 404);
    if (!canWriteSession(caller, setLog)) return forbidden();

    const body = await req.json().catch(() => null);
    if (!body || typeof body !== "object" || Array.isArray(body)) {
      return jsonError("Body must be an object", 400);
    }
    const { training_set_id, exercise_id, position, note, drops } = body;

    const fields = {
      ...(training_set_id !== undefined && { training_set_id }),
      ...(exercise_id !== undefined && { exercise_id }),
      ...(position !== undefined && { position }),
      ...(note !== undefined && { note }),
    };

    const result = await db.transaction().execute(async (trx) => {
      if (Object.keys(fields).length) {
        await trx.updateTable("session_set_log").set(fields).where("id", "=", id).execute();
      }
      if (Array.isArray(drops)) {
        await trx.deleteFrom("session_drop_log").where("session_set_log_id", "=", id).execute();
        if (drops.length) {
          await trx.insertInto("session_drop_log").values(toDropInserts(id, drops)).execute();
        }
      }
      await trx
        .updateTable("training_session")
        .set({ updated_at: new Date().toISOString() })
        .where("id", "=", setLog.session_id)
        .execute();
      return await fetchSetLogWithDrops(id, trx);
    });

    return json(result);
  }

  // ── DELETE /training-sessions/sets/:setLogId — remove a logged set ────────────
  if (req.method === "DELETE" && id && action === "set_log") {
    const setLog = await findSetLog(id);
    if (!setLog) return jsonError("Set log not found", 404);
    if (!canWriteSession(caller, setLog)) return forbidden();

    // session_drop_log rows cascade.
    await db.deleteFrom("session_set_log").where("id", "=", id).execute();
    return new Response(null, { status: 204 });
  }

  // ── POST /training-sessions/sets/:setLogId/drops — add drops to a set log ─────
  if (req.method === "POST" && id && action === "drops") {
    const setLog = await findSetLog(id);
    if (!setLog) return jsonError("Set log not found", 404);
    if (!canWriteSession(caller, setLog)) return forbidden();

    const body = await req.json().catch(() => null);
    if (!body) return jsonError("Body must not be empty", 400);
    const drops: DropPayload[] = Array.isArray(body) ? body : [body];
    if (!drops.length) return json([], 201);

    const inserted = await db
      .insertInto("session_drop_log")
      .values(toDropInserts(id, drops))
      .returning(DROP_LOG_COLS)
      .execute();

    return json(inserted, 201);
  }

  // ── DELETE /training-sessions/:id ────────────────────────────────────────────
  if (req.method === "DELETE" && id && !action) {
    const session = await db
      .selectFrom("training_session")
      .select(["user_id"])
      .where("id", "=", id)
      .executeTakeFirst();
    if (!session) return jsonError("Session not found", 404);
    if (!canWriteSession(caller, session)) return forbidden();

    await db.deleteFrom("training_session").where("id", "=", id).execute();
    return new Response(null, { status: 204 });
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
