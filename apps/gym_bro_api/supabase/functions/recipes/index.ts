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
  RecipeInsert,
  RecipeUpdate,
  RecipeIngredientInsert,
  RecipeStepInsert,
  RecipeImageInsert,
  RecipeVideoInsert,
} from "../../types/schema/public.ts";

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

const INGREDIENT_COLS = ["id", "recipe_id", "food_item_id", "quantity", "note", "position"] as const;
const STEP_COLS = ["id", "recipe_id", "position", "instruction", "image_url"] as const;
const IMAGE_COLS = ["id", "recipe_id", "url", "is_thumbnail", "position"] as const;
const VIDEO_COLS = ["id", "recipe_id", "url", "title", "position"] as const;

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

/** Meal plans whose days contain this recipe. */
async function mealPlansUsingRecipe(recipeId: string): Promise<string[]> {
  const rows = await db
    .selectFrom("daily_meal_plan_slot_entry")
    .innerJoin("daily_meal_plan_slot", "daily_meal_plan_slot.id", "daily_meal_plan_slot_entry.daily_meal_plan_slot_id")
    .innerJoin("meal_plan_day", "meal_plan_day.daily_meal_plan_id", "daily_meal_plan_slot.daily_meal_plan_id")
    .select("meal_plan_day.meal_plan_id")
    .where("daily_meal_plan_slot_entry.recipe_id", "=", recipeId)
    .execute();
  return rows.map((r) => r.meal_plan_id);
}

// ── Path parsing ──────────────────────────────────────────────────────────────

function parseId(pathname: string): string | null {
  const match = pathname.match(/^\/recipes\/([^/]+)$/);
  return match ? match[1] : null;
}

// ── Nested fetch ──────────────────────────────────────────────────────────────

async function fetchRecipeDetail(recipeId: string) {
  const recipe = await db
    .selectFrom("recipe")
    .select(RECIPE_COLS)
    .where("id", "=", recipeId)
    .executeTakeFirst();

  if (!recipe) return null;

  const ingredients = await db
    .selectFrom("recipe_ingredient")
    .select(INGREDIENT_COLS)
    .where("recipe_id", "=", recipeId)
    .orderBy("position", "asc")
    .execute();

  const steps = await db
    .selectFrom("recipe_step")
    .select(STEP_COLS)
    .where("recipe_id", "=", recipeId)
    .orderBy("position", "asc")
    .execute();

  const images = await db
    .selectFrom("recipe_image")
    .select(IMAGE_COLS)
    .where("recipe_id", "=", recipeId)
    .orderBy("position", "asc")
    .execute();

  const videos = await db
    .selectFrom("recipe_video")
    .select(VIDEO_COLS)
    .where("recipe_id", "=", recipeId)
    .orderBy("position", "asc")
    .execute();

  const foodItemIds = [...new Set(ingredients.map((i) => i.food_item_id))];
  const foodItems = foodItemIds.length
    ? await db.selectFrom("food_item").select(FOOD_ITEM_COLS).where("id", "in", foodItemIds).execute()
    : [];
  const foodItemMap = Object.fromEntries(foodItems.map((f) => [f.id, f]));

  return {
    ...recipe,
    ingredients: ingredients.map((i) => ({ ...i, food_item: foodItemMap[i.food_item_id] ?? null })),
    steps,
    images,
    videos,
  };
}

// ── Replace nested children (always inside a transaction) ────────────────────

// deno-lint-ignore no-explicit-any
async function replaceRecipeIngredients(trx: Kysely<Database>, recipeId: string, ingredients: any[]) {
  await trx.deleteFrom("recipe_ingredient").where("recipe_id", "=", recipeId).execute();
  const rows: RecipeIngredientInsert[] = ingredients
    .filter((i) => i?.food_item_id)
    .map((i, idx) => ({
      recipe_id: recipeId,
      food_item_id: i.food_item_id,
      quantity: i.quantity,
      note: i.note ?? null,
      position: i.position ?? idx,
    }));
  if (rows.length) await trx.insertInto("recipe_ingredient").values(rows).execute();
}

// deno-lint-ignore no-explicit-any
async function replaceRecipeSteps(trx: Kysely<Database>, recipeId: string, steps: any[]) {
  await trx.deleteFrom("recipe_step").where("recipe_id", "=", recipeId).execute();
  const rows: RecipeStepInsert[] = steps.map((s, idx) => ({
    recipe_id: recipeId,
    position: s.position ?? idx,
    instruction: s.instruction,
    image_url: s.image_url ?? null,
  }));
  if (rows.length) await trx.insertInto("recipe_step").values(rows).execute();
}

// deno-lint-ignore no-explicit-any
async function replaceRecipeImages(trx: Kysely<Database>, recipeId: string, images: any[]) {
  await trx.deleteFrom("recipe_image").where("recipe_id", "=", recipeId).execute();
  const rows: RecipeImageInsert[] = images.map((img, idx) => ({
    recipe_id: recipeId,
    url: img.url,
    is_thumbnail: img.is_thumbnail ?? idx === 0,
    position: img.position ?? idx,
  }));
  if (rows.length) await trx.insertInto("recipe_image").values(rows).execute();
}

// deno-lint-ignore no-explicit-any
async function replaceRecipeVideos(trx: Kysely<Database>, recipeId: string, videos: any[]) {
  await trx.deleteFrom("recipe_video").where("recipe_id", "=", recipeId).execute();
  const rows: RecipeVideoInsert[] = videos.map((v, idx) => ({
    recipe_id: recipeId,
    url: v.url,
    title: v.title ?? null,
    position: v.position ?? idx,
  }));
  if (rows.length) await trx.insertInto("recipe_video").values(rows).execute();
}

// ── Macro recomputation ──────────────────────────────────────────────────────
// Never trust client-supplied macro values — always derive kcal/protein/carb/
// fat/fiber per serving from the current ingredient list and food_item macros.

function round2(n: number): number {
  return Math.round(n * 100) / 100;
}

async function recomputeRecipeMacros(trx: Kysely<Database>, recipeId: string, servings: number) {
  const rows = await trx
    .selectFrom("recipe_ingredient")
    .innerJoin("food_item", "food_item.id", "recipe_ingredient.food_item_id")
    .select([
      "recipe_ingredient.quantity as quantity",
      "food_item.kcal_per_100 as kcal_per_100",
      "food_item.protein_per_100 as protein_per_100",
      "food_item.carb_per_100 as carb_per_100",
      "food_item.fat_per_100 as fat_per_100",
      "food_item.fiber_per_100 as fiber_per_100",
    ])
    .where("recipe_ingredient.recipe_id", "=", recipeId)
    .execute();

  let kcal = 0, protein = 0, carb = 0, fat = 0, fiber = 0;
  for (const r of rows) {
    const qty = Number(r.quantity) / 100;
    kcal += Number(r.kcal_per_100) * qty;
    protein += Number(r.protein_per_100) * qty;
    carb += Number(r.carb_per_100) * qty;
    fat += Number(r.fat_per_100) * qty;
    fiber += Number(r.fiber_per_100) * qty;
  }

  const s = servings > 0 ? servings : 1;

  await trx
    .updateTable("recipe")
    .set({
      kcal_per_serving: round2(kcal / s),
      protein_per_serving: round2(protein / s),
      carb_per_serving: round2(carb / s),
      fat_per_serving: round2(fat / s),
      fiber_per_serving: round2(fiber / s),
    })
    .where("id", "=", recipeId)
    .execute();
}

// ── Postgres error mapping ────────────────────────────────────────────────────

function pgErrorResponse(e: unknown, method: string): Response {
  const err = e as { code?: string; message?: string; detail?: string } | null;
  switch (err?.code) {
    case "23505":
      return jsonError("Already exists", 409, { detail: err.detail });
    case "23503":
      return method === "DELETE"
        ? jsonError("Recipe is used by a daily meal plan and can't be deleted", 409)
        : jsonError("Referenced food item does not exist", 400, { detail: err.detail });
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

  // ── GET /recipes — public + owned ─────────────────────────────────────────────
  if (req.method === "GET" && !id) {
    const name = url.searchParams.get("name");
    const mine = url.searchParams.get("mine") === "true";
    const page = parseInt(url.searchParams.get("page") ?? "0");
    const pageSize = Math.min(parseInt(url.searchParams.get("page_size") ?? "20"), 100);

    let query = db.selectFrom("recipe").select(RECIPE_COLS);

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

    query = query.orderBy("updated_at", "desc").limit(pageSize).offset(page * pageSize);
    return json(await query.execute());
  }

  // ── GET /recipes/:id — public, returns full nested detail ────────────────────
  if (req.method === "GET" && id) {
    const detail = await fetchRecipeDetail(id);
    if (!detail) return jsonError("Recipe not found", 404);
    if (!detail.is_public) {
      // Private recipes: author, super, or assigned access to a meal plan using it.
      const caller = await optionalCaller(req);
      const allowed = caller !== null && (
        isSuperUser(caller) || detail.author_id === caller.id ||
        (await callerHasAssignedAccessToMealPlan(caller, await mealPlansUsingRecipe(id)))
      );
      if (!allowed) return jsonError("Recipe not found", 404);
    }
    return json(detail);
  }

  // ── Auth wall ─────────────────────────────────────────────────────────────────

  const { caller, response } = await requireCaller(req);
  if (!caller) return response;

  // ── POST /recipes ──────────────────────────────────────────────────────────────
  if (req.method === "POST" && !id) {
    const body = await req.json().catch(() => null);
    const {
      name,
      description,
      servings,
      prep_time_minutes,
      cook_time_minutes,
      is_public,
      ingredients,
      steps,
      images,
      videos,
    } = body ?? {};

    if (!name) return jsonError("Missing required field: name", 400);

    const finalServings = servings ?? 1;
    if (typeof finalServings !== "number" || finalServings <= 0) {
      return jsonError("servings must be a positive number", 400);
    }

    const insert: RecipeInsert = {
      name,
      description: description ?? null,
      author_id: caller.id,
      servings: finalServings,
      prep_time_minutes: prep_time_minutes ?? null,
      cook_time_minutes: cook_time_minutes ?? null,
      is_public: is_public ?? false,
    };

    const recipeId = await db.transaction().execute(async (trx) => {
      const recipe = await trx
        .insertInto("recipe")
        .values(insert)
        .returning(["id"])
        .executeTakeFirstOrThrow();

      if (Array.isArray(ingredients) && ingredients.length) {
        await replaceRecipeIngredients(trx, recipe.id, ingredients);
      }
      if (Array.isArray(steps) && steps.length) {
        await replaceRecipeSteps(trx, recipe.id, steps);
      }
      if (Array.isArray(images) && images.length) {
        await replaceRecipeImages(trx, recipe.id, images);
      }
      if (Array.isArray(videos) && videos.length) {
        await replaceRecipeVideos(trx, recipe.id, videos);
      }

      await recomputeRecipeMacros(trx, recipe.id, finalServings);
      return recipe.id;
    });

    const detail = await fetchRecipeDetail(recipeId);
    return json(detail, 201);
  }

  // ── PUT /recipes/:id ──────────────────────────────────────────────────────────
  if (req.method === "PUT" && id) {
    const existing = await db
      .selectFrom("recipe")
      .select(["id", "author_id", "is_system", "servings"])
      .where("id", "=", id)
      .executeTakeFirst();
    if (!existing) return jsonError("Recipe not found", 404);

    if (!canEdit(caller, existing)) return forbidden();

    const body = await req.json().catch(() => null);
    if (!body || Object.keys(body).length === 0) {
      return jsonError("Body must not be empty", 400);
    }

    const {
      name,
      description,
      servings,
      prep_time_minutes,
      cook_time_minutes,
      is_public,
      ingredients,
      steps,
      images,
      videos,
    } = body;

    if (servings !== undefined && (typeof servings !== "number" || servings <= 0)) {
      return jsonError("servings must be a positive number", 400);
    }

    const update: RecipeUpdate = {
      ...(name !== undefined && { name }),
      ...(description !== undefined && { description }),
      ...(servings !== undefined && { servings }),
      ...(prep_time_minutes !== undefined && { prep_time_minutes }),
      ...(cook_time_minutes !== undefined && { cook_time_minutes }),
      ...(is_public !== undefined && { is_public }),
      updated_at: new Date().toISOString(),
    };

    await db.transaction().execute(async (trx) => {
      await trx.updateTable("recipe").set(update).where("id", "=", id).execute();

      if (Array.isArray(ingredients)) await replaceRecipeIngredients(trx, id, ingredients);
      if (Array.isArray(steps)) await replaceRecipeSteps(trx, id, steps);
      if (Array.isArray(images)) await replaceRecipeImages(trx, id, images);
      if (Array.isArray(videos)) await replaceRecipeVideos(trx, id, videos);

      const finalServings = servings ?? existing.servings;
      if (Array.isArray(ingredients) || servings !== undefined) {
        await recomputeRecipeMacros(trx, id, Number(finalServings));
      }
    });

    const detail = await fetchRecipeDetail(id);
    return json(detail);
  }

  // ── DELETE /recipes/:id ────────────────────────────────────────────────────────
  if (req.method === "DELETE" && id) {
    const existing = await db
      .selectFrom("recipe")
      .select(["author_id", "is_system"])
      .where("id", "=", id)
      .executeTakeFirst();
    if (!existing) return jsonError("Recipe not found", 404);

    if (!canEdit(caller, existing)) return forbidden();

    await db.deleteFrom("recipe").where("id", "=", id).execute();
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
