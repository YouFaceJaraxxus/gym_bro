import type { Kysely } from "npm:kysely@^0.27";
import { db } from "../_shared/config.ts";
import {
  type Caller,
  canEditAuthored,
  forbidden,
  isSuperUser,
  json,
  jsonError,
  requireCaller,
} from "../_shared/auth.ts";
import type {
  Database,
  MealPlanInsert,
  MealPlanUpdate,
  MealPlanImageInsert,
  MealPlanDayInsert,
} from "../../types/schema/public.ts";
import { callerHasAssignedAccessToMealPlan } from "../_shared/nutrition.ts";

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

/** Reads are public; resolve the caller only when a token was sent. */
async function optionalCaller(req: Request): Promise<Caller | null> {
  if (!req.headers.get("Authorization")) return null;
  const { caller } = await requireCaller(req);
  return caller ?? null;
}

/** System rows are super-user only; everything else follows canEditAuthored. */
function canEdit(caller: Caller, row: { author_id: string | null; is_system: boolean }): boolean {
  if (row.is_system && !isSuperUser(caller)) return false;
  return canEditAuthored(caller, row.author_id);
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

// ── Replace nested children (always inside a transaction) ────────────────────

// deno-lint-ignore no-explicit-any
async function replaceMealPlanDays(trx: Kysely<Database>, planId: string, days: any[]) {
  await trx.deleteFrom("meal_plan_day").where("meal_plan_id", "=", planId).execute();
  const rows: MealPlanDayInsert[] = days
    .filter((d) => d?.daily_meal_plan_id)
    .map((d) => ({
      meal_plan_id: planId,
      daily_meal_plan_id: d.daily_meal_plan_id,
      week_number: d.week_number,
      day_of_week: d.day_of_week,
      note: d.note ?? null,
    }));
  if (rows.length) await trx.insertInto("meal_plan_day").values(rows).execute();
}

// deno-lint-ignore no-explicit-any
async function replaceMealPlanImages(trx: Kysely<Database>, planId: string, images: any[]) {
  await trx.deleteFrom("meal_plan_image").where("meal_plan_id", "=", planId).execute();
  const rows: MealPlanImageInsert[] = images.map((img, idx) => ({
    meal_plan_id: planId,
    url: img.url,
    is_thumbnail: img.is_thumbnail ?? idx === 0,
    position: img.position ?? idx,
  }));
  if (rows.length) await trx.insertInto("meal_plan_image").values(rows).execute();
}

// ── Postgres error mapping ────────────────────────────────────────────────────

function pgErrorResponse(e: unknown, method: string): Response {
  const err = e as { code?: string; message?: string; detail?: string } | null;
  switch (err?.code) {
    case "23505":
      return jsonError("Already exists", 409, { detail: err.detail });
    case "23503":
      return method === "DELETE"
        ? jsonError("Meal plan is still referenced and can't be deleted", 409)
        : jsonError("Referenced daily meal plan does not exist", 400, { detail: err.detail });
    case "23502":
    case "23514":
    case "22P02":
      return jsonError(err.message ?? "Invalid value", 400);
  }
  throw e;
}

// ── Handler ───────────────────────────────────────────────────────────────────

async function handler(req: Request): Promise<Response> {
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
      // Never fall through to an unfiltered query when the profile is missing.
      const { caller } = await requireCaller(req);
      if (!caller) return jsonError("Unauthorized", 401);
      query = query.where("author_id", "=", caller.id);
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
      // Private plans: author, super, assigned user, or their coach.
      const caller = await optionalCaller(req);
      const allowed = caller !== null && (
        isSuperUser(caller) || detail.author_id === caller.id ||
        (await callerHasAssignedAccessToMealPlan(caller, id))
      );
      if (!allowed) return jsonError("Meal plan not found", 404);
    }
    return json(detail);
  }

  // ── Auth wall ─────────────────────────────────────────────────────────────────

  const { caller, response } = await requireCaller(req);
  if (!caller) return response;

  // ── POST /meal-plans ────────────────────────────────────────────────────────────
  if (req.method === "POST" && !id) {
    const body = await req.json().catch(() => null);
    const { name, description, is_public, num_weeks, days, images } = body ?? {};

    if (!name) return jsonError("Missing required field: name", 400);

    const finalNumWeeks = num_weeks ?? 1;
    if (typeof finalNumWeeks !== "number" || finalNumWeeks < 1 || finalNumWeeks > 4) {
      return jsonError("num_weeks must be between 1 and 4", 400);
    }

    const insert: MealPlanInsert = {
      name,
      description: description ?? null,
      author_id: caller.id,
      is_public: is_public ?? false,
      num_weeks: finalNumWeeks,
    };

    const planId = await db.transaction().execute(async (trx) => {
      const plan = await trx
        .insertInto("meal_plan")
        .values(insert)
        .returning(["id"])
        .executeTakeFirstOrThrow();

      if (Array.isArray(days) && days.length) {
        await replaceMealPlanDays(trx, plan.id, days);
      }
      if (Array.isArray(images) && images.length) {
        await replaceMealPlanImages(trx, plan.id, images);
      }
      return plan.id;
    });

    const detail = await fetchMealPlanDetail(planId);
    return json(detail, 201);
  }

  // ── PUT /meal-plans/:id ──────────────────────────────────────────────────────────
  if (req.method === "PUT" && id) {
    const existing = await db
      .selectFrom("meal_plan")
      .select(["id", "author_id", "is_system"])
      .where("id", "=", id)
      .executeTakeFirst();
    if (!existing) return jsonError("Meal plan not found", 404);

    if (!canEdit(caller, existing)) return forbidden();

    const body = await req.json().catch(() => null);
    if (!body || Object.keys(body).length === 0) {
      return jsonError("Body must not be empty", 400);
    }

    const { name, description, is_public, num_weeks, days, images } = body;

    if (num_weeks !== undefined && (typeof num_weeks !== "number" || num_weeks < 1 || num_weeks > 4)) {
      return jsonError("num_weeks must be between 1 and 4", 400);
    }

    const update: MealPlanUpdate = {
      ...(name !== undefined && { name }),
      ...(description !== undefined && { description }),
      ...(is_public !== undefined && { is_public }),
      ...(num_weeks !== undefined && { num_weeks }),
      updated_at: new Date().toISOString(),
    };

    await db.transaction().execute(async (trx) => {
      await trx.updateTable("meal_plan").set(update).where("id", "=", id).execute();
      if (Array.isArray(days)) await replaceMealPlanDays(trx, id, days);
      if (Array.isArray(images)) await replaceMealPlanImages(trx, id, images);
    });

    const detail = await fetchMealPlanDetail(id);
    return json(detail);
  }

  // ── DELETE /meal-plans/:id ─────────────────────────────────────────────────────
  if (req.method === "DELETE" && id) {
    const existing = await db
      .selectFrom("meal_plan")
      .select(["author_id", "is_system"])
      .where("id", "=", id)
      .executeTakeFirst();
    if (!existing) return jsonError("Meal plan not found", 404);

    if (!canEdit(caller, existing)) return forbidden();

    await db.deleteFrom("meal_plan").where("id", "=", id).execute();
    return new Response(null, { status: 204 });
  }

  return jsonError("Not found", 404);
}

Deno.serve(async (req: Request) => {
  try {
    return await handler(req);
  } catch (e) {
    return pgErrorResponse(e, req.method);
  }
});
