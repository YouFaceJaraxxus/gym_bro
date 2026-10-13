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
import { notify } from "../_shared/notify.ts";
import type { RoutineAssignmentTable } from "../../types/schema/public.ts";

// Routines assigned to a user (by themself or a coach). Mirrors
// meal-plan-assignments.
//
// Row shape: { id, routine_id, user_id, assigned_by_id, start_date, end_date
//              ('YYYY-MM-DD' | null), note, created_at, routine_name,
//              routine_is_public, routine_schedule_label, user_name,
//              assigned_by_name }

const ASSIGNMENT_COLS = [
  "id",
  "routine_id",
  "user_id",
  "assigned_by_id",
  sql<string | null>`to_char(start_date, 'YYYY-MM-DD')`.as("start_date"),
  sql<string | null>`to_char(end_date, 'YYYY-MM-DD')`.as("end_date"),
  "note",
  "created_at",
] as const;

const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;

type AssignmentRow = {
  id: string;
  routine_id: string;
  user_id: string;
  assigned_by_id: string | null;
};

// ── Path parsing ──────────────────────────────────────────────────────────────

function parseId(pathname: string): string | null {
  const match = pathname.match(/^\/routine-assignments\/([^/]+)$/);
  return match ? match[1] : null;
}

// ── Response shaping ──────────────────────────────────────────────────────────

function fullName(u: { name: string | null; last_name: string | null }): string | null {
  return `${u.name ?? ""} ${u.last_name ?? ""}`.trim() || null;
}

async function withDetails<T extends AssignmentRow>(assignments: T[]) {
  const routineIds = [...new Set(assignments.map((a) => a.routine_id))];
  const routines = routineIds.length
    ? await db
      .selectFrom("routine")
      .select(["id", "name", "is_public", "schedule_type", "num_weeks"])
      .where("id", "in", routineIds)
      .execute()
    : [];
  const routineMap = Object.fromEntries(routines.map((r) => [r.id, r]));

  const userIds = [
    ...new Set(
      assignments.flatMap((a) => [a.user_id, a.assigned_by_id]).filter((x): x is string => !!x),
    ),
  ];
  const users = userIds.length
    ? await db.selectFrom("users").select(["id", "name", "last_name"]).where("id", "in", userIds).execute()
    : [];
  const nameOf = Object.fromEntries(users.map((u) => [u.id, fullName(u)]));

  return assignments.map((a) => {
    const r = routineMap[a.routine_id];
    return {
      ...a,
      routine_name: r?.name ?? null,
      routine_is_public: r?.is_public ?? null,
      routine_schedule_label: r
        ? (r.schedule_type === "fixed_weeks" && r.num_weeks ? `${r.num_weeks}-Week Program` : "Wildcard")
        : null,
      user_name: nameOf[a.user_id] ?? null,
      assigned_by_name: a.assigned_by_id ? nameOf[a.assigned_by_id] ?? null : null,
    };
  });
}

// ── Postgres error mapping ────────────────────────────────────────────────────

function pgErrorResponse(e: unknown): Response {
  const err = e as { code?: string; message?: string; detail?: string } | null;
  switch (err?.code) {
    case "23505":
      return jsonError("Already assigned", 409, { detail: err.detail });
    case "23503":
      return jsonError("Referenced routine or user does not exist", 400, { detail: err.detail });
    case "23514":
      return jsonError("end_date must be on or after start_date", 400);
    case "23502":
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
  const id = parseId(url.pathname);

  const { caller, response } = await requireCaller(req);
  if (!caller) return response;

  // ── GET /routine-assignments — ?user_id= / ?routine_id= / ?assigned_by_id= ────
  // Rows are limited to ones where the caller is the target or the assigner,
  // unless the caller is super or coaches the target user.
  if (req.method === "GET" && !id) {
    const userId = url.searchParams.get("user_id");
    const routineId = url.searchParams.get("routine_id");
    const assignedById = url.searchParams.get("assigned_by_id");

    let query = db.selectFrom("routine_assignment").select(ASSIGNMENT_COLS);
    if (userId) query = query.where("user_id", "=", userId);
    if (routineId) query = query.where("routine_id", "=", routineId);
    if (assignedById) query = query.where("assigned_by_id", "=", assignedById);

    const unrestricted = isSuperUser(caller) ||
      (assignedById !== null && assignedById === caller.id) ||
      (userId !== null && (userId === caller.id || (await coachesUser(caller, userId))));

    if (!unrestricted && !routineId) {
      query = query.where((eb) =>
        eb.or([eb("user_id", "=", caller.id), eb("assigned_by_id", "=", caller.id)])
      );
    }

    let assignments = await query.orderBy("created_at", "desc").execute();

    if (!unrestricted && routineId) {
      assignments = await filterVisible(caller, assignments);
    }

    return json(await withDetails(assignments));
  }

  // ── POST /routine-assignments ─────────────────────────────────────────────────
  // Body: { routine_id, user_id, start_date?, end_date?, note? }
  if (req.method === "POST" && !id) {
    const body = await req.json().catch(() => null);
    const { routine_id, user_id, start_date, end_date, note } = body ?? {};

    if (!routine_id || !user_id) {
      return jsonError("routine_id and user_id are required", 400);
    }
    for (const [k, v] of [["start_date", start_date], ["end_date", end_date]] as const) {
      if (v != null && (typeof v !== "string" || !DATE_RE.test(v))) {
        return jsonError(`${k} must be YYYY-MM-DD`, 400);
      }
    }

    const routine = await db
      .selectFrom("routine")
      .select(["id", "name", "is_public", "author_id"])
      .where("id", "=", routine_id)
      .executeTakeFirst();
    if (!routine) return jsonError("Routine not found", 404);
    if (!routine.is_public && routine.author_id !== caller.id && !isSuperUser(caller)) {
      return forbidden("You can only assign public routines or your own");
    }

    if (user_id !== caller.id) {
      const target = await db.selectFrom("users").select("id").where("id", "=", user_id).executeTakeFirst();
      if (!target) return jsonError("User not found", 404);
      if (!(await coachesUser(caller, user_id))) {
        return forbidden("You can only assign routines to yourself or members you coach");
      }
    }

    const insert: Insertable<RoutineAssignmentTable> = {
      routine_id,
      user_id,
      assigned_by_id: caller.id,
      start_date: start_date ?? null,
      end_date: end_date ?? null,
      note: typeof note === "string" && note.trim() ? note.trim() : null,
    };

    const assignment = await db
      .insertInto("routine_assignment")
      .values(insert)
      .returning(ASSIGNMENT_COLS)
      .executeTakeFirstOrThrow();

    if (user_id !== caller.id) {
      const assigner = `${caller.name ?? ""} ${caller.last_name ?? ""}`.trim() || "Your coach";
      await notify([user_id], {
        type: "training",
        title: "New routine assigned",
        body: `${assigner} assigned you "${routine.name}"`,
        metadata: { routine_id, routine_assignment_id: assignment.id },
      });
    }

    const [row] = await withDetails([assignment]);
    return json(row, 201);
  }

  // ── DELETE /routine-assignments/:id — assigner, target or super ──────────────
  if (req.method === "DELETE" && id) {
    const existing = await db
      .selectFrom("routine_assignment")
      .select(["assigned_by_id", "user_id"])
      .where("id", "=", id)
      .executeTakeFirst();
    if (!existing) return jsonError("Routine assignment not found", 404);

    const isAssigner = existing.assigned_by_id !== null && existing.assigned_by_id === caller.id;
    const isTargetUser = existing.user_id === caller.id;
    if (!isAssigner && !isTargetUser && !isSuperUser(caller)) return forbidden();

    await db.deleteFrom("routine_assignment").where("id", "=", id).execute();
    return new Response(null, { status: 204 });
  }

  return jsonError("Not found", 404);
}

/** Keeps rows where the caller is target/assigner or coaches the target. */
async function filterVisible<T extends AssignmentRow>(caller: Caller, rows: T[]): Promise<T[]> {
  const coached = new Map<string, boolean>();
  const out: T[] = [];
  for (const row of rows) {
    if (row.user_id === caller.id || row.assigned_by_id === caller.id) {
      out.push(row);
      continue;
    }
    if (!coached.has(row.user_id)) coached.set(row.user_id, await coachesUser(caller, row.user_id));
    if (coached.get(row.user_id)) out.push(row);
  }
  return out;
}

Deno.serve(async (req: Request) => {
  try {
    return await handler(req);
  } catch (e) {
    return pgErrorResponse(e);
  }
});
