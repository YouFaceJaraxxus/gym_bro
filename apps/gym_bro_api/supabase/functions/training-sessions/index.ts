import { db, supabaseAdmin } from "../_shared/config.ts";
import type {
  TrainingSessionInsert,
  TrainingSessionUpdate,
  SessionSetLogInsert,
  SessionDropLogInsert,
  RepType,
  BodySide,
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

// ── Auth ──────────────────────────────────────────────────────────────────────

async function requireAuth(req: Request) {
  const token = req.headers.get("Authorization")?.replace(/^Bearer\s+/i, "");
  if (!token) return { user: null, error: "Missing Authorization header" };
  const { data: { user }, error } = await supabaseAdmin.auth.getUser(token);
  return { user: error ? null : user, error: error?.message ?? null };
}

// ── Path helpers ──────────────────────────────────────────────────────────────

// /training-sessions                        → { id: null, action: null }
// /training-sessions/:id                    → { id, action: null }
// /training-sessions/:id/sets               → { id, action: 'sets' }
// /training-sessions/sets/:setLogId/drops   → { id: setLogId, action: 'drops' }

function parsePath(pathname: string) {
  const setsDrops = pathname.match(/^\/training-sessions\/sets\/([^/]+)\/drops$/);
  if (setsDrops) return { id: setsDrops[1], action: "drops" as const };

  const withAction = pathname.match(/^\/training-sessions\/([^/]+)\/(sets|end)$/);
  if (withAction) return { id: withAction[1], action: withAction[2] as "sets" | "end" };

  const withId = pathname.match(/^\/training-sessions\/([^/]+)$/);
  if (withId) return { id: withId[1], action: null };

  return { id: null, action: null };
}

// ── Nested fetch ──────────────────────────────────────────────────────────────

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

// ── Handler ───────────────────────────────────────────────────────────────────

Deno.serve(async (req: Request) => {
  const url = new URL(req.url);
  const { id, action } = parsePath(url.pathname);

  const { user, error: authError } = await requireAuth(req);
  if (!user) return jsonError(authError ?? "Unauthorized", 401);

  const dbUser = await db
    .selectFrom("users")
    .select(["id", "role"])
    .where("auth_id", "=", user.id)
    .executeTakeFirst();

  if (!dbUser) return jsonError("User not found", 404);

  // ── GET /training-sessions — list user's sessions ─────────────────────────────
  if (req.method === "GET" && !id) {
    const targetUserId = url.searchParams.get("user_id") ?? dbUser.id;
    const trainingId = url.searchParams.get("training_id");
    const page = parseInt(url.searchParams.get("page") ?? "0");
    const pageSize = Math.min(parseInt(url.searchParams.get("page_size") ?? "20"), 100);

    // Only super_user can read other users' sessions
    if (targetUserId !== dbUser.id && dbUser.role !== "super_user") {
      return jsonError("Forbidden", 403);
    }

    let query = db.selectFrom("training_session").select(SESSION_COLS)
      .where("user_id", "=", targetUserId);

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

    if (detail.user_id !== dbUser.id && dbUser.role !== "super_user") {
      return jsonError("Forbidden", 403);
    }

    return json(detail);
  }

  // ── POST /training-sessions — start a new session ─────────────────────────────
  if (req.method === "POST" && !id) {
    const body = await req.json().catch(() => null);
    const { training_id, trainer_id, notes } = body ?? {};

    const insert: TrainingSessionInsert = {
      user_id: dbUser.id,
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
    if (session.user_id !== dbUser.id && dbUser.role !== "super_user") {
      return jsonError("Forbidden", 403);
    }

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

  // ── POST /training-sessions/:id/sets — log a set ──────────────────────────────
  if (req.method === "POST" && id && action === "sets") {
    const session = await db
      .selectFrom("training_session")
      .select(["id", "user_id"])
      .where("id", "=", id)
      .executeTakeFirst();
    if (!session) return jsonError("Session not found", 404);
    if (session.user_id !== dbUser.id) return jsonError("Forbidden", 403);

    const body = await req.json().catch(() => null);
    const { training_set_id, exercise_id, position, note, drops } = body ?? {};

    const setLogInsert: SessionSetLogInsert = {
      session_id: id,
      training_set_id: training_set_id ?? null,
      exercise_id: exercise_id ?? null,
      position: position ?? 0,
      note: note ?? null,
    };

    const setLog = await db
      .insertInto("session_set_log")
      .values(setLogInsert)
      .returning(SET_LOG_COLS)
      .executeTakeFirstOrThrow();

    if (Array.isArray(drops) && drops.length) {
      const dropInserts: SessionDropLogInsert[] = drops.map(
        (d: {
          training_set_drop_id?: string;
          drop_number?: number;
          rep_type_actual?: RepType;
          rep_count_actual?: number;
          weight_kg_actual?: number;
          side?: BodySide;
          note?: string;
        }, i: number) => ({
          session_set_log_id: setLog.id,
          training_set_drop_id: d.training_set_drop_id ?? null,
          drop_number: d.drop_number ?? i,
          rep_type_actual: VALID_REP_TYPES.includes(d.rep_type_actual!)
            ? d.rep_type_actual!
            : "count",
          rep_count_actual: d.rep_count_actual ?? null,
          weight_kg_actual: d.weight_kg_actual ?? null,
          side: VALID_SIDES.includes(d.side!) ? d.side! : "both",
          note: d.note ?? null,
        }),
      );
      await db.insertInto("session_drop_log").values(dropInserts).execute();
    }

    // Return the set log with drops
    const dropLogs = await db
      .selectFrom("session_drop_log")
      .select(DROP_LOG_COLS)
      .where("session_set_log_id", "=", setLog.id)
      .orderBy("drop_number", "asc")
      .execute();

    return json({ ...setLog, drop_logs: dropLogs }, 201);
  }

  // ── POST /training-sessions/sets/:setLogId/drops — add drops to a set log ─────
  if (req.method === "POST" && id && action === "drops") {
    const setLog = await db
      .selectFrom("session_set_log")
      .select(["id", "session_id"])
      .where("id", "=", id)
      .executeTakeFirst();
    if (!setLog) return jsonError("Set log not found", 404);

    // Verify the session belongs to this user
    const session = await db
      .selectFrom("training_session")
      .select(["user_id"])
      .where("id", "=", setLog.session_id)
      .executeTakeFirst();
    if (!session || session.user_id !== dbUser.id) return jsonError("Forbidden", 403);

    const body = await req.json().catch(() => null);
    const drops: {
      training_set_drop_id?: string;
      drop_number?: number;
      rep_type_actual?: RepType;
      rep_count_actual?: number;
      weight_kg_actual?: number;
      side?: BodySide;
      note?: string;
    }[] = Array.isArray(body) ? body : [body];

    const dropInserts: SessionDropLogInsert[] = drops.map((d, i) => ({
      session_set_log_id: id,
      training_set_drop_id: d.training_set_drop_id ?? null,
      drop_number: d.drop_number ?? i,
      rep_type_actual: VALID_REP_TYPES.includes(d.rep_type_actual!) ? d.rep_type_actual! : "count",
      rep_count_actual: d.rep_count_actual ?? null,
      weight_kg_actual: d.weight_kg_actual ?? null,
      side: VALID_SIDES.includes(d.side!) ? d.side! : "both",
      note: d.note ?? null,
    }));

    const inserted = await db
      .insertInto("session_drop_log")
      .values(dropInserts)
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
    if (session.user_id !== dbUser.id && dbUser.role !== "super_user") {
      return jsonError("Forbidden", 403);
    }

    await db.deleteFrom("training_session").where("id", "=", id).execute();
    return new Response(null, { status: 204 });
  }

  return jsonError("Not found", 404);
});

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function jsonError(message: string, status: number): Response {
  return json({ error: message }, status);
}
