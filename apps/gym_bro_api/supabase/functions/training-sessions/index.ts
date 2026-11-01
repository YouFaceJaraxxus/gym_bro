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
import { streakAfterWorkout } from "../_shared/streaks.ts";
import { syncChallengesLater } from "../_shared/challenges.ts";
import { libraryAccess } from "../_shared/shares.ts";
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
  "started_at", "ended_at", "notes", "plan_entry_id", "created_at", "updated_at",
] as const;

/** Number of comments on the session; select alongside SESSION_COLS. */
const COMMENT_COUNT = sql<number>`(
  SELECT COUNT(*)::int FROM session_comment sc WHERE sc.session_id = training_session.id
)`.as("comment_count");

/** Sets logged in the session (the list leaves the set logs out). */
const SET_COUNT = sql<number>`(
  SELECT COUNT(*)::int FROM session_set_log sl WHERE sl.session_id = training_session.id
)`.as("set_count");

/** The followed training's name; null for free sessions or a deleted training. */
const TRAINING_NAME = sql<string | null>`(
  SELECT t.name FROM training t WHERE t.id = training_session.training_id
)`.as("training_name");

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

type SetPayload = {
  training_set_id?: string;
  exercise_id?: string;
  position?: number;
  note?: string;
  drops?: DropPayload[];
};

/** Parses an ISO timestamp; null when missing or unparseable. */
function parseInstant(v: unknown): Date | null {
  if (typeof v !== "string") return null;
  const d = new Date(v);
  return Number.isNaN(d.getTime()) ? null : d;
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
// /training-sessions/last-sets              → { id: null, action: 'last_sets' }

type Action = "set_log" | "drops" | "sets" | "end" | "comments" | "comment" | "last_sets" | null;

function parsePath(pathname: string): { id: string | null; action: Action } {
  if (/^\/training-sessions\/last-sets\/?$/.test(pathname)) return { id: null, action: "last_sets" };

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

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

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

/**
 * The athlete, the trainer who ran it (gym or no gym), or super. Trainers
 * log and edit sessions for the people they coach.
 */
function canWriteSession(caller: Caller, session: { user_id: string; trainer_id: string | null }): boolean {
  if (session.user_id === caller.id || isSuperUser(caller)) return true;
  return caller.is_trainer && session.trainer_id === caller.id;
}

/** Loads a set log together with the owner of its session. */
async function findSetLog(setLogId: string) {
  return await db
    .selectFrom("session_set_log")
    .innerJoin("training_session", "training_session.id", "session_set_log.session_id")
    .select([
      "session_set_log.id",
      "session_set_log.session_id",
      "training_session.user_id",
      "training_session.trainer_id",
    ])
    .where("session_set_log.id", "=", setLogId)
    .executeTakeFirst();
}

/** Tells a client their trainer logged a session for them. */
async function notifyClient(trainer: Caller, clientId: string, sessionId: string) {
  const name = `${trainer.name} ${trainer.last_name}`.trim();
  await notify([clientId], {
    type: "training",
    title: `${name} logged a session with you`,
    body: "It's in your sessions and counts towards your progress.",
    metadata: { session_id: sessionId, trainer_id: trainer.id },
  });
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
    .select([...SESSION_COLS, COMMENT_COUNT, TRAINER_NAME, TRAINING_NAME])
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

// ── Last sets (progressive-overload suggestions) ──────────────────────────────

type LastSetsRow = {
  exercise_id: string;
  session_id: string;
  started_at: Date;
  sets: { weight_kg: number | null; reps: number | null; rep_type: RepType; side: BodySide }[];
};

/**
 * Per exercise in `exerciseIds`: the drops `userId` logged for it in their
 * most recent finished session that started before `before`, in logged order.
 * Exercises are resolved like userDropRows (set log → planned drop's slot →
 * the planned set's only exercise). One round trip; exercises never logged
 * are left out.
 */
async function lastSets(userId: string, exerciseIds: string[], before: Date) {
  const res = await sql<LastSetsRow>`
    WITH d AS (
      SELECT ts.id AS session_id, ts.started_at, sl.position, dl.drop_number,
             COALESCE(
               sl.exercise_id,
               tse.exercise_id,
               (SELECT CASE WHEN COUNT(*) = 1 THEN (ARRAY_AGG(x.exercise_id))[1] END
                  FROM training_set_exercise x
                 WHERE x.training_set_id = sl.training_set_id)
             ) AS exercise_id,
             dl.rep_type_actual, dl.rep_count_actual, dl.weight_kg_actual, dl.side
        FROM training_session ts
        JOIN session_set_log sl        ON sl.session_id = ts.id
        JOIN session_drop_log dl       ON dl.session_set_log_id = sl.id
        LEFT JOIN training_set_drop tsd     ON tsd.id = dl.training_set_drop_id
        LEFT JOIN training_set_exercise tse ON tse.id = tsd.training_set_exercise_id
       WHERE ts.user_id = ${userId}
         AND ts.ended_at IS NOT NULL
         AND ts.started_at < ${before.toISOString()}
    ),
    latest AS (
      SELECT DISTINCT ON (exercise_id) exercise_id, session_id, started_at
        FROM d
       WHERE exercise_id = ANY(${exerciseIds}::uuid[])
       ORDER BY exercise_id, started_at DESC, session_id
    )
    SELECT l.exercise_id, l.session_id, l.started_at,
           json_agg(json_build_object(
             'weight_kg', d.weight_kg_actual::float8,
             'reps',      d.rep_count_actual,
             'rep_type',  d.rep_type_actual,
             'side',      d.side
           ) ORDER BY d.position, d.drop_number) AS sets
      FROM latest l
      JOIN d ON d.session_id = l.session_id AND d.exercise_id = l.exercise_id
     GROUP BY l.exercise_id, l.session_id, l.started_at
  `.execute(db);
  return res.rows;
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

// ── Streak ────────────────────────────────────────────────────────────────────

/** The athlete's streak after a workout changed; a failure here never fails the workout. */
async function streakOrNull(userId: string) {
  // Challenge progress and completions, after the response.
  syncChallengesLater(userId);
  try {
    return await streakAfterWorkout(userId);
  } catch (err) {
    console.error("streak refresh failed", userId, err);
    return null;
  }
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

  // ── GET /training-sessions/last-sets?exercise_ids=a,b — last time per exercise ─
  // For progressive-overload suggestions while logging: per exercise, the sets
  // of the caller's most recent finished session with it (?before= an ISO
  // timestamp, e.g. when back-filling a past workout). A trainer logging for
  // a client passes ?user_id= (same access as listing their sessions).
  // Rows: [{ exercise_id, session_id, started_at,
  //          sets: [{ weight_kg, reps, rep_type, side }] }]
  if (req.method === "GET" && action === "last_sets") {
    const ids = [...new Set((url.searchParams.get("exercise_ids") ?? "").split(",").map((s) => s.trim()).filter(Boolean))];
    if (ids.length > 100) return jsonError("At most 100 exercise_ids", 400);
    if (ids.some((x) => !UUID_RE.test(x))) return jsonError("exercise_ids must be UUIDs", 400);
    const targetUserId = url.searchParams.get("user_id") ?? caller.id;
    if (!UUID_RE.test(targetUserId)) return jsonError("user_id must be a UUID", 400);
    if (targetUserId !== caller.id && !(await coachesUser(caller, targetUserId))) return forbidden();
    const rawBefore = url.searchParams.get("before");
    const before = rawBefore === null ? new Date() : parseInstant(rawBefore);
    if (!before) return jsonError("before must be an ISO timestamp", 400);
    if (!ids.length) return json([]);
    return json(await lastSets(targetUserId, ids, before));
  }
  if (action === "last_sets") return jsonError("Method not allowed", 405);

  // ── GET /training-sessions — list sessions ────────────────────────────────────
  if (req.method === "GET" && !id) {
    const trainerId = url.searchParams.get("trainer_id");
    const trainingId = url.searchParams.get("training_id");
    const page = parseInt(url.searchParams.get("page") ?? "0");
    const pageSize = Math.min(parseInt(url.searchParams.get("page_size") ?? "20"), 100);

    let query = db.selectFrom("training_session").select([...SESSION_COLS, COMMENT_COUNT, SET_COUNT, TRAINER_NAME, TRAINING_NAME]);

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

    // Calendar weeks: sessions starting in [from, to).
    for (const [param, op] of [["from", ">="], ["to", "<"]] as const) {
      const raw = url.searchParams.get(param);
      if (raw === null) continue;
      const at = parseInstant(raw);
      if (!at) return jsonError(`${param} must be an ISO timestamp`, 400);
      query = query.where("started_at", op, at.toISOString());
    }

    const sessions = await query
      .orderBy("started_at", "desc")
      .limit(pageSize)
      .offset(page * pageSize)
      .execute();

    return json(sessions);
  }

  // ── GET /training-sessions/:id — full detail ──────────────────────────────────
  // training_access: whether the viewer can open the followed training — "ok"
  // or "private"; null for a free session (or once the training is deleted).
  if (req.method === "GET" && id && !action) {
    const detail = await fetchSessionDetail(id);
    if (!detail) return jsonError("Session not found", 404);
    if (!(await canReadSession(caller, detail))) return forbidden();
    const trainingAccess = detail.training_id ? await libraryAccess(caller, "training", detail.training_id) : null;
    return json({ ...detail, training_access: trainingAccess });
  }

  // ── POST /training-sessions — start a session, or log a finished one ─────────
  // Body: { training_id?, trainer_id?, notes? } starts one now. A trainer logs
  // one for someone they coach with { user_id } (trainer_id is then them):
  // an accepted client, or a member of a gym they work at. Belonging to a gym
  // isn't needed. Logging one
  // from a calendar slot adds { started_at, ended_at, sets: [{ training_set_id?,
  // exercise_id?, position?, note?, drops }] } and returns the full detail; no
  // PR detection for those. The slot may be in the future (logged ahead of
  // time; it can't be shared as a post until it has happened).
  // plan_entry_id: the planned workout this session confirms (marks it done).
  if (req.method === "POST" && !id) {
    const body = await req.json().catch(() => null);
    const { training_id, notes, started_at, ended_at, sets, plan_entry_id } = body ?? {};
    let trainer_id = body?.trainer_id;

    // Whose session it is: mine, or a client's when I'm their trainer.
    const athleteId: string = typeof body?.user_id === "string" ? body.user_id : caller.id;
    const forClient = athleteId !== caller.id;
    if (forClient) {
      if (!UUID_RE.test(athleteId)) return jsonError("User not found", 404);
      if (!caller.is_trainer || !(await coachesUser(caller, athleteId))) {
        return forbidden("You can only log sessions for people you coach");
      }
      trainer_id = caller.id;
    }

    const startedAt = started_at == null ? null : parseInstant(started_at);
    const endedAt = ended_at == null ? null : parseInstant(ended_at);
    if (started_at != null && !startedAt) return jsonError("started_at must be an ISO timestamp", 400);
    if (ended_at != null && !endedAt) return jsonError("ended_at must be an ISO timestamp", 400);
    if (endedAt && endedAt.getTime() < (startedAt ?? new Date()).getTime()) {
      return jsonError("ended_at must be after started_at", 400);
    }
    if (sets !== undefined && !Array.isArray(sets)) return jsonError("sets must be an array", 400);
    const setPayloads = (sets ?? []) as SetPayload[];
    if (setPayloads.some((s) => !s || typeof s !== "object" || (!s.training_set_id && !s.exercise_id))) {
      return jsonError("Each set needs a training_set_id or an exercise_id", 400);
    }

    if (plan_entry_id != null) {
      const entry = typeof plan_entry_id === "string"
        ? await db.selectFrom("plan_entry").select(["user_id", "kind"]).where("id", "=", plan_entry_id)
          .executeTakeFirst().catch(() => undefined)
        : undefined;
      if (!entry || entry.user_id !== athleteId) return jsonError("Planned workout not found", 404);
      if (entry.kind !== "workout") return jsonError("That plan entry isn't a workout", 400);
    }

    if (trainer_id) {
      const trainer = await db.selectFrom("users").select("id").where("id", "=", trainer_id)
        .where("is_trainer", "=", true).executeTakeFirst().catch(() => undefined);
      if (!trainer) {
        return jsonError("trainer_id must be a user who is a trainer", 400);
      }
    }

    const insert: TrainingSessionInsert = {
      user_id: athleteId,
      training_id: training_id ?? null,
      trainer_id: trainer_id ?? null,
      notes: notes ?? null,
      plan_entry_id: plan_entry_id ?? null,
      ...(startedAt && { started_at: startedAt.toISOString() }),
      ...(endedAt && { ended_at: endedAt.toISOString() }),
    };

    if (!startedAt && !endedAt && !setPayloads.length) {
      const session = await db
        .insertInto("training_session")
        .values(insert)
        .returning(SESSION_COLS)
        .executeTakeFirstOrThrow();
      if (forClient) await notifyClient(caller, athleteId, session.id);
      return json({ ...session, comment_count: 0 }, 201);
    }

    const sessionId = await db.transaction().execute(async (trx) => {
      const session = await trx
        .insertInto("training_session")
        .values(insert)
        .returning(["id"])
        .executeTakeFirstOrThrow();
      for (const [i, s] of setPayloads.entries()) {
        const setLogInsert: SessionSetLogInsert = {
          session_id: session.id,
          training_set_id: s.training_set_id ?? null,
          exercise_id: s.exercise_id ?? null,
          position: s.position ?? i,
          note: s.note ?? null,
        };
        const setLog = await trx
          .insertInto("session_set_log")
          .values(setLogInsert)
          .returning(["id"])
          .executeTakeFirstOrThrow();
        if (Array.isArray(s.drops) && s.drops.length) {
          await trx.insertInto("session_drop_log").values(toDropInserts(setLog.id, s.drops)).execute();
        }
      }
      return session.id;
    });

    if (forClient) await notifyClient(caller, athleteId, sessionId);
    const detail = await fetchSessionDetail(sessionId);
    return json(endedAt ? { ...detail, streak: await streakOrNull(athleteId) } : detail, 201);
  }

  // ── PUT /training-sessions/:id — update session (end time, notes) ─────────────
  if (req.method === "PUT" && id && !action) {
    const session = await db
      .selectFrom("training_session")
      .select(["id", "user_id", "trainer_id"])
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
      .returning([...SESSION_COLS, COMMENT_COUNT, TRAINER_NAME, TRAINING_NAME])
      .executeTakeFirst();
    if (body?.ended_at !== undefined) await streakOrNull(session.user_id);

    return json(updated);
  }

  // ── POST /training-sessions/:id/end — finish the session ──────────────────────
  if (req.method === "POST" && id && action === "end") {
    const session = await db
      .selectFrom("training_session")
      .select(["id", "user_id", "trainer_id"])
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

    return json({ ...(await fetchSessionDetail(id)), streak: await streakOrNull(session.user_id) });
  }

  // ── POST /training-sessions/:id/sets — log a set ──────────────────────────────
  if (req.method === "POST" && id && action === "sets") {
    const session = await db
      .selectFrom("training_session")
      .select(["id", "user_id", "trainer_id"])
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
      .select(["user_id", "trainer_id"])
      .where("id", "=", id)
      .executeTakeFirst();
    if (!session) return jsonError("Session not found", 404);
    if (!canWriteSession(caller, session)) return forbidden();

    await db.deleteFrom("training_session").where("id", "=", id).execute();
    await streakOrNull(session.user_id);
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
