import { db, supabaseAdmin } from "../_shared/config.ts";
import { sql } from "npm:kysely@^0.27";
import type {
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

async function requireAuth(req: Request) {
  const token = req.headers.get("Authorization")?.replace(/^Bearer\s+/i, "");
  if (!token) return { user: null, error: "Missing Authorization header" };
  const { data: { user }, error } = await supabaseAdmin.auth.getUser(token);
  return { user: error ? null : user, error: error?.message ?? null };
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

// ── Replace nested children ──────────────────────────────────────────────────

// deno-lint-ignore no-explicit-any
async function replaceRecipeIngredients(recipeId: string, ingredients: any[]) {
  await db.deleteFrom("recipe_ingredient").where("recipe_id", "=", recipeId).execute();
  const rows: RecipeIngredientInsert[] = ingredients
    .filter((i) => i?.food_item_id)
    .map((i, idx) => ({
      recipe_id: recipeId,
      food_item_id: i.food_item_id,
      quantity: i.quantity,
      note: i.note ?? null,
      position: i.position ?? idx,
    }));
  if (rows.length) await db.insertInto("recipe_ingredient").values(rows).execute();
}

// deno-lint-ignore no-explicit-any
async function replaceRecipeSteps(recipeId: string, steps: any[]) {
  await db.deleteFrom("recipe_step").where("recipe_id", "=", recipeId).execute();
  const rows: RecipeStepInsert[] = steps.map((s, idx) => ({
    recipe_id: recipeId,
    position: s.position ?? idx,
    instruction: s.instruction,
    image_url: s.image_url ?? null,
  }));
  if (rows.length) await db.insertInto("recipe_step").values(rows).execute();
}

// deno-lint-ignore no-explicit-any
async function replaceRecipeImages(recipeId: string, images: any[]) {
  await db.deleteFrom("recipe_image").where("recipe_id", "=", recipeId).execute();
  const rows: RecipeImageInsert[] = images.map((img, idx) => ({
    recipe_id: recipeId,
    url: img.url,
    is_thumbnail: img.is_thumbnail ?? idx === 0,
    position: img.position ?? idx,
  }));
  if (rows.length) await db.insertInto("recipe_image").values(rows).execute();
}

// deno-lint-ignore no-explicit-any
async function replaceRecipeVideos(recipeId: string, videos: any[]) {
  await db.deleteFrom("recipe_video").where("recipe_id", "=", recipeId).execute();
  const rows: RecipeVideoInsert[] = videos.map((v, idx) => ({
    recipe_id: recipeId,
    url: v.url,
    title: v.title ?? null,
    position: v.position ?? idx,
  }));
  if (rows.length) await db.insertInto("recipe_video").values(rows).execute();
}

// ── Macro recomputation ──────────────────────────────────────────────────────
// Never trust client-supplied macro values — always derive kcal/protein/carb/
// fat/fiber per serving from the current ingredient list and food_item macros.

function round2(n: number): number {
  return Math.round(n * 100) / 100;
}

async function recomputeRecipeMacros(recipeId: string, servings: number) {
  const rows = await db
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

  await db
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

// ── Handler ───────────────────────────────────────────────────────────────────

Deno.serve(async (req: Request) => {
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

    query = query.orderBy("updated_at", "desc").limit(pageSize).offset(page * pageSize);
    return json(await query.execute());
  }

  // ── GET /recipes/:id — public, returns full nested detail ────────────────────
  if (req.method === "GET" && id) {
    const detail = await fetchRecipeDetail(id);
    if (!detail) return jsonError("Recipe not found", 404);
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

    try {
      const insert: RecipeInsert = {
        name,
        description: description ?? null,
        author_id: dbUser?.id ?? null,
        servings: finalServings,
        prep_time_minutes: prep_time_minutes ?? null,
        cook_time_minutes: cook_time_minutes ?? null,
        is_public: is_public ?? false,
      };

      const recipe = await db
        .insertInto("recipe")
        .values(insert)
        .returning(["id"])
        .executeTakeFirstOrThrow();

      if (Array.isArray(ingredients) && ingredients.length) {
        await replaceRecipeIngredients(recipe.id, ingredients);
      }
      if (Array.isArray(steps) && steps.length) {
        await replaceRecipeSteps(recipe.id, steps);
      }
      if (Array.isArray(images) && images.length) {
        await replaceRecipeImages(recipe.id, images);
      }
      if (Array.isArray(videos) && videos.length) {
        await replaceRecipeVideos(recipe.id, videos);
      }

      await recomputeRecipeMacros(recipe.id, finalServings);

      const detail = await fetchRecipeDetail(recipe.id);
      return json(detail, 201);
    } catch (e) {
      return dbErrorResponse(e);
    }
  }

  // ── PUT /recipes/:id ──────────────────────────────────────────────────────────
  if (req.method === "PUT" && id) {
    const existing = await db
      .selectFrom("recipe")
      .select(["id", "author_id", "is_system", "servings"])
      .where("id", "=", id)
      .executeTakeFirst();
    if (!existing) return jsonError("Recipe not found", 404);

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

    try {
      const update: RecipeUpdate = {
        ...(name !== undefined && { name }),
        ...(description !== undefined && { description }),
        ...(servings !== undefined && { servings }),
        ...(prep_time_minutes !== undefined && { prep_time_minutes }),
        ...(cook_time_minutes !== undefined && { cook_time_minutes }),
        ...(is_public !== undefined && { is_public }),
        updated_at: new Date().toISOString(),
      };
      await db.updateTable("recipe").set(update).where("id", "=", id).execute();

      if (Array.isArray(ingredients)) await replaceRecipeIngredients(id, ingredients);
      if (Array.isArray(steps)) await replaceRecipeSteps(id, steps);
      if (Array.isArray(images)) await replaceRecipeImages(id, images);
      if (Array.isArray(videos)) await replaceRecipeVideos(id, videos);

      const finalServings = servings ?? existing.servings;
      if (Array.isArray(ingredients) || servings !== undefined) {
        await recomputeRecipeMacros(id, Number(finalServings));
      }

      const detail = await fetchRecipeDetail(id);
      return json(detail);
    } catch (e) {
      return dbErrorResponse(e);
    }
  }

  // ── DELETE /recipes/:id ────────────────────────────────────────────────────────
  if (req.method === "DELETE" && id) {
    const existing = await db
      .selectFrom("recipe")
      .select(["author_id", "is_system"])
      .where("id", "=", id)
      .executeTakeFirst();
    if (!existing) return jsonError("Recipe not found", 404);

    if (existing.is_system && dbUser?.role !== "super_user") {
      return jsonError("Forbidden", 403);
    }
    if (existing.author_id && existing.author_id !== dbUser?.id && dbUser?.role !== "super_user") {
      return jsonError("Forbidden", 403);
    }

    try {
      await db.deleteFrom("recipe").where("id", "=", id).execute();
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
