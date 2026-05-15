import { db, supabaseAdmin } from "../_shared/config.ts";
import type {
  TrainingInsert,
  TrainingUpdate,
  TrainingImageInsert,
  TrainingSetInsert,
  TrainingSetExerciseInsert,
  TrainingSetDropInsert,
  WorkoutSetType,
  RepType,
  BodySide,
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

const VALID_SET_TYPES: WorkoutSetType[] = ["standard", "superset", "dropset", "circuit"];
const VALID_REP_TYPES: RepType[] = ["count", "failure", "unspecified"];
const VALID_SIDES: BodySide[] = ["both", "left", "right"];

// ── Auth ──────────────────────────────────────────────────────────────────────

async function requireAuth(req: Request) {
  const token = req.headers.get("Authorization")?.replace(/^Bearer\s+/i, "");
  if (!token) return { user: null, error: "Missing Authorization header" };
  const { data: { user }, error } = await supabaseAdmin.auth.getUser(token);
  return { user: error ? null : user, error: error?.message ?? null };
}

// ── Path parsing ──────────────────────────────────────────────────────────────

function parseId(pathname: string): string | null {
  const match = pathname.match(/^\/trainings\/([^/]+)$/);
  return match ? match[1] : null;
}

// ── Nested fetch ──────────────────────────────────────────────────────────────

async function fetchTrainingDetail(trainingId: string) {
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
        drops: dropsByExercise[e.id] ?? [],
      });
      return acc;
    },
    {} as Record<string, unknown[]>,
  );

  return {
    ...training,
    images,
    sets: sets.map((s) => ({
      ...s,
      exercises: exercisesBySet[s.id] ?? [],
    })),
  };
}

// ── Upsert nested sets for a training ────────────────────────────────────────
// Deletes all existing sets (cascade) then re-inserts from payload.

async function replaceTrainingSets(
  trainingId: string,
  // deno-lint-ignore no-explicit-any
  setsPayload: any[],
) {
  await db.deleteFrom("training_set").where("training_id", "=", trainingId).execute();

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

    const newSet = await db
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

      const newEx = await db
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

        await db.insertInto("training_set_drop").values(dropInsert).execute();
      }
    }
  }
}

// ── Handler ───────────────────────────────────────────────────────────────────

Deno.serve(async (req: Request) => {
  const url = new URL(req.url);
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
    const detail = await fetchTrainingDetail(id);
    if (!detail) return jsonError("Training not found", 404);
    if (!detail.is_public) {
      // allow owner or super_user to read private
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

  // ── POST /trainings ────────────────────────────────────────────────────────────
  if (req.method === "POST" && !id) {
    const body = await req.json().catch(() => null);
    const { name, description, notes, is_public, images, sets } = body ?? {};

    if (!name) return jsonError("Missing required field: name", 400);

    const insert: TrainingInsert = {
      name,
      description: description ?? null,
      notes: notes ?? null,
      author_id: dbUser?.id ?? null,
      is_public: is_public ?? false,
    };

    const training = await db
      .insertInto("training")
      .values(insert)
      .returning(TRAINING_COLS)
      .executeTakeFirstOrThrow();

    if (Array.isArray(images)) {
      const imageInserts: TrainingImageInsert[] = images.map((img: {
        url: string;
        is_thumbnail?: boolean;
        position?: number;
      }, i: number) => ({
        training_id: training.id,
        url: img.url,
        is_thumbnail: img.is_thumbnail ?? i === 0,
        position: img.position ?? i,
      }));
      if (imageInserts.length) {
        await db.insertInto("training_image").values(imageInserts).execute();
      }
    }

    if (Array.isArray(sets) && sets.length) {
      await replaceTrainingSets(training.id, sets);
    }

    const detail = await fetchTrainingDetail(training.id);
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

    if (existing.author_id && existing.author_id !== dbUser?.id && dbUser?.role !== "super_user") {
      return jsonError("Forbidden", 403);
    }

    const body = await req.json().catch(() => null);
    const { name, description, notes, is_public, images, sets } = body ?? {};

    const update: TrainingUpdate = {
      ...(name !== undefined && { name }),
      ...(description !== undefined && { description }),
      ...(notes !== undefined && { notes }),
      ...(is_public !== undefined && { is_public }),
      updated_at: new Date().toISOString(),
    };

    await db.updateTable("training").set(update).where("id", "=", id).execute();

    if (Array.isArray(images)) {
      await db.deleteFrom("training_image").where("training_id", "=", id).execute();
      const imageInserts: TrainingImageInsert[] = images.map(
        (img: { url: string; is_thumbnail?: boolean; position?: number }, i: number) => ({
          training_id: id,
          url: img.url,
          is_thumbnail: img.is_thumbnail ?? i === 0,
          position: img.position ?? i,
        }),
      );
      if (imageInserts.length) {
        await db.insertInto("training_image").values(imageInserts).execute();
      }
    }

    if (Array.isArray(sets)) {
      await replaceTrainingSets(id, sets);
    }

    const detail = await fetchTrainingDetail(id);
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

    if (existing.author_id && existing.author_id !== dbUser?.id && dbUser?.role !== "super_user") {
      return jsonError("Forbidden", 403);
    }

    await db.deleteFrom("training").where("id", "=", id).execute();
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
