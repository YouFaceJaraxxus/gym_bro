import type { Kysely } from "npm:kysely@^0.27";
import { db } from "./config.ts";
import { type Caller, coachesUser } from "./auth.ts";
import type { Database, MealSlotType } from "../../types/schema/public.ts";

// ── Columns ───────────────────────────────────────────────────────────────────

export const FOOD_ITEM_COLS = [
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

export const RECIPE_COLS = [
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

// ── Macro math ────────────────────────────────────────────────────────────────

export type Macros = { kcal: number; protein: number; carb: number; fat: number; fiber: number };

type Num = string | number | null | undefined;

export function round2(n: number): number {
  return Math.round(n * 100) / 100;
}

export function emptyMacros(): Macros {
  return { kcal: 0, protein: 0, carb: 0, fat: 0, fiber: 0 };
}

export function addMacros(a: Macros, b: Macros): Macros {
  return {
    kcal: a.kcal + b.kcal,
    protein: a.protein + b.protein,
    carb: a.carb + b.carb,
    fat: a.fat + b.fat,
    fiber: a.fiber + b.fiber,
  };
}

export function roundMacros(m: Macros): Macros {
  return {
    kcal: round2(m.kcal),
    protein: round2(m.protein),
    carb: round2(m.carb),
    fat: round2(m.fat),
    fiber: round2(m.fiber),
  };
}

/** Macros for `amount` g/ml of a food item (values are stored per 100). */
export function foodItemMacros(
  item: { kcal_per_100: Num; protein_per_100: Num; carb_per_100: Num; fat_per_100: Num; fiber_per_100: Num },
  amount: number,
): Macros {
  const f = amount / 100;
  return {
    kcal: Number(item.kcal_per_100 ?? 0) * f,
    protein: Number(item.protein_per_100 ?? 0) * f,
    carb: Number(item.carb_per_100 ?? 0) * f,
    fat: Number(item.fat_per_100 ?? 0) * f,
    fiber: Number(item.fiber_per_100 ?? 0) * f,
  };
}

/** Macros for `servings` servings of a recipe. */
export function recipeMacros(
  recipe: {
    kcal_per_serving: Num;
    protein_per_serving: Num;
    carb_per_serving: Num;
    fat_per_serving: Num;
    fiber_per_serving: Num;
  },
  servings: number,
): Macros {
  return {
    kcal: Number(recipe.kcal_per_serving ?? 0) * servings,
    protein: Number(recipe.protein_per_serving ?? 0) * servings,
    carb: Number(recipe.carb_per_serving ?? 0) * servings,
    fat: Number(recipe.fat_per_serving ?? 0) * servings,
    fiber: Number(recipe.fiber_per_serving ?? 0) * servings,
  };
}

// ── Recompute (always call inside a transaction) ─────────────────────────────
// Never trust client-supplied macros: recipe per-serving values and daily plan
// totals are always derived from the current food_item macros.

/** Recomputes a recipe's per-serving macros from its ingredients. */
export async function recomputeRecipeMacros(trx: Kysely<Database>, recipeId: string, servings?: number) {
  let s = servings;
  if (s === undefined) {
    const row = await trx.selectFrom("recipe").select("servings").where("id", "=", recipeId).executeTakeFirst();
    if (!row) return;
    s = Number(row.servings);
  }

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

  let total = emptyMacros();
  for (const r of rows) total = addMacros(total, foodItemMacros(r, Number(r.quantity)));

  const div = s > 0 ? s : 1;
  await trx
    .updateTable("recipe")
    .set({
      kcal_per_serving: round2(total.kcal / div),
      protein_per_serving: round2(total.protein / div),
      carb_per_serving: round2(total.carb / div),
      fat_per_serving: round2(total.fat / div),
      fiber_per_serving: round2(total.fiber / div),
    })
    .where("id", "=", recipeId)
    .execute();
}

/** Recomputes a daily meal plan's totals from its slot entries. */
export async function recomputeDailyMealPlanTotals(trx: Kysely<Database>, planId: string) {
  const entries = await trx
    .selectFrom("daily_meal_plan_slot_entry")
    .innerJoin("daily_meal_plan_slot", "daily_meal_plan_slot.id", "daily_meal_plan_slot_entry.daily_meal_plan_slot_id")
    .leftJoin("food_item", "food_item.id", "daily_meal_plan_slot_entry.food_item_id")
    .leftJoin("recipe", "recipe.id", "daily_meal_plan_slot_entry.recipe_id")
    .select([
      "daily_meal_plan_slot_entry.food_item_id as food_item_id",
      "daily_meal_plan_slot_entry.recipe_id as recipe_id",
      "daily_meal_plan_slot_entry.quantity as quantity",
      "daily_meal_plan_slot_entry.servings as servings",
      "food_item.kcal_per_100 as kcal_per_100",
      "food_item.protein_per_100 as protein_per_100",
      "food_item.carb_per_100 as carb_per_100",
      "food_item.fat_per_100 as fat_per_100",
      "food_item.fiber_per_100 as fiber_per_100",
      "recipe.kcal_per_serving as kcal_per_serving",
      "recipe.protein_per_serving as protein_per_serving",
      "recipe.carb_per_serving as carb_per_serving",
      "recipe.fat_per_serving as fat_per_serving",
      "recipe.fiber_per_serving as fiber_per_serving",
    ])
    .where("daily_meal_plan_slot.daily_meal_plan_id", "=", planId)
    .execute();

  let total = emptyMacros();
  for (const e of entries) {
    if (e.food_item_id && e.kcal_per_100 !== null) {
      total = addMacros(total, foodItemMacros(e, Number(e.quantity ?? 0)));
    } else if (e.recipe_id && e.kcal_per_serving !== null) {
      total = addMacros(total, recipeMacros(e, Number(e.servings ?? 1)));
    }
  }

  const t = roundMacros(total);
  await trx
    .updateTable("daily_meal_plan")
    .set({
      kcal_total: t.kcal,
      protein_total: t.protein,
      carb_total: t.carb,
      fat_total: t.fat,
      fiber_total: t.fiber,
      updated_at: new Date().toISOString(),
    })
    .where("id", "=", planId)
    .execute();
}

/** Daily meal plans with an entry pointing at any of these recipes. */
async function dailyPlansUsingRecipes(trx: Kysely<Database>, recipeIds: string[]): Promise<string[]> {
  if (!recipeIds.length) return [];
  const rows = await trx
    .selectFrom("daily_meal_plan_slot_entry")
    .innerJoin("daily_meal_plan_slot", "daily_meal_plan_slot.id", "daily_meal_plan_slot_entry.daily_meal_plan_slot_id")
    .select("daily_meal_plan_slot.daily_meal_plan_id as id")
    .where("daily_meal_plan_slot_entry.recipe_id", "in", recipeIds)
    .execute();
  return rows.map((r) => r.id);
}

/**
 * A recipe's macros changed: recompute every daily meal plan that uses it.
 * Call after recomputeRecipeMacros, inside the same transaction.
 */
export async function recomputeAfterRecipeChange(trx: Kysely<Database>, recipeId: string) {
  const planIds = [...new Set(await dailyPlansUsingRecipes(trx, [recipeId]))];
  for (const planId of planIds) await recomputeDailyMealPlanTotals(trx, planId);
}

/**
 * A food item's macros changed: recompute every recipe using it, then every
 * daily meal plan using it directly or through one of those recipes.
 */
export async function recomputeAfterFoodItemChange(trx: Kysely<Database>, foodItemId: string) {
  const recipeRows = await trx
    .selectFrom("recipe_ingredient")
    .select("recipe_id")
    .where("food_item_id", "=", foodItemId)
    .execute();
  const recipeIds = [...new Set(recipeRows.map((r) => r.recipe_id))];
  for (const recipeId of recipeIds) await recomputeRecipeMacros(trx, recipeId);

  const direct = await trx
    .selectFrom("daily_meal_plan_slot_entry")
    .innerJoin("daily_meal_plan_slot", "daily_meal_plan_slot.id", "daily_meal_plan_slot_entry.daily_meal_plan_slot_id")
    .select("daily_meal_plan_slot.daily_meal_plan_id as id")
    .where("daily_meal_plan_slot_entry.food_item_id", "=", foodItemId)
    .execute();
  const planIds = new Set([...direct.map((r) => r.id), ...(await dailyPlansUsingRecipes(trx, recipeIds))]);
  for (const planId of planIds) await recomputeDailyMealPlanTotals(trx, planId);
}

// ── Assigned-plan access ──────────────────────────────────────────────────────

/**
 * True when the caller was assigned one of these meal plans, or coaches
 * someone who was. Grants read access to private plans and the daily plans,
 * recipes and food items they reference.
 */
export async function callerHasAssignedAccessToMealPlan(
  caller: Caller,
  mealPlanId: string | string[],
): Promise<boolean> {
  const ids = [...new Set(Array.isArray(mealPlanId) ? mealPlanId : [mealPlanId])];
  if (!ids.length) return false;
  const rows = await db
    .selectFrom("meal_plan_assignment")
    .select("user_id")
    .where("meal_plan_id", "in", ids)
    .where("left_at", "is", null) // an ended enrolment no longer grants access
    .execute();
  const targets = [...new Set(rows.map((r) => r.user_id))];
  if (targets.includes(caller.id)) return true;
  for (const target of targets) {
    if (await coachesUser(caller, target)) return true;
  }
  return false;
}

/** Meal plans whose days contain this daily meal plan. */
export async function mealPlansUsingDailyPlan(dailyPlanId: string): Promise<string[]> {
  const rows = await db
    .selectFrom("meal_plan_day")
    .select("meal_plan_id")
    .where("daily_meal_plan_id", "=", dailyPlanId)
    .execute();
  return rows.map((r) => r.meal_plan_id);
}

/** Meal plans whose days contain this recipe. */
export async function mealPlansUsingRecipe(recipeId: string): Promise<string[]> {
  const rows = await db
    .selectFrom("daily_meal_plan_slot_entry")
    .innerJoin("daily_meal_plan_slot", "daily_meal_plan_slot.id", "daily_meal_plan_slot_entry.daily_meal_plan_slot_id")
    .innerJoin("meal_plan_day", "meal_plan_day.daily_meal_plan_id", "daily_meal_plan_slot.daily_meal_plan_id")
    .select("meal_plan_day.meal_plan_id")
    .where("daily_meal_plan_slot_entry.recipe_id", "=", recipeId)
    .execute();
  return rows.map((r) => r.meal_plan_id);
}

/** Meal plans whose days contain this food item, directly or via a recipe. */
export async function mealPlansUsingFoodItem(foodItemId: string): Promise<string[]> {
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

/** Read access to a food item: public, system, own, super, or via an assigned plan. */
export async function canSeeFoodItem(
  caller: Caller,
  item: { id: string; is_public: boolean; is_system: boolean; author_id: string | null },
): Promise<boolean> {
  if (item.is_public || item.is_system || item.author_id === caller.id || caller.role === "super_user") return true;
  return callerHasAssignedAccessToMealPlan(caller, await mealPlansUsingFoodItem(item.id));
}

/** Read access to a recipe: public, system, own, super, or via an assigned plan. */
export async function canSeeRecipe(
  caller: Caller,
  recipe: { id: string; is_public: boolean; is_system: boolean; author_id: string | null },
): Promise<boolean> {
  if (recipe.is_public || recipe.is_system || recipe.author_id === caller.id || caller.role === "super_user") {
    return true;
  }
  return callerHasAssignedAccessToMealPlan(caller, await mealPlansUsingRecipe(recipe.id));
}

// ── Planned meals ─────────────────────────────────────────────────────────────

/** The unit a logged/planned amount is in: g/ml for food items, servings for recipes. */
export type LogUnit = "g" | "ml" | "serving";

export type PlannedEntry = Macros & {
  food_item_id: string | null;
  recipe_id: string | null;
  name: string;
  amount: number;
  unit: LogUnit;
  note: string | null;
};

export type PlannedSlot = { slot_type: MealSlotType; position: number; note: string | null; entries: PlannedEntry[] };

/** A daily meal plan's slots with each entry's name, amount and macros. */
export async function dailyPlanSlots(dailyPlanId: string): Promise<PlannedSlot[]> {
  const slots = await db
    .selectFrom("daily_meal_plan_slot")
    .select(["id", "slot_type", "position", "note"])
    .where("daily_meal_plan_id", "=", dailyPlanId)
    .orderBy("position", "asc")
    .execute();
  const slotIds = slots.map((s) => s.id);
  const entries = slotIds.length
    ? await db
      .selectFrom("daily_meal_plan_slot_entry")
      .select(["id", "daily_meal_plan_slot_id", "food_item_id", "recipe_id", "quantity", "servings", "note"])
      .where("daily_meal_plan_slot_id", "in", slotIds)
      .orderBy("position", "asc")
      .execute()
    : [];

  const foodIds = [...new Set(entries.flatMap((e) => (e.food_item_id ? [e.food_item_id] : [])))];
  const recipeIds = [...new Set(entries.flatMap((e) => (e.recipe_id ? [e.recipe_id] : [])))];
  const foods = foodIds.length
    ? await db.selectFrom("food_item").select(FOOD_ITEM_COLS).where("id", "in", foodIds).execute()
    : [];
  const recipes = recipeIds.length
    ? await db.selectFrom("recipe").select(RECIPE_COLS).where("id", "in", recipeIds).execute()
    : [];
  const foodMap = new Map(foods.map((f) => [f.id, f]));
  const recipeMap = new Map(recipes.map((r) => [r.id, r]));

  const planned: PlannedSlot[] = slots.map((s) => ({
    slot_type: s.slot_type,
    position: s.position,
    note: s.note,
    entries: entries
      .filter((e) => e.daily_meal_plan_slot_id === s.id)
      .flatMap((e): PlannedEntry[] => {
        const food = e.food_item_id ? foodMap.get(e.food_item_id) : undefined;
        if (food) {
          const amount = Number(e.quantity ?? 0);
          if (amount <= 0) return [];
          return [{
            food_item_id: food.id,
            recipe_id: null,
            name: food.brand ? `${food.name} (${food.brand})` : food.name,
            amount,
            unit: food.serving_unit,
            note: e.note,
            ...roundMacros(foodItemMacros(food, amount)),
          }];
        }
        const recipe = e.recipe_id ? recipeMap.get(e.recipe_id) : undefined;
        if (recipe) {
          const amount = Number(e.servings ?? 1);
          if (amount <= 0) return [];
          return [{
            food_item_id: null,
            recipe_id: recipe.id,
            name: recipe.name,
            amount,
            unit: "serving",
            note: e.note,
            ...roundMacros(recipeMacros(recipe, amount)),
          }];
        }
        return [];
      }),
  }));
  return planned;
}
