import { db } from "../_shared/config.ts";
import { canStaffShop, forbidden, json, jsonError, requireCaller } from "../_shared/auth.ts";
import type { ShopItemInsert, ShopItemType, ShopItemUpdate } from "../../types/schema/public.ts";
import { pgCode } from "../_shared/roles.ts";
import { businessName, notify } from "../_shared/notify.ts";

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
  "image_url",
] as const;

const ITEM_TYPES: ShopItemType[] = ["equipment", "supplement", "gift_card"];

// Columns a PUT may change (shop_id is immutable).
const UPDATABLE = [
  "type",
  "name",
  "description",
  "price",
  "quantity",
  "is_active",
  "active_until",
  "image_url",
] as const;

// ── Helpers ───────────────────────────────────────────────────────────────────

/**
 * Item restocked (0 → n): tell buyers whose recent order with it was cancelled
 * (typically because it ran out) that it's back.
 */
async function notifyBackInStock(itemId: string, shopId: string, itemName: string): Promise<void> {
  const rows = await db
    .selectFrom("invoice_item as ii")
    .innerJoin("invoice as o", "o.id", "ii.invoice_id")
    .select("o.user_id")
    .distinct()
    .where("ii.shop_item_id", "=", itemId)
    .where("o.status", "=", "cancelled")
    .where("o.user_id", "is not", null)
    .where("o.cancelled_at", ">", new Date(Date.now() - 60 * 24 * 3600 * 1000).toISOString())
    .execute();
  if (rows.length === 0) return;
  const shopName = await businessName(shopId);
  await notify(rows.map((r) => r.user_id!), {
    type: "shop_item_update",
    title: `${itemName} is back in stock`,
    body: `${shopName} has ${itemName} available again.`,
    metadata: { shop_item_id: itemId, shop_id: shopId, shop_name: shopName },
  });
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

  // ── Auth wall — writes require shop staff (owner or vendor) ──────────────────

  const { caller, response } = await requireCaller(req);
  if (response) return response;

  // ── POST /shop-items ──────────────────────────────────────────────────────────
  if (req.method === "POST" && !id) {
    const body = await req.json().catch(() => null);
    const { shop_id, type, name, description, price, quantity, is_active, active_until, image_url } =
      body ?? {};

    if (!shop_id || !type || !name || price == null || quantity == null) {
      return jsonError("Missing required fields: shop_id, type, name, price, quantity", 400);
    }
    if (!ITEM_TYPES.includes(type)) {
      return jsonError("type must be 'equipment', 'supplement', or 'gift_card'", 400);
    }
    if (!Number.isInteger(quantity) || quantity < 0) {
      return jsonError("quantity must be a whole number of 0 or more", 400);
    }
    if (!(await canStaffShop(caller, shop_id))) return forbidden();

    const insert: ShopItemInsert = {
      shop_id,
      type,
      name,
      description: description ?? null,
      price,
      quantity,
      is_active: is_active ?? true,
      active_until: active_until ?? null,
      image_url: image_url ?? null,
    };

    try {
      const item = await db
        .insertInto("shop_item")
        .values(insert)
        .returning(COLS)
        .executeTakeFirstOrThrow();
      return json(item, 201);
    } catch (err) {
      if (pgCode(err) === "23503") return jsonError("Shop not found", 400);
      throw err;
    }
  }

  // ── PUT /shop-items/:id ───────────────────────────────────────────────────────
  if (req.method === "PUT" && id) {
    const body = await req.json().catch(() => null);
    if (!body || typeof body !== "object") return jsonError("Body must not be empty", 400);

    const update: ShopItemUpdate = {};
    for (const key of UPDATABLE) {
      if (key in body) (update as Record<string, unknown>)[key] = body[key];
    }
    if (Object.keys(update).length === 0) return jsonError("Body must not be empty", 400);
    if (update.type !== undefined && !ITEM_TYPES.includes(update.type as ShopItemType)) {
      return jsonError("type must be 'equipment', 'supplement', or 'gift_card'", 400);
    }
    if (update.quantity !== undefined && (!Number.isInteger(update.quantity) || update.quantity < 0)) {
      return jsonError("quantity must be a whole number of 0 or more", 400);
    }

    const existing = await db.selectFrom("shop_item").select(["shop_id", "quantity"]).where("id", "=", id)
      .executeTakeFirst();
    if (!existing) return jsonError("Shop item not found", 404);
    if (!(await canStaffShop(caller, existing.shop_id))) return forbidden();

    const item = await db
      .updateTable("shop_item")
      .set(update)
      .where("id", "=", id)
      .returning(COLS)
      .executeTakeFirst();
    if (!item) return jsonError("Shop item not found", 404);
    if (existing.quantity === 0 && item.quantity > 0 && item.is_active) {
      await notifyBackInStock(item.id, item.shop_id, item.name);
    }
    return json(item);
  }

  // ── DELETE /shop-items/:id ────────────────────────────────────────────────────
  if (req.method === "DELETE" && id) {
    const existing = await db.selectFrom("shop_item").select("shop_id").where("id", "=", id)
      .executeTakeFirst();
    if (!existing) return jsonError("Shop item not found", 404);
    if (!(await canStaffShop(caller, existing.shop_id))) return forbidden();

    try {
      await db.deleteFrom("shop_item").where("id", "=", id).execute();
    } catch (err) {
      if (pgCode(err) === "23503") {
        return jsonError("This item appears on invoices — deactivate it instead", 409);
      }
      throw err;
    }
    return new Response(null, { status: 204 });
  }

  return jsonError("Not found", 404);
});
