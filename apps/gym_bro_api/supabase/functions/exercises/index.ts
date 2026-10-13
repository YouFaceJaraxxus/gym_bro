import { sql } from "npm:kysely@^0.27";
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
  ExerciseInsert,
  ExerciseUpdate,
  MuscleGroup,
} from "../../types/schema/public.ts";

const COLS = [
  "id",
  "name",
  "description",
  "note",
  "image_url",
  "video_url",
  "author_id",
  "primary_muscles",
  "secondary_muscles",
  "is_public",
  "created_at",
  "updated_at",
] as const;

const VALID_MUSCLES: MuscleGroup[] = [
  "chest_all", "chest_upper", "chest_lower",
  "back_all", "back_upper", "back_mid", "back_lower",
  "back_rhomboids", "back_traps", "back_lats",
  "delts_all", "delts_front", "delts_medial", "delts_rear",
  "biceps",
  "triceps_all", "triceps_long", "triceps_lateral", "triceps_medial",
  "forearms_all", "forearms_top", "forearms_bottom",
  "abs_upper", "abs_lower", "abs_obliques",
  "quads_all", "quads_medial", "quads_lateral",
  "hamstrings",
  "glutes_all", "glutes_medius", "glutes_minimus", "glutes_maximus",
  "calves",
  "neck",
];

function filterMuscles(value: unknown): MuscleGroup[] {
  if (!Array.isArray(value)) return [];
  return value.filter((m): m is MuscleGroup => VALID_MUSCLES.includes(m as MuscleGroup));
}

// ── Auth ──────────────────────────────────────────────────────────────────────

/** Reads are public; resolve the caller only when a token was sent. */
async function optionalCaller(req: Request): Promise<Caller | null> {
  if (!req.headers.get("Authorization")) return null;
  const { caller } = await requireCaller(req);
  return caller ?? null;
}

// ── Path parsing ──────────────────────────────────────────────────────────────

function parseId(pathname: string): string | null {
  const match = pathname.match(/^\/exercises\/([^/]+)$/);
  return match ? match[1] : null;
}

// ── Postgres error mapping ────────────────────────────────────────────────────

function pgErrorResponse(e: unknown, method: string): Response {
  const err = e as { code?: string; message?: string; detail?: string } | null;
  switch (err?.code) {
    case "23505":
      return jsonError("Already exists", 409, { detail: err.detail });
    case "23503":
      return method === "DELETE"
        ? jsonError("Exercise is used by a training and can't be deleted", 409)
        : jsonError("Referenced record does not exist", 400, { detail: err.detail });
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

  // ── GET /exercises — public; ?is_public=false lists the caller's private ones ─
  if (req.method === "GET" && !id) {
    const name = url.searchParams.get("name");
    const muscle = url.searchParams.get("muscle") as MuscleGroup | null;
    const authorId = url.searchParams.get("author_id");
    const isPublic = url.searchParams.get("is_public");
    const page = parseInt(url.searchParams.get("page") ?? "0");
    const pageSize = Math.min(parseInt(url.searchParams.get("page_size") ?? "20"), 100);

    let query = db.selectFrom("exercise").select(COLS);

    if (isPublic === "false") {
      const { caller, response } = await requireCaller(req);
      if (!caller) return response;
      query = query.where("is_public", "=", false).where("author_id", "=", caller.id);
    } else {
      query = query.where("is_public", "=", true);
    }

    if (name) {
      query = query.where(
        sql<boolean>`to_tsvector('english', name) @@ plainto_tsquery('english', ${name})`,
      );
    }
    if (muscle && VALID_MUSCLES.includes(muscle)) {
      query = query.where(sql<boolean>`primary_muscles @> ARRAY[${muscle}]::muscle_group[]`);
    }
    if (authorId) query = query.where("author_id", "=", authorId);

    query = query.orderBy("name", "asc").limit(pageSize).offset(page * pageSize);
    return json(await query.execute());
  }

  // ── GET /exercises/:id — public, private ones only for author / super ───────
  if (req.method === "GET" && id) {
    const exercise = await db
      .selectFrom("exercise")
      .select(COLS)
      .where("id", "=", id)
      .executeTakeFirst();
    if (!exercise) return jsonError("Exercise not found", 404);
    if (!exercise.is_public) {
      const caller = await optionalCaller(req);
      if (!caller || (!isSuperUser(caller) && exercise.author_id !== caller.id)) {
        return jsonError("Exercise not found", 404);
      }
    }
    return json(exercise);
  }

  // ── Auth wall ─────────────────────────────────────────────────────────────────

  const { caller, response } = await requireCaller(req);
  if (!caller) return response;

  // ── POST /exercises ────────────────────────────────────────────────────────────
  if (req.method === "POST" && !id) {
    const body = await req.json().catch(() => null);
    const {
      name,
      description,
      note,
      image_url,
      video_url,
      primary_muscles,
      secondary_muscles,
      is_public,
    } = body ?? {};

    if (!name) return jsonError("Missing required field: name", 400);

    const insert: ExerciseInsert = {
      name,
      description: description ?? null,
      note: note ?? null,
      image_url: image_url ?? null,
      video_url: video_url ?? null,
      author_id: caller.id,
      primary_muscles: filterMuscles(primary_muscles),
      secondary_muscles: filterMuscles(secondary_muscles),
      is_public: is_public ?? true,
    };

    const exercise = await db
      .insertInto("exercise")
      .values(insert)
      .returning(COLS)
      .executeTakeFirstOrThrow();

    return json(exercise, 201);
  }

  // ── PUT /exercises/:id ────────────────────────────────────────────────────────
  if (req.method === "PUT" && id) {
    const body = await req.json().catch(() => null);
    if (!body || Object.keys(body).length === 0) {
      return jsonError("Body must not be empty", 400);
    }

    const existing = await db
      .selectFrom("exercise")
      .select(["id", "author_id"])
      .where("id", "=", id)
      .executeTakeFirst();
    if (!existing) return jsonError("Exercise not found", 404);
    if (!canEditAuthored(caller, existing.author_id)) return forbidden();

    const { name, description, note, image_url, video_url, primary_muscles, secondary_muscles, is_public } =
      body;

    const update: ExerciseUpdate = {
      ...(name !== undefined && { name }),
      ...(description !== undefined && { description }),
      ...(note !== undefined && { note }),
      ...(image_url !== undefined && { image_url }),
      ...(video_url !== undefined && { video_url }),
      ...(primary_muscles !== undefined && { primary_muscles: filterMuscles(primary_muscles) }),
      ...(secondary_muscles !== undefined && { secondary_muscles: filterMuscles(secondary_muscles) }),
      ...(is_public !== undefined && { is_public }),
      updated_at: new Date().toISOString(),
    };

    const exercise = await db
      .updateTable("exercise")
      .set(update)
      .where("id", "=", id)
      .returning(COLS)
      .executeTakeFirst();

    return json(exercise);
  }

  // ── DELETE /exercises/:id ─────────────────────────────────────────────────────
  if (req.method === "DELETE" && id) {
    const existing = await db
      .selectFrom("exercise")
      .select(["author_id"])
      .where("id", "=", id)
      .executeTakeFirst();
    if (!existing) return jsonError("Exercise not found", 404);
    if (!canEditAuthored(caller, existing.author_id)) return forbidden();

    await db.deleteFrom("exercise").where("id", "=", id).execute();
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
