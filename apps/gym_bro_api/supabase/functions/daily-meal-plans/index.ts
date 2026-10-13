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
  DailyMealPlanInsert,
  DailyMealPlanUpdate,
  DailyMealPlanSlotInsert,
  DailyMealPlanSlotEntryInsert,
  MealSlotType,
} from "../../types/schema/public.ts";
import {
  callerHasAssignedAccessToMealPlan,
  FOOD_ITEM_COLS,
  mealPlansUsingDailyPlan,
  RECIPE_COLS,
  recomputeDailyMealPlanTotals,
} from "../_shared/nutrition.ts";

const PLAN_COLS = [
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

const SLOT_COLS = ["id", "daily_meal_plan_id", "slot_type", "position", "note"] as const;
const ENTRY_COLS = [
  "id",
  "daily_meal_plan_slot_id",
  "food_item_id",
  "recipe_id",
  "quantity",
  "servings",
  "position",
  "note",
] as const;

const VALID_SLOT_TYPES: MealSlotType[] = [
  "breakfast",
  "morning_snack",
  "lunch",
  "afternoon_snack",
  "dinner",
  "evening_snack",
  "pre_workout",
  "post_workout",
];

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
  const match = pathname.match(/^\/daily-meal-plans\/([^/]+)$/);
  return match ? match[1] : null;
}

// ── Nested fetch ──────────────────────────────────────────────────────────────

async function fetchDailyMealPlanDetail(planId: string) {
  const plan = await db
    .selectFrom("daily_meal_plan")
    .select(PLAN_COLS)
    .where("id", "=", planId)
    .executeTakeFirst();

  if (!plan) return null;

  const slots = await db
    .selectFrom("daily_meal_plan_slot")
    .select(SLOT_COLS)
    .where("daily_meal_plan_id", "=", planId)
    .orderBy("position", "asc")
    .execute();

  const slotIds = slots.map((s) => s.id);
  const entries = slotIds.length
    ? await db
        .selectFrom("daily_meal_plan_slot_entry")
        .select(ENTRY_COLS)
        .where("daily_meal_plan_slot_id", "in", slotIds)
        .orderBy("position", "asc")
        .execute()
    : [];

  const foodItemIds = [...new Set(entries.filter((e) => e.food_item_id).map((e) => e.food_item_id!))];
  const recipeIds = [...new Set(entries.filter((e) => e.recipe_id).map((e) => e.recipe_id!))];

  const foodItems = foodItemIds.length
    ? await db.selectFrom("food_item").select(FOOD_ITEM_COLS).where("id", "in", foodItemIds).execute()
    : [];
  const recipes = recipeIds.length
    ? await db.selectFrom("recipe").select(RECIPE_COLS).where("id", "in", recipeIds).execute()
    : [];

  const foodItemMap = Object.fromEntries(foodItems.map((f) => [f.id, f]));
  const recipeMap = Object.fromEntries(recipes.map((r) => [r.id, r]));

  const entriesBySlot = entries.reduce(
    (acc, e) => {
      (acc[e.daily_meal_plan_slot_id] ??= []).push({
        ...e,
        food_item: e.food_item_id ? foodItemMap[e.food_item_id] ?? null : null,
        recipe: e.recipe_id ? recipeMap[e.recipe_id] ?? null : null,
      });
      return acc;
    },
    {} as Record<string, unknown[]>,
  );

  return {
    ...plan,
    slots: slots.map((s) => ({ ...s, entries: entriesBySlot[s.id] ?? [] })),
  };
}

// ── Replace nested slots → entries ───────────────────────────────────────────
// Deletes all existing slots (cascade removes entries) then re-inserts.
// Always call inside a transaction.

async function replaceDailyMealPlanSlots(
  trx: Kysely<Database>,
  planId: string,
  // deno-lint-ignore no-explicit-any
  slotsPayload: any[],
) {
  await trx.deleteFrom("daily_meal_plan_slot").where("daily_meal_plan_id", "=", planId).execute();

  for (const [si, slotData] of slotsPayload.entries()) {
    const slotType: MealSlotType = VALID_SLOT_TYPES.includes(slotData.slot_type)
      ? slotData.slot_type
      : "breakfast";

    const slotInsert: DailyMealPlanSlotInsert = {
      daily_meal_plan_id: planId,
      slot_type: slotType,
      position: slotData.position ?? si,
      note: slotData.note ?? null,
    };

    const newSlot = await trx
      .insertInto("daily_meal_plan_slot")
      .values(slotInsert)
      .returning(["id"])
      .executeTakeFirstOrThrow();

    const entryRows: DailyMealPlanSlotEntryInsert[] = (slotData.entries ?? [])
      .filter((e: { food_item_id?: string; recipe_id?: string }) => e.food_item_id || e.recipe_id)
      .map((e: {
        food_item_id?: string | null;
        recipe_id?: string | null;
        quantity?: number | null;
        servings?: number | null;
        position?: number;
        note?: string | null;
      }, ei: number) => ({
        daily_meal_plan_slot_id: newSlot.id,
        food_item_id: e.food_item_id ?? null,
        recipe_id: e.recipe_id ?? null,
        quantity: e.quantity ?? null,
        servings: e.servings ?? 1.0,
        position: e.position ?? ei,
        note: e.note ?? null,
      }));

    if (entryRows.length) {
      await trx.insertInto("daily_meal_plan_slot_entry").values(entryRows).execute();
    }
  }
}

// ── Postgres error mapping ────────────────────────────────────────────────────

function pgErrorResponse(e: unknown, method: string): Response {
  const err = e as { code?: string; message?: string; detail?: string } | null;
  switch (err?.code) {
    case "23505":
      return jsonError("Already exists", 409, { detail: err.detail });
    case "23503":
      return method === "DELETE"
        ? jsonError("Daily meal plan is used by a meal plan and can't be deleted", 409)
        : jsonError("Referenced food item or recipe does not exist", 400, { detail: err.detail });
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

  // ── GET /daily-meal-plans — public + owned ────────────────────────────────────
  if (req.method === "GET" && !id) {
    const name = url.searchParams.get("name");
    const mine = url.searchParams.get("mine") === "true";
    const page = parseInt(url.searchParams.get("page") ?? "0");
    const pageSize = Math.min(parseInt(url.searchParams.get("page_size") ?? "20"), 100);

    let query = db.selectFrom("daily_meal_plan").select(PLAN_COLS);

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

    const planIds = plans.map((p) => p.id);
    const counts = planIds.length
      ? await db
          .selectFrom("daily_meal_plan_slot")
          .select(["daily_meal_plan_id", db.fn.count("id").as("count")])
          .where("daily_meal_plan_id", "in", planIds)
          .groupBy("daily_meal_plan_id")
          .execute()
      : [];
    const countByPlanId = Object.fromEntries(counts.map((c) => [c.daily_meal_plan_id, Number(c.count)]));

    return json(plans.map((p) => ({ ...p, meal_count: countByPlanId[p.id] ?? 0 })));
  }

  // ── GET /daily-meal-plans/:id — public, returns full nested detail ───────────
  if (req.method === "GET" && id) {
    const detail = await fetchDailyMealPlanDetail(id);
    if (!detail) return jsonError("Daily meal plan not found", 404);
    if (!detail.is_public) {
      // Private plans: author, super, or assigned access to a meal plan using it.
      const caller = await optionalCaller(req);
      const allowed = caller !== null && (
        isSuperUser(caller) || detail.author_id === caller.id ||
        (await callerHasAssignedAccessToMealPlan(caller, await mealPlansUsingDailyPlan(id)))
      );
      if (!allowed) return jsonError("Daily meal plan not found", 404);
    }
    return json(detail);
  }

  // ── Auth wall ─────────────────────────────────────────────────────────────────

  const { caller, response } = await requireCaller(req);
  if (!caller) return response;

  // ── POST /daily-meal-plans ──────────────────────────────────────────────────────
  if (req.method === "POST" && !id) {
    const body = await req.json().catch(() => null);
    const { name, description, is_public, slots } = body ?? {};

    if (!name) return jsonError("Missing required field: name", 400);

    const insert: DailyMealPlanInsert = {
      name,
      description: description ?? null,
      author_id: caller.id,
      is_public: is_public ?? false,
    };

    const planId = await db.transaction().execute(async (trx) => {
      const plan = await trx
        .insertInto("daily_meal_plan")
        .values(insert)
        .returning(["id"])
        .executeTakeFirstOrThrow();

      if (Array.isArray(slots) && slots.length) {
        await replaceDailyMealPlanSlots(trx, plan.id, slots);
      }

      await recomputeDailyMealPlanTotals(trx, plan.id);
      return plan.id;
    });

    const detail = await fetchDailyMealPlanDetail(planId);
    return json(detail, 201);
  }

  // ── PUT /daily-meal-plans/:id ────────────────────────────────────────────────────
  if (req.method === "PUT" && id) {
    const existing = await db
      .selectFrom("daily_meal_plan")
      .select(["id", "author_id", "is_system"])
      .where("id", "=", id)
      .executeTakeFirst();
    if (!existing) return jsonError("Daily meal plan not found", 404);

    if (!canEdit(caller, existing)) return forbidden();

    const body = await req.json().catch(() => null);
    if (!body || Object.keys(body).length === 0) {
      return jsonError("Body must not be empty", 400);
    }

    const { name, description, is_public, slots } = body;

    const update: DailyMealPlanUpdate = {
      ...(name !== undefined && { name }),
      ...(description !== undefined && { description }),
      ...(is_public !== undefined && { is_public }),
      updated_at: new Date().toISOString(),
    };

    await db.transaction().execute(async (trx) => {
      await trx.updateTable("daily_meal_plan").set(update).where("id", "=", id).execute();

      if (Array.isArray(slots)) {
        await replaceDailyMealPlanSlots(trx, id, slots);
      }

      await recomputeDailyMealPlanTotals(trx, id);
    });

    const detail = await fetchDailyMealPlanDetail(id);
    return json(detail);
  }

  // ── DELETE /daily-meal-plans/:id ───────────────────────────────────────────────
  if (req.method === "DELETE" && id) {
    const existing = await db
      .selectFrom("daily_meal_plan")
      .select(["author_id", "is_system"])
      .where("id", "=", id)
      .executeTakeFirst();
    if (!existing) return jsonError("Daily meal plan not found", 404);

    if (!canEdit(caller, existing)) return forbidden();

    await db.deleteFrom("daily_meal_plan").where("id", "=", id).execute();
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
