import { db, supabaseAdmin } from "../_shared/config.ts";
import type { ShopItemInsert, ShopItemUpdate } from "../../types/schema/public.ts";

const COLS = [
  "id",
  "shop_id",
  "type",
  "name",
  "description",
  "price",
  "quantity",
  "is_active",
  "active_until",
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
  const match = pathname.match(/^\/shop-items\/([^/]+)$/);
  return match ? match[1] : null;
}

// ── Handler ───────────────────────────────────────────────────────────────────

Deno.serve(async (req: Request) => {
  const url = new URL(req.url);
  const id = parseId(url.pathname);

  // ── GET /shop-items — public; optional ?shop_id= and ?active_only=true ────────
  if (req.method === "GET" && !id) {
    const shopId = url.searchParams.get("shop_id");
    const activeOnly = url.searchParams.get("active_only") === "true";
    let query = db.selectFrom("shop_item").select(COLS);
    if (shopId) query = query.where("shop_id", "=", shopId);
    if (activeOnly) query = query.where("is_active", "=", true);
    return json(await query.execute());
  }

  // ── GET /shop-items/:id — public ─────────────────────────────────────────────
  if (req.method === "GET" && id) {
    const item = await db
      .selectFrom("shop_item")
      .select(COLS)
      .where("id", "=", id)
      .executeTakeFirst();
    if (!item) return jsonError("Shop item not found", 404);
    return json(item);
  }

  // ── Auth wall — writes require a valid JWT ────────────────────────────────────

  const { user, error: authError } = await requireAuth(req);
  if (!user) return jsonError(authError ?? "Unauthorized", 401);

  // ── POST /shop-items ──────────────────────────────────────────────────────────
  if (req.method === "POST" && !id) {
    const body = await req.json().catch(() => null);
    const { shop_id, type, name, description, price, quantity, is_active, active_until } = body ?? {};

    if (!shop_id || !type || !name || price == null || quantity == null) {
      return jsonError("Missing required fields: shop_id, type, name, price, quantity", 400);
    }
    if (!["equipment", "supplement", "gift_card"].includes(type)) {
      return jsonError("type must be 'equipment', 'supplement', or 'gift_card'", 400);
    }
    if (!Number.isInteger(quantity) || quantity < 1) {
      return jsonError("quantity must be a positive integer", 400);
    }

    const insert: ShopItemInsert = {
      shop_id,
      type,
      name,
      description: description ?? null,
      price,
      quantity,
      is_active: is_active ?? true,
      active_until: active_until ?? null,
    };

    const item = await db
      .insertInto("shop_item")
      .values(insert)
      .returning(COLS)
      .executeTakeFirstOrThrow();
    return json(item, 201);
  }

  // ── PUT /shop-items/:id ───────────────────────────────────────────────────────
  if (req.method === "PUT" && id) {
    const body = await req.json().catch(() => null);
    if (!body || Object.keys(body).length === 0) {
      return jsonError("Body must not be empty", 400);
    }
    const { id: _id, shop_id: _sid, ...fields } = body;
    const update: ShopItemUpdate = fields;
    const item = await db
      .updateTable("shop_item")
      .set(update)
      .where("id", "=", id)
      .returning(COLS)
      .executeTakeFirst();
    if (!item) return jsonError("Shop item not found", 404);
    return json(item);
  }

  // ── DELETE /shop-items/:id ────────────────────────────────────────────────────
  if (req.method === "DELETE" && id) {
    const result = await db
      .deleteFrom("shop_item")
      .where("id", "=", id)
      .executeTakeFirst();
    if (!result.numDeletedRows) return jsonError("Shop item not found", 404);
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
