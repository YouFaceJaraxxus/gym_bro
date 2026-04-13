import { db, supabaseAdmin } from "../_shared/config.ts";

// ── Auth ──────────────────────────────────────────────────────────────────────

async function requireAuth(req: Request) {
  const token = req.headers.get("Authorization")?.replace(/^Bearer\s+/i, "");
  if (!token) return { user: null, error: "Missing Authorization header" };
  const { data: { user }, error } = await supabaseAdmin.auth.getUser(token);
  return { user: error ? null : user, error: error?.message ?? null };
}

// ── Path parsing ──────────────────────────────────────────────────────────────

function parseId(pathname: string): string | null {
  const match = pathname.match(/^\/shop-owners\/([^/]+)$/);
  return match ? match[1] : null;
}

// ── Handler ───────────────────────────────────────────────────────────────────

Deno.serve(async (req: Request) => {
  const { user, error: authError } = await requireAuth(req);
  if (!user) return jsonError(authError ?? "Unauthorized", 401);

  const url = new URL(req.url);
  const id = parseId(url.pathname);

  // ── POST /shop-owners ─────────────────────────────────────────────────────────
  if (req.method === "POST" && !id) {
    const body = await req.json().catch(() => null);
    const { user_id, shop_id } = body ?? {};
    if (!user_id || !shop_id) return jsonError("user_id and shop_id are required", 400);

    const row = await db
      .insertInto("shop_owner")
      .values({ user_id, shop_id })
      .returningAll()
      .executeTakeFirstOrThrow();
    await db.updateTable("users").set({ role: "owner" }).where("id", "=", user_id).execute();
    return json(row, 201);
  }

  // ── GET /shop-owners — optional ?user_id= and/or ?shop_id= filters ───────────
  if (req.method === "GET" && !id) {
    const userId = url.searchParams.get("user_id");
    const shopId = url.searchParams.get("shop_id");
    let query = db.selectFrom("shop_owner").selectAll();
    if (userId) query = query.where("user_id", "=", userId);
    if (shopId) query = query.where("shop_id", "=", shopId);
    return json(await query.execute());
  }

  // ── GET /shop-owners/:id ──────────────────────────────────────────────────────
  if (req.method === "GET" && id) {
    const row = await db
      .selectFrom("shop_owner")
      .selectAll()
      .where("id", "=", id)
      .executeTakeFirst();
    if (!row) return jsonError("Shop owner not found", 404);
    return json(row);
  }

  // ── DELETE /shop-owners/:id ───────────────────────────────────────────────────
  if (req.method === "DELETE" && id) {
    const result = await db.deleteFrom("shop_owner").where("id", "=", id).executeTakeFirst();
    if (!result.numDeletedRows) return jsonError("Shop owner not found", 404);
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
