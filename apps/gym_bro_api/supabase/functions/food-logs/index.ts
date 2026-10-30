import { type Insertable, type Kysely, sql } from "npm:kysely@^0.27";
import { db } from "../_shared/config.ts";
import {
  type Caller,
  coachesUser,
  forbidden,
  isSuperUser,
  json,
  jsonError,
  requireCaller,
} from "../_shared/auth.ts";
import {
  addMacros,
  canSeeFoodItem,
  canSeeRecipe,
  dailyPlanSlots,
  emptyMacros,
  foodItemMacros,
  FOOD_ITEM_COLS,
  type LogUnit,
  type Macros,
  type PlannedSlot,
  RECIPE_COLS,
  recipeMacros,
  roundMacros,
} from "../_shared/nutrition.ts";
import type { Database, FoodLogTable, MealSlotType } from "../../types/schema/public.ts";

// The generated Numeric columns don't accept plain numbers on insert; the
// snapshot values are numbers, so inserts go through this alias.
type FoodLogInsert = Insertable<FoodLogTable>;

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

const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;
const MAX_RANGE_DAYS = 92;


// ── Path parsing ──────────────────────────────────────────────────────────────

function parseId(pathname: string): string | null {
  const match = pathname.match(/^\/food-logs\/([^/]+)$/);
  return match && match[1] !== "summary" && match[1] !== "from-plan" ? match[1] : null;
}

function isValidDate(v: unknown): v is string {
  return typeof v === "string" && DATE_RE.test(v) && !Number.isNaN(Date.parse(`${v}T00:00:00Z`));
}

function todayUtc(): string {
  return new Date().toISOString().slice(0, 10);
}

/** eaten_at from a body: undefined when absent, null to clear, or an ISO string. */
function parseEatenAt(v: unknown): string | null | undefined | Response {
  if (v === undefined) return undefined;
  if (v === null) return null;
  const d = typeof v === "string" ? new Date(v) : null;
  if (!d || Number.isNaN(d.getTime())) return jsonError("eaten_at must be an ISO timestamp", 400);
  return d.toISOString();
}

/** A planned meal of the caller's, or an error response. */
async function ownMealPlanEntry(caller: Caller, id: unknown) {
  if (typeof id !== "string") return jsonError("plan_entry_id must be a string", 400);
  const entry = await db.selectFrom("plan_entry")
    .select(["id", "user_id", "kind", "daily_meal_plan_id", "meal_slot", "starts_at",
      sql<string>`to_char(plan_date, 'YYYY-MM-DD')`.as("plan_date")])
    .where("id", "=", id).executeTakeFirst().catch(() => undefined);
  if (!entry || entry.user_id !== caller.id) return jsonError("Planned meal not found", 404);
  if (entry.kind !== "meal") return jsonError("That plan entry isn't a meal", 400);
  return entry;
}

// ── Access ────────────────────────────────────────────────────────────────────

/** Reads: self, super, or anyone who coaches the user. */
async function resolveReadTarget(caller: Caller, userIdParam: string | null): Promise<string | Response> {
  const userId = userIdParam || caller.id;
  if (userId === caller.id || isSuperUser(caller) || (await coachesUser(caller, userId))) return userId;
  return forbidden("You can only view your own food diary or one of a member you coach");
}

// ── Row shaping ───────────────────────────────────────────────────────────────

/** food_log rows with log_date as YYYY-MM-DD and the unit the amount is in. */
function logQuery(executor: Kysely<Database> = db) {
  return executor
    .selectFrom("food_log")
    .leftJoin("food_item", "food_item.id", "food_log.food_item_id")
    .select([
      "food_log.id as id",
      "food_log.user_id as user_id",
      sql<string>`to_char(food_log.log_date, 'YYYY-MM-DD')`.as("log_date"),
      "food_log.slot_type as slot_type",
      "food_log.food_item_id as food_item_id",
      "food_log.recipe_id as recipe_id",
      "food_log.name as name",
      "food_log.amount as amount",
      sql<LogUnit>`CASE WHEN food_log.recipe_id IS NOT NULL THEN 'serving'
        ELSE COALESCE(food_item.serving_unit::text, 'g') END`.as("unit"),
      "food_log.kcal as kcal",
      "food_log.protein as protein",
      "food_log.carb as carb",
      "food_log.fat as fat",
      "food_log.fiber as fiber",
      "food_log.note as note",
      "food_log.eaten_at as eaten_at",
      "food_log.plan_entry_id as plan_entry_id",
      "food_log.created_at as created_at",
    ]);
}

async function fetchLog(id: string, executor: Kysely<Database> = db) {
  return await logQuery(executor).where("food_log.id", "=", id).executeTakeFirst();
}

// ── Snapshot (server-computed name + macros) ─────────────────────────────────

type Snapshot = Macros & { name: string; food_item_id: string | null; recipe_id: string | null };

/**
 * Resolves the item and computes name + macros for `amount`
 * (g/ml for food items, servings for recipes). Checks visibility.
 */
async function buildSnapshot(
  caller: Caller,
  foodItemId: string | null,
  recipeId: string | null,
  amount: number,
): Promise<{ snapshot: Snapshot; response?: never } | { snapshot?: never; response: Response }> {
  if (foodItemId) {
    const item = await db.selectFrom("food_item").select(FOOD_ITEM_COLS).where("id", "=", foodItemId)
      .executeTakeFirst();
    if (!item || !(await canSeeFoodItem(caller, item))) return { response: jsonError("Food item not found", 404) };
    const name = item.brand ? `${item.name} (${item.brand})` : item.name;
    return {
      snapshot: { name, food_item_id: item.id, recipe_id: null, ...roundMacros(foodItemMacros(item, amount)) },
    };
  }
  if (recipeId) {
    const recipe = await db.selectFrom("recipe").select(RECIPE_COLS).where("id", "=", recipeId).executeTakeFirst();
    if (!recipe || !(await canSeeRecipe(caller, recipe))) return { response: jsonError("Recipe not found", 404) };
    return {
      snapshot: {
        name: recipe.name,
        food_item_id: null,
        recipe_id: recipe.id,
        ...roundMacros(recipeMacros(recipe, amount)),
      },
    };
  }
  return { response: jsonError("food_item_id or recipe_id is required", 400) };
}

// ── Planned day ───────────────────────────────────────────────────────────────
// The meal plan assignment active on `date` (start_date defaults to the day it
// was created). meal_plan_day.day_of_week is the ISO weekday (1 = Monday, as
// the app labels plan days), so day_of_week = ISODOW(date) and week_number
// counts calendar weeks (Monday-based) since the start week, mod num_weeks.

/** The planned meals of one plan entry's day plan (an edited entry may use another). */
async function planEntryDay(planEntryId: string) {
  const entry = await db.selectFrom("plan_entry").select(["daily_meal_plan_id"]).where("id", "=", planEntryId)
    .executeTakeFirst();
  if (!entry?.daily_meal_plan_id) return null;
  return { planned: await dailyPlanSlots(entry.daily_meal_plan_id) };
}

async function plannedDay(userId: string, date: string) {
  const assignment = await sql<{
    assignment_id: string;
    meal_plan_id: string;
    meal_plan_name: string;
    num_weeks: number;
    start_date: string;
    weeks_since: number;
    iso_dow: number;
  }>`
    SELECT a.id AS assignment_id, a.meal_plan_id, mp.name AS meal_plan_name, mp.num_weeks,
           to_char(COALESCE(a.start_date, a.created_at::date), 'YYYY-MM-DD') AS start_date,
           ((date_trunc('week', ${date}::date)::date
             - date_trunc('week', COALESCE(a.start_date, a.created_at::date))::date) / 7) AS weeks_since,
           EXTRACT(ISODOW FROM ${date}::date)::int AS iso_dow
      FROM meal_plan_assignment a
      JOIN meal_plan mp ON mp.id = a.meal_plan_id
     WHERE a.user_id = ${userId}
       AND COALESCE(a.start_date, a.created_at::date) <= ${date}::date
       AND (a.end_date IS NULL OR a.end_date >= ${date}::date)
     ORDER BY COALESCE(a.start_date, a.created_at::date) DESC, a.created_at DESC
     LIMIT 1
  `.execute(db);

  const a = assignment.rows[0];
  if (!a) return null;

  const weekNumber = (Number(a.weeks_since) % Math.max(1, Number(a.num_weeks))) + 1;
  const dayOfWeek = Number(a.iso_dow);

  const day = await db
    .selectFrom("meal_plan_day")
    .innerJoin("daily_meal_plan", "daily_meal_plan.id", "meal_plan_day.daily_meal_plan_id")
    .select([
      "daily_meal_plan.id as id",
      "daily_meal_plan.name as name",
      "daily_meal_plan.kcal_total as kcal_total",
      "daily_meal_plan.protein_total as protein_total",
      "daily_meal_plan.carb_total as carb_total",
      "daily_meal_plan.fat_total as fat_total",
      "daily_meal_plan.fiber_total as fiber_total",
    ])
    .where("meal_plan_day.meal_plan_id", "=", a.meal_plan_id)
    .where("meal_plan_day.week_number", "=", weekNumber)
    .where("meal_plan_day.day_of_week", "=", dayOfWeek)
    .executeTakeFirst();

  const plan = {
    assignment_id: a.assignment_id,
    meal_plan_id: a.meal_plan_id,
    meal_plan_name: a.meal_plan_name,
    start_date: a.start_date,
    week_number: weekNumber,
    day_of_week: dayOfWeek,
    daily_meal_plan_id: day?.id ?? null,
    daily_meal_plan_name: day?.name ?? null,
  };
  if (!day) return { plan, targets: null, planned: [] as PlannedSlot[] };

  const targets: Macros = {
    kcal: Number(day.kcal_total),
    protein: Number(day.protein_total),
    carb: Number(day.carb_total),
    fat: Number(day.fat_total),
    fiber: Number(day.fiber_total),
  };

  const planned = await dailyPlanSlots(day.id);

  return { plan, targets: roundMacros(targets), planned };
}

// ── Postgres error mapping ────────────────────────────────────────────────────

function pgErrorResponse(e: unknown): Response {
  const err = e as { code?: string; message?: string; detail?: string } | null;
  switch (err?.code) {
    case "23505":
      return jsonError("Already exists", 409, { detail: err.detail });
    case "23503":
      return jsonError("Referenced food item or recipe does not exist", 400, { detail: err.detail });
    case "23502":
    case "23514":
    case "22P02":
    case "22007":
    case "22008":
    case "22003":
      return jsonError(err.message ?? "Invalid value", 400);
  }
  throw e;
}

// ── Handler ───────────────────────────────────────────────────────────────────

async function handler(req: Request): Promise<Response> {
  const url = new URL(req.url);
  const path = url.pathname.replace(/\/+$/, "");
  const id = parseId(path);

  const { caller, response } = await requireCaller(req);
  if (!caller) return response;

  // ── GET /food-logs/summary?date=&user_id= ─────────────────────────────────────
  if (req.method === "GET" && path === "/food-logs/summary") {
    const date = url.searchParams.get("date") ?? todayUtc();
    if (!isValidDate(date)) return jsonError("date must be YYYY-MM-DD", 400);
    const userId = await resolveReadTarget(caller, url.searchParams.get("user_id"));
    if (userId instanceof Response) return userId;

    const rows = await db
      .selectFrom("food_log")
      .select(["slot_type", "kcal", "protein", "carb", "fat", "fiber"])
      .where("user_id", "=", userId)
      .where("log_date", "=", date)
      .execute();

    const bySlot = new Map<MealSlotType, Macros & { count: number }>();
    let totals = emptyMacros();
    for (const r of rows) {
      const m: Macros = {
        kcal: Number(r.kcal),
        protein: Number(r.protein),
        carb: Number(r.carb),
        fat: Number(r.fat),
        fiber: Number(r.fiber),
      };
      totals = addMacros(totals, m);
      const prev = bySlot.get(r.slot_type) ?? { ...emptyMacros(), count: 0 };
      bySlot.set(r.slot_type, { ...addMacros(prev, m), count: prev.count + 1 });
    }
    const slots = VALID_SLOT_TYPES.filter((s) => bySlot.has(s)).map((s) => {
      const v = bySlot.get(s)!;
      return { slot_type: s, count: v.count, ...roundMacros(v) };
    });

    const planned = await plannedDay(userId, date);
    return json({
      date,
      user_id: userId,
      totals: roundMacros(totals),
      slots,
      targets: planned?.targets ?? null,
      plan: planned?.plan ?? null,
      planned: planned?.planned ?? [],
    });
  }

  // ── GET /food-logs?date= | ?from=&to= (+ user_id) ─────────────────────────────
  if (req.method === "GET" && path === "/food-logs") {
    const date = url.searchParams.get("date");
    const from = url.searchParams.get("from") ?? date ?? todayUtc();
    const to = url.searchParams.get("to") ?? date ?? from;
    if (!isValidDate(from) || !isValidDate(to)) return jsonError("Dates must be YYYY-MM-DD", 400);
    if (to < from) return jsonError("to must be on or after from", 400);
    const spanDays = (Date.parse(`${to}T00:00:00Z`) - Date.parse(`${from}T00:00:00Z`)) / 86_400_000;
    if (spanDays > MAX_RANGE_DAYS) return jsonError(`Range can't exceed ${MAX_RANGE_DAYS} days`, 400);

    const userId = await resolveReadTarget(caller, url.searchParams.get("user_id"));
    if (userId instanceof Response) return userId;

    const rows = await logQuery()
      .where("food_log.user_id", "=", userId)
      .where("food_log.log_date", ">=", from)
      .where("food_log.log_date", "<=", to)
      .orderBy("food_log.log_date", "asc")
      .orderBy("food_log.slot_type", "asc") // enum order = declaration order
      .orderBy("food_log.created_at", "asc")
      .execute();
    return json(rows);
  }

  // ── POST /food-logs/from-plan {date, slot_type?, eaten_at?} ───────────────────
  // With plan_entry_id instead, logs that planned meal (its date and slot)
  // and links the logs to it, which marks it done.
  if (req.method === "POST" && path === "/food-logs/from-plan") {
    const body = await req.json().catch(() => null);
    const eatenAt = parseEatenAt(body?.eaten_at);
    if (eatenAt instanceof Response) return eatenAt;
    let date = body?.date ?? todayUtc();
    let slotType = body?.slot_type ?? null;
    let planEntryId: string | null = null;
    if (body?.plan_entry_id != null) {
      const entry = await ownMealPlanEntry(caller, body.plan_entry_id);
      if (entry instanceof Response) return entry;
      date = entry.plan_date;
      slotType = entry.meal_slot;
      planEntryId = entry.id;
    }
    if (!isValidDate(date)) return jsonError("date must be YYYY-MM-DD", 400);
    if (slotType !== null && !VALID_SLOT_TYPES.includes(slotType)) {
      return jsonError(`slot_type must be one of: ${VALID_SLOT_TYPES.join(", ")}`, 400);
    }

    const planned = planEntryId ? await planEntryDay(planEntryId) : await plannedDay(caller.id, date);
    const slots = (planned?.planned ?? []).filter((s) => slotType === null || s.slot_type === slotType);
    // Stagger created_at so the diary keeps the plan's entry order.
    const base = Date.now();
    const values = slots.flatMap((s) => s.entries.map((e) => ({ s, e }))).map(({ s, e }, i) => ({
      created_at: new Date(base + i).toISOString(),
      user_id: caller.id,
      log_date: date,
      slot_type: s.slot_type,
      food_item_id: e.food_item_id,
      recipe_id: e.recipe_id,
      name: e.name,
      amount: e.amount,
      kcal: e.kcal,
      protein: e.protein,
      carb: e.carb,
      fat: e.fat,
      fiber: e.fiber,
      note: e.note,
      eaten_at: eatenAt ?? null,
      plan_entry_id: planEntryId,
    }));
    if (!values.length) return jsonError("No planned meals for this date", 404);

    const rows = await db.transaction().execute(async (trx) => {
      const inserted = await trx.insertInto("food_log").values(values as unknown as FoodLogInsert[]).returning("id").execute();
      return await logQuery(trx)
        .where("food_log.id", "in", inserted.map((r) => r.id))
        .orderBy("food_log.slot_type", "asc")
        .orderBy("food_log.created_at", "asc")
        .execute();
    });
    return json(rows, 201);
  }

  // ── POST /food-logs ───────────────────────────────────────────────────────────
  if (req.method === "POST" && path === "/food-logs") {
    const body = await req.json().catch(() => null);
    const { log_date, slot_type, food_item_id, recipe_id, amount, note } = body ?? {};
    const date = log_date ?? todayUtc();
    const eatenAt = parseEatenAt(body?.eaten_at);
    if (eatenAt instanceof Response) return eatenAt;
    let planEntryId: string | null = null;
    if (body?.plan_entry_id != null) {
      const entry = await ownMealPlanEntry(caller, body.plan_entry_id);
      if (entry instanceof Response) return entry;
      planEntryId = entry.id;
    }

    if (!isValidDate(date)) return jsonError("log_date must be YYYY-MM-DD", 400);
    if (!VALID_SLOT_TYPES.includes(slot_type)) {
      return jsonError(`slot_type must be one of: ${VALID_SLOT_TYPES.join(", ")}`, 400);
    }
    if (!!food_item_id === !!recipe_id) return jsonError("Provide exactly one of food_item_id or recipe_id", 400);
    if (typeof amount !== "number" || !(amount > 0)) return jsonError("amount must be a positive number", 400);

    const snap = await buildSnapshot(caller, food_item_id ?? null, recipe_id ?? null, amount);
    if (!snap.snapshot) return snap.response;

    const row = await db
      .insertInto("food_log")
      .values({
        user_id: caller.id,
        log_date: date,
        slot_type,
        amount,
        note: typeof note === "string" && note.trim() ? note.trim() : null,
        eaten_at: eatenAt ?? null,
        plan_entry_id: planEntryId,
        ...snap.snapshot,
      } as unknown as FoodLogInsert)
      .returning("id")
      .executeTakeFirstOrThrow();
    return json(await fetchLog(row.id), 201);
  }

  // ── PUT /food-logs/:id ────────────────────────────────────────────────────────
  if (req.method === "PUT" && id) {
    const existing = await db
      .selectFrom("food_log")
      .select(["id", "user_id", "food_item_id", "recipe_id", "amount"])
      .where("id", "=", id)
      .executeTakeFirst();
    if (!existing) return jsonError("Food log entry not found", 404);
    if (existing.user_id !== caller.id && !isSuperUser(caller)) return forbidden();

    const body = await req.json().catch(() => null);
    if (!body || Object.keys(body).length === 0) return jsonError("Body must not be empty", 400);

    const update: Record<string, unknown> = {};
    if ("log_date" in body) {
      if (!isValidDate(body.log_date)) return jsonError("log_date must be YYYY-MM-DD", 400);
      update.log_date = body.log_date;
    }
    if ("slot_type" in body) {
      if (!VALID_SLOT_TYPES.includes(body.slot_type)) {
        return jsonError(`slot_type must be one of: ${VALID_SLOT_TYPES.join(", ")}`, 400);
      }
      update.slot_type = body.slot_type;
    }
    if ("note" in body) {
      update.note = typeof body.note === "string" && body.note.trim() ? body.note.trim() : null;
    }
    if ("eaten_at" in body) {
      const eatenAt = parseEatenAt(body.eaten_at);
      if (eatenAt instanceof Response) return eatenAt;
      update.eaten_at = eatenAt;
    }
    if ("amount" in body && (typeof body.amount !== "number" || !(body.amount > 0))) {
      return jsonError("amount must be a positive number", 400);
    }

    const itemChanged = ("food_item_id" in body && body.food_item_id !== existing.food_item_id) ||
      ("recipe_id" in body && body.recipe_id !== existing.recipe_id);
    if (itemChanged || "amount" in body) {
      let foodId = existing.food_item_id;
      let recipeId = existing.recipe_id;
      if (itemChanged) {
        foodId = body.food_item_id ?? null;
        recipeId = body.recipe_id ?? null;
        if (!!foodId === !!recipeId) return jsonError("Provide exactly one of food_item_id or recipe_id", 400);
      }
      if (!foodId && !recipeId) {
        return jsonError("The logged item no longer exists; delete this entry and log it again", 409);
      }
      const amount = "amount" in body ? body.amount : Number(existing.amount);
      const snap = await buildSnapshot(caller, foodId, recipeId, amount);
      if (!snap.snapshot) return snap.response;
      Object.assign(update, snap.snapshot, { amount });
    }

    if (Object.keys(update).length === 0) return jsonError("Nothing to update", 400);
    await db.updateTable("food_log").set(update).where("id", "=", id).execute();
    return json(await fetchLog(id));
  }

  // ── DELETE /food-logs/:id ─────────────────────────────────────────────────────
  if (req.method === "DELETE" && id) {
    const existing = await db.selectFrom("food_log").select(["user_id"]).where("id", "=", id).executeTakeFirst();
    if (!existing) return jsonError("Food log entry not found", 404);
    if (existing.user_id !== caller.id && !isSuperUser(caller)) return forbidden();

    await db.deleteFrom("food_log").where("id", "=", id).execute();
    return new Response(null, { status: 204 });
  }

  return jsonError("Not found", 404);
}

Deno.serve(async (req: Request) => {
  try {
    return await handler(req);
  } catch (e) {
    return pgErrorResponse(e);
  }
});
