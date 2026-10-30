import { sql } from "npm:kysely@^0.27";
import { db } from "./config.ts";
import { type Caller, isSuperUser, jsonError } from "./auth.ts";
import { userDropRows } from "./progress.ts";
import { canSeeFoodItem, canSeeRecipe } from "./nutrition.ts";
import type { MealSlotType, PostType } from "../../types/schema/public.ts";

// What a typed post shares. The server builds the attachment from the source
// when posting — a snapshot, so the post keeps showing what was shared even
// if the source is later edited, deleted or private to the viewer:
//
//   workout          { title, training_id, started_at, ended_at, duration_minutes,
//                      exercise_count, set_count, volume_kg, exercises: [{ id, name,
//                      sets, best_weight_kg, best_reps }] }  (top 6 exercises)
//   meal             { title (null), log_date, slot_type, eaten_at, items: [{ name,
//                      amount, unit, kcal }], totals: { kcal, protein, carb, fat, fiber } }
//   exercise         { title, description, image_url, primary_muscles, secondary_muscles }
//   training         { title, description, image_url, exercise_count, set_count }
//   routine          { title, description, image_url, schedule_type, num_weeks, training_count }
//   recipe           { title, description, image_url, servings, kcal_per_serving,
//                      protein_per_serving, carb_per_serving, fat_per_serving }
//   food_item        { title, brand, serving_unit, kcal_per_100, protein_per_100,
//                      carb_per_100, fat_per_100 }
//   daily_meal_plan  { title, description, kcal_total, protein_total, carb_total, fat_total }
//   meal_plan        { title, description, image_url, num_weeks, days_planned }
//
// A logged workout or meal can only be shared once it has happened.

export const POST_TYPES: readonly PostType[] = [
  "generic", "workout", "meal", "exercise", "training", "routine",
  "recipe", "food_item", "daily_meal_plan", "meal_plan",
];

const SLOT_TYPES: readonly MealSlotType[] = [
  "breakfast", "morning_snack", "lunch", "afternoon_snack", "dinner", "evening_snack", "pre_workout", "post_workout",
];

type Built = { ref_id: string | null; attachment: Record<string, unknown> };

const num = (v: unknown) => (v == null ? null : Number(v));
const notFound = (what: string) => jsonError(`${what} not found`, 404);
const notYet = () =>
  jsonError("You can share this once it has happened", 400, { code: "future_activity" });

/** Public, the caller's own, or anything for super users. */
const visible = (caller: Caller, row: { is_public: boolean; author_id: string | null }) =>
  row.is_public || row.author_id === caller.id || isSuperUser(caller);

/**
 * The ref_id and attachment for a post of [type] sharing [body.ref_id]
 * (or [body.meal] = { log_date, slot_type } for a meal); a Response on error.
 * [opts.trusted] skips the library visibility check, for a caller whose
 * access was already established another way (see _shared/shares.ts).
 */
export async function buildAttachment(
  caller: Caller,
  type: PostType,
  body: { ref_id?: unknown; meal?: unknown },
  opts: { trusted?: boolean } = {},
): Promise<Built | Response> {
  const ok = (allowed: boolean) => opts.trusted || allowed;
  const refId = typeof body.ref_id === "string" ? body.ref_id : null;
  if (type !== "meal" && !refId) return jsonError("ref_id is required for this post type", 400);
  try {
    switch (type) {
      case "workout":
        return await workout(caller, refId!);
      case "meal":
        return await meal(caller, body.meal);
      case "exercise": {
        const x = await db.selectFrom("exercise")
          .select(["id", "name", "description", "image_url", "primary_muscles", "secondary_muscles", "is_public", "author_id"])
          .where("id", "=", refId!).executeTakeFirst();
        if (!x || !ok(visible(caller, x))) return notFound("Exercise");
        return {
          ref_id: x.id,
          attachment: {
            title: x.name,
            description: x.description,
            image_url: x.image_url,
            primary_muscles: x.primary_muscles,
            secondary_muscles: x.secondary_muscles,
          },
        };
      }
      case "training": {
        const t = await db.selectFrom("training").select(["id", "name", "description", "is_public", "author_id"])
          .where("id", "=", refId!).executeTakeFirst();
        if (!t || !ok(visible(caller, t))) return notFound("Workout");
        const { rows: [c] } = await sql<{ exercise_count: number; set_count: number }>`
          SELECT count(DISTINCT tse.exercise_id)::int AS exercise_count, count(DISTINCT ts.id)::int AS set_count
            FROM training_set ts LEFT JOIN training_set_exercise tse ON tse.training_set_id = ts.id
           WHERE ts.training_id = ${t.id}`.execute(db);
        return {
          ref_id: t.id,
          attachment: {
            title: t.name,
            description: t.description,
            image_url: await thumbnail("training_image", "training_id", t.id),
            exercise_count: c?.exercise_count ?? 0,
            set_count: c?.set_count ?? 0,
          },
        };
      }
      case "routine": {
        const r = await db.selectFrom("routine")
          .select(["id", "name", "description", "is_public", "author_id", "schedule_type", "num_weeks"])
          .where("id", "=", refId!).executeTakeFirst();
        if (!r || !ok(visible(caller, r))) return notFound("Routine");
        const { rows: [c] } = await sql<{ n: number }>`
          SELECT count(DISTINCT training_id)::int AS n FROM routine_training WHERE routine_id = ${r.id}`.execute(db);
        return {
          ref_id: r.id,
          attachment: {
            title: r.name,
            description: r.description,
            image_url: await thumbnail("routine_image", "routine_id", r.id),
            schedule_type: r.schedule_type,
            num_weeks: r.num_weeks,
            training_count: c?.n ?? 0,
          },
        };
      }
      case "recipe": {
        const r = await db.selectFrom("recipe")
          .select(["id", "name", "description", "is_public", "is_system", "author_id", "servings",
            "kcal_per_serving", "protein_per_serving", "carb_per_serving", "fat_per_serving"])
          .where("id", "=", refId!).executeTakeFirst();
        if (!r || !(opts.trusted || await canSeeRecipe(caller, r))) return notFound("Recipe");
        const img = await db.selectFrom("recipe_image").select("url").where("recipe_id", "=", r.id)
          .orderBy("position").executeTakeFirst();
        return {
          ref_id: r.id,
          attachment: {
            title: r.name,
            description: r.description,
            image_url: img?.url ?? null,
            servings: r.servings,
            kcal_per_serving: num(r.kcal_per_serving),
            protein_per_serving: num(r.protein_per_serving),
            carb_per_serving: num(r.carb_per_serving),
            fat_per_serving: num(r.fat_per_serving),
          },
        };
      }
      case "food_item": {
        const f = await db.selectFrom("food_item")
          .select(["id", "name", "brand", "is_public", "is_system", "author_id", "serving_unit",
            "kcal_per_100", "protein_per_100", "carb_per_100", "fat_per_100"])
          .where("id", "=", refId!).executeTakeFirst();
        if (!f || !(opts.trusted || await canSeeFoodItem(caller, f))) return notFound("Food item");
        return {
          ref_id: f.id,
          attachment: {
            title: f.name,
            brand: f.brand,
            serving_unit: f.serving_unit,
            kcal_per_100: num(f.kcal_per_100),
            protein_per_100: num(f.protein_per_100),
            carb_per_100: num(f.carb_per_100),
            fat_per_100: num(f.fat_per_100),
          },
        };
      }
      case "daily_meal_plan": {
        const d = await db.selectFrom("daily_meal_plan")
          .select(["id", "name", "description", "is_public", "is_system", "author_id",
            "kcal_total", "protein_total", "carb_total", "fat_total"])
          .where("id", "=", refId!).executeTakeFirst();
        if (!d || !ok(d.is_system || visible(caller, d))) return notFound("Day plan");
        return {
          ref_id: d.id,
          attachment: {
            title: d.name,
            description: d.description,
            kcal_total: num(d.kcal_total),
            protein_total: num(d.protein_total),
            carb_total: num(d.carb_total),
            fat_total: num(d.fat_total),
          },
        };
      }
      case "meal_plan": {
        const m = await db.selectFrom("meal_plan")
          .select(["id", "name", "description", "is_public", "is_system", "author_id", "num_weeks"])
          .where("id", "=", refId!).executeTakeFirst();
        if (!m || !ok(m.is_system || visible(caller, m))) return notFound("Meal plan");
        const { rows: [c] } = await sql<{ n: number }>`
          SELECT count(*)::int AS n FROM meal_plan_day WHERE meal_plan_id = ${m.id}`.execute(db);
        return {
          ref_id: m.id,
          attachment: {
            title: m.name,
            description: m.description,
            image_url: await thumbnail("meal_plan_image", "meal_plan_id", m.id),
            num_weeks: m.num_weeks,
            days_planned: c?.n ?? 0,
          },
        };
      }
      default:
        return jsonError(`type must be one of: ${POST_TYPES.join(", ")}`, 400);
    }
  } catch (e) {
    if ((e as { code?: string })?.code === "22P02") return jsonError("ref_id must be a UUID", 400);
    throw e;
  }
}

async function thumbnail(
  table: "training_image" | "routine_image" | "meal_plan_image",
  fk: "training_id" | "routine_id" | "meal_plan_id",
  id: string,
): Promise<string | null> {
  const { rows: [row] } = await sql<{ url: string }>`
    SELECT url FROM ${sql.table(table)} WHERE ${sql.ref(fk)} = ${id}
     ORDER BY is_thumbnail DESC, position LIMIT 1`.execute(db);
  return row?.url ?? null;
}

async function workout(caller: Caller, sessionId: string): Promise<Built | Response> {
  const s = await db.selectFrom("training_session")
    .leftJoin("training", "training.id", "training_session.training_id")
    .select(["training_session.id", "training_session.user_id", "training_session.training_id",
      "training_session.started_at", "training_session.ended_at", "training.name as training_name"])
    .where("training_session.id", "=", sessionId).executeTakeFirst();
  if (!s || s.user_id !== caller.id) return notFound("Workout");
  const started = new Date(s.started_at);
  if (started.getTime() > Date.now()) return notYet();
  const ended = s.ended_at ? new Date(s.ended_at) : null;

  const { rows } = await sql<{
    exercise_id: string | null;
    name: string | null;
    sets: number;
    volume_kg: number;
    best_weight_kg: number | null;
    best_reps: number | null;
  }>`
    WITH d AS (${userDropRows(caller.id)})
    SELECT d.exercise_id, x.name,
           count(DISTINCT d.set_log_id)::int AS sets,
           COALESCE(sum(d.volume_kg), 0)::float8 AS volume_kg,
           (array_agg(d.weight_kg::float8 ORDER BY d.e1rm DESC NULLS LAST, d.weight_kg DESC NULLS LAST))[1] AS best_weight_kg,
           (array_agg(d.reps ORDER BY d.e1rm DESC NULLS LAST, d.weight_kg DESC NULLS LAST))[1] AS best_reps
      FROM d LEFT JOIN exercise x ON x.id = d.exercise_id
     WHERE d.session_id = ${s.id}
     GROUP BY d.exercise_id, x.name
     ORDER BY min(d.started_at), sets DESC
  `.execute(db);
  const { rows: [counts] } = await sql<{ set_count: number }>`
    SELECT count(*)::int AS set_count FROM session_set_log WHERE session_id = ${s.id}`.execute(db);

  return {
    ref_id: s.id,
    attachment: {
      title: s.training_name,
      training_id: s.training_id,
      started_at: started.toISOString(),
      ended_at: ended?.toISOString() ?? null,
      duration_minutes: ended ? Math.max(0, Math.round((ended.getTime() - started.getTime()) / 60_000)) : null,
      exercise_count: rows.filter((r) => r.exercise_id).length,
      set_count: counts?.set_count ?? 0,
      volume_kg: Math.round(rows.reduce((a, r) => a + Number(r.volume_kg), 0)),
      exercises: rows.filter((r) => r.exercise_id).slice(0, 6).map((r) => ({
        id: r.exercise_id,
        name: r.name,
        sets: r.sets,
        best_weight_kg: r.best_weight_kg,
        best_reps: r.best_reps,
      })),
    },
  };
}

async function meal(caller: Caller, raw: unknown): Promise<Built | Response> {
  const m = (raw ?? {}) as { log_date?: unknown; slot_type?: unknown };
  if (typeof m.log_date !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(m.log_date)) {
    return jsonError("meal.log_date must be YYYY-MM-DD", 400);
  }
  if (!SLOT_TYPES.includes(m.slot_type as MealSlotType)) return jsonError("meal.slot_type is invalid", 400);
  const logs = await db.selectFrom("food_log")
    .leftJoin("food_item", "food_item.id", "food_log.food_item_id")
    .select(["food_log.name", "food_log.amount", "food_log.kcal", "food_log.protein", "food_log.carb",
      "food_log.fat", "food_log.fiber", "food_log.eaten_at", "food_log.recipe_id",
      sql<string>`COALESCE(food_item.serving_unit::text, 'g')`.as("food_unit"),
      sql<boolean>`food_log.log_date <= (now() + INTERVAL '14 hours')::date`.as("date_ok")])
    .where("food_log.user_id", "=", caller.id)
    .where("food_log.log_date", "=", m.log_date)
    .where("food_log.slot_type", "=", m.slot_type as MealSlotType)
    .orderBy("food_log.created_at").execute();
  if (!logs.length) return notFound("Meal");
  // eaten_at decides when set; otherwise the date must not be ahead of anyone's today.
  const eaten = logs.map((l) => (l.eaten_at ? new Date(l.eaten_at).getTime() : null));
  if (eaten.some((t) => t !== null && t > Date.now()) || logs.some((l, i) => eaten[i] === null && !l.date_ok)) {
    return notYet();
  }
  const total = (k: "kcal" | "protein" | "carb" | "fat" | "fiber") =>
    Math.round(logs.reduce((a, l) => a + Number(l[k]), 0) * 10) / 10;
  const firstEaten = eaten.filter((t): t is number => t !== null).sort()[0];
  return {
    ref_id: null,
    attachment: {
      title: null,
      log_date: m.log_date,
      slot_type: m.slot_type,
      eaten_at: firstEaten ? new Date(firstEaten).toISOString() : null,
      items: logs.slice(0, 12).map((l) => ({
        name: l.name,
        amount: Number(l.amount),
        unit: l.recipe_id ? "serving" : l.food_unit,
        kcal: Math.round(Number(l.kcal)),
      })),
      item_count: logs.length,
      totals: { kcal: total("kcal"), protein: total("protein"), carb: total("carb"), fat: total("fat"), fiber: total("fiber") },
    },
  };
}
