import { type Kysely, sql } from "npm:kysely@^0.27";
import { db } from "../_shared/config.ts";
import {
  type Caller,
  canEditAuthored,
  coachesUser,
  forbidden,
  isSuperUser,
  json,
  jsonError,
  requireCaller,
} from "../_shared/auth.ts";
import type {
  Database,
  FoodItemInsert,
  FoodItemUpdate,
  FoodItemType,
  FoodSubtype,
  DrinkSubtype,
  SpiceSubtype,
  ServingUnit,
} from "../../types/schema/public.ts";

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

const VITAMIN_COLS = ["id", "name", "symbol", "default_unit"] as const;
const MINERAL_COLS = ["id", "name", "symbol", "default_unit"] as const;

const VALID_TYPES: FoodItemType[] = ["food", "spice", "drink"];

const VALID_FOOD_SUBTYPES: FoodSubtype[] = [
  "vegetable", "fruit", "mushroom", "herb_fresh",
  "meat_beef", "meat_pork", "meat_lamb", "meat_game", "poultry",
  "fish", "seafood", "egg",
  "dairy_milk", "dairy_cheese", "dairy_yogurt", "dairy_cream", "dairy_butter",
  "plant_milk",
  "grain_cereal", "pasta_noodle", "rice", "bread_bakery",
  "potato_tuber", "corn_maize",
  "legume_bean", "legume_lentil", "nut", "seed",
  "oil_fat",
  "canned_food", "frozen_food", "processed_meat", "ready_meal",
  "snack_chips", "snack_bar", "cereal_bar",
  "chocolate_candy", "biscuit_cookie", "sweetener", "jam_spread",
  "baking_ingredient",
  "sauce_condiment", "dressing",
  "baby_food", "supplement_powder", "other_food",
];

const VALID_DRINK_SUBTYPES: DrinkSubtype[] = [
  "water_still", "water_sparkling", "water_flavoured",
  "juice_fruit", "juice_vegetable",
  "smoothie", "shake",
  "milk_dairy", "milk_plant",
  "coffee", "espresso", "tea_black", "tea_green", "tea_herbal",
  "soda", "energy_drink", "sports_drink", "isotonic",
  "alcohol_beer", "alcohol_cider", "alcohol_wine", "alcohol_spirit", "alcohol_cocktail",
  "protein_shake", "meal_replacement",
  "kombucha", "kefir_drink",
  "other_drink",
];

const VALID_SPICE_SUBTYPES: SpiceSubtype[] = [
  "herb_dried", "spice_ground", "spice_whole", "spice_seed",
  "seasoning_blend", "rub", "marinade_dry",
  "salt", "pepper",
  "extract_essence",
  "other_spice",
];

const VALID_SERVING_UNITS: ServingUnit[] = ["g", "ml"];

const EDITABLE_FIELDS = [
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
  "is_public",
] as const;

// ── Auth ──────────────────────────────────────────────────────────────────────

/** Reads are public; resolve the caller only when a token was sent. */
async function optionalCaller(req: Request): Promise<Caller | null> {
  if (!req.headers.get("Authorization")) return null;
  const { caller } = await requireCaller(req);
  return caller ?? null;
}

/** System items are super-user only; everything else follows canEditAuthored. */
function canEditFoodItem(caller: Caller, item: { author_id: string | null; is_system: boolean }): boolean {
  if (item.is_system && !isSuperUser(caller)) return false;
  return canEditAuthored(caller, item.author_id);
}

/**
 * True when the caller was assigned one of these meal plans, or coaches
 * someone who was. Grants read access to private plans and the daily plans,
 * recipes and food items they reference.
 */
async function callerHasAssignedAccessToMealPlan(
  caller: Caller,
  mealPlanId: string | string[],
): Promise<boolean> {
  const ids = [...new Set(Array.isArray(mealPlanId) ? mealPlanId : [mealPlanId])];
  if (!ids.length) return false;
  const rows = await db
    .selectFrom("meal_plan_assignment")
    .select("user_id")
    .where("meal_plan_id", "in", ids)
    .execute();
  const targets = [...new Set(rows.map((r) => r.user_id))];
  if (targets.includes(caller.id)) return true;
  for (const target of targets) {
    if (await coachesUser(caller, target)) return true;
  }
  return false;
}

/** Meal plans whose days contain this food item, directly or via a recipe. */
async function mealPlansUsingFoodItem(foodItemId: string): Promise<string[]> {
  const direct = await db
    .selectFrom("daily_meal_plan_slot_entry")
    .innerJoin("daily_meal_plan_slot", "daily_meal_plan_slot.id", "daily_meal_plan_slot_entry.daily_meal_plan_slot_id")
    .innerJoin("meal_plan_day", "meal_plan_day.daily_meal_plan_id", "daily_meal_plan_slot.daily_meal_plan_id")
    .select("meal_plan_day.meal_plan_id")
    .where("daily_meal_plan_slot_entry.food_item_id", "=", foodItemId)
    .execute();
  const viaRecipe = await db
    .selectFrom("recipe_ingredient")
    .innerJoin("daily_meal_plan_slot_entry", "daily_meal_plan_slot_entry.recipe_id", "recipe_ingredient.recipe_id")
    .innerJoin("daily_meal_plan_slot", "daily_meal_plan_slot.id", "daily_meal_plan_slot_entry.daily_meal_plan_slot_id")
    .innerJoin("meal_plan_day", "meal_plan_day.daily_meal_plan_id", "daily_meal_plan_slot.daily_meal_plan_id")
    .select("meal_plan_day.meal_plan_id")
    .where("recipe_ingredient.food_item_id", "=", foodItemId)
    .execute();
  return [...direct, ...viaRecipe].map((r) => r.meal_plan_id);
}

// ── Path parsing ──────────────────────────────────────────────────────────────

function parseId(pathname: string): string | null {
  const match = pathname.match(/^\/food-items\/([^/]+)$/);
  return match ? match[1] : null;
}

// ── Validation ────────────────────────────────────────────────────────────────
// Mirrors the food_item_one_subtype CHECK constraint: exactly one of
// food_subtype / drink_subtype / spice_subtype must be set, matching `type`.

function validateSubtypes(
  type: unknown,
  foodSubtype: unknown,
  drinkSubtype: unknown,
  spiceSubtype: unknown,
): string | null {
  if (!VALID_TYPES.includes(type as FoodItemType)) {
    return "type must be one of: food, spice, drink";
  }
  if (type === "food") {
    if (!VALID_FOOD_SUBTYPES.includes(foodSubtype as FoodSubtype)) {
      return "food_subtype is required and must be valid for type 'food'";
    }
    if (drinkSubtype != null || spiceSubtype != null) {
      return "drink_subtype and spice_subtype must not be set for type 'food'";
    }
  } else if (type === "drink") {
    if (!VALID_DRINK_SUBTYPES.includes(drinkSubtype as DrinkSubtype)) {
      return "drink_subtype is required and must be valid for type 'drink'";
    }
    if (foodSubtype != null || spiceSubtype != null) {
      return "food_subtype and spice_subtype must not be set for type 'drink'";
    }
  } else if (type === "spice") {
    if (!VALID_SPICE_SUBTYPES.includes(spiceSubtype as SpiceSubtype)) {
      return "spice_subtype is required and must be valid for type 'spice'";
    }
    if (foodSubtype != null || drinkSubtype != null) {
      return "food_subtype and drink_subtype must not be set for type 'spice'";
    }
  }
  return null;
}

// ── Nested fetch ──────────────────────────────────────────────────────────────

async function fetchFoodItemDetail(id: string) {
  const foodItem = await db
    .selectFrom("food_item")
    .select(FOOD_ITEM_COLS)
    .where("id", "=", id)
    .executeTakeFirst();

  if (!foodItem) return null;

  const vitaminRows = await db
    .selectFrom("food_item_vitamin")
    .innerJoin("vitamin", "vitamin.id", "food_item_vitamin.vitamin_id")
    .select([
      "food_item_vitamin.vitamin_id as vitamin_id",
      "food_item_vitamin.amount_per_100 as amount_per_100",
      "food_item_vitamin.unit as unit",
      "vitamin.id as v_id",
      "vitamin.name as v_name",
      "vitamin.symbol as v_symbol",
      "vitamin.default_unit as v_default_unit",
    ])
    .where("food_item_vitamin.food_item_id", "=", id)
    .execute();

  const mineralRows = await db
    .selectFrom("food_item_mineral")
    .innerJoin("mineral", "mineral.id", "food_item_mineral.mineral_id")
    .select([
      "food_item_mineral.mineral_id as mineral_id",
      "food_item_mineral.amount_per_100 as amount_per_100",
      "food_item_mineral.unit as unit",
      "mineral.id as m_id",
      "mineral.name as m_name",
      "mineral.symbol as m_symbol",
      "mineral.default_unit as m_default_unit",
    ])
    .where("food_item_mineral.food_item_id", "=", id)
    .execute();

  return {
    ...foodItem,
    vitamins: vitaminRows.map((r) => ({
      vitamin_id: r.vitamin_id,
      vitamin: { id: r.v_id, name: r.v_name, symbol: r.v_symbol, default_unit: r.v_default_unit },
      amount_per_100: r.amount_per_100,
      unit: r.unit,
    })),
    minerals: mineralRows.map((r) => ({
      mineral_id: r.mineral_id,
      mineral: { id: r.m_id, name: r.m_name, symbol: r.m_symbol, default_unit: r.m_default_unit },
      amount_per_100: r.amount_per_100,
      unit: r.unit,
    })),
  };
}

// ── Replace nested vitamins/minerals (always inside a transaction) ───────────

// deno-lint-ignore no-explicit-any
async function replaceFoodItemVitamins(trx: Kysely<Database>, foodItemId: string, vitamins: any[]) {
  await trx.deleteFrom("food_item_vitamin").where("food_item_id", "=", foodItemId).execute();
  const rows = vitamins
    .filter((v) => v?.vitamin_id)
    .map((v) => ({
      food_item_id: foodItemId,
      vitamin_id: v.vitamin_id,
      amount_per_100: v.amount_per_100 ?? 0,
      unit: v.unit ?? null,
    }));
  if (rows.length) await trx.insertInto("food_item_vitamin").values(rows).execute();
}

// deno-lint-ignore no-explicit-any
async function replaceFoodItemMinerals(trx: Kysely<Database>, foodItemId: string, minerals: any[]) {
  await trx.deleteFrom("food_item_mineral").where("food_item_id", "=", foodItemId).execute();
  const rows = minerals
    .filter((m) => m?.mineral_id)
    .map((m) => ({
      food_item_id: foodItemId,
      mineral_id: m.mineral_id,
      amount_per_100: m.amount_per_100 ?? 0,
      unit: m.unit ?? null,
    }));
  if (rows.length) await trx.insertInto("food_item_mineral").values(rows).execute();
}

// ── Postgres error mapping ────────────────────────────────────────────────────

function pgErrorResponse(e: unknown, method: string): Response {
  const err = e as { code?: string; message?: string; detail?: string } | null;
  switch (err?.code) {
    case "23505":
      return jsonError("Already exists", 409, { detail: err.detail });
    case "23503":
      return method === "DELETE"
        ? jsonError("Food item is used by a recipe or meal plan and can't be deleted", 409)
        : jsonError("Referenced vitamin or mineral does not exist", 400, { detail: err.detail });
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

  // ── GET /food-items — public + owned ──────────────────────────────────────────
  if (req.method === "GET" && !id) {
    const name = url.searchParams.get("name");
    const type = url.searchParams.get("type") as FoodItemType | null;
    const mine = url.searchParams.get("mine") === "true";
    const page = parseInt(url.searchParams.get("page") ?? "0");
    const pageSize = Math.min(parseInt(url.searchParams.get("page_size") ?? "20"), 100);

    let query = db.selectFrom("food_item").select(FOOD_ITEM_COLS);

    if (mine) {
      // Never fall through to an unfiltered query when the profile is missing.
      const { caller } = await requireCaller(req);
      if (!caller) return jsonError("Unauthorized", 401);
      query = query.where("author_id", "=", caller.id);
    } else {
      query = query.where("is_public", "=", true);
    }

    if (name) {
      query = query.where(
        sql<boolean>`to_tsvector('english', name) @@ plainto_tsquery('english', ${name})`,
      );
    }
    if (type && VALID_TYPES.includes(type)) query = query.where("type", "=", type);

    query = query.orderBy("name", "asc").limit(pageSize).offset(page * pageSize);
    return json(await query.execute());
  }

  // ── GET /food-items/:id — public, returns detail with vitamins/minerals ──────
  if (req.method === "GET" && id) {
    const detail = await fetchFoodItemDetail(id);
    if (!detail) return jsonError("Food item not found", 404);
    if (!detail.is_public) {
      // Private items: author, super, or assigned access to a meal plan using it.
      const caller = await optionalCaller(req);
      const allowed = caller !== null && (
        isSuperUser(caller) || detail.author_id === caller.id ||
        (await callerHasAssignedAccessToMealPlan(caller, await mealPlansUsingFoodItem(id)))
      );
      if (!allowed) return jsonError("Food item not found", 404);
    }
    return json(detail);
  }

  // ── Auth wall ─────────────────────────────────────────────────────────────────

  const { caller, response } = await requireCaller(req);
  if (!caller) return response;

  // ── POST /food-items ───────────────────────────────────────────────────────────
  if (req.method === "POST" && !id) {
    const body = await req.json().catch(() => null);
    const {
      name,
      brand,
      barcode,
      type,
      food_subtype,
      drink_subtype,
      spice_subtype,
      serving_unit,
      kcal_per_100,
      protein_per_100,
      carb_per_100,
      fat_per_100,
      fiber_per_100,
      is_public,
      vitamins,
      minerals,
    } = body ?? {};

    if (!name) return jsonError("Missing required field: name", 400);

    const subtypeError = validateSubtypes(type, food_subtype, drink_subtype, spice_subtype);
    if (subtypeError) return jsonError(subtypeError, 400);

    const insert: FoodItemInsert = {
      name,
      brand: brand ?? null,
      barcode: barcode ?? null,
      type,
      food_subtype: food_subtype ?? null,
      drink_subtype: drink_subtype ?? null,
      spice_subtype: spice_subtype ?? null,
      serving_unit: VALID_SERVING_UNITS.includes(serving_unit) ? serving_unit : "g",
      kcal_per_100: kcal_per_100 ?? 0,
      protein_per_100: protein_per_100 ?? 0,
      carb_per_100: carb_per_100 ?? 0,
      fat_per_100: fat_per_100 ?? 0,
      fiber_per_100: fiber_per_100 ?? 0,
      author_id: caller.id,
      is_public: is_public ?? true,
    };

    const foodItemId = await db.transaction().execute(async (trx) => {
      const foodItem = await trx
        .insertInto("food_item")
        .values(insert)
        .returning(["id"])
        .executeTakeFirstOrThrow();

      if (Array.isArray(vitamins) && vitamins.length) {
        await replaceFoodItemVitamins(trx, foodItem.id, vitamins);
      }
      if (Array.isArray(minerals) && minerals.length) {
        await replaceFoodItemMinerals(trx, foodItem.id, minerals);
      }
      return foodItem.id;
    });

    const detail = await fetchFoodItemDetail(foodItemId);
    return json(detail, 201);
  }

  // ── PUT /food-items/:id ────────────────────────────────────────────────────────
  if (req.method === "PUT" && id) {
    const existing = await db
      .selectFrom("food_item")
      .select(["id", "author_id", "is_system", "type", "food_subtype", "drink_subtype", "spice_subtype"])
      .where("id", "=", id)
      .executeTakeFirst();
    if (!existing) return jsonError("Food item not found", 404);

    if (!canEditFoodItem(caller, existing)) return forbidden();

    const body = await req.json().catch(() => null);
    if (!body || Object.keys(body).length === 0) {
      return jsonError("Body must not be empty", 400);
    }

    const { vitamins, minerals } = body;
    // Only these columns are client-editable (author, is_system, timestamps are not).
    const fields: Record<string, unknown> = {};
    for (const key of EDITABLE_FIELDS) {
      if (key in body) fields[key] = body[key];
    }

    const finalType = fields.type ?? existing.type;
    const finalFoodSubtype = "food_subtype" in fields ? fields.food_subtype : existing.food_subtype;
    const finalDrinkSubtype = "drink_subtype" in fields ? fields.drink_subtype : existing.drink_subtype;
    const finalSpiceSubtype = "spice_subtype" in fields ? fields.spice_subtype : existing.spice_subtype;

    if ("type" in fields || "food_subtype" in fields || "drink_subtype" in fields || "spice_subtype" in fields) {
      const subtypeError = validateSubtypes(finalType, finalFoodSubtype, finalDrinkSubtype, finalSpiceSubtype);
      if (subtypeError) return jsonError(subtypeError, 400);
    }

    if ("serving_unit" in fields && !VALID_SERVING_UNITS.includes(fields.serving_unit as ServingUnit)) {
      return jsonError("serving_unit must be one of: g, ml", 400);
    }

    const update = { ...fields, updated_at: new Date().toISOString() } as FoodItemUpdate;
    await db.transaction().execute(async (trx) => {
      await trx.updateTable("food_item").set(update).where("id", "=", id).execute();
      if (Array.isArray(vitamins)) await replaceFoodItemVitamins(trx, id, vitamins);
      if (Array.isArray(minerals)) await replaceFoodItemMinerals(trx, id, minerals);
    });

    const detail = await fetchFoodItemDetail(id);
    return json(detail);
  }

  // ── DELETE /food-items/:id ─────────────────────────────────────────────────────
  if (req.method === "DELETE" && id) {
    const existing = await db
      .selectFrom("food_item")
      .select(["author_id", "is_system"])
      .where("id", "=", id)
      .executeTakeFirst();
    if (!existing) return jsonError("Food item not found", 404);

    if (!canEditFoodItem(caller, existing)) return forbidden();

    await db.deleteFrom("food_item").where("id", "=", id).execute();
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
