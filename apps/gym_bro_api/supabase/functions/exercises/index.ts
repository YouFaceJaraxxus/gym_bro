import { db, supabaseAdmin } from "../_shared/config.ts";
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

// ── Auth ──────────────────────────────────────────────────────────────────────

async function requireAuth(req: Request) {
  const token = req.headers.get("Authorization")?.replace(/^Bearer\s+/i, "");
  if (!token) return { user: null, error: "Missing Authorization header" };
  const { data: { user }, error } = await supabaseAdmin.auth.getUser(token);
  return { user: error ? null : user, error: error?.message ?? null };
}

// ── Path parsing ──────────────────────────────────────────────────────────────

function parseId(pathname: string): string | null {
  const match = pathname.match(/^\/exercises\/([^/]+)$/);
  return match ? match[1] : null;
}

// ── Handler ───────────────────────────────────────────────────────────────────

Deno.serve(async (req: Request) => {
  const url = new URL(req.url);
  const id = parseId(url.pathname);

  // ── GET /exercises — public ───────────────────────────────────────────────────
  if (req.method === "GET" && !id) {
    const name = url.searchParams.get("name");
    const muscle = url.searchParams.get("muscle") as MuscleGroup | null;
    const authorId = url.searchParams.get("author_id");
    const isPublic = url.searchParams.get("is_public");
    const page = parseInt(url.searchParams.get("page") ?? "0");
    const pageSize = Math.min(parseInt(url.searchParams.get("page_size") ?? "20"), 100);

    let query = db.selectFrom("exercise").select(COLS);

    if (name) {
      query = query.where(
        db.fn("to_tsvector", ["english", "name"]),
        "@@",
        db.fn("plainto_tsquery", ["english", db.val(name)]),
      ) as typeof query;
    }
    if (muscle && VALID_MUSCLES.includes(muscle)) {
      query = query.where(
        db.raw<boolean>("primary_muscles @> ARRAY[?]::muscle_group[]", [muscle]),
      );
    }
    if (authorId) query = query.where("author_id", "=", authorId);
    if (isPublic === "true") query = query.where("is_public", "=", true);
    else if (isPublic === "false") query = query.where("is_public", "=", false);
    else query = query.where("is_public", "=", true); // default to public

    query = query.orderBy("name", "asc").limit(pageSize).offset(page * pageSize);
    return json(await query.execute());
  }

  // ── GET /exercises/:id — public ───────────────────────────────────────────────
  if (req.method === "GET" && id) {
    const exercise = await db
      .selectFrom("exercise")
      .select(COLS)
      .where("id", "=", id)
      .executeTakeFirst();
    if (!exercise) return jsonError("Exercise not found", 404);
    return json(exercise);
  }

  // ── Auth wall ─────────────────────────────────────────────────────────────────

  const { user, error: authError } = await requireAuth(req);
  if (!user) return jsonError(authError ?? "Unauthorized", 401);

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

    const primaries: MuscleGroup[] = (primary_muscles ?? []).filter((m: string) =>
      VALID_MUSCLES.includes(m as MuscleGroup)
    );
    const secondaries: MuscleGroup[] = (secondary_muscles ?? []).filter((m: string) =>
      VALID_MUSCLES.includes(m as MuscleGroup)
    );

    // Resolve author_id from auth user
    const dbUser = await db
      .selectFrom("users")
      .select(["id"])
      .where("auth_id", "=", user.id)
      .executeTakeFirst();

    const insert: ExerciseInsert = {
      name,
      description: description ?? null,
      note: note ?? null,
      image_url: image_url ?? null,
      video_url: video_url ?? null,
      author_id: dbUser?.id ?? null,
      primary_muscles: primaries,
      secondary_muscles: secondaries,
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

    const dbUser = await db
      .selectFrom("users")
      .select(["id", "role"])
      .where("auth_id", "=", user.id)
      .executeTakeFirst();

    if (existing.author_id && existing.author_id !== dbUser?.id && dbUser?.role !== "super_user") {
      return jsonError("Forbidden", 403);
    }

    const { id: _id, author_id: _aid, created_at: _ca, ...fields } = body;
    if (fields.primary_muscles) {
      fields.primary_muscles = fields.primary_muscles.filter((m: string) =>
        VALID_MUSCLES.includes(m as MuscleGroup)
      );
    }
    if (fields.secondary_muscles) {
      fields.secondary_muscles = fields.secondary_muscles.filter((m: string) =>
        VALID_MUSCLES.includes(m as MuscleGroup)
      );
    }

    const update: ExerciseUpdate = { ...fields, updated_at: new Date().toISOString() };
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

    const dbUser = await db
      .selectFrom("users")
      .select(["id", "role"])
      .where("auth_id", "=", user.id)
      .executeTakeFirst();

    if (existing.author_id && existing.author_id !== dbUser?.id && dbUser?.role !== "super_user") {
      return jsonError("Forbidden", 403);
    }

    await db.deleteFrom("exercise").where("id", "=", id).execute();
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
