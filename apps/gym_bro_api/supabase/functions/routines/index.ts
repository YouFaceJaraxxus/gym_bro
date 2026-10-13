import type { Kysely } from "npm:kysely@^0.27";
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
  RoutineInsert,
  RoutineUpdate,
  RoutineImageInsert,
  RoutineTrainingInsert,
  RoutineScheduleType,
} from "../../types/schema/public.ts";

const ROUTINE_COLS = [
  "id", "name", "description", "notes",
  "author_id", "is_public", "schedule_type", "num_weeks",
  "created_at", "updated_at",
] as const;

const IMAGE_COLS = ["id", "routine_id", "url", "is_thumbnail", "position"] as const;
const RT_COLS = [
  "id", "routine_id", "training_id",
  "week_number", "day_of_week", "position", "note",
] as const;

const VALID_SCHEDULE_TYPES: RoutineScheduleType[] = ["fixed_weeks", "wildcard"];

// ── Auth ──────────────────────────────────────────────────────────────────────

/** Reads are public; resolve the caller only when a token was sent. */
async function optionalCaller(req: Request): Promise<Caller | null> {
  if (!req.headers.get("Authorization")) return null;
  const { caller } = await requireCaller(req);
  return caller ?? null;
}

function parseId(pathname: string): string | null {
  const match = pathname.match(/^\/routines\/([^/]+)$/);
  return match ? match[1] : null;
}

// ── Nested fetch ──────────────────────────────────────────────────────────────

async function fetchRoutineDetail(routineId: string) {
  const routine = await db
    .selectFrom("routine")
    .select(ROUTINE_COLS)
    .where("id", "=", routineId)
    .executeTakeFirst();

  if (!routine) return null;

  const images = await db
    .selectFrom("routine_image")
    .select(IMAGE_COLS)
    .where("routine_id", "=", routineId)
    .orderBy("position", "asc")
    .execute();

  const routineTrainings = await db
    .selectFrom("routine_training")
    .select(RT_COLS)
    .where("routine_id", "=", routineId)
    .orderBy("position", "asc")
    .execute();

  // Attach training names for display
  const trainingIds = [...new Set(routineTrainings.map((rt) => rt.training_id))];
  const trainings = trainingIds.length
    ? await db
        .selectFrom("training")
        .select(["id", "name", "description", "is_public"])
        .where("id", "in", trainingIds)
        .execute()
    : [];
  const trainingMap = Object.fromEntries(trainings.map((t) => [t.id, t]));

  return {
    ...routine,
    images,
    trainings: routineTrainings.map((rt) => ({
      ...rt,
      training: trainingMap[rt.training_id] ?? null,
    })),
  };
}

// ── Replace nested children (always inside a transaction) ────────────────────

// deno-lint-ignore no-explicit-any
async function replaceRoutineImages(trx: Kysely<Database>, routineId: string, images: any[]) {
  await trx.deleteFrom("routine_image").where("routine_id", "=", routineId).execute();
  if (!images.length) return;
  const imageInserts: RoutineImageInsert[] = images.map(
    (img: { url: string; is_thumbnail?: boolean; position?: number }, i: number) => ({
      routine_id: routineId,
      url: img.url,
      is_thumbnail: img.is_thumbnail ?? i === 0,
      position: img.position ?? i,
    }),
  );
  await trx.insertInto("routine_image").values(imageInserts).execute();
}

// deno-lint-ignore no-explicit-any
async function replaceRoutineTrainings(trx: Kysely<Database>, routineId: string, trainings: any[]) {
  await trx.deleteFrom("routine_training").where("routine_id", "=", routineId).execute();
  if (!trainings.length) return;
  const rtInserts: RoutineTrainingInsert[] = trainings.map(
    (rt: {
      training_id: string;
      week_number?: number;
      day_of_week?: number;
      position?: number;
      note?: string;
    }, i: number) => ({
      routine_id: routineId,
      training_id: rt.training_id,
      week_number: rt.week_number ?? null,
      day_of_week: rt.day_of_week ?? null,
      position: rt.position ?? i,
      note: rt.note ?? null,
    }),
  );
  await trx.insertInto("routine_training").values(rtInserts).execute();
}

// ── Postgres error mapping ────────────────────────────────────────────────────

function pgErrorResponse(e: unknown, method: string): Response {
  const err = e as { code?: string; message?: string; detail?: string } | null;
  switch (err?.code) {
    case "23505":
      return jsonError("Already exists", 409, { detail: err.detail });
    case "23503":
      return method === "DELETE"
        ? jsonError("Routine is still referenced and can't be deleted", 409)
        : jsonError("Referenced training does not exist", 400, { detail: err.detail });
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

  // ── GET /routines — public + owned ───────────────────────────────────────────
  if (req.method === "GET" && !id) {
    const name = url.searchParams.get("name");
    const authorId = url.searchParams.get("author_id");
    const mine = url.searchParams.get("mine") === "true";
    const page = parseInt(url.searchParams.get("page") ?? "0");
    const pageSize = Math.min(parseInt(url.searchParams.get("page_size") ?? "20"), 100);

    let query = db.selectFrom("routine").select(ROUTINE_COLS);

    if (mine) {
      // Never fall through to an unfiltered query when the profile is missing.
      const { caller } = await requireCaller(req);
      if (!caller) return jsonError("Unauthorized", 401);
      query = query.where("author_id", "=", caller.id);
    } else {
      query = query.where("is_public", "=", true);
    }

    if (name) query = query.where("name", "ilike", `%${name}%`);
    if (authorId) query = query.where("author_id", "=", authorId);

    const routines = await query
      .orderBy("updated_at", "desc")
      .limit(pageSize)
      .offset(page * pageSize)
      .execute();

    const ids = routines.map((r) => r.id);
    const thumbnails = ids.length
      ? await db
          .selectFrom("routine_image")
          .select(IMAGE_COLS)
          .where("routine_id", "in", ids)
          .where("is_thumbnail", "=", true)
          .execute()
      : [];
    const thumbMap = Object.fromEntries(thumbnails.map((t) => [t.routine_id, t]));

    return json(routines.map((r) => ({ ...r, thumbnail: thumbMap[r.id] ?? null })));
  }

  // ── GET /routines/:id ────────────────────────────────────────────────────────
  if (req.method === "GET" && id) {
    const detail = await fetchRoutineDetail(id);
    if (!detail) return jsonError("Routine not found", 404);
    if (!detail.is_public) {
      const caller = await optionalCaller(req);
      if (!caller || (!isSuperUser(caller) && detail.author_id !== caller.id)) {
        return jsonError("Routine not found", 404);
      }
    }
    return json(detail);
  }

  // ── Auth wall ─────────────────────────────────────────────────────────────────

  const { caller, response } = await requireCaller(req);
  if (!caller) return response;

  // ── POST /routines ────────────────────────────────────────────────────────────
  if (req.method === "POST" && !id) {
    const body = await req.json().catch(() => null);
    const {
      name, description, notes, is_public,
      schedule_type, num_weeks, images, trainings,
    } = body ?? {};

    if (!name) return jsonError("Missing required field: name", 400);

    const scheduleType: RoutineScheduleType = VALID_SCHEDULE_TYPES.includes(schedule_type)
      ? schedule_type
      : "wildcard";

    if (scheduleType === "fixed_weeks" && (!num_weeks || num_weeks < 1)) {
      return jsonError("num_weeks must be >= 1 for fixed_weeks routines", 400);
    }

    const insert: RoutineInsert = {
      name,
      description: description ?? null,
      notes: notes ?? null,
      author_id: caller.id,
      is_public: is_public ?? false,
      schedule_type: scheduleType,
      num_weeks: scheduleType === "fixed_weeks" ? num_weeks : null,
    };

    const routineId = await db.transaction().execute(async (trx) => {
      const routine = await trx
        .insertInto("routine")
        .values(insert)
        .returning(["id"])
        .executeTakeFirstOrThrow();
      if (Array.isArray(images) && images.length) {
        await replaceRoutineImages(trx, routine.id, images);
      }
      if (Array.isArray(trainings) && trainings.length) {
        await replaceRoutineTrainings(trx, routine.id, trainings);
      }
      return routine.id;
    });

    const detail = await fetchRoutineDetail(routineId);
    return json(detail, 201);
  }

  // ── PUT /routines/:id ─────────────────────────────────────────────────────────
  if (req.method === "PUT" && id) {
    const existing = await db
      .selectFrom("routine")
      .select(["id", "author_id"])
      .where("id", "=", id)
      .executeTakeFirst();
    if (!existing) return jsonError("Routine not found", 404);

    if (!canEditAuthored(caller, existing.author_id)) return forbidden();

    const body = await req.json().catch(() => null);
    const {
      name, description, notes, is_public,
      schedule_type, num_weeks, images, trainings,
    } = body ?? {};

    const update: RoutineUpdate = {
      ...(name !== undefined && { name }),
      ...(description !== undefined && { description }),
      ...(notes !== undefined && { notes }),
      ...(is_public !== undefined && { is_public }),
      ...(schedule_type !== undefined && VALID_SCHEDULE_TYPES.includes(schedule_type) && {
        schedule_type,
      }),
      ...(num_weeks !== undefined && { num_weeks }),
      updated_at: new Date().toISOString(),
    };

    await db.transaction().execute(async (trx) => {
      await trx.updateTable("routine").set(update).where("id", "=", id).execute();
      if (Array.isArray(images)) await replaceRoutineImages(trx, id, images);
      if (Array.isArray(trainings)) await replaceRoutineTrainings(trx, id, trainings);
    });

    const detail = await fetchRoutineDetail(id);
    return json(detail);
  }

  // ── DELETE /routines/:id ──────────────────────────────────────────────────────
  if (req.method === "DELETE" && id) {
    const existing = await db
      .selectFrom("routine")
      .select(["author_id"])
      .where("id", "=", id)
      .executeTakeFirst();
    if (!existing) return jsonError("Routine not found", 404);

    if (!canEditAuthored(caller, existing.author_id)) return forbidden();

    await db.deleteFrom("routine").where("id", "=", id).execute();
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
