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
  TrainingInsert,
  TrainingUpdate,
  TrainingImageInsert,
  TrainingSetInsert,
  TrainingSetExerciseInsert,
  TrainingSetDropInsert,
  WorkoutSetType,
  RepType,
  BodySide,
  MuscleGroup,
  RoutineTrainingInsert,
} from "../../types/schema/public.ts";

const TRAINING_COLS = [
  "id", "name", "description", "notes",
  "author_id", "is_public", "created_at", "updated_at",
] as const;

const IMAGE_COLS = ["id", "training_id", "url", "is_thumbnail", "position"] as const;
const SET_COLS = ["id", "training_id", "type", "position", "rest_seconds", "note"] as const;
const SET_EX_COLS = [
  "id", "training_set_id", "exercise_id", "position",
  "is_alternating", "rest_between_drops_seconds", "note",
] as const;
const DROP_COLS = [
  "id", "training_set_exercise_id", "drop_number",
  "rep_type", "rep_count", "weight_kg", "side", "note",
] as const;

// muscle_group[] isn't parsed by the pg driver (it arrives as "{a,b}"); text[] is.
const EXERCISE_COLS = [
  "id", "name", "description", "note", "image_url", "video_url", "author_id",
  sql<MuscleGroup[]>`primary_muscles::text[]`.as("primary_muscles"),
  sql<MuscleGroup[]>`secondary_muscles::text[]`.as("secondary_muscles"),
  "is_public", "created_at", "updated_at",
] as const;

const VALID_SET_TYPES: WorkoutSetType[] = ["standard", "superset", "dropset", "circuit"];
const VALID_REP_TYPES: RepType[] = ["count", "failure", "unspecified"];
const VALID_SIDES: BodySide[] = ["both", "left", "right"];

// ── Auth ──────────────────────────────────────────────────────────────────────

/** Reads are public; resolve the caller only when a token was sent. */
async function optionalCaller(req: Request): Promise<Caller | null> {
  if (!req.headers.get("Authorization")) return null;
  const { caller } = await requireCaller(req);
  return caller ?? null;
}

/**
 * Public trainings, the author's and super users', plus private ones the
 * caller has logged a session with or has in a routine assigned to them.
 */
async function canReadTraining(
  caller: Caller | null,
  t: { id: string; is_public: boolean; author_id: string | null },
): Promise<boolean> {
  if (t.is_public) return true;
  if (!caller) return false;
  if (isSuperUser(caller) || t.author_id === caller.id) return true;
  const res = await sql<{ ok: boolean }>`
    SELECT EXISTS (
             SELECT 1 FROM training_session
              WHERE training_id = ${t.id} AND user_id = ${caller.id})
        OR EXISTS (
             SELECT 1 FROM routine_training rt
               JOIN routine_assignment ra ON ra.routine_id = rt.routine_id
              WHERE rt.training_id = ${t.id} AND ra.user_id = ${caller.id} AND ra.left_at IS NULL) AS ok
  `.execute(db);
  return res.rows[0]?.ok === true;
}

/**
 * True once any session used the training, directly or through its sets.
 * Its sets are frozen from then on: past set and drop logs point at them.
 */
async function hasSessions(trainingId: string): Promise<boolean> {
  const res = await sql<{ used: boolean }>`
    SELECT EXISTS (SELECT 1 FROM training_session WHERE training_id = ${trainingId})
        OR EXISTS (
             SELECT 1 FROM session_set_log sl
               JOIN training_set s ON s.id = sl.training_set_id
              WHERE s.training_id = ${trainingId}) AS used
  `.execute(db);
  return res.rows[0]?.used === true;
}

// ── Path parsing ──────────────────────────────────────────────────────────────

function parseId(pathname: string): string | null {
  const match = pathname.match(/^\/trainings\/([^/]+)$/);
  return match ? match[1] : null;
}

// ── Nested fetch ──────────────────────────────────────────────────────────────

/**
 * The training with images and nested sets → exercises (each with its
 * `exercise` row) → drops, plus `has_sessions` (sets are frozen when true)
 * and `routine_ids`: which of the caller's own routines include it.
 */
async function fetchTrainingDetail(trainingId: string, caller: Caller | null = null) {
  const training = await db
    .selectFrom("training")
    .select(TRAINING_COLS)
    .where("id", "=", trainingId)
    .executeTakeFirst();

  if (!training) return null;

  const images = await db
    .selectFrom("training_image")
    .select(IMAGE_COLS)
    .where("training_id", "=", trainingId)
    .orderBy("position", "asc")
    .execute();

  const sets = await db
    .selectFrom("training_set")
    .select(SET_COLS)
    .where("training_id", "=", trainingId)
    .orderBy("position", "asc")
    .execute();

  const setIds = sets.map((s) => s.id);
  const exercises = setIds.length
    ? await db
        .selectFrom("training_set_exercise")
        .select(SET_EX_COLS)
        .where("training_set_id", "in", setIds)
        .orderBy("position", "asc")
        .execute()
    : [];

  const exerciseIds = exercises.map((e) => e.id);
  const drops = exerciseIds.length
    ? await db
        .selectFrom("training_set_drop")
        .select(DROP_COLS)
        .where("training_set_exercise_id", "in", exerciseIds)
        .orderBy("drop_number", "asc")
        .execute()
    : [];

  const exerciseRowIds = [...new Set(exercises.map((e) => e.exercise_id))];
  const exerciseRows = exerciseRowIds.length
    ? await db.selectFrom("exercise").select(EXERCISE_COLS).where("id", "in", exerciseRowIds).execute()
    : [];
  const exerciseById = Object.fromEntries(exerciseRows.map((e) => [e.id, e]));

  const routineIds = caller
    ? await db
        .selectFrom("routine_training")
        .innerJoin("routine", "routine.id", "routine_training.routine_id")
        .select("routine_training.routine_id")
        .distinct()
        .where("routine_training.training_id", "=", trainingId)
        .where("routine.author_id", "=", caller.id)
        .execute()
    : [];

  // Nest drops into exercises, exercises into sets
  const dropsByExercise = drops.reduce(
    (acc, d) => {
      (acc[d.training_set_exercise_id] ??= []).push(d);
      return acc;
    },
    {} as Record<string, typeof drops>,
  );

  const exercisesBySet = exercises.reduce(
    (acc, e) => {
      (acc[e.training_set_id] ??= []).push({
        ...e,
        exercise: exerciseById[e.exercise_id] ?? null,
        drops: dropsByExercise[e.id] ?? [],
      });
      return acc;
    },
    {} as Record<string, unknown[]>,
  );

  return {
    ...training,
    has_sessions: await hasSessions(trainingId),
    routine_ids: routineIds.map((r) => r.routine_id),
    images,
    sets: sets.map((s) => ({
      ...s,
      exercises: exercisesBySet[s.id] ?? [],
    })),
  };
}

// ── Upsert nested sets for a training ────────────────────────────────────────
// Deletes all existing sets (cascade) then re-inserts from payload. PUT
// refuses this once the training has sessions (see hasSessions): their set
// and drop logs reference these rows.
// Always call inside a transaction.

async function replaceTrainingSets(
  trx: Kysely<Database>,
  trainingId: string,
  // deno-lint-ignore no-explicit-any
  setsPayload: any[],
) {
  await trx.deleteFrom("training_set").where("training_id", "=", trainingId).execute();

  for (const [si, setData] of setsPayload.entries()) {
    const setType: WorkoutSetType = VALID_SET_TYPES.includes(setData.type)
      ? setData.type
      : "standard";

    const setInsert: TrainingSetInsert = {
      training_id: trainingId,
      type: setType,
      position: setData.position ?? si,
      rest_seconds: setData.rest_seconds ?? null,
      note: setData.note ?? null,
    };

    const newSet = await trx
      .insertInto("training_set")
      .values(setInsert)
      .returning(["id"])
      .executeTakeFirstOrThrow();

    for (const [ei, exData] of (setData.exercises ?? []).entries()) {
      if (!exData.exercise_id) continue;

      const exInsert: TrainingSetExerciseInsert = {
        training_set_id: newSet.id,
        exercise_id: exData.exercise_id,
        position: exData.position ?? ei,
        is_alternating: exData.is_alternating ?? false,
        rest_between_drops_seconds: exData.rest_between_drops_seconds ?? null,
        note: exData.note ?? null,
      };

      const newEx = await trx
        .insertInto("training_set_exercise")
        .values(exInsert)
        .returning(["id"])
        .executeTakeFirstOrThrow();

      for (const [di, dropData] of (exData.drops ?? []).entries()) {
        const repType: RepType = VALID_REP_TYPES.includes(dropData.rep_type)
          ? dropData.rep_type
          : "count";
        const side: BodySide = VALID_SIDES.includes(dropData.side) ? dropData.side : "both";

        const dropInsert: TrainingSetDropInsert = {
          training_set_exercise_id: newEx.id,
          drop_number: dropData.drop_number ?? di,
          rep_type: repType,
          rep_count: dropData.rep_count ?? null,
          weight_kg: dropData.weight_kg ?? null,
          side,
          note: dropData.note ?? null,
        };

        await trx.insertInto("training_set_drop").values(dropInsert).execute();
      }
    }
  }
}

// deno-lint-ignore no-explicit-any
async function replaceTrainingImages(trx: Kysely<Database>, trainingId: string, images: any[]) {
  await trx.deleteFrom("training_image").where("training_id", "=", trainingId).execute();
  const imageInserts: TrainingImageInsert[] = images.map(
    (img: { url: string; is_thumbnail?: boolean; position?: number }, i: number) => ({
      training_id: trainingId,
      url: img.url,
      is_thumbnail: img.is_thumbnail ?? i === 0,
      position: img.position ?? i,
    }),
  );
  if (imageInserts.length) {
    await trx.insertInto("training_image").values(imageInserts).execute();
  }
}

// ── Routine membership ────────────────────────────────────────────────────────
// `routine_ids` on POST/PUT lists the caller's own routines the training should
// be in. Missing ones get it appended (no week/day slot yet, set in the routine
// form); own routines left out lose it. Other authors' routines are untouched.

/** The ids as a deduplicated list when all are the caller's routines; null otherwise. */
async function ownRoutineIds(caller: Caller, raw: unknown): Promise<string[] | null> {
  if (!Array.isArray(raw) || raw.some((r) => typeof r !== "string")) return null;
  const ids = [...new Set(raw as string[])];
  if (!ids.length) return ids;
  const owned = await db
    .selectFrom("routine")
    .select("id")
    .where("id", "in", ids)
    .where("author_id", "=", caller.id)
    .execute();
  return owned.length === ids.length ? ids : null;
}

async function syncRoutines(
  trx: Kysely<Database>,
  caller: Caller,
  trainingId: string,
  routineIds: string[],
) {
  const current = await trx
    .selectFrom("routine_training")
    .innerJoin("routine", "routine.id", "routine_training.routine_id")
    .select("routine_training.routine_id")
    .distinct()
    .where("routine_training.training_id", "=", trainingId)
    .where("routine.author_id", "=", caller.id)
    .execute();
  const have = new Set(current.map((r) => r.routine_id));
  const toRemove = [...have].filter((id) => !routineIds.includes(id));
  const toAdd = routineIds.filter((id) => !have.has(id));

  if (toRemove.length) {
    await trx
      .deleteFrom("routine_training")
      .where("training_id", "=", trainingId)
      .where("routine_id", "in", toRemove)
      .execute();
  }
  for (const routineId of toAdd) {
    const last = await trx
      .selectFrom("routine_training")
      .select(sql<number | null>`MAX(position)`.as("max"))
      .where("routine_id", "=", routineId)
      .executeTakeFirst();
    const insert: RoutineTrainingInsert = {
      routine_id: routineId,
      training_id: trainingId,
      position: (last?.max ?? -1) + 1,
    };
    await trx.insertInto("routine_training").values(insert).execute();
  }
  const changed = [...toRemove, ...toAdd];
  if (changed.length) {
    await trx
      .updateTable("routine")
      .set({ updated_at: new Date().toISOString() })
      .where("id", "in", changed)
      .execute();
  }
}

// ── Log suggestions ───────────────────────────────────────────────────────────
// GET /trainings/suggestions?name=&limit= — what to offer when logging a
// workout, in priority order and without repeats:
//   recent:   trainings of the caller's past sessions, last used first
//             (+ last_used_at)
//   assigned: trainings in routines a coach assigned to the caller that
//             haven't ended (+ routine_name, assigned_by_name)
//   library:  the caller's own and public trainings matching `name`
// Every item is a list row with its thumbnail; `name` filters all three.

async function fetchSuggestions(caller: Caller, name: string | null, limit: number) {
  const like = name ? `%${name}%` : null;

  let recentQuery = db
    .selectFrom("training_session as ts")
    .innerJoin("training as t", "t.id", "ts.training_id")
    .select(["t.id", sql<string>`MAX(ts.started_at)`.as("last_used_at")])
    .where("ts.user_id", "=", caller.id)
    .groupBy("t.id")
    .orderBy(sql`MAX(ts.started_at)`, "desc")
    .limit(limit);
  if (like) recentQuery = recentQuery.where("t.name", "ilike", like);
  const recent = await recentQuery.execute();
  const seen = new Set(recent.map((r) => r.id));

  const assignedRes = await sql<{
    id: string;
    routine_name: string;
    assigned_by_name: string | null;
  }>`
    SELECT id, routine_name, assigned_by_name FROM (
      SELECT DISTINCT ON (t.id)
             t.id,
             r.name AS routine_name,
             NULLIF(TRIM(COALESCE(u.name, '') || ' ' || COALESCE(u.last_name, '')), '') AS assigned_by_name,
             ra.created_at AS assigned_at,
             rt.position
        FROM routine_assignment ra
        JOIN routine r           ON r.id = ra.routine_id
        JOIN routine_training rt ON rt.routine_id = ra.routine_id
        JOIN training t          ON t.id = rt.training_id
        LEFT JOIN users u        ON u.id = ra.assigned_by_id
       WHERE ra.user_id = ${caller.id}
         AND ra.left_at IS NULL
         AND ra.assigned_by_id IS NOT NULL
         AND ra.assigned_by_id <> ${caller.id}
         AND (ra.end_date IS NULL OR ra.end_date >= CURRENT_DATE)
         ${like ? sql`AND t.name ILIKE ${like}` : sql``}
       ORDER BY t.id, ra.created_at DESC, rt.position
    ) x
    ORDER BY assigned_at DESC, position
    LIMIT ${limit + seen.size}
  `.execute(db);
  const assigned = assignedRes.rows.filter((r) => !seen.has(r.id)).slice(0, limit);
  for (const a of assigned) seen.add(a.id);

  let libraryQuery = db
    .selectFrom("training")
    .select("id")
    .where((eb) => eb.or([eb("is_public", "=", true), eb("author_id", "=", caller.id)]))
    .orderBy(sql`author_id = ${caller.id}`, "desc")
    .orderBy("updated_at", "desc")
    .limit(limit);
  if (like) libraryQuery = libraryQuery.where("name", "ilike", like);
  if (seen.size) libraryQuery = libraryQuery.where("id", "not in", [...seen]);
  const library = await libraryQuery.execute();

  const ids = [...seen, ...library.map((l) => l.id)];
  if (!ids.length) return { recent: [], assigned: [], library: [] };
  const [rows, thumbnails] = await Promise.all([
    db.selectFrom("training").select(TRAINING_COLS).where("id", "in", ids).execute(),
    db
      .selectFrom("training_image")
      .select(IMAGE_COLS)
      .where("training_id", "in", ids)
      .where("is_thumbnail", "=", true)
      .execute(),
  ]);
  const thumbMap = Object.fromEntries(thumbnails.map((t) => [t.training_id, t]));
  const rowOf = (id: string) => {
    const row = rows.find((r) => r.id === id);
    return row ? { ...row, thumbnail: thumbMap[id] ?? null } : null;
  };

  return {
    recent: recent.flatMap((r) => {
      const row = rowOf(r.id);
      return row ? [{ ...row, last_used_at: r.last_used_at }] : [];
    }),
    assigned: assigned.flatMap((a) => {
      const row = rowOf(a.id);
      return row ? [{ ...row, routine_name: a.routine_name, assigned_by_name: a.assigned_by_name }] : [];
    }),
    library: library.flatMap((l) => {
      const row = rowOf(l.id);
      return row ? [row] : [];
    }),
  };
}

// ── Postgres error mapping ────────────────────────────────────────────────────

function pgErrorResponse(e: unknown, method: string): Response {
  const err = e as { code?: string; message?: string; detail?: string } | null;
  switch (err?.code) {
    case "23505":
      return jsonError("Already exists", 409, { detail: err.detail });
    case "23503":
      return method === "DELETE"
        ? jsonError("Training is used by a routine and can't be deleted", 409)
        : jsonError("Referenced exercise does not exist", 400, { detail: err.detail });
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

  // ── GET /trainings/suggestions — what to offer when logging a workout ───────
  if (req.method === "GET" && url.pathname === "/trainings/suggestions") {
    const { caller, response } = await requireCaller(req);
    if (!caller) return response;
    const name = url.searchParams.get("name")?.trim() || null;
    const limit = Math.min(Math.max(parseInt(url.searchParams.get("limit") ?? "10") || 10, 1), 50);
    return json(await fetchSuggestions(caller, name, limit));
  }

  const id = parseId(url.pathname);

  // ── GET /trainings — public + owned ──────────────────────────────────────────
  if (req.method === "GET" && !id) {
    const name = url.searchParams.get("name");
    const authorId = url.searchParams.get("author_id");
    const mine = url.searchParams.get("mine") === "true";
    const page = parseInt(url.searchParams.get("page") ?? "0");
    const pageSize = Math.min(parseInt(url.searchParams.get("page_size") ?? "20"), 100);

    let query = db.selectFrom("training").select(TRAINING_COLS);

    if (mine) {
      // Never fall through to an unfiltered query when the profile is missing.
      const { caller } = await requireCaller(req);
      if (!caller) return jsonError("Unauthorized", 401);
      query = query.where("author_id", "=", caller.id);
    } else {
      query = query.where("is_public", "=", true);
    }

    if (name) {
      query = query.where("name", "ilike", `%${name}%`);
    }
    if (authorId) query = query.where("author_id", "=", authorId);

    const trainings = await query
      .orderBy("updated_at", "desc")
      .limit(pageSize)
      .offset(page * pageSize)
      .execute();

    // Attach thumbnail images to list items
    const ids = trainings.map((t) => t.id);
    const thumbnails = ids.length
      ? await db
          .selectFrom("training_image")
          .select(IMAGE_COLS)
          .where("training_id", "in", ids)
          .where("is_thumbnail", "=", true)
          .execute()
      : [];
    const thumbMap = Object.fromEntries(thumbnails.map((t) => [t.training_id, t]));

    return json(trainings.map((t) => ({ ...t, thumbnail: thumbMap[t.id] ?? null })));
  }

  // ── GET /trainings/:id — public, returns full nested detail ──────────────────
  if (req.method === "GET" && id) {
    const caller = await optionalCaller(req);
    const detail = await fetchTrainingDetail(id, caller);
    if (!detail) return jsonError("Training not found", 404);
    if (!(await canReadTraining(caller, detail))) return jsonError("Training not found", 404);
    return json(detail);
  }

  // ── Auth wall ─────────────────────────────────────────────────────────────────

  const { caller, response } = await requireCaller(req);
  if (!caller) return response;

  // ── POST /trainings ────────────────────────────────────────────────────────────
  if (req.method === "POST" && !id) {
    const body = await req.json().catch(() => null);
    const { name, description, notes, is_public, images, sets, routine_ids } = body ?? {};

    if (!name) return jsonError("Missing required field: name", 400);
    const routineIds = routine_ids === undefined ? null : await ownRoutineIds(caller, routine_ids);
    if (routine_ids !== undefined && !routineIds) {
      return jsonError("routine_ids must list your own routines", 400);
    }

    const insert: TrainingInsert = {
      name,
      description: description ?? null,
      notes: notes ?? null,
      author_id: caller.id,
      is_public: is_public ?? false,
    };

    const trainingId = await db.transaction().execute(async (trx) => {
      const training = await trx
        .insertInto("training")
        .values(insert)
        .returning(["id"])
        .executeTakeFirstOrThrow();

      if (Array.isArray(images) && images.length) {
        await replaceTrainingImages(trx, training.id, images);
      }
      if (Array.isArray(sets) && sets.length) {
        await replaceTrainingSets(trx, training.id, sets);
      }
      if (routineIds?.length) await syncRoutines(trx, caller, training.id, routineIds);
      return training.id;
    });

    const detail = await fetchTrainingDetail(trainingId, caller);
    return json(detail, 201);
  }

  // ── PUT /trainings/:id ────────────────────────────────────────────────────────
  if (req.method === "PUT" && id) {
    const existing = await db
      .selectFrom("training")
      .select(["id", "author_id"])
      .where("id", "=", id)
      .executeTakeFirst();
    if (!existing) return jsonError("Training not found", 404);

    if (!canEditAuthored(caller, existing.author_id)) return forbidden();

    const body = await req.json().catch(() => null);
    const { name, description, notes, is_public, images, sets, routine_ids } = body ?? {};

    // Past sessions resolve their exercises through these sets.
    if (Array.isArray(sets) && (await hasSessions(id))) {
      return jsonError(
        "This training has logged sessions, so its exercises can't be changed. Edit its details, or save a copy as a new training.",
        409,
        { code: "exercises_locked" },
      );
    }
    const routineIds = routine_ids === undefined ? null : await ownRoutineIds(caller, routine_ids);
    if (routine_ids !== undefined && !routineIds) {
      return jsonError("routine_ids must list your own routines", 400);
    }

    const update: TrainingUpdate = {
      ...(name !== undefined && { name }),
      ...(description !== undefined && { description }),
      ...(notes !== undefined && { notes }),
      ...(is_public !== undefined && { is_public }),
      updated_at: new Date().toISOString(),
    };

    await db.transaction().execute(async (trx) => {
      await trx.updateTable("training").set(update).where("id", "=", id).execute();
      if (Array.isArray(images)) await replaceTrainingImages(trx, id, images);
      if (Array.isArray(sets)) await replaceTrainingSets(trx, id, sets);
      if (routineIds) await syncRoutines(trx, caller, id, routineIds);
    });

    const detail = await fetchTrainingDetail(id, caller);
    return json(detail);
  }

  // ── DELETE /trainings/:id ─────────────────────────────────────────────────────
  if (req.method === "DELETE" && id) {
    const existing = await db
      .selectFrom("training")
      .select(["author_id"])
      .where("id", "=", id)
      .executeTakeFirst();
    if (!existing) return jsonError("Training not found", 404);

    if (!canEditAuthored(caller, existing.author_id)) return forbidden();

    await db.deleteFrom("training").where("id", "=", id).execute();
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
