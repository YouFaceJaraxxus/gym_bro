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
import { forgetUntouchedEntries, readTimezone } from "../_shared/plans.ts";
import type { MealPlanAssignmentInsert } from "../../types/schema/public.ts";

const ASSIGNMENT_COLS = [
  "id",
  "meal_plan_id",
  "user_id",
  "assigned_by_id",
  "start_date",
  "end_date",
  "note",
  "timezone",
  "created_at",
] as const;

// Flat meal_plan row embedded under `meal_plan` — MealPlan.fromJson defaults
// days/images to [] when absent, so a flat row is safe to embed here.
const MEAL_PLAN_COLS = [
  "id",
  "name",
  "description",
  "author_id",
  "is_public",
  "is_system",
  "num_weeks",
  "created_at",
  "updated_at",
] as const;

type AssignmentRow = {
  id: string;
  meal_plan_id: string;
  user_id: string;
  assigned_by_id: string | null;
};

// ── Path parsing ──────────────────────────────────────────────────────────────

function parseId(pathname: string): string | null {
  const match = pathname.match(/^\/meal-plan-assignments\/([^/]+)$/);
  return match ? match[1] : null;
}

// ── Response shaping ──────────────────────────────────────────────────────────
// Each row: assignment columns + `meal_plan` (flat row or null) +
// `meal_plan_name` + `assigned_by_name` / `user_name` ("Name Last" or null).

async function withDetails<T extends AssignmentRow>(assignments: T[]) {
  const planIds = [...new Set(assignments.map((a) => a.meal_plan_id))];
  const plans = planIds.length
    ? await db.selectFrom("meal_plan").select(MEAL_PLAN_COLS).where("id", "in", planIds).execute()
    : [];
  const planMap = Object.fromEntries(plans.map((p) => [p.id, p]));

  // Assigners and assignees in one lookup.
  const userIds = [
    ...new Set(assignments.flatMap((a) => [a.assigned_by_id, a.user_id]).filter((x): x is string => !!x)),
  ];
  const users = userIds.length
    ? await db.selectFrom("users").select(["id", "name", "last_name"]).where("id", "in", userIds).execute()
    : [];
  const userName = Object.fromEntries(
    users.map((u) => [u.id, `${u.name ?? ""} ${u.last_name ?? ""}`.trim() || null]),
  );

  return assignments.map((a) => ({
    ...a,
    meal_plan: planMap[a.meal_plan_id] ?? null,
    meal_plan_name: planMap[a.meal_plan_id]?.name ?? null,
    assigned_by_name: a.assigned_by_id ? userName[a.assigned_by_id] ?? null : null,
    user_name: userName[a.user_id] ?? null,
  }));
}

// ── Postgres error mapping ────────────────────────────────────────────────────

function pgErrorResponse(e: unknown): Response {
  const err = e as { code?: string; message?: string; detail?: string } | null;
  switch (err?.code) {
    case "23505":
      return jsonError("Already assigned", 409, { detail: err.detail });
    case "23503":
      return jsonError("Referenced meal plan or user does not exist", 400, { detail: err.detail });
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
  const id = parseId(url.pathname);

  const { caller, response } = await requireCaller(req);
  if (!caller) return response;

  // ── GET /meal-plan-assignments — ?user_id= / ?meal_plan_id= ──────────────────
  // Rows are limited to ones where the caller is the target or the assigner,
  // unless the caller is super or coaches the target user.
  if (req.method === "GET" && !id) {
    const userId = url.searchParams.get("user_id");
    const mealPlanId = url.searchParams.get("meal_plan_id");

    let query = db.selectFrom("meal_plan_assignment").select(ASSIGNMENT_COLS);
    if (userId) query = query.where("user_id", "=", userId);
    if (mealPlanId) query = query.where("meal_plan_id", "=", mealPlanId);

    const unrestricted = isSuperUser(caller) ||
      (userId !== null && (userId === caller.id || (await coachesUser(caller, userId))));

    if (!unrestricted && !mealPlanId) {
      // No plan filter: restrict in SQL so we never scan everyone's assignments.
      query = query.where((eb) =>
        eb.or([eb("user_id", "=", caller.id), eb("assigned_by_id", "=", caller.id)])
      );
    }

    let assignments = await query.orderBy("created_at", "desc").execute();

    if (!unrestricted && mealPlanId) {
      assignments = await filterVisible(caller, assignments);
    }

    return json(await withDetails(assignments));
  }

  // ── POST /meal-plan-assignments ───────────────────────────────────────────────
  if (req.method === "POST" && !id) {
    const body = await req.json().catch(() => null);
    const { meal_plan_id, user_id, start_date, end_date, note } = body ?? {};
    // The zone planned meals are put on the calendar in.
    const timezone = readTimezone(body?.timezone);
    if (timezone instanceof Response) return timezone;

    if (!meal_plan_id || !user_id) {
      return jsonError("meal_plan_id and user_id are required", 400);
    }

    const plan = await db
      .selectFrom("meal_plan")
      .select(MEAL_PLAN_COLS)
      .where("id", "=", meal_plan_id)
      .executeTakeFirst();
    if (!plan) return jsonError("Meal plan not found", 404);
    if (!plan.is_public && plan.author_id !== caller.id && !isSuperUser(caller)) {
      return forbidden("You can only assign public meal plans or your own");
    }

    if (user_id !== caller.id) {
      const target = await db.selectFrom("users").select("id").where("id", "=", user_id).executeTakeFirst();
      if (!target) return jsonError("User not found", 404);
      if (!(await coachesUser(caller, user_id))) {
        return forbidden("You can only assign meal plans to yourself or members you coach");
      }
    }

    const insert: MealPlanAssignmentInsert = {
      meal_plan_id,
      user_id,
      assigned_by_id: caller.id,
      start_date: start_date ?? null,
      end_date: end_date ?? null,
      note: note ?? null,
      timezone: timezone ?? null,
    };

    const assignment = await db
      .insertInto("meal_plan_assignment")
      .values(insert)
      .returning(ASSIGNMENT_COLS)
      .executeTakeFirstOrThrow();

    if (user_id !== caller.id) {
      const assigner = `${caller.name ?? ""} ${caller.last_name ?? ""}`.trim() || "Your coach";
      await notify([user_id], {
        type: "training",
        title: "New meal plan assigned",
        body: `${assigner} assigned you "${plan.name}"`,
        metadata: { meal_plan_id, assignment_id: assignment.id },
      });
    }

    const [row] = await withDetails([assignment]);
    return json(row, 201);
  }

  // ── PUT /meal-plan-assignments/:id {start_date?, end_date?, note?, timezone?} ──
  // Assigner, target or super. Planned meals still to come that weren't edited
  // or logged are regenerated.
  if (req.method === "PUT" && id) {
    const existing = await db
      .selectFrom("meal_plan_assignment")
      .select(["assigned_by_id", "user_id"])
      .where("id", "=", id)
      .executeTakeFirst();
    if (!existing) return jsonError("Meal plan assignment not found", 404);
    const allowed = existing.user_id === caller.id || existing.assigned_by_id === caller.id || isSuperUser(caller);
    if (!allowed) return forbidden();

    const body = await req.json().catch(() => null);
    if (!body || typeof body !== "object") return jsonError("Body must be an object", 400);
    for (const k of ["start_date", "end_date"] as const) {
      const v = body[k];
      if (v !== undefined && v !== null && (typeof v !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(v))) {
        return jsonError(`${k} must be YYYY-MM-DD`, 400);
      }
    }
    const timezone = readTimezone(body.timezone);
    if (timezone instanceof Response) return timezone;
    const update = {
      ...(body.start_date !== undefined && { start_date: body.start_date }),
      ...(body.end_date !== undefined && { end_date: body.end_date }),
      ...(body.note !== undefined && { note: body.note || null }),
      ...(timezone !== undefined && { timezone }),
    };
    if (!Object.keys(update).length) return jsonError("Nothing to update", 400);

    const assignment = await db.transaction().execute(async (trx) => {
      const row = await trx.updateTable("meal_plan_assignment").set(update).where("id", "=", id)
        .returning(ASSIGNMENT_COLS).executeTakeFirstOrThrow();
      await forgetUntouchedEntries(trx, { mealPlanAssignmentId: id });
      return row;
    });
    const [row] = await withDetails([assignment]);
    return json(row);
  }

  // ── DELETE /meal-plan-assignments/:id ─────────────────────────────────────────
  if (req.method === "DELETE" && id) {
    const existing = await db
      .selectFrom("meal_plan_assignment")
      .select(["assigned_by_id", "user_id"])
      .where("id", "=", id)
      .executeTakeFirst();
    if (!existing) return jsonError("Meal plan assignment not found", 404);

    const isAssigner = existing.assigned_by_id !== null && existing.assigned_by_id === caller.id;
    const isTargetUser = existing.user_id === caller.id;
    if (!isAssigner && !isTargetUser && !isSuperUser(caller)) return forbidden();

    await db.deleteFrom("meal_plan_assignment").where("id", "=", id).execute();
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
