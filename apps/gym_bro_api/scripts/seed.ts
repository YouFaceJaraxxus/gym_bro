// seed.ts — Populates the local dev database with realistic demo content.
//
// Runs OUTSIDE the edge runtime (plain `deno run` on the host), so it talks to
// Postgres/Auth directly rather than through `host.docker.internal`. Safe to
// re-run: every insert is guarded by a "does this already exist by name/email"
// lookup, so it never touches rows it didn't create and never duplicates on a
// second run.
//
// Usage (with local Supabase already running via `supabase start`):
//   cd apps/gym_bro_api
//   export SUPABASE_SERVICE_ROLE_KEY="$(supabase status -o env | grep '^SERVICE_ROLE_KEY=' | cut -d'"' -f2)"
//   deno run --allow-net --allow-env --allow-read scripts/seed.ts
//
// Note: .env.local's SUPABASE_SERVICE_ROLE_KEY is pulled from Doppler and may
// not match this local instance's actual JWT secret (it's only used by the
// edge runtime for POSTGRES_URL/SUPER_ADMIN_PASS — see config.toml — so this
// mismatch doesn't affect the app itself, only standalone scripts like this
// one). Always source the key from `supabase status` instead.

import { Kysely, PostgresDialect } from "npm:kysely@^0.27";
import pg from "npm:pg@^8";
import { createClient } from "jsr:@supabase/supabase-js@2";
import type {
  Database,
  DailyMealPlanSlotEntryInsert,
  DrinkSubtype,
  FoodItemInsert,
  FoodSubtype,
  MealSlotType,
  MuscleGroup,
  RepType,
  SpiceSubtype,
  TrainingSetDropInsert,
  TrainingSetExerciseInsert,
  TrainingSetInsert,
  UserRole,
  WorkoutSetType,
} from "../supabase/types/schema/public.ts";

const { Pool } = pg;

const POSTGRES_URL = "postgresql://postgres:postgres@127.0.0.1:54322/postgres";
const SUPABASE_URL = "http://127.0.0.1:54321";
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
if (!SERVICE_ROLE_KEY) {
  throw new Error(
    "SUPABASE_SERVICE_ROLE_KEY is not set — run `set -a; source .env.local; set +a` first.",
  );
}

const db = new Kysely<Database>({
  dialect: new PostgresDialect({ pool: new Pool({ connectionString: POSTGRES_URL }) }),
});

const supabaseAdmin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
  auth: { persistSession: false, autoRefreshToken: false },
});

const SEED_PASSWORD = "GymBroSeed123!";

// ── Image helpers ─────────────────────────────────────────────────────────────
// Deterministic placeholder images — no upload pipeline needed for seed data,
// just stable URLs in the same TEXT columns the app already renders from.

const avatarUrl = (seed: string) =>
  `https://api.dicebear.com/9.x/avataaars/png?seed=${encodeURIComponent(seed)}&size=256`;
const photoUrl = (seed: string, w = 800, h = 600) =>
  `https://picsum.photos/seed/${encodeURIComponent(seed)}/${w}/${h}`;

// ── Seed data ─────────────────────────────────────────────────────────────────

const dataPath = new URL("./seed_data.json", import.meta.url);
const seedData = JSON.parse(await Deno.readTextFile(dataPath));

type SeedBusiness = {
  name: string;
  location: string;
  type: "gym" | "shop";
  working_hours_from: string;
  working_hours_to: string;
  working_weekdays: number[];
  logo_image_key: string;
};
type SeedPersona = {
  username: string;
  email: string;
  first_name: string;
  last_name: string;
  role: UserRole;
  avatar_key: string;
};
type SeedExercise = {
  name: string;
  description: string;
  note: string | null;
  primary_muscles: MuscleGroup[];
  secondary_muscles: MuscleGroup[];
};
type SeedTrainingSet = {
  exercise_name: string;
  type: WorkoutSetType;
  position: number;
  sets_count: number;
  rep_range: string;
  rest_seconds: number;
};
type SeedTraining = { name: string; description: string; sets: SeedTrainingSet[] };
type SeedRoutine = {
  name: string;
  description: string;
  schedule_type: "fixed_weeks" | "wildcard";
  num_weeks: number;
  training_names: string[];
};
type SeedFoodItem = {
  name: string;
  brand: string | null;
  type: "food" | "spice" | "drink";
  food_subtype: FoodSubtype | null;
  drink_subtype: DrinkSubtype | null;
  spice_subtype: SpiceSubtype | null;
  serving_unit: "g" | "ml";
  kcal_per_100: number;
  protein_per_100: number;
  carb_per_100: number;
  fat_per_100: number;
  fiber_per_100: number;
};
type SeedRecipe = {
  name: string;
  description: string;
  servings: number;
  prep_time_minutes: number;
  cook_time_minutes: number;
  ingredients: { food_item_name: string; quantity_g_or_ml: number; note: string | null }[];
  steps: string[];
};
type SeedDailyMealPlan = {
  name: string;
  description: string;
  slots: {
    slot_type: MealSlotType;
    entries: {
      source: "food_item" | "recipe";
      name: string;
      quantity_g_or_ml?: number;
      servings?: number;
    }[];
  }[];
};
type SeedMealPlan = {
  name: string;
  description: string;
  num_weeks: number;
  days: { week_number: number; day_of_week: number; daily_meal_plan_name: string }[];
};
type SeedShopProduct = {
  name: string;
  description: string;
  type: "equipment" | "supplement" | "gift_card";
  price: number;
  quantity: number;
};
type SeedPost = { author_persona_username: string; content: string; has_image: boolean };

const businesses: SeedBusiness[] = seedData.businesses;
const personas: SeedPersona[] = seedData.personas;
const exercises: SeedExercise[] = seedData.exercises;
const trainings: SeedTraining[] = seedData.trainings;
const routines: SeedRoutine[] = seedData.routines;
const foodItems: SeedFoodItem[] = seedData.food_items;
const recipes: SeedRecipe[] = seedData.recipes;
const dailyMealPlans: SeedDailyMealPlan[] = seedData.daily_meal_plans;
const mealPlans: SeedMealPlan[] = seedData.meal_plans;
const shopProducts: SeedShopProduct[] = seedData.shop_products;
const posts: SeedPost[] = seedData.posts;

// ── 1. Businesses ─────────────────────────────────────────────────────────────

const businessIdByName = new Map<string, string>();
const businessTypeByName = new Map<string, "gym" | "shop">();

for (const b of businesses) {
  const existing = await db.selectFrom("business").select(["id"]).where("name", "=", b.name).executeTakeFirst();
  let id: string;
  if (existing) {
    id = existing.id;
    console.log(`= business "${b.name}" already exists`);
  } else {
    const row = await db
      .insertInto("business")
      .values({
        name: b.name,
        location: b.location,
        logo: photoUrl(b.logo_image_key, 800, 400),
        working_hours_from: b.working_hours_from,
        working_hours_to: b.working_hours_to,
        working_weekdays: b.working_weekdays,
        type: b.type,
      })
      .returning(["id"])
      .executeTakeFirstOrThrow();
    id = row.id;
    if (b.type === "gym") await db.insertInto("gym").values({ id }).execute();
    else await db.insertInto("shop").values({ id }).execute();
    console.log(`+ business "${b.name}" (${b.type})`);
  }
  businessIdByName.set(b.name, id);
  businessTypeByName.set(b.name, b.type);
}

const gymName = businesses.find((b) => b.type === "gym")!.name;
const shopName = businesses.find((b) => b.type === "shop")!.name;
const gymId = businessIdByName.get(gymName)!;
const shopId = businessIdByName.get(shopName)!;

// ── 2. Personas (auth users + profile rows + role-join rows) ─────────────────

const userIdByUsername = new Map<string, string>();

for (const p of personas) {
  const existingProfile = await db
    .selectFrom("users")
    .select(["id"])
    .where("email", "=", p.email)
    .executeTakeFirst();

  let userId: string;
  if (existingProfile) {
    userId = existingProfile.id;
    console.log(`= user "${p.username}" already exists`);
  } else {
    let authUserId: string;
    const { data, error } = await supabaseAdmin.auth.admin.createUser({
      email: p.email,
      password: SEED_PASSWORD,
      email_confirm: true,
      user_metadata: { username: p.username, name: p.first_name, last_name: p.last_name },
    });
    if (data.user) {
      authUserId = data.user.id;
    } else if (error?.message.includes("already been registered")) {
      // Left over from a partial run (e.g. auth user created but the profile
      // insert failed afterward) — reuse the existing auth user instead.
      const { data: list, error: listErr } = await supabaseAdmin.auth.admin.listUsers();
      if (listErr) throw new Error(`Failed to list auth users: ${listErr.message}`);
      const found = list.users.find((u) => u.email === p.email);
      if (!found) throw new Error(`Auth said "${p.email}" is registered but it wasn't found in listUsers()`);
      authUserId = found.id;
    } else {
      throw new Error(`Failed to create auth user ${p.email}: ${error?.message}`);
    }

    const row = await db
      .insertInto("users")
      .values({
        username: p.username,
        email: p.email,
        name: p.first_name,
        last_name: p.last_name,
        role: p.role,
        avatar_url: avatarUrl(p.avatar_key),
        auth_id: authUserId,
      })
      .returning(["id"])
      .executeTakeFirstOrThrow();
    userId = row.id;
    console.log(`+ user "${p.username}" (${p.role})`);
  }
  userIdByUsername.set(p.username, userId);

  // Role-join rows (idempotent: only insert if not already present).
  const roleTable = {
    trainer: "trainer" as const,
    member: "member" as const,
    employee: "employee" as const,
    employee_trainer: "employee_trainer" as const,
  }[p.role as "trainer" | "member" | "employee" | "employee_trainer"];

  if (roleTable) {
    const exists = await db
      .selectFrom(roleTable)
      .select("id")
      .where("user_id", "=", userId)
      .where("gym_id", "=", gymId)
      .executeTakeFirst();
    if (!exists) await db.insertInto(roleTable).values({ user_id: userId, gym_id: gymId }).execute();
  } else if (p.role === "owner") {
    const gymOwnerExists = await db
      .selectFrom("gym_owner")
      .select("id")
      .where("user_id", "=", userId)
      .where("gym_id", "=", gymId)
      .executeTakeFirst();
    if (!gymOwnerExists) await db.insertInto("gym_owner").values({ user_id: userId, gym_id: gymId }).execute();

    const shopOwnerExists = await db
      .selectFrom("shop_owner")
      .select("id")
      .where("user_id", "=", userId)
      .where("shop_id", "=", shopId)
      .executeTakeFirst();
    if (!shopOwnerExists) await db.insertInto("shop_owner").values({ user_id: userId, shop_id: shopId }).execute();
  } else if (p.role === "shop_vendor") {
    const exists = await db
      .selectFrom("shop_vendor")
      .select("id")
      .where("user_id", "=", userId)
      .where("shop_id", "=", shopId)
      .executeTakeFirst();
    if (!exists) await db.insertInto("shop_vendor").values({ user_id: userId, shop_id: shopId }).execute();
  }
}

const trainerUsername = personas.find((p) => p.role === "trainer")!.username;
const ownerUsername = personas.find((p) => p.role === "owner")!.username;
const trainerId = userIdByUsername.get(trainerUsername)!;
const ownerId = userIdByUsername.get(ownerUsername)!;
const memberUsernames = personas.filter((p) => p.role === "member").map((p) => p.username);

// ── 3. Exercises ──────────────────────────────────────────────────────────────

const exerciseIdByName = new Map<string, string>();

for (const ex of exercises) {
  const existing = await db.selectFrom("exercise").select(["id"]).where("name", "=", ex.name).executeTakeFirst();
  if (existing) {
    exerciseIdByName.set(ex.name, existing.id);
    continue;
  }
  const row = await db
    .insertInto("exercise")
    .values({
      name: ex.name,
      description: ex.description,
      note: ex.note,
      image_url: photoUrl(`exercise-${ex.name}`, 800, 600),
      video_url: null,
      author_id: trainerId,
      primary_muscles: ex.primary_muscles,
      secondary_muscles: ex.secondary_muscles,
      is_public: true,
    })
    .returning(["id"])
    .executeTakeFirstOrThrow();
  exerciseIdByName.set(ex.name, row.id);
  console.log(`+ exercise "${ex.name}"`);
}

// ── 4. Trainings ──────────────────────────────────────────────────────────────

function repCountFromRange(range: string): number {
  const [lo, hi] = range.split("-").map((n) => parseInt(n, 10));
  if (Number.isNaN(hi)) return lo;
  return Math.round((lo + hi) / 2);
}

const trainingIdByName = new Map<string, string>();

for (const t of trainings) {
  const existing = await db.selectFrom("training").select(["id"]).where("name", "=", t.name).executeTakeFirst();
  if (existing) {
    trainingIdByName.set(t.name, existing.id);
    continue;
  }

  const training = await db
    .insertInto("training")
    .values({ name: t.name, description: t.description, notes: null, author_id: trainerId, is_public: true })
    .returning(["id"])
    .executeTakeFirstOrThrow();
  trainingIdByName.set(t.name, training.id);

  await db
    .insertInto("training_image")
    .values({ training_id: training.id, url: photoUrl(`training-${t.name}`, 800, 450), is_thumbnail: true, position: 0 })
    .execute();

  // Group set entries by position — entries sharing a position form one
  // training_set with multiple exercise slots (e.g. a superset pairing).
  const byPosition = new Map<number, SeedTrainingSet[]>();
  for (const s of t.sets) {
    (byPosition.get(s.position) ?? byPosition.set(s.position, []).get(s.position)!).push(s);
  }

  for (const [position, group] of [...byPosition.entries()].sort((a, b) => a[0] - b[0])) {
    const setInsert: TrainingSetInsert = {
      training_id: training.id,
      type: group[0].type,
      position,
      rest_seconds: group[0].rest_seconds,
      note: null,
    };
    const trainingSet = await db.insertInto("training_set").values(setInsert).returning(["id"]).executeTakeFirstOrThrow();

    for (const [i, s] of group.entries()) {
      const exerciseId = exerciseIdByName.get(s.exercise_name);
      if (!exerciseId) {
        console.warn(`  ! unknown exercise "${s.exercise_name}" referenced by training "${t.name}" — skipping`);
        continue;
      }
      const exInsert: TrainingSetExerciseInsert = {
        training_set_id: trainingSet.id,
        exercise_id: exerciseId,
        position: i,
        is_alternating: false,
        rest_between_drops_seconds: null,
        note: null,
      };
      const setExercise = await db
        .insertInto("training_set_exercise")
        .values(exInsert)
        .returning(["id"])
        .executeTakeFirstOrThrow();

      const repCount = repCountFromRange(s.rep_range);
      const dropInserts: TrainingSetDropInsert[] = Array.from({ length: s.sets_count }, (_, dropNumber) => ({
        training_set_exercise_id: setExercise.id,
        drop_number: dropNumber,
        rep_type: "count" as RepType,
        rep_count: repCount,
        weight_kg: null,
        side: "both",
        note: null,
      }));
      await db.insertInto("training_set_drop").values(dropInserts).execute();
    }
  }
  console.log(`+ training "${t.name}"`);
}

// ── 5. Routines ────────────────────────────────────────────────────────────────

for (const r of routines) {
  const existing = await db.selectFrom("routine").select(["id"]).where("name", "=", r.name).executeTakeFirst();
  if (existing) continue;

  const routine = await db
    .insertInto("routine")
    .values({
      name: r.name,
      description: r.description,
      notes: null,
      author_id: trainerId,
      is_public: true,
      schedule_type: r.schedule_type,
      num_weeks: r.num_weeks,
    })
    .returning(["id"])
    .executeTakeFirstOrThrow();

  await db
    .insertInto("routine_image")
    .values({ routine_id: routine.id, url: photoUrl(`routine-${r.name}`, 800, 450), is_thumbnail: true, position: 0 })
    .execute();

  for (let week = 1; week <= r.num_weeks; week++) {
    for (const [i, trainingName] of r.training_names.entries()) {
      const trainingId = trainingIdByName.get(trainingName);
      if (!trainingId) {
        console.warn(`  ! unknown training "${trainingName}" referenced by routine "${r.name}" — skipping`);
        continue;
      }
      await db
        .insertInto("routine_training")
        .values({
          routine_id: routine.id,
          training_id: trainingId,
          week_number: week,
          day_of_week: (i % 7) + 1,
          position: i,
          note: null,
        })
        .execute();
    }
  }
  console.log(`+ routine "${r.name}"`);
}

// ── 6. Food items ──────────────────────────────────────────────────────────────

const foodItemIdByName = new Map<string, string>();
const foodItemMacrosByName = new Map<string, SeedFoodItem>();

for (const f of foodItems) {
  foodItemMacrosByName.set(f.name, f);
  const existing = await db.selectFrom("food_item").select(["id"]).where("name", "=", f.name).executeTakeFirst();
  if (existing) {
    foodItemIdByName.set(f.name, existing.id);
    continue;
  }
  const insert: FoodItemInsert = {
    name: f.name,
    brand: f.brand,
    barcode: null,
    type: f.type,
    food_subtype: f.food_subtype,
    drink_subtype: f.drink_subtype,
    spice_subtype: f.spice_subtype,
    serving_unit: f.serving_unit,
    kcal_per_100: f.kcal_per_100,
    protein_per_100: f.protein_per_100,
    carb_per_100: f.carb_per_100,
    fat_per_100: f.fat_per_100,
    fiber_per_100: f.fiber_per_100,
    author_id: null,
    is_public: true,
    is_system: true,
  };
  const row = await db.insertInto("food_item").values(insert).returning(["id"]).executeTakeFirstOrThrow();
  foodItemIdByName.set(f.name, row.id);
  console.log(`+ food item "${f.name}"`);
}

// ── 7. Recipes ─────────────────────────────────────────────────────────────────

type RecipeMacros = { kcal: number; protein: number; carb: number; fat: number; fiber: number };
const recipeIdByName = new Map<string, string>();
const recipeMacrosPerServingByName = new Map<string, RecipeMacros>();

for (const r of recipes) {
  const existing = await db.selectFrom("recipe").select(["id"]).where("name", "=", r.name).executeTakeFirst();
  if (existing) {
    recipeIdByName.set(r.name, existing.id);
    // Recompute macros from ingredients so downstream daily-meal-plan totals
    // still work correctly even when the recipe already existed.
  }

  const totals = { kcal: 0, protein: 0, carb: 0, fat: 0, fiber: 0 };
  for (const ing of r.ingredients) {
    const macros = foodItemMacrosByName.get(ing.food_item_name);
    if (!macros) {
      console.warn(`  ! unknown food item "${ing.food_item_name}" referenced by recipe "${r.name}" — skipping ingredient`);
      continue;
    }
    const factor = ing.quantity_g_or_ml / 100;
    totals.kcal += macros.kcal_per_100 * factor;
    totals.protein += macros.protein_per_100 * factor;
    totals.carb += macros.carb_per_100 * factor;
    totals.fat += macros.fat_per_100 * factor;
    totals.fiber += macros.fiber_per_100 * factor;
  }
  const perServing: RecipeMacros = {
    kcal: totals.kcal / r.servings,
    protein: totals.protein / r.servings,
    carb: totals.carb / r.servings,
    fat: totals.fat / r.servings,
    fiber: totals.fiber / r.servings,
  };
  recipeMacrosPerServingByName.set(r.name, perServing);

  if (existing) continue;

  const recipe = await db
    .insertInto("recipe")
    .values({
      name: r.name,
      description: r.description,
      author_id: trainerId,
      servings: r.servings,
      prep_time_minutes: r.prep_time_minutes,
      cook_time_minutes: r.cook_time_minutes,
      kcal_per_serving: perServing.kcal,
      protein_per_serving: perServing.protein,
      carb_per_serving: perServing.carb,
      fat_per_serving: perServing.fat,
      fiber_per_serving: perServing.fiber,
      is_public: true,
      is_system: false,
    })
    .returning(["id"])
    .executeTakeFirstOrThrow();
  recipeIdByName.set(r.name, recipe.id);

  for (const [i, ing] of r.ingredients.entries()) {
    const foodItemId = foodItemIdByName.get(ing.food_item_name);
    if (!foodItemId) continue;
    await db
      .insertInto("recipe_ingredient")
      .values({
        recipe_id: recipe.id,
        food_item_id: foodItemId,
        quantity: ing.quantity_g_or_ml,
        note: ing.note,
        position: i,
      })
      .execute();
  }

  for (const [i, step] of r.steps.entries()) {
    await db
      .insertInto("recipe_step")
      .values({ recipe_id: recipe.id, position: i, instruction: step, image_url: null })
      .execute();
  }

  await db
    .insertInto("recipe_image")
    .values({ recipe_id: recipe.id, url: photoUrl(`recipe-${r.name}`, 800, 600), is_thumbnail: true, position: 0 })
    .execute();

  console.log(`+ recipe "${r.name}"`);
}

// ── 8. Daily meal plans ──────────────────────────────────────────────────────

const dailyMealPlanIdByName = new Map<string, string>();

for (const d of dailyMealPlans) {
  const existing = await db.selectFrom("daily_meal_plan").select(["id"]).where("name", "=", d.name).executeTakeFirst();
  if (existing) {
    dailyMealPlanIdByName.set(d.name, existing.id);
    continue;
  }

  const totals = { kcal: 0, protein: 0, carb: 0, fat: 0, fiber: 0 };
  const resolvedSlots = d.slots.map((slot) => ({
    ...slot,
    entries: slot.entries.map((entry) => {
      if (entry.source === "food_item") {
        const macros = foodItemMacrosByName.get(entry.name);
        const qty = entry.quantity_g_or_ml ?? 0;
        if (macros) {
          const factor = qty / 100;
          totals.kcal += macros.kcal_per_100 * factor;
          totals.protein += macros.protein_per_100 * factor;
          totals.carb += macros.carb_per_100 * factor;
          totals.fat += macros.fat_per_100 * factor;
          totals.fiber += macros.fiber_per_100 * factor;
        }
        return { ...entry, foodItemId: foodItemIdByName.get(entry.name) };
      } else {
        const macros = recipeMacrosPerServingByName.get(entry.name);
        const servings = entry.servings ?? 1;
        if (macros) {
          totals.kcal += macros.kcal * servings;
          totals.protein += macros.protein * servings;
          totals.carb += macros.carb * servings;
          totals.fat += macros.fat * servings;
          totals.fiber += macros.fiber * servings;
        }
        return { ...entry, recipeId: recipeIdByName.get(entry.name) };
      }
    }),
  }));

  const plan = await db
    .insertInto("daily_meal_plan")
    .values({
      name: d.name,
      description: d.description,
      author_id: trainerId,
      is_public: true,
      is_system: false,
      kcal_total: totals.kcal,
      protein_total: totals.protein,
      carb_total: totals.carb,
      fat_total: totals.fat,
      fiber_total: totals.fiber,
    })
    .returning(["id"])
    .executeTakeFirstOrThrow();
  dailyMealPlanIdByName.set(d.name, plan.id);

  for (const [slotIndex, slot] of resolvedSlots.entries()) {
    const slotRow = await db
      .insertInto("daily_meal_plan_slot")
      .values({ daily_meal_plan_id: plan.id, slot_type: slot.slot_type, position: slotIndex, note: null })
      .returning(["id"])
      .executeTakeFirstOrThrow();

    for (const [entryIndex, entry] of slot.entries.entries()) {
      const isFood = "foodItemId" in entry;
      if (isFood && !entry.foodItemId) continue;
      if (!isFood && !("recipeId" in entry && entry.recipeId)) continue;

      const insert: DailyMealPlanSlotEntryInsert = {
        daily_meal_plan_slot_id: slotRow.id,
        food_item_id: isFood ? (entry as { foodItemId?: string }).foodItemId ?? null : null,
        recipe_id: !isFood ? (entry as { recipeId?: string }).recipeId ?? null : null,
        quantity: isFood ? entry.quantity_g_or_ml ?? null : null,
        servings: !isFood ? entry.servings ?? 1 : null,
        position: entryIndex,
        note: null,
      };
      await db.insertInto("daily_meal_plan_slot_entry").values(insert).execute();
    }
  }
  console.log(`+ daily meal plan "${d.name}"`);
}

// ── 9. Meal plans ─────────────────────────────────────────────────────────────

const mealPlanIdByName = new Map<string, string>();

for (const m of mealPlans) {
  const existing = await db.selectFrom("meal_plan").select(["id"]).where("name", "=", m.name).executeTakeFirst();
  if (existing) {
    mealPlanIdByName.set(m.name, existing.id);
    continue;
  }

  const plan = await db
    .insertInto("meal_plan")
    .values({
      name: m.name,
      description: m.description,
      author_id: trainerId,
      is_public: true,
      is_system: false,
      num_weeks: m.num_weeks,
    })
    .returning(["id"])
    .executeTakeFirstOrThrow();
  mealPlanIdByName.set(m.name, plan.id);

  await db
    .insertInto("meal_plan_image")
    .values({ meal_plan_id: plan.id, url: photoUrl(`mealplan-${m.name}`, 800, 600), is_thumbnail: true, position: 0 })
    .execute();

  for (const day of m.days) {
    const dailyId = dailyMealPlanIdByName.get(day.daily_meal_plan_name);
    if (!dailyId) {
      console.warn(`  ! unknown daily meal plan "${day.daily_meal_plan_name}" referenced by "${m.name}" — skipping day`);
      continue;
    }
    await db
      .insertInto("meal_plan_day")
      .values({
        meal_plan_id: plan.id,
        daily_meal_plan_id: dailyId,
        week_number: day.week_number,
        day_of_week: day.day_of_week,
        note: null,
      })
      .execute();
  }
  console.log(`+ meal plan "${m.name}"`);
}

// Assign each meal plan to a couple of members for realism.
for (const [i, m] of mealPlans.entries()) {
  const planId = mealPlanIdByName.get(m.name);
  if (!planId) continue;
  const assignee = memberUsernames[i % memberUsernames.length];
  const assigneeId = userIdByUsername.get(assignee);
  if (!assigneeId) continue;
  const existing = await db
    .selectFrom("meal_plan_assignment")
    .select("id")
    .where("meal_plan_id", "=", planId)
    .where("user_id", "=", assigneeId)
    .executeTakeFirst();
  if (existing) continue;
  await db
    .insertInto("meal_plan_assignment")
    .values({
      meal_plan_id: planId,
      user_id: assigneeId,
      assigned_by_id: trainerId,
      start_date: new Date().toISOString().substring(0, 10),
      end_date: null,
      note: null,
    })
    .execute();
  console.log(`+ assigned "${m.name}" to ${assignee}`);
}

// ── 10. Shop products ─────────────────────────────────────────────────────────

for (const p of shopProducts) {
  const existing = await db
    .selectFrom("shop_item")
    .select(["id"])
    .where("shop_id", "=", shopId)
    .where("name", "=", p.name)
    .executeTakeFirst();
  if (existing) continue;
  await db
    .insertInto("shop_item")
    .values({
      shop_id: shopId,
      type: p.type,
      name: p.name,
      description: p.description,
      price: p.price,
      quantity: p.quantity,
      is_active: true,
      active_until: null,
      image_url: photoUrl(`product-${p.name}`, 800, 800),
    })
    .execute();
  console.log(`+ shop product "${p.name}"`);
}

// ── 11. Posts ──────────────────────────────────────────────────────────────────

const personaByUsername = new Map(personas.map((p) => [p.username, p]));

function businessIdForAuthor(username: string): string {
  const role = personaByUsername.get(username)?.role;
  return role === "shop_vendor" ? shopId : gymId;
}

for (const p of posts) {
  const existing = await db
    .selectFrom("post")
    .select(["id"])
    .where("content", "=", p.content)
    .executeTakeFirst();
  if (existing) continue;

  const authorId = userIdByUsername.get(p.author_persona_username);
  if (!authorId) {
    console.warn(`  ! unknown persona "${p.author_persona_username}" referenced by a post — skipping`);
    continue;
  }

  const post = await db
    .insertInto("post")
    .values({ business_id: businessIdForAuthor(p.author_persona_username), author_id: authorId, content: p.content })
    .returning(["id"])
    .executeTakeFirstOrThrow();

  if (p.has_image) {
    await db
      .insertInto("post_image")
      .values({ post_id: post.id, url: photoUrl(`post-${post.id}`, 1000, 600), position: 0 })
      .execute();
  }
  console.log(`+ post by ${p.author_persona_username}`);
}

// ── 12. Membership types + a few active memberships ───────────────────────────

const membershipTypeDefs = [
  { name: "Basic", monthly_cost: 29.99 },
  { name: "Premium", monthly_cost: 59.99 },
  { name: "Elite", monthly_cost: 99.99 },
];
const membershipTypeIdByName = new Map<string, string>();

for (const t of membershipTypeDefs) {
  const existing = await db
    .selectFrom("gym_membership_type")
    .select(["id"])
    .where("gym_id", "=", gymId)
    .where("name", "=", t.name)
    .executeTakeFirst();
  if (existing) {
    membershipTypeIdByName.set(t.name, existing.id);
    continue;
  }
  const row = await db
    .insertInto("gym_membership_type")
    .values({ name: t.name, monthly_cost: t.monthly_cost, gym_id: gymId, is_active: true })
    .returning(["id"])
    .executeTakeFirstOrThrow();
  membershipTypeIdByName.set(t.name, row.id);
  console.log(`+ membership type "${t.name}"`);
}

const typeNames = [...membershipTypeIdByName.keys()];
for (const [i, username] of memberUsernames.entries()) {
  const userId = userIdByUsername.get(username)!;
  const existing = await db.selectFrom("membership").select(["id"]).where("user_id", "=", userId).executeTakeFirst();
  if (existing) continue;

  const typeName = typeNames[i % typeNames.length];
  const typeId = membershipTypeIdByName.get(typeName)!;
  const from = new Date();
  from.setMonth(from.getMonth() - 1);
  const to = new Date();
  to.setMonth(to.getMonth() + 2);

  const membership = await db
    .insertInto("membership")
    .values({
      user_id: userId,
      current_membership_type_id: typeId,
      from_date: from.toISOString().substring(0, 10),
      to_date: to.toISOString().substring(0, 10),
      is_active: true,
    })
    .returning(["id"])
    .executeTakeFirstOrThrow();

  const monthlyCost = membershipTypeDefs.find((t) => t.name === typeName)!.monthly_cost;
  await db
    .insertInto("membership_invoice")
    .values({ membership_id: membership.id, membership_type_id: typeId, amount: monthlyCost * 3 })
    .execute();

  console.log(`+ membership for ${username} (${typeName})`);
}

await db.destroy();
console.log("\nSeed complete.");
