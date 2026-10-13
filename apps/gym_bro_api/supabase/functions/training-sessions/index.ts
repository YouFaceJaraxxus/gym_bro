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
import { notify } from "../_shared/notify.ts";
import { userDropRows } from "../_shared/progress.ts";
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

/** Number of comments on the session; select alongside SESSION_COLS. */
const COMMENT_COUNT = sql<number>`(
  SELECT COUNT(*)::int FROM session_comment sc WHERE sc.session_id = training_session.id
)`.as("comment_count");

/** The trainer's display name ("Elena Vasquez"); null when there's no trainer. */
const TRAINER_NAME = sql<string | null>`(
  SELECT NULLIF(TRIM(u.name || ' ' || u.last_name), '') FROM users u WHERE u.id = training_session.trainer_id
)`.as("trainer_name");

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
// /training-sessions/:id/comments           → { id, action: 'comments' }
// /training-sessions/comments/:commentId    → { id: commentId, action: 'comment' }

type Action = "set_log" | "drops" | "sets" | "end" | "comments" | "comment" | null;

function parsePath(pathname: string): { id: string | null; action: Action } {
  const comment = pathname.match(/^\/training-sessions\/comments\/([^/]+)$/);
  if (comment) return { id: comment[1], action: "comment" };

  const setLog = pathname.match(/^\/training-sessions\/sets\/([^/]+)$/);
  if (setLog) return { id: setLog[1], action: "set_log" };

  const setsDrops = pathname.match(/^\/training-sessions\/sets\/([^/]+)\/drops$/);
  if (setsDrops) return { id: setsDrops[1], action: "drops" };

  const withAction = pathname.match(/^\/training-sessions\/([^/]+)\/(sets|end|comments)$/);
  if (withAction) return { id: withAction[1], action: withAction[2] as "sets" | "end" | "comments" };

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
    .select([...SESSION_COLS, COMMENT_COUNT, TRAINER_NAME])
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

// ── Personal records ──────────────────────────────────────────────────────────

type PrHit = { exercise_id: string; e1rm: number; previous_e1rm: number };

/**
 * Compares the just-logged set's best e1RM per exercise with the user's best
 * from every other logged set. A first-ever log of an exercise is not a PR.
 * Returns { is_pr, pr_e1rm, pr_exercise_id, previous_e1rm, prs[] }.
 */
async function detectPrs(userId: string, setLogId: string) {
  const res = await sql<PrHit>`
    WITH d AS (${userDropRows(userId)}),
    cur AS (
      SELECT exercise_id, MAX(e1rm) AS e1rm
        FROM d
       WHERE set_log_id = ${setLogId} AND exercise_id IS NOT NULL AND e1rm IS NOT NULL
       GROUP BY exercise_id
    ),
    prev AS (
      SELECT d.exercise_id, MAX(d.e1rm) AS e1rm
        FROM d JOIN cur ON cur.exercise_id = d.exercise_id
       WHERE d.set_log_id <> ${setLogId}
       GROUP BY d.exercise_id
    )
    SELECT cur.exercise_id,
           ROUND(cur.e1rm, 2)::float8  AS e1rm,
           ROUND(prev.e1rm, 2)::float8 AS previous_e1rm
      FROM cur JOIN prev ON prev.exercise_id = cur.exercise_id
     WHERE cur.e1rm > prev.e1rm
     ORDER BY cur.e1rm DESC
  `.execute(db);
  const top = res.rows[0];
  return {
    is_pr: !!top,
    pr_e1rm: top?.e1rm ?? null,
    pr_exercise_id: top?.exercise_id ?? null,
    previous_e1rm: top?.previous_e1rm ?? null,
    prs: res.rows,
  };
}

// ── Comments ──────────────────────────────────────────────────────────────────
// Row: { id, session_id, author_id, author_name, author_avatar_url, body,
//        created_at, updated_at }

async function fetchComments(where: { sessionId?: string; commentId?: string }) {
  let query = db
    .selectFrom("session_comment")
    .leftJoin("users", "users.id", "session_comment.author_id")
    .select([
      "session_comment.id",
      "session_comment.session_id",
      "session_comment.author_id",
      sql<string | null>`NULLIF(TRIM(COALESCE(users.name, '') || ' ' || COALESCE(users.last_name, '')), '')`
        .as("author_name"),
      "users.avatar_url as author_avatar_url",
      "session_comment.body",
      "session_comment.created_at",
      "session_comment.updated_at",
    ]);
  if (where.sessionId) query = query.where("session_comment.session_id", "=", where.sessionId);
  if (where.commentId) query = query.where("session_comment.id", "=", where.commentId);
  return await query.orderBy("session_comment.created_at", "asc").execute();
}

function readCommentBody(body: unknown): string | null {
  const text = (body as { body?: unknown } | null)?.body;
  if (typeof text !== "string") return null;
  const trimmed = text.trim();
  return trimmed && trimmed.length <= 4000 ? trimmed : null;
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

    let query = db.selectFrom("training_session").select([...SESSION_COLS, COMMENT_COUNT, TRAINER_NAME]);

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

    return json({ ...session, comment_count: 0 }, 201);
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
      .returning([...SESSION_COLS, COMMENT_COUNT, TRAINER_NAME])
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

    return json({ ...result, ...(await detectPrs(session.user_id, result.id)) }, 201);
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

  // ── GET /training-sessions/:id/comments ──────────────────────────────────────
  if (req.method === "GET" && id && action === "comments") {
    const session = await db
      .selectFrom("training_session")
      .select(["id", "user_id", "trainer_id"])
      .where("id", "=", id)
      .executeTakeFirst();
    if (!session) return jsonError("Session not found", 404);
    if (!(await canReadSession(caller, session))) return forbidden();
    return json(await fetchComments({ sessionId: id }));
  }

  // ── POST /training-sessions/:id/comments — owner, trainer or coach ───────────
  // Notifies the owner when someone else comments, and earlier non-owner
  // commenters when the owner replies.
  if (req.method === "POST" && id && action === "comments") {
    const session = await db
      .selectFrom("training_session")
      .select(["id", "user_id", "trainer_id"])
      .where("id", "=", id)
      .executeTakeFirst();
    if (!session) return jsonError("Session not found", 404);
    if (!(await canReadSession(caller, session))) return forbidden();

    const text = readCommentBody(await req.json().catch(() => null));
    if (!text) return jsonError("body is required (max 4000 characters)", 400);

    const inserted = await db
      .insertInto("session_comment")
      .values({ session_id: id, author_id: caller.id, body: text })
      .returning(["id"])
      .executeTakeFirstOrThrow();

    const author = `${caller.name ?? ""} ${caller.last_name ?? ""}`.trim() || "Someone";
    const preview = text.length > 120 ? `${text.slice(0, 117)}…` : text;
    const metadata = { session_id: id, comment_id: inserted.id };
    if (caller.id !== session.user_id) {
      await notify([session.user_id], {
        type: "session_comment",
        title: `${author} commented on your session`,
        body: preview,
        metadata,
      });
    } else {
      const previous = await db
        .selectFrom("session_comment")
        .select("author_id")
        .distinct()
        .where("session_id", "=", id)
        .where("author_id", "is not", null)
        .where("author_id", "<>", session.user_id)
        .execute();
      await notify(previous.map((r) => r.author_id!), {
        type: "session_comment",
        title: `${author} replied on their session`,
        body: preview,
        metadata,
      });
    }

    const [comment] = await fetchComments({ commentId: inserted.id });
    return json(comment, 201);
  }

  // ── PUT /training-sessions/comments/:commentId — author or super ─────────────
  if (req.method === "PUT" && id && action === "comment") {
    const existing = await db
      .selectFrom("session_comment")
      .select(["author_id"])
      .where("id", "=", id)
      .executeTakeFirst();
    if (!existing) return jsonError("Comment not found", 404);
    if (existing.author_id !== caller.id && !isSuperUser(caller)) return forbidden();

    const text = readCommentBody(await req.json().catch(() => null));
    if (!text) return jsonError("body is required (max 4000 characters)", 400);

    await db
      .updateTable("session_comment")
      .set({ body: text, updated_at: sql<string>`now()` })
      .where("id", "=", id)
      .execute();
    const [comment] = await fetchComments({ commentId: id });
    return json(comment);
  }

  // ── DELETE /training-sessions/comments/:commentId — author or super ──────────
  if (req.method === "DELETE" && id && action === "comment") {
    const existing = await db
      .selectFrom("session_comment")
      .select(["author_id"])
      .where("id", "=", id)
      .executeTakeFirst();
    if (!existing) return jsonError("Comment not found", 404);
    if (existing.author_id !== caller.id && !isSuperUser(caller)) return forbidden();

    await db.deleteFrom("session_comment").where("id", "=", id).execute();
    return new Response(null, { status: 204 });
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
