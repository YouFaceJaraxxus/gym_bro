import { db, supabaseAdmin } from "../_shared/config.ts";
import type { BusinessInsert, BusinessUpdate } from "../../types/schema/public.ts";

const COLS = [
  "id",
  "name",
  "location",
  "logo",
  "working_hours_from",
  "working_hours_to",
  "working_weekdays",
  "type",
] as const;

// ── Auth ──────────────────────────────────────────────────────────────────────

async function requireAuth(req: Request) {
  const token = req.headers.get("Authorization")?.replace(/^Bearer\s+/i, "");
  if (!token) return { user: null, error: "Missing Authorization header" };
  const { data: { user }, error } = await supabaseAdmin.auth.getUser(token);
  return { user: error ? null : user, error: error?.message ?? null };
}

// ── Path parsing ──────────────────────────────────────────────────────────────

function parseId(pathname: string): string | null {
  const match = pathname.match(/^\/businesses\/([^/]+)$/);
  return match ? match[1] : null;
}

// ── Handler ───────────────────────────────────────────────────────────────────

Deno.serve(async (req: Request) => {
  const url = new URL(req.url);
  const id = parseId(url.pathname);

  // ── GET /businesses — requires auth, returns only the caller's owned businesses ─
  if (req.method === "GET" && !id) {
    const { user, error: authError } = await requireAuth(req);
    if (!user) return jsonError(authError ?? "Unauthorized", 401);

    const profile = await db
      .selectFrom("users")
      .select(["id"])
      .where("auth_id", "=", user.id)
      .executeTakeFirst();
    if (!profile) return jsonError("User profile not found", 404);

    const [gymOwners, shopOwners] = await Promise.all([
      db.selectFrom("gym_owner").select(["gym_id"]).where("user_id", "=", profile.id).execute(),
      db.selectFrom("shop_owner").select(["shop_id"]).where("user_id", "=", profile.id).execute(),
    ]);

    const ownedIds = [
      ...gymOwners.map((r) => r.gym_id),
      ...shopOwners.map((r) => r.shop_id),
    ];

    if (ownedIds.length === 0) return json([]);

    const typeFilter = url.searchParams.get("type");
    let query = db.selectFrom("business").select(COLS).where("id", "in", ownedIds);
    if (typeFilter === "gym" || typeFilter === "shop") {
      query = query.where("type", "=", typeFilter);
    }
    return json(await query.execute());
  }

  // ── GET /businesses/:id — public ─────────────────────────────────────────────
  if (req.method === "GET" && id) {
    const b = await db
      .selectFrom("business")
      .select(COLS)
      .where("id", "=", id)
      .executeTakeFirst();
    if (!b) return jsonError("Business not found", 404);
    return json(b);
  }

  // ── Auth wall — writes require a valid JWT ────────────────────────────────────

  const { user, error: authError } = await requireAuth(req);
  if (!user) return jsonError(authError ?? "Unauthorized", 401);

  // ── POST /businesses ──────────────────────────────────────────────────────────
  // Creates a business row and the corresponding gym or shop sub-row atomically.
  if (req.method === "POST" && !id) {
    const body = await req.json().catch(() => null);
    const { name, location, logo, working_hours_from, working_hours_to, working_weekdays, type } =
      body ?? {};

    if (!name || !location || !working_hours_from || !working_hours_to || !working_weekdays || !type) {
      return jsonError(
        "Missing required fields: name, location, working_hours_from, working_hours_to, working_weekdays, type",
        400,
      );
    }
    if (type !== "gym" && type !== "shop") return jsonError("type must be 'gym' or 'shop'", 400);

    const insert: BusinessInsert = {
      name,
      location,
      logo: logo ?? null,
      working_hours_from,
      working_hours_to,
      working_weekdays,
      type,
    };

    const business = await db.transaction().execute(async (trx) => {
      const biz = await trx
        .insertInto("business")
        .values(insert)
        .returning(COLS)
        .executeTakeFirstOrThrow();
      if (type === "gym") {
        await trx.insertInto("gym").values({ id: biz.id }).execute();
        await trx.insertInto("gym_owner").values({ user_id: user.id, gym_id: biz.id }).execute();
      } else {
        await trx.insertInto("shop").values({ id: biz.id }).execute();
        await trx.insertInto("shop_owner").values({ user_id: user.id, shop_id: biz.id }).execute();
      }
      return biz;
    });

    return json(business, 201);
  }

  // ── PUT /businesses/:id — type is immutable after creation ───────────────────
  if (req.method === "PUT" && id) {
    const body = await req.json().catch(() => null);
    if (!body || Object.keys(body).length === 0) return jsonError("Body must not be empty", 400);
    const { id: _id, type: _type, ...fields } = body;
    const update: BusinessUpdate = fields;
    const b = await db
      .updateTable("business")
      .set(update)
      .where("id", "=", id)
      .returning(COLS)
      .executeTakeFirst();
    if (!b) return jsonError("Business not found", 404);
    return json(b);
  }

  // ── DELETE /businesses/:id ────────────────────────────────────────────────────
  // Removes gym/shop sub-row first (RESTRICT FK), then the business row.
  if (req.method === "DELETE" && id) {
    let found = false;
    await db.transaction().execute(async (trx) => {
      await trx.deleteFrom("gym").where("id", "=", id).execute();
      await trx.deleteFrom("shop").where("id", "=", id).execute();
      const result = await trx.deleteFrom("business").where("id", "=", id).executeTakeFirst();
      found = Number(result.numDeletedRows) > 0;
    });
    if (!found) return jsonError("Business not found", 404);
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
