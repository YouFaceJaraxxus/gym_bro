import { db, supabaseAdmin } from "../_shared/config.ts";
import type {
  MealPlanInsert,
  MealPlanUpdate,
  MealPlanImageInsert,
  MealPlanDayInsert,
} from "../../types/schema/public.ts";

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

const IMAGE_COLS = ["id", "meal_plan_id", "url", "is_thumbnail", "position"] as const;
const DAY_COLS = ["id", "meal_plan_id", "daily_meal_plan_id", "week_number", "day_of_week", "note"] as const;

const DAILY_PLAN_COLS = [
  "id",
  "name",
  "description",
  "author_id",
  "is_public",
  "is_system",
  "kcal_total",
  "protein_total",
  "carb_total",
  "fat_total",
  "fiber_total",
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
  const match = pathname.match(/^\/meal-plans\/([^/]+)$/);
  return match ? match[1] : null;
}

// ── Nested fetch ──────────────────────────────────────────────────────────────

async function fetchMealPlanDetail(planId: string) {
  const plan = await db
    .selectFrom("meal_plan")
    .select(MEAL_PLAN_COLS)
    .where("id", "=", planId)
    .executeTakeFirst();

  if (!plan) return null;

  const images = await db
    .selectFrom("meal_plan_image")
    .select(IMAGE_COLS)
    .where("meal_plan_id", "=", planId)
    .orderBy("position", "asc")
    .execute();

  const days = await db
    .selectFrom("meal_plan_day")
    .select(DAY_COLS)
    .where("meal_plan_id", "=", planId)
    .orderBy("week_number", "asc")
    .orderBy("day_of_week", "asc")
    .execute();

  const dailyPlanIds = [...new Set(days.map((d) => d.daily_meal_plan_id))];
  const dailyPlans = dailyPlanIds.length
    ? await db.selectFrom("daily_meal_plan").select(DAILY_PLAN_COLS).where("id", "in", dailyPlanIds).execute()
    : [];
  const dailyPlanMap = Object.fromEntries(dailyPlans.map((d) => [d.id, d]));

  return {
    ...plan,
    days: days.map((d) => ({ ...d, daily_meal_plan: dailyPlanMap[d.daily_meal_plan_id] ?? null })),
    images,
  };
}

// ── Replace nested children ──────────────────────────────────────────────────

// deno-lint-ignore no-explicit-any
async function replaceMealPlanDays(planId: string, days: any[]) {
  await db.deleteFrom("meal_plan_day").where("meal_plan_id", "=", planId).execute();
  const rows: MealPlanDayInsert[] = days
    .filter((d) => d?.daily_meal_plan_id)
    .map((d) => ({
      meal_plan_id: planId,
      daily_meal_plan_id: d.daily_meal_plan_id,
      week_number: d.week_number,
      day_of_week: d.day_of_week,
      note: d.note ?? null,
    }));
  if (rows.length) await db.insertInto("meal_plan_day").values(rows).execute();
}

// deno-lint-ignore no-explicit-any
async function replaceMealPlanImages(planId: string, images: any[]) {
  await db.deleteFrom("meal_plan_image").where("meal_plan_id", "=", planId).execute();
  const rows: MealPlanImageInsert[] = images.map((img, idx) => ({
    meal_plan_id: planId,
    url: img.url,
    is_thumbnail: img.is_thumbnail ?? idx === 0,
    position: img.position ?? idx,
  }));
  if (rows.length) await db.insertInto("meal_plan_image").values(rows).execute();
}

// ── Handler ───────────────────────────────────────────────────────────────────

Deno.serve(async (req: Request) => {
  const url = new URL(req.url);
  const id = parseId(url.pathname);

  // ── GET /meal-plans — public + owned ──────────────────────────────────────────
  if (req.method === "GET" && !id) {
    const name = url.searchParams.get("name");
    const mine = url.searchParams.get("mine") === "true";
    const page = parseInt(url.searchParams.get("page") ?? "0");
    const pageSize = Math.min(parseInt(url.searchParams.get("page_size") ?? "20"), 100);

    let query = db.selectFrom("meal_plan").select(MEAL_PLAN_COLS);

    if (mine) {
      const { user } = await requireAuth(req);
      if (!user) return jsonError("Unauthorized", 401);
      const dbUser = await db
        .selectFrom("users")
        .select(["id"])
        .where("auth_id", "=", user.id)
        .executeTakeFirst();
      if (dbUser) query = query.where("author_id", "=", dbUser.id);
    } else {
      query = query.where("is_public", "=", true);
    }

    if (name) query = query.where("name", "ilike", `%${name}%`);

    query = query.orderBy("updated_at", "desc").limit(pageSize).offset(page * pageSize);
    const plans = await query.execute();

    // Attach thumbnail images to list items
    const ids = plans.map((p) => p.id);
    const thumbnails = ids.length
      ? await db
          .selectFrom("meal_plan_image")
          .select(IMAGE_COLS)
          .where("meal_plan_id", "in", ids)
          .where("is_thumbnail", "=", true)
          .execute()
      : [];
    const thumbMap = Object.fromEntries(thumbnails.map((t) => [t.meal_plan_id, t]));

    return json(plans.map((p) => ({ ...p, images: thumbMap[p.id] ? [thumbMap[p.id]] : [] })));
  }

  // ── GET /meal-plans/:id — public, returns full nested detail ─────────────────
  if (req.method === "GET" && id) {
    const detail = await fetchMealPlanDetail(id);
    if (!detail) return jsonError("Meal plan not found", 404);
    if (!detail.is_public) {
      const { user } = await requireAuth(req);
      if (!user) return jsonError("Not found", 404);
      const dbUser = await db
        .selectFrom("users")
        .select(["id", "role"])
        .where("auth_id", "=", user.id)
        .executeTakeFirst();
      if (detail.author_id !== dbUser?.id && dbUser?.role !== "super_user") {
        return jsonError("Not found", 404);
      }
    }
    return json(detail);
  }

  // ── Auth wall ─────────────────────────────────────────────────────────────────

  const { user, error: authError } = await requireAuth(req);
  if (!user) return jsonError(authError ?? "Unauthorized", 401);

  const dbUser = await db
    .selectFrom("users")
    .select(["id", "role"])
    .where("auth_id", "=", user.id)
    .executeTakeFirst();

  // ── POST /meal-plans ────────────────────────────────────────────────────────────
  if (req.method === "POST" && !id) {
    const body = await req.json().catch(() => null);
    const { name, description, is_public, num_weeks, days, images } = body ?? {};

    if (!name) return jsonError("Missing required field: name", 400);

    const finalNumWeeks = num_weeks ?? 1;
    if (typeof finalNumWeeks !== "number" || finalNumWeeks < 1 || finalNumWeeks > 4) {
      return jsonError("num_weeks must be between 1 and 4", 400);
    }

    try {
      const insert: MealPlanInsert = {
        name,
        description: description ?? null,
        author_id: dbUser?.id ?? null,
        is_public: is_public ?? false,
        num_weeks: finalNumWeeks,
      };

      const plan = await db
        .insertInto("meal_plan")
        .values(insert)
        .returning(["id"])
        .executeTakeFirstOrThrow();

      if (Array.isArray(days) && days.length) {
        await replaceMealPlanDays(plan.id, days);
      }
      if (Array.isArray(images) && images.length) {
        await replaceMealPlanImages(plan.id, images);
      }

      const detail = await fetchMealPlanDetail(plan.id);
      return json(detail, 201);
    } catch (e) {
      return dbErrorResponse(e);
    }
  }

  // ── PUT /meal-plans/:id ──────────────────────────────────────────────────────────
  if (req.method === "PUT" && id) {
    const existing = await db
      .selectFrom("meal_plan")
      .select(["id", "author_id", "is_system"])
      .where("id", "=", id)
      .executeTakeFirst();
    if (!existing) return jsonError("Meal plan not found", 404);

    if (existing.is_system && dbUser?.role !== "super_user") {
      return jsonError("Forbidden", 403);
    }
    if (existing.author_id && existing.author_id !== dbUser?.id && dbUser?.role !== "super_user") {
      return jsonError("Forbidden", 403);
    }

    const body = await req.json().catch(() => null);
    if (!body || Object.keys(body).length === 0) {
      return jsonError("Body must not be empty", 400);
    }

    const { name, description, is_public, num_weeks, days, images } = body;

    if (num_weeks !== undefined && (typeof num_weeks !== "number" || num_weeks < 1 || num_weeks > 4)) {
      return jsonError("num_weeks must be between 1 and 4", 400);
    }

    try {
      const update: MealPlanUpdate = {
        ...(name !== undefined && { name }),
        ...(description !== undefined && { description }),
        ...(is_public !== undefined && { is_public }),
        ...(num_weeks !== undefined && { num_weeks }),
        updated_at: new Date().toISOString(),
      };
      await db.updateTable("meal_plan").set(update).where("id", "=", id).execute();

      if (Array.isArray(days)) await replaceMealPlanDays(id, days);
      if (Array.isArray(images)) await replaceMealPlanImages(id, images);

      const detail = await fetchMealPlanDetail(id);
      return json(detail);
    } catch (e) {
      return dbErrorResponse(e);
    }
  }

  // ── DELETE /meal-plans/:id ─────────────────────────────────────────────────────
  if (req.method === "DELETE" && id) {
    const existing = await db
      .selectFrom("meal_plan")
      .select(["author_id", "is_system"])
      .where("id", "=", id)
      .executeTakeFirst();
    if (!existing) return jsonError("Meal plan not found", 404);

    if (existing.is_system && dbUser?.role !== "super_user") {
      return jsonError("Forbidden", 403);
    }
    if (existing.author_id && existing.author_id !== dbUser?.id && dbUser?.role !== "super_user") {
      return jsonError("Forbidden", 403);
    }

    try {
      await db.deleteFrom("meal_plan").where("id", "=", id).execute();
    } catch (e) {
      return dbErrorResponse(e);
    }
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
