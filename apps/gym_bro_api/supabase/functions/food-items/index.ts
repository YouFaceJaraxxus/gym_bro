import { type Kysely, sql } from "npm:kysely@^0.27";
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
  FoodItemInsert,
  FoodItemUpdate,
  FoodItemType,
  FoodSubtype,
  DrinkSubtype,
  SpiceSubtype,
  ServingUnit,
} from "../../types/schema/public.ts";
import {
  callerHasAssignedAccessToMealPlan,
  FOOD_ITEM_COLS,
  mealPlansUsingFoodItem,
  recomputeAfterFoodItemChange,
} from "../_shared/nutrition.ts";

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

const MACRO_FIELDS = ["kcal_per_100", "protein_per_100", "carb_per_100", "fat_per_100", "fiber_per_100"] as const;

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

// ── Open Food Facts import ────────────────────────────────────────────────────

const OFF_TIMEOUT_MS = 5000;
const BARCODE_RE = /^\d{6,14}$/;

// Checked in order (most specific first) against the product's category tags.
const CATEGORY_SUBTYPES: [string[], FoodSubtype][] = [
  [["baby-food"], "baby_food"],
  [["protein-powder", "dietary-supplement", "sports-nutrition"], "supplement_powder"],
  [["plant-based-milk", "plant-milk", "soy-milk", "oat-milk", "almond-milk"], "plant_milk"],
  [["cereal-bar", "granola-bar"], "cereal_bar"],
  [["protein-bar", "energy-bar", "snack-bar"], "snack_bar"],
  [["cheese"], "dairy_cheese"],
  [["yogurt", "yoghurt"], "dairy_yogurt"],
  [["peanut-butter", "nut-butter", "nut-spread"], "jam_spread"],
  [["butter"], "dairy_butter"],
  [["cream"], "dairy_cream"],
  [["milk"], "dairy_milk"],
  [["sausage", "ham", "bacon", "salami", "prepared-meat", "cold-cut", "charcuterie"], "processed_meat"],
  [["chicken", "turkey", "poultry"], "poultry"],
  [["beef"], "meat_beef"],
  [["pork"], "meat_pork"],
  [["lamb"], "meat_lamb"],
  [["seafood", "shrimp", "prawn", "mussel", "crustacean", "shellfish"], "seafood"],
  [["fish", "tuna", "salmon", "sardine"], "fish"],
  [["egg"], "egg"],
  [["chocolate", "candy", "confectionery", "sweets"], "chocolate_candy"],
  [["biscuit", "cookie", "wafer"], "biscuit_cookie"],
  [["chips", "crisps"], "snack_chips"],
  [["jam", "spread", "honey", "marmalade"], "jam_spread"],
  [["sweetener", "sugar"], "sweetener"],
  [["dressing"], "dressing"],
  [["sauce", "condiment", "ketchup", "mustard", "mayonnaise"], "sauce_condiment"],
  [["oil", "fats"], "oil_fat"],
  [["pasta", "noodle"], "pasta_noodle"],
  [["rice"], "rice"],
  [["bread", "bakery", "pastries", "pastry"], "bread_bakery"],
  [["breakfast-cereal", "cereal", "oat", "flour", "grain"], "grain_cereal"],
  [["lentil"], "legume_lentil"],
  [["bean", "chickpea", "legume", "pulses"], "legume_bean"],
  [["nut", "almond", "peanut", "cashew", "hazelnut", "walnut"], "nut"],
  [["seed"], "seed"],
  [["potato"], "potato_tuber"],
  [["corn", "maize"], "corn_maize"],
  [["mushroom"], "mushroom"],
  [["fruit"], "fruit"],
  [["vegetable"], "vegetable"],
  [["meal", "pizza", "sandwich", "soup"], "ready_meal"],
  [["frozen"], "frozen_food"],
  [["canned"], "canned_food"],
  [["baking"], "baking_ingredient"],
  [["dairies"], "dairy_milk"],
  [["meat"], "meat_game"],
  [["snack"], "snack_chips"],
];

/** True when a category tag name (e.g. "breakfast-cereals") matches a needle. */
function tagMatches(name: string, needle: string): boolean {
  if (needle.includes("-")) return name.includes(needle);
  const plural = needle.endsWith("y") ? `${needle.slice(0, -1)}ies` : null;
  return name.split("-").some((w) => w === needle || w === `${needle}s` || w === `${needle}es` || w === plural);
}

/** Best-guess food_subtype from Open Food Facts category tags (e.g. "en:cheeses"). */
function subtypeFromCategories(tags: string[]): FoodSubtype {
  const names = tags.map((t) => t.replace(/^[a-z]{2}:/, "").toLowerCase());
  for (const [needles, subtype] of CATEGORY_SUBTYPES) {
    if (names.some((n) => needles.some((needle) => tagMatches(n, needle)))) return subtype;
  }
  return "other_food";
}

// OFF nutriment key (values per 100 g, in grams) → our reference row name.
const OFF_VITAMINS: Record<string, string> = {
  "vitamin-a_100g": "Vitamin A",
  "vitamin-b1_100g": "Vitamin B1 (Thiamine)",
  "vitamin-b2_100g": "Vitamin B2 (Riboflavin)",
  "vitamin-pp_100g": "Vitamin B3 (Niacin)",
  "pantothenic-acid_100g": "Vitamin B5 (Pantothenic acid)",
  "vitamin-b6_100g": "Vitamin B6",
  "biotin_100g": "Vitamin B7 (Biotin)",
  "vitamin-b9_100g": "Vitamin B9 (Folate)",
  "vitamin-b12_100g": "Vitamin B12",
  "vitamin-c_100g": "Vitamin C",
  "vitamin-d_100g": "Vitamin D",
  "vitamin-e_100g": "Vitamin E",
  "vitamin-k_100g": "Vitamin K",
};
const OFF_MINERALS: Record<string, string> = {
  "calcium_100g": "Calcium",
  "iron_100g": "Iron",
  "magnesium_100g": "Magnesium",
  "phosphorus_100g": "Phosphorus",
  "potassium_100g": "Potassium",
  "sodium_100g": "Sodium",
  "zinc_100g": "Zinc",
  "copper_100g": "Copper",
  "manganese_100g": "Manganese",
  "selenium_100g": "Selenium",
  "iodine_100g": "Iodine",
};

function gramsTo(unit: string, grams: number): number {
  if (unit === "mg") return grams * 1000;
  if (unit === "µg" || unit === "ug" || unit === "mcg") return grams * 1_000_000;
  return grams;
}

function num(v: unknown): number | null {
  const n = typeof v === "number" ? v : typeof v === "string" ? parseFloat(v) : NaN;
  return Number.isFinite(n) && n >= 0 ? n : null;
}

type OffProduct = {
  product_name?: string;
  brands?: string;
  categories_tags?: string[];
  nutriments?: Record<string, unknown>;
};

/** Fetches a product from Open Food Facts. null = unknown barcode; throws on network failure. */
async function fetchOffProduct(code: string): Promise<OffProduct | null> {
  const url =
    `https://world.openfoodfacts.org/api/v2/product/${code}.json?fields=product_name,brands,nutriments,categories_tags`;
  const res = await fetch(url, {
    headers: { "User-Agent": "GymBro/1.0 (https://gymbro.app)" },
    signal: AbortSignal.timeout(OFF_TIMEOUT_MS),
  });
  if (res.status === 404) {
    await res.body?.cancel();
    return null;
  }
  if (!res.ok) {
    await res.body?.cancel();
    throw new Error(`Open Food Facts responded ${res.status}`);
  }
  const body = await res.json() as { status?: number; product?: OffProduct };
  if (body.status !== 1 || !body.product) return null;
  return body.product;
}

/** Creates a private food item for the caller from an OFF product. Returns its id. */
async function importOffProduct(caller: Caller, code: string, product: OffProduct): Promise<string> {
  const n = product.nutriments ?? {};
  const tags = product.categories_tags ?? [];
  const kcal = num(n["energy-kcal_100g"]) ??
    (num(n["energy_100g"]) !== null ? num(n["energy_100g"])! / 4.184 : 0);
  const isBeverage = tags.some((t) => /(^|:|-)(beverages|drinks|waters|juices|milks|nectars|sodas)$/.test(t));
  const r2 = (x: number) => Math.round(x * 100) / 100;

  const insert: FoodItemInsert = {
    name: product.product_name?.trim() || `Product ${code}`,
    brand: product.brands?.split(",")[0]?.trim() || null,
    barcode: code,
    type: "food",
    food_subtype: subtypeFromCategories(tags),
    serving_unit: isBeverage ? "ml" : "g",
    kcal_per_100: r2(kcal),
    protein_per_100: r2(num(n["proteins_100g"]) ?? 0),
    carb_per_100: r2(num(n["carbohydrates_100g"]) ?? 0),
    fat_per_100: r2(num(n["fat_100g"]) ?? 0),
    fiber_per_100: r2(num(n["fiber_100g"]) ?? 0),
    author_id: caller.id,
    is_public: false,
  };

  const vitamins = await db.selectFrom("vitamin").select(VITAMIN_COLS).execute();
  const minerals = await db.selectFrom("mineral").select(MINERAL_COLS).execute();
  const pick = (map: Record<string, string>, refs: { id: string; name: string; default_unit: string }[]) =>
    Object.entries(map).flatMap(([key, name]) => {
      const grams = num(n[key]);
      const ref = refs.find((r) => r.name === name);
      if (grams === null || grams === 0 || !ref) return [];
      return [{ id: ref.id, amount_per_100: Math.round(gramsTo(ref.default_unit, grams) * 10000) / 10000 }];
    });

  return await db.transaction().execute(async (trx) => {
    const row = await trx.insertInto("food_item").values(insert).returning(["id"]).executeTakeFirstOrThrow();
    const v = pick(OFF_VITAMINS, vitamins).map((x) => ({ vitamin_id: x.id, amount_per_100: x.amount_per_100 }));
    const m = pick(OFF_MINERALS, minerals).map((x) => ({ mineral_id: x.id, amount_per_100: x.amount_per_100 }));
    if (v.length) await replaceFoodItemVitamins(trx, row.id, v);
    if (m.length) await replaceFoodItemMinerals(trx, row.id, m);
    return row.id;
  });
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
  const barcodeMatch = url.pathname.match(/^\/food-items\/barcode\/([^/]+)$/);
  const isNutrients = url.pathname === "/food-items/nutrients";
  const id = isNutrients ? null : parseId(url.pathname);

  // ── GET /food-items/nutrients — vitamin & mineral reference rows ─────────────
  if (req.method === "GET" && isNutrients) {
    const vitamins = await db.selectFrom("vitamin").select(VITAMIN_COLS).orderBy("name", "asc").execute();
    const minerals = await db.selectFrom("mineral").select(MINERAL_COLS).orderBy("name", "asc").execute();
    return json({ vitamins, minerals });
  }

  // ── GET /food-items/barcode/:code — local item, else import from Open Food Facts
  if (req.method === "GET" && barcodeMatch) {
    const { caller, response } = await requireCaller(req);
    if (!caller) return response;

    const code = decodeURIComponent(barcodeMatch[1]).trim();
    if (!BARCODE_RE.test(code)) return jsonError("Barcode must be 6-14 digits", 400);

    // Prefer the caller's own item, then system, then any public one.
    const local = await db
      .selectFrom("food_item")
      .select(["id"])
      .where("barcode", "=", code)
      .where((eb) =>
        eb.or([eb("author_id", "=", caller.id), eb("is_public", "=", true), eb("is_system", "=", true)])
      )
      .orderBy(sql`(author_id = ${caller.id})`, "desc")
      .orderBy("is_system", "desc")
      .orderBy("created_at", "asc")
      .executeTakeFirst();
    if (local) {
      return json({ ...(await fetchFoodItemDetail(local.id)), source: "local" });
    }

    let product: OffProduct | null;
    try {
      product = await fetchOffProduct(code);
    } catch (_) {
      return jsonError("Couldn't reach Open Food Facts. Try again or enter the item manually.", 502, {
        code: "lookup_unavailable",
      });
    }
    if (!product) return jsonError("No product found for this barcode", 404);

    const newId = await importOffProduct(caller, code, product);
    return json({ ...(await fetchFoodItemDetail(newId)), source: "openfoodfacts" }, 201);
  }

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
      // Recipes and daily plans store derived macros; refresh them in the same transaction.
      if (MACRO_FIELDS.some((k) => k in fields)) await recomputeAfterFoodItemChange(trx, id);
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
