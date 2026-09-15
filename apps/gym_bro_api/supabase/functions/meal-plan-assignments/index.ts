import { db, supabaseAdmin } from "../_shared/config.ts";
import type { MealPlanAssignmentInsert } from "../../types/schema/public.ts";

const ASSIGNMENT_COLS = [
  "id",
  "meal_plan_id",
  "user_id",
  "assigned_by_id",
  "start_date",
  "end_date",
  "note",
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

// ── Auth ──────────────────────────────────────────────────────────────────────

async function requireAuth(req: Request) {
  const token = req.headers.get("Authorization")?.replace(/^Bearer\s+/i, "");
  if (!token) return { user: null, error: "Missing Authorization header" };
  const { data: { user }, error } = await supabaseAdmin.auth.getUser(token);
  return { user: error ? null : user, error: error?.message ?? null };
}

// ── Path parsing ──────────────────────────────────────────────────────────────

function parseId(pathname: string): string | null {
  const match = pathname.match(/^\/meal-plan-assignments\/([^/]+)$/);
  return match ? match[1] : null;
}

// ── Handler ───────────────────────────────────────────────────────────────────

Deno.serve(async (req: Request) => {
  const url = new URL(req.url);
  const id = parseId(url.pathname);

  // ── GET /meal-plan-assignments — public, filtered by user_id/meal_plan_id ────
  if (req.method === "GET" && !id) {
    const userId = url.searchParams.get("user_id");
    const mealPlanId = url.searchParams.get("meal_plan_id");

    let query = db.selectFrom("meal_plan_assignment").select(ASSIGNMENT_COLS);
    if (userId) query = query.where("user_id", "=", userId);
    if (mealPlanId) query = query.where("meal_plan_id", "=", mealPlanId);

    const assignments = await query.orderBy("created_at", "desc").execute();

    const planIds = [...new Set(assignments.map((a) => a.meal_plan_id))];
    const plans = planIds.length
      ? await db.selectFrom("meal_plan").select(MEAL_PLAN_COLS).where("id", "in", planIds).execute()
      : [];
    const planMap = Object.fromEntries(plans.map((p) => [p.id, p]));

    return json(assignments.map((a) => ({ ...a, meal_plan: planMap[a.meal_plan_id] ?? null })));
  }

  // ── Auth wall ─────────────────────────────────────────────────────────────────

  const { user, error: authError } = await requireAuth(req);
  if (!user) return jsonError(authError ?? "Unauthorized", 401);

  const dbUser = await db
    .selectFrom("users")
    .select(["id", "role"])
    .where("auth_id", "=", user.id)
    .executeTakeFirst();

  // ── POST /meal-plan-assignments ───────────────────────────────────────────────
  if (req.method === "POST" && !id) {
    const body = await req.json().catch(() => null);
    const { meal_plan_id, user_id, start_date, end_date, note } = body ?? {};

    if (!meal_plan_id || !user_id) {
      return jsonError("meal_plan_id and user_id are required", 400);
    }

    try {
      const insert: MealPlanAssignmentInsert = {
        meal_plan_id,
        user_id,
        assigned_by_id: dbUser?.id ?? null,
        start_date: start_date ?? null,
        end_date: end_date ?? null,
        note: note ?? null,
      };

      const assignment = await db
        .insertInto("meal_plan_assignment")
        .values(insert)
        .returning(ASSIGNMENT_COLS)
        .executeTakeFirstOrThrow();

      const plan = await db
        .selectFrom("meal_plan")
        .select(MEAL_PLAN_COLS)
        .where("id", "=", meal_plan_id)
        .executeTakeFirst();

      return json({ ...assignment, meal_plan: plan ?? null }, 201);
    } catch (e) {
      return dbErrorResponse(e);
    }
  }

  // ── DELETE /meal-plan-assignments/:id ─────────────────────────────────────────
  if (req.method === "DELETE" && id) {
    const existing = await db
      .selectFrom("meal_plan_assignment")
      .select(["assigned_by_id", "user_id"])
      .where("id", "=", id)
      .executeTakeFirst();
    if (!existing) return jsonError("Meal plan assignment not found", 404);

    const isAssigner = existing.assigned_by_id && existing.assigned_by_id === dbUser?.id;
    const isTargetUser = existing.user_id === dbUser?.id;
    if (!isAssigner && !isTargetUser && dbUser?.role !== "super_user") {
      return jsonError("Forbidden", 403);
    }

    await db.deleteFrom("meal_plan_assignment").where("id", "=", id).execute();
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

function dbErrorResponse(e: unknown): Response {
  const code = (e as { code?: string } | null)?.code;
  if (code === "23503" || code === "23505" || code === "23514" || code === "23502") {
    const message = (e as { message?: string } | null)?.message ?? "Constraint violation";
    return jsonError(message, 400);
  }
  throw e;
}
