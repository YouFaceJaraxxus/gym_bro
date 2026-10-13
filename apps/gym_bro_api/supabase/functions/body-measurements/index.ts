import { type Insertable, sql } from "npm:kysely@^0.27";
import { db } from "../_shared/config.ts";
import {
  coachesUser,
  forbidden,
  isSuperUser,
  json,
  jsonError,
  requireCaller,
} from "../_shared/auth.ts";
import type { BodyMeasurementTable } from "../../types/schema/public.ts";

// Body weight / body-fat log. Users write only their own rows; coaches (and
// super users) can read a coached member's log with ?user_id=.
//
// Row shape: { id, user_id, measured_on: 'YYYY-MM-DD', weight_kg: number|null,
//              body_fat_pct: number|null, note, created_at }

const COLS = [
  "id",
  "user_id",
  sql<string>`to_char(measured_on, 'YYYY-MM-DD')`.as("measured_on"),
  sql<number | null>`weight_kg::float8`.as("weight_kg"),
  sql<number | null>`body_fat_pct::float8`.as("body_fat_pct"),
  "note",
  "created_at",
] as const;

const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;

// ── Path parsing ──────────────────────────────────────────────────────────────

function parseId(pathname: string): string | null {
  const match = pathname.match(/^\/body-measurements\/([^/]+)$/);
  return match ? match[1] : null;
}

// ── Validation ────────────────────────────────────────────────────────────────

type Fields = {
  measured_on?: string;
  weight_kg?: number | null;
  body_fat_pct?: number | null;
  note?: string | null;
};

/** Returns the validated subset of fields present in `body`, or an error. */
function readFields(body: Record<string, unknown>): { fields: Fields; error?: string } {
  const fields: Fields = {};
  if (body.measured_on !== undefined) {
    if (typeof body.measured_on !== "string" || !DATE_RE.test(body.measured_on)) {
      return { fields, error: "measured_on must be YYYY-MM-DD" };
    }
    fields.measured_on = body.measured_on;
  }
  for (const key of ["weight_kg", "body_fat_pct"] as const) {
    const v = body[key];
    if (v === undefined) continue;
    if (v === null || v === "") {
      fields[key] = null;
      continue;
    }
    const n = typeof v === "number" ? v : Number(v);
    if (!Number.isFinite(n) || n <= 0) return { fields, error: `${key} must be a positive number` };
    if (key === "body_fat_pct" && n >= 100) return { fields, error: "body_fat_pct must be below 100" };
    if (key === "weight_kg" && n >= 10000) return { fields, error: "weight_kg is too large" };
    fields[key] = n;
  }
  if (body.note !== undefined) {
    fields.note = typeof body.note === "string" && body.note.trim() ? body.note.trim() : null;
  }
  return { fields };
}

// ── Postgres error mapping ────────────────────────────────────────────────────

function pgErrorResponse(e: unknown): Response {
  const err = e as { code?: string; message?: string; detail?: string } | null;
  switch (err?.code) {
    case "23505":
      return jsonError("Already exists", 409, { detail: err.detail });
    case "23503":
      return jsonError("Referenced record does not exist", 400, { detail: err.detail });
    case "23514":
      return jsonError("A measurement needs a weight or a body-fat value", 400);
    case "23502":
    case "22P02":
    case "22003":
    case "22007":
    case "22008":
      return jsonError(err.message ?? "Invalid value", 400);
  }
  throw e;
}

// ── Handler ───────────────────────────────────────────────────────────────────

async function handler(req: Request): Promise<Response> {
  const url = new URL(req.url);
  const id = parseId(url.pathname);

  const { caller, response } = await requireCaller(req);
  if (!caller) return response;

  // ── GET /body-measurements?user_id=&from=&to= ─────────────────────────────────
  // Oldest first (chart order).
  if (req.method === "GET" && !id) {
    const userId = url.searchParams.get("user_id") ?? caller.id;
    if (userId !== caller.id && !(await coachesUser(caller, userId))) return forbidden();
    const from = url.searchParams.get("from");
    const to = url.searchParams.get("to");
    if ((from && !DATE_RE.test(from)) || (to && !DATE_RE.test(to))) {
      return jsonError("from/to must be YYYY-MM-DD", 400);
    }

    let query = db.selectFrom("body_measurement").select(COLS).where("user_id", "=", userId);
    if (from) query = query.where("measured_on", ">=", from);
    if (to) query = query.where("measured_on", "<=", to);

    const rows = await query.orderBy("measured_on", "asc").orderBy("created_at", "asc").execute();
    return json(rows);
  }

  // ── POST /body-measurements — own row ─────────────────────────────────────────
  if (req.method === "POST" && !id) {
    const body = await req.json().catch(() => null);
    if (!body || typeof body !== "object" || Array.isArray(body)) {
      return jsonError("Body must be an object", 400);
    }
    const { fields, error } = readFields(body);
    if (error) return jsonError(error, 400);
    if (fields.weight_kg == null && fields.body_fat_pct == null) {
      return jsonError("weight_kg or body_fat_pct is required", 400);
    }

    const insert: Insertable<BodyMeasurementTable> = {
      user_id: caller.id,
      weight_kg: fields.weight_kg ?? null,
      body_fat_pct: fields.body_fat_pct ?? null,
      note: fields.note ?? null,
      ...(fields.measured_on && { measured_on: fields.measured_on }),
    };

    const row = await db
      .insertInto("body_measurement")
      .values(insert)
      .returning(COLS)
      .executeTakeFirstOrThrow();
    return json(row, 201);
  }

  // ── PUT /body-measurements/:id — owner (or super) ─────────────────────────────
  if (req.method === "PUT" && id) {
    const existing = await db
      .selectFrom("body_measurement")
      .select(["user_id"])
      .where("id", "=", id)
      .executeTakeFirst();
    if (!existing) return jsonError("Measurement not found", 404);
    if (existing.user_id !== caller.id && !isSuperUser(caller)) return forbidden();

    const body = await req.json().catch(() => null);
    if (!body || typeof body !== "object" || Array.isArray(body)) {
      return jsonError("Body must be an object", 400);
    }
    const { fields, error } = readFields(body);
    if (error) return jsonError(error, 400);
    if (!Object.keys(fields).length) return jsonError("Nothing to update", 400);

    const row = await db
      .updateTable("body_measurement")
      .set(fields)
      .where("id", "=", id)
      .returning(COLS)
      .executeTakeFirstOrThrow();
    return json(row);
  }

  // ── DELETE /body-measurements/:id — owner (or super) ──────────────────────────
  if (req.method === "DELETE" && id) {
    const existing = await db
      .selectFrom("body_measurement")
      .select(["user_id"])
      .where("id", "=", id)
      .executeTakeFirst();
    if (!existing) return jsonError("Measurement not found", 404);
    if (existing.user_id !== caller.id && !isSuperUser(caller)) return forbidden();

    await db.deleteFrom("body_measurement").where("id", "=", id).execute();
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
