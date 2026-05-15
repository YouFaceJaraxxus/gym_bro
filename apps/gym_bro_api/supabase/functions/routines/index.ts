import { db, supabaseAdmin } from "../_shared/config.ts";
import type {
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

async function requireAuth(req: Request) {
  const token = req.headers.get("Authorization")?.replace(/^Bearer\s+/i, "");
  if (!token) return { user: null, error: "Missing Authorization header" };
  const { data: { user }, error } = await supabaseAdmin.auth.getUser(token);
  return { user: error ? null : user, error: error?.message ?? null };
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

// ── Handler ───────────────────────────────────────────────────────────────────

Deno.serve(async (req: Request) => {
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
      author_id: dbUser?.id ?? null,
      is_public: is_public ?? false,
      schedule_type: scheduleType,
      num_weeks: scheduleType === "fixed_weeks" ? num_weeks : null,
    };

    const routine = await db
      .insertInto("routine")
      .values(insert)
      .returning(ROUTINE_COLS)
      .executeTakeFirstOrThrow();

    if (Array.isArray(images) && images.length) {
      const imageInserts: RoutineImageInsert[] = images.map(
        (img: { url: string; is_thumbnail?: boolean; position?: number }, i: number) => ({
          routine_id: routine.id,
          url: img.url,
          is_thumbnail: img.is_thumbnail ?? i === 0,
          position: img.position ?? i,
        }),
      );
      await db.insertInto("routine_image").values(imageInserts).execute();
    }

    if (Array.isArray(trainings) && trainings.length) {
      const rtInserts: RoutineTrainingInsert[] = trainings.map(
        (rt: {
          training_id: string;
          week_number?: number;
          day_of_week?: number;
          position?: number;
          note?: string;
        }, i: number) => ({
          routine_id: routine.id,
          training_id: rt.training_id,
          week_number: rt.week_number ?? null,
          day_of_week: rt.day_of_week ?? null,
          position: rt.position ?? i,
          note: rt.note ?? null,
        }),
      );
      await db.insertInto("routine_training").values(rtInserts).execute();
    }

    const detail = await fetchRoutineDetail(routine.id);
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

    if (existing.author_id && existing.author_id !== dbUser?.id && dbUser?.role !== "super_user") {
      return jsonError("Forbidden", 403);
    }

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

    await db.updateTable("routine").set(update).where("id", "=", id).execute();

    if (Array.isArray(images)) {
      await db.deleteFrom("routine_image").where("routine_id", "=", id).execute();
      if (images.length) {
        const imageInserts: RoutineImageInsert[] = images.map(
          (img: { url: string; is_thumbnail?: boolean; position?: number }, i: number) => ({
            routine_id: id,
            url: img.url,
            is_thumbnail: img.is_thumbnail ?? i === 0,
            position: img.position ?? i,
          }),
        );
        await db.insertInto("routine_image").values(imageInserts).execute();
      }
    }

    if (Array.isArray(trainings)) {
      await db.deleteFrom("routine_training").where("routine_id", "=", id).execute();
      if (trainings.length) {
        const rtInserts: RoutineTrainingInsert[] = trainings.map(
          (rt: {
            training_id: string;
            week_number?: number;
            day_of_week?: number;
            position?: number;
            note?: string;
          }, i: number) => ({
            routine_id: id,
            training_id: rt.training_id,
            week_number: rt.week_number ?? null,
            day_of_week: rt.day_of_week ?? null,
            position: rt.position ?? i,
            note: rt.note ?? null,
          }),
        );
        await db.insertInto("routine_training").values(rtInserts).execute();
      }
    }

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

    if (existing.author_id && existing.author_id !== dbUser?.id && dbUser?.role !== "super_user") {
      return jsonError("Forbidden", 403);
    }

    await db.deleteFrom("routine").where("id", "=", id).execute();
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
