import { db, supabaseAdmin } from "../_shared/config.ts";
import { sql } from "npm:kysely@^0.27";
import type {
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

// ── Auth ──────────────────────────────────────────────────────────────────────

async function requireAuth(req: Request) {
  const token = req.headers.get("Authorization")?.replace(/^Bearer\s+/i, "");
  if (!token) return { user: null, error: "Missing Authorization header" };
  const { data: { user }, error } = await supabaseAdmin.auth.getUser(token);
  return { user: error ? null : user, error: error?.message ?? null };
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

// ── Replace nested vitamins/minerals ─────────────────────────────────────────

// deno-lint-ignore no-explicit-any
async function replaceFoodItemVitamins(foodItemId: string, vitamins: any[]) {
  await db.deleteFrom("food_item_vitamin").where("food_item_id", "=", foodItemId).execute();
  const rows = vitamins
    .filter((v) => v?.vitamin_id)
    .map((v) => ({
      food_item_id: foodItemId,
      vitamin_id: v.vitamin_id,
      amount_per_100: v.amount_per_100 ?? 0,
      unit: v.unit ?? null,
    }));
  if (rows.length) await db.insertInto("food_item_vitamin").values(rows).execute();
}

// deno-lint-ignore no-explicit-any
async function replaceFoodItemMinerals(foodItemId: string, minerals: any[]) {
  await db.deleteFrom("food_item_mineral").where("food_item_id", "=", foodItemId).execute();
  const rows = minerals
    .filter((m) => m?.mineral_id)
    .map((m) => ({
      food_item_id: foodItemId,
      mineral_id: m.mineral_id,
      amount_per_100: m.amount_per_100 ?? 0,
      unit: m.unit ?? null,
    }));
  if (rows.length) await db.insertInto("food_item_mineral").values(rows).execute();
}

// ── Handler ───────────────────────────────────────────────────────────────────

Deno.serve(async (req: Request) => {
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

    try {
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
        author_id: dbUser?.id ?? null,
        is_public: is_public ?? true,
      };

      const foodItem = await db
        .insertInto("food_item")
        .values(insert)
        .returning(["id"])
        .executeTakeFirstOrThrow();

      if (Array.isArray(vitamins) && vitamins.length) {
        await replaceFoodItemVitamins(foodItem.id, vitamins);
      }
      if (Array.isArray(minerals) && minerals.length) {
        await replaceFoodItemMinerals(foodItem.id, minerals);
      }

      const detail = await fetchFoodItemDetail(foodItem.id);
      return json(detail, 201);
    } catch (e) {
      return dbErrorResponse(e);
    }
  }

  // ── PUT /food-items/:id ────────────────────────────────────────────────────────
  if (req.method === "PUT" && id) {
    const existing = await db
      .selectFrom("food_item")
      .select(["id", "author_id", "is_system", "type", "food_subtype", "drink_subtype", "spice_subtype"])
      .where("id", "=", id)
      .executeTakeFirst();
    if (!existing) return jsonError("Food item not found", 404);

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

    const {
      id: _id,
      author_id: _aid,
      is_system: _isys,
      created_at: _ca,
      vitamins,
      minerals,
      ...fields
    } = body;

    const finalType = fields.type ?? existing.type;
    const finalFoodSubtype = "food_subtype" in fields ? fields.food_subtype : existing.food_subtype;
    const finalDrinkSubtype = "drink_subtype" in fields ? fields.drink_subtype : existing.drink_subtype;
    const finalSpiceSubtype = "spice_subtype" in fields ? fields.spice_subtype : existing.spice_subtype;

    if ("type" in fields || "food_subtype" in fields || "drink_subtype" in fields || "spice_subtype" in fields) {
      const subtypeError = validateSubtypes(finalType, finalFoodSubtype, finalDrinkSubtype, finalSpiceSubtype);
      if (subtypeError) return jsonError(subtypeError, 400);
    }

    try {
      const update: FoodItemUpdate = { ...fields, updated_at: new Date().toISOString() };
      await db.updateTable("food_item").set(update).where("id", "=", id).execute();

      if (Array.isArray(vitamins)) await replaceFoodItemVitamins(id, vitamins);
      if (Array.isArray(minerals)) await replaceFoodItemMinerals(id, minerals);

      const detail = await fetchFoodItemDetail(id);
      return json(detail);
    } catch (e) {
      return dbErrorResponse(e);
    }
  }

  // ── DELETE /food-items/:id ─────────────────────────────────────────────────────
  if (req.method === "DELETE" && id) {
    const existing = await db
      .selectFrom("food_item")
      .select(["author_id", "is_system"])
      .where("id", "=", id)
      .executeTakeFirst();
    if (!existing) return jsonError("Food item not found", 404);

    if (existing.is_system && dbUser?.role !== "super_user") {
      return jsonError("Forbidden", 403);
    }
    if (existing.author_id && existing.author_id !== dbUser?.id && dbUser?.role !== "super_user") {
      return jsonError("Forbidden", 403);
    }

    try {
      await db.deleteFrom("food_item").where("id", "=", id).execute();
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

// Maps common Postgres constraint-violation error codes to a 400 response
// instead of letting them surface as an opaque 500.
function dbErrorResponse(e: unknown): Response {
  const code = (e as { code?: string } | null)?.code;
  if (code === "23503" || code === "23505" || code === "23514" || code === "23502") {
    const message = (e as { message?: string } | null)?.message ?? "Constraint violation";
    return jsonError(message, 400);
  }
  throw e;
}
