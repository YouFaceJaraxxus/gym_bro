import { db, supabaseAdmin } from "../_shared/config.ts";
import type {
  DailyMealPlanInsert,
  DailyMealPlanUpdate,
  DailyMealPlanSlotInsert,
  DailyMealPlanSlotEntryInsert,
  MealSlotType,
} from "../../types/schema/public.ts";

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

const FOOD_ITEM_COLS = [
  "id",
  "name",
  "brand",
  "barcode",
  "type",
  "food_subtype",
  "drink_subtype",
  "spice_subtype",
  "serving_unit",
  "kcal_per_100",
  "protein_per_100",
  "carb_per_100",
  "fat_per_100",
  "fiber_per_100",
  "author_id",
  "is_public",
  "is_system",
  "created_at",
  "updated_at",
] as const;

const RECIPE_COLS = [
  "id",
  "name",
  "description",
  "author_id",
  "servings",
  "prep_time_minutes",
  "cook_time_minutes",
  "kcal_per_serving",
  "protein_per_serving",
  "carb_per_serving",
  "fat_per_serving",
  "fiber_per_serving",
  "is_public",
  "is_system",
  "created_at",
  "updated_at",
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

async function requireAuth(req: Request) {
  const token = req.headers.get("Authorization")?.replace(/^Bearer\s+/i, "");
  if (!token) return { user: null, error: "Missing Authorization header" };
  const { data: { user }, error } = await supabaseAdmin.auth.getUser(token);
  return { user: error ? null : user, error: error?.message ?? null };
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

async function replaceDailyMealPlanSlots(
  planId: string,
  // deno-lint-ignore no-explicit-any
  slotsPayload: any[],
) {
  await db.deleteFrom("daily_meal_plan_slot").where("daily_meal_plan_id", "=", planId).execute();

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

    const newSlot = await db
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
      await db.insertInto("daily_meal_plan_slot_entry").values(entryRows).execute();
    }
  }
}

// ── Totals recomputation ─────────────────────────────────────────────────────
// Never trust client-supplied totals — always derive them from the current
// entries and the referenced food_item/recipe macros.

function round2(n: number): number {
  return Math.round(n * 100) / 100;
}

async function recomputeDailyMealPlanTotals(planId: string) {
  const slots = await db
    .selectFrom("daily_meal_plan_slot")
    .select(["id"])
    .where("daily_meal_plan_id", "=", planId)
    .execute();
  const slotIds = slots.map((s) => s.id);

  let kcal = 0, protein = 0, carb = 0, fat = 0, fiber = 0;

  if (slotIds.length) {
    const entries = await db
      .selectFrom("daily_meal_plan_slot_entry")
      .select(["food_item_id", "recipe_id", "quantity", "servings"])
      .where("daily_meal_plan_slot_id", "in", slotIds)
      .execute();

    const foodItemIds = [...new Set(entries.filter((e) => e.food_item_id).map((e) => e.food_item_id!))];
    const recipeIds = [...new Set(entries.filter((e) => e.recipe_id).map((e) => e.recipe_id!))];

    const foodItems = foodItemIds.length
      ? await db
          .selectFrom("food_item")
          .select(["id", "kcal_per_100", "protein_per_100", "carb_per_100", "fat_per_100", "fiber_per_100"])
          .where("id", "in", foodItemIds)
          .execute()
      : [];
    const recipes = recipeIds.length
      ? await db
          .selectFrom("recipe")
          .select([
            "id",
            "kcal_per_serving",
            "protein_per_serving",
            "carb_per_serving",
            "fat_per_serving",
            "fiber_per_serving",
          ])
          .where("id", "in", recipeIds)
          .execute()
      : [];

    const fiMap = Object.fromEntries(foodItems.map((f) => [f.id, f]));
    const rMap = Object.fromEntries(recipes.map((r) => [r.id, r]));

    for (const e of entries) {
      if (e.food_item_id && fiMap[e.food_item_id]) {
        const fi = fiMap[e.food_item_id];
        const qty = Number(e.quantity ?? 0) / 100;
        kcal += Number(fi.kcal_per_100) * qty;
        protein += Number(fi.protein_per_100) * qty;
        carb += Number(fi.carb_per_100) * qty;
        fat += Number(fi.fat_per_100) * qty;
        fiber += Number(fi.fiber_per_100) * qty;
      } else if (e.recipe_id && rMap[e.recipe_id]) {
        const r = rMap[e.recipe_id];
        const servings = Number(e.servings ?? 1);
        kcal += Number(r.kcal_per_serving) * servings;
        protein += Number(r.protein_per_serving) * servings;
        carb += Number(r.carb_per_serving) * servings;
        fat += Number(r.fat_per_serving) * servings;
        fiber += Number(r.fiber_per_serving) * servings;
      }
    }
  }

  await db
    .updateTable("daily_meal_plan")
    .set({
      kcal_total: round2(kcal),
      protein_total: round2(protein),
      carb_total: round2(carb),
      fat_total: round2(fat),
      fiber_total: round2(fiber),
      updated_at: new Date().toISOString(),
    })
    .where("id", "=", planId)
    .execute();
}

// ── Handler ───────────────────────────────────────────────────────────────────

Deno.serve(async (req: Request) => {
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

  // ── POST /daily-meal-plans ──────────────────────────────────────────────────────
  if (req.method === "POST" && !id) {
    const body = await req.json().catch(() => null);
    const { name, description, is_public, slots } = body ?? {};

    if (!name) return jsonError("Missing required field: name", 400);

    try {
      const insert: DailyMealPlanInsert = {
        name,
        description: description ?? null,
        author_id: dbUser?.id ?? null,
        is_public: is_public ?? false,
      };

      const plan = await db
        .insertInto("daily_meal_plan")
        .values(insert)
        .returning(["id"])
        .executeTakeFirstOrThrow();

      if (Array.isArray(slots) && slots.length) {
        await replaceDailyMealPlanSlots(plan.id, slots);
      }

      await recomputeDailyMealPlanTotals(plan.id);

      const detail = await fetchDailyMealPlanDetail(plan.id);
      return json(detail, 201);
    } catch (e) {
      return dbErrorResponse(e);
    }
  }

  // ── PUT /daily-meal-plans/:id ────────────────────────────────────────────────────
  if (req.method === "PUT" && id) {
    const existing = await db
      .selectFrom("daily_meal_plan")
      .select(["id", "author_id", "is_system"])
      .where("id", "=", id)
      .executeTakeFirst();
    if (!existing) return jsonError("Daily meal plan not found", 404);

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

    const { name, description, is_public, slots } = body;

    try {
      const update: DailyMealPlanUpdate = {
        ...(name !== undefined && { name }),
        ...(description !== undefined && { description }),
        ...(is_public !== undefined && { is_public }),
        updated_at: new Date().toISOString(),
      };
      await db.updateTable("daily_meal_plan").set(update).where("id", "=", id).execute();

      if (Array.isArray(slots)) {
        await replaceDailyMealPlanSlots(id, slots);
      }

      await recomputeDailyMealPlanTotals(id);

      const detail = await fetchDailyMealPlanDetail(id);
      return json(detail);
    } catch (e) {
      return dbErrorResponse(e);
    }
  }

  // ── DELETE /daily-meal-plans/:id ───────────────────────────────────────────────
  if (req.method === "DELETE" && id) {
    const existing = await db
      .selectFrom("daily_meal_plan")
      .select(["author_id", "is_system"])
      .where("id", "=", id)
      .executeTakeFirst();
    if (!existing) return jsonError("Daily meal plan not found", 404);

    if (existing.is_system && dbUser?.role !== "super_user") {
      return jsonError("Forbidden", 403);
    }
    if (existing.author_id && existing.author_id !== dbUser?.id && dbUser?.role !== "super_user") {
      return jsonError("Forbidden", 403);
    }

    try {
      await db.deleteFrom("daily_meal_plan").where("id", "=", id).execute();
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
