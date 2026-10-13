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
  RecipeInsert,
  RecipeUpdate,
  RecipeIngredientInsert,
  RecipeStepInsert,
  RecipeImageInsert,
  RecipeVideoInsert,
} from "../../types/schema/public.ts";
import {
  callerHasAssignedAccessToMealPlan,
  FOOD_ITEM_COLS,
  mealPlansUsingRecipe,
  RECIPE_COLS,
  recomputeAfterRecipeChange,
  recomputeRecipeMacros,
} from "../_shared/nutrition.ts";

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
        // Daily plans using this recipe carry derived totals.
        await recomputeAfterRecipeChange(trx, id);
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
