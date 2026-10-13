import { type Kysely, sql, type Transaction } from "npm:kysely@^0.27";
import { db } from "../_shared/config.ts";
import { canStaffShop, forbidden, json, jsonError, requireCaller } from "../_shared/auth.ts";
import { notify } from "../_shared/notify.ts";
import { paymentsCurrency, refundPaymentIntent, stripeEnabled, stripeRequest } from "../_shared/stripe.ts";
import type { Database, OrderStatus } from "../../types/schema/public.ts";

// Shop orders live in the `invoice` / `invoice_item` tables (000003 + 000012):
// one invoice row per order, one invoice_item per product with a unit_price
// snapshot. Stock (shop_item.quantity) is reserved when the order is placed
// and returned when it is cancelled.

const STATUSES: OrderStatus[] = ["pending", "paid", "fulfilled", "cancelled"];
const PAYMENT_METHODS = ["card", "pay_at_pickup"] as const;
type PaymentMethod = (typeof PAYMENT_METHODS)[number];
const MAX_QUANTITY = 999;

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const isUuid = (v: unknown): v is string => typeof v === "string" && UUID_RE.test(v);

type Db = Kysely<Database> | Transaction<Database>;

/** Thrown inside a transaction to roll it back and answer with this error. */
class OrderError extends Error {
  constructor(message: string, readonly status: number, readonly extra?: Record<string, unknown>) {
    super(message);
  }
}

// ── Path parsing ──────────────────────────────────────────────────────────────

type Route =
  | { name: "shops" | "collection" }
  | { name: "one" | "status"; id: string }
  | null;

function parseRoute(pathname: string): Route {
  const path = pathname.replace(/\/+$/, "");
  if (path === "/orders") return { name: "collection" };
  if (path === "/orders/shops") return { name: "shops" };
  const status = path.match(/^\/orders\/([^/]+)\/status$/);
  if (status && isUuid(status[1])) return { name: "status", id: status[1] };
  const one = path.match(/^\/orders\/([^/]+)$/);
  if (one && isUuid(one[1])) return { name: "one", id: one[1] };
  return null;
}

// ── Queries ───────────────────────────────────────────────────────────────────

function orderQuery(q: Db = db) {
  return q
    .selectFrom("invoice as o")
    .leftJoin("business as b", "b.id", "o.shop_id")
    .leftJoin("users as u", "u.id", "o.user_id")
    .select([
      "o.id",
      "o.shop_id",
      "b.name as shop_name",
      "b.logo as shop_logo",
      "o.user_id",
      sql<string | null>`NULLIF(TRIM(CONCAT(u.name, ' ', u.last_name)), '')`.as("buyer_name"),
      "u.email as buyer_email",
      "o.status",
      "o.payment_method",
      "o.note",
      "o.total",
      "o.created_at",
      "o.paid_at",
      "o.fulfilled_at",
      "o.cancelled_at",
      // Latest card payment attempt, so the app knows whether "Pay now" makes sense.
      sql<string | null>`(
        SELECT p.status::text FROM payment p WHERE p.order_id = o.id ORDER BY p.created_at DESC LIMIT 1
      )`.as("payment_status"),
    ])
    .where("o.shop_id", "is not", null);
}

type OrderRow = Awaited<ReturnType<ReturnType<typeof orderQuery>["executeTakeFirstOrThrow"]>>;

type OrderItem = {
  id: string;
  shop_item_id: string;
  name: string;
  type: string;
  image_url: string | null;
  quantity: number;
  unit_price: string;
  line_total: string;
};

async function itemsFor(orderIds: string[]): Promise<Map<string, OrderItem[]>> {
  const map = new Map<string, OrderItem[]>();
  if (orderIds.length === 0) return map;
  const rows = await db
    .selectFrom("invoice_item as ii")
    .innerJoin("shop_item as si", "si.id", "ii.shop_item_id")
    .select([
      "ii.id",
      "ii.invoice_id",
      "ii.shop_item_id",
      "si.name",
      "si.type",
      "si.image_url",
      "ii.quantity",
      sql<string>`COALESCE(ii.unit_price, si.price)`.as("unit_price"),
      sql<string>`(ii.quantity * COALESCE(ii.unit_price, si.price))::numeric(10,2)`.as("line_total"),
    ])
    .where("ii.invoice_id", "in", orderIds)
    .orderBy("si.name")
    .execute();
  for (const { invoice_id, ...item } of rows) {
    const list = map.get(invoice_id) ?? [];
    list.push(item);
    map.set(invoice_id, list);
  }
  return map;
}

async function withItems(orders: OrderRow[]) {
  const items = await itemsFor(orders.map((o) => o.id));
  return orders.map((o) => {
    const list = items.get(o.id) ?? [];
    return {
      ...o,
      items: list,
      item_count: list.reduce((n, i) => n + i.quantity, 0),
    };
  });
}

async function loadOrder(id: string) {
  const row = await orderQuery().where("o.id", "=", id).executeTakeFirst();
  if (!row) return null;
  return (await withItems([row]))[0];
}

async function shopStaffIds(shopId: string): Promise<string[]> {
  const rows = await db.selectFrom("shop_owner").select("user_id").where("shop_id", "=", shopId)
    .union(db.selectFrom("shop_vendor").select("user_id").where("shop_id", "=", shopId))
    .execute();
  return rows.map((r) => r.user_id);
}

function formatMoney(amount: string | number): string {
  const currency = paymentsCurrency().toUpperCase();
  try {
    return new Intl.NumberFormat("en-US", { style: "currency", currency }).format(Number(amount));
  } catch {
    return Number(amount).toFixed(2);
  }
}

// ── Status changes ────────────────────────────────────────────────────────────

/**
 * Whether `actor` may move an order from `from` to `to`. Staff run the counter;
 * the buyer can only back out while nothing has happened yet.
 */
function allowedTransition(from: OrderStatus, to: OrderStatus, isStaff: boolean, isBuyer: boolean): boolean {
  if (isStaff) {
    if (from === "pending" && (to === "paid" || to === "cancelled")) return true;
    if (from === "paid" && (to === "fulfilled" || to === "cancelled")) return true;
  }
  if (isBuyer && from === "pending" && to === "cancelled") return true;
  return false;
}

const STATUS_COPY: Record<OrderStatus, string> = {
  pending: "is pending",
  paid: "is paid",
  fulfilled: "is complete",
  cancelled: "was cancelled",
};

/**
 * After a cancellation: expire open Checkout Sessions and refund a succeeded
 * card payment. Returns how the refund went (null when there was nothing to refund).
 */
async function settleCancelledPayments(orderId: string): Promise<"refunded" | "failed" | "manual" | null> {
  const payments = await db.selectFrom("payment")
    .select(["id", "status", "stripe_checkout_session_id", "stripe_payment_intent_id"])
    .where("order_id", "=", orderId)
    .where("status", "in", ["pending", "succeeded"])
    .execute();

  let refund: "refunded" | "failed" | "manual" | null = null;
  for (const p of payments) {
    if (p.status === "pending") {
      if (stripeEnabled() && p.stripe_checkout_session_id) {
        await stripeRequest("POST", `/checkout/sessions/${encodeURIComponent(p.stripe_checkout_session_id)}/expire`)
          .catch(() => {}); // already completed or expired
      }
      await db.updateTable("payment").set({ status: "cancelled", updated_at: sql`NOW()` })
        .where("id", "=", p.id).where("status", "=", "pending").execute();
      continue;
    }
    if (!stripeEnabled() || !p.stripe_payment_intent_id) {
      refund = "manual";
      continue;
    }
    try {
      await refundPaymentIntent(p.stripe_payment_intent_id, `refund-${p.id}`);
      await db.updateTable("payment").set({ status: "refunded", updated_at: sql`NOW()` })
        .where("id", "=", p.id).execute();
      refund = "refunded";
    } catch (err) {
      console.error("order refund failed", orderId, p.id, err);
      refund = "failed";
    }
  }
  return refund;
}

// ── Handler ───────────────────────────────────────────────────────────────────

Deno.serve(async (req: Request) => {
  const url = new URL(req.url);
  const route = parseRoute(url.pathname);
  if (!route) return jsonError("Not found", 404);

  const { caller, response } = await requireCaller(req);
  if (response) return response;

  // ── GET /orders/shops — storefront: every shop + active item count ───────────
  if (route.name === "shops" && req.method === "GET") {
    const rows = await db
      .selectFrom("shop")
      .innerJoin("business as b", "b.id", "shop.id")
      .select([
        "b.id",
        "b.name",
        "b.location",
        "b.logo",
        "b.working_hours_from",
        "b.working_hours_to",
        sql<number>`(
          SELECT COUNT(*)::int FROM shop_item si
          WHERE si.shop_id = b.id AND si.is_active
            AND (si.active_until IS NULL OR si.active_until > NOW())
        )`.as("active_item_count"),
      ])
      .orderBy("b.name")
      .execute();
    return json(rows);
  }

  // ── POST /orders ─────────────────────────────────────────────────────────────
  // { shop_id, items: [{ shop_item_id, quantity }], payment_method, note? }
  if (route.name === "collection" && req.method === "POST") {
    const body = await req.json().catch(() => null);
    const { shop_id, items, payment_method, note } = body ?? {};
    if (!isUuid(shop_id)) return jsonError("shop_id is required", 400);
    if (!Array.isArray(items) || items.length === 0) return jsonError("items must be a non-empty list", 400);
    if (!PAYMENT_METHODS.includes(payment_method)) {
      return jsonError("payment_method must be 'card' or 'pay_at_pickup'", 400);
    }
    if (payment_method === "card" && !stripeEnabled()) {
      return jsonError("Card payments aren't available — choose pay at pickup", 400, { code: "not_configured" });
    }
    if (note != null && (typeof note !== "string" || note.length > 1000)) {
      return jsonError("note must be text up to 1000 characters", 400);
    }

    // Merge duplicate lines (invoice_item is unique per order + product).
    const wanted = new Map<string, number>();
    for (const line of items) {
      const qty = line?.quantity;
      if (!isUuid(line?.shop_item_id)) return jsonError("Each item needs a shop_item_id", 400);
      if (!Number.isInteger(qty) || qty < 1 || qty > MAX_QUANTITY) {
        return jsonError(`quantity must be a whole number between 1 and ${MAX_QUANTITY}`, 400);
      }
      wanted.set(line.shop_item_id, (wanted.get(line.shop_item_id) ?? 0) + qty);
    }

    const shop = await db.selectFrom("shop").innerJoin("business as b", "b.id", "shop.id")
      .select(["b.id", "b.name"]).where("shop.id", "=", shop_id).executeTakeFirst();
    if (!shop) return jsonError("Shop not found", 400);

    let orderId: string;
    try {
      orderId = await db.transaction().execute(async (trx) => {
        // Lock in id order so concurrent orders can't deadlock each other.
        const rows = await trx
          .selectFrom("shop_item")
          .select([
            "id",
            "shop_id",
            "name",
            "price",
            "quantity",
            "is_active",
            sql<boolean>`active_until IS NOT NULL AND active_until < NOW()`.as("expired"),
          ])
          .where("id", "in", [...wanted.keys()])
          .orderBy("id")
          .forUpdate()
          .execute();
        const byId = new Map(rows.map((r) => [r.id, r]));

        for (const [itemId, qty] of wanted) {
          const item = byId.get(itemId);
          if (!item) throw new OrderError("An item in your cart no longer exists", 400, { code: "item_not_found", shop_item_id: itemId });
          if (item.shop_id !== shop_id) {
            throw new OrderError(`${item.name} isn't sold by ${shop.name}`, 400, { code: "wrong_shop", shop_item_id: itemId });
          }
          if (!item.is_active || item.expired) {
            throw new OrderError(`${item.name} is no longer available`, 409, { code: "item_inactive", shop_item_id: itemId });
          }
          if (item.quantity < qty) {
            throw new OrderError(
              item.quantity === 0
                ? `${item.name} is out of stock`
                : `Only ${item.quantity} × ${item.name} left in stock`,
              409,
              { code: "out_of_stock", shop_item_id: itemId, available: item.quantity },
            );
          }
        }

        for (const [itemId, qty] of wanted) {
          await trx.updateTable("shop_item").set({ quantity: sql`quantity - ${qty}` }).where("id", "=", itemId)
            .execute();
        }
        const order = await trx.insertInto("invoice").values({
          user_id: caller.id,
          shop_id,
          payment_method: payment_method as PaymentMethod,
          note: typeof note === "string" && note.trim() ? note.trim() : null,
        }).returning("id").executeTakeFirstOrThrow();
        await trx.insertInto("invoice_item").values(
          [...wanted].map(([itemId, qty]) => ({
            invoice_id: order.id,
            shop_item_id: itemId,
            quantity: qty,
            unit_price: byId.get(itemId)!.price,
          })),
        ).execute();
        return order.id;
      });
    } catch (err) {
      if (err instanceof OrderError) return jsonError(err.message, err.status, err.extra);
      throw err;
    }

    const order = (await loadOrder(orderId))!;
    const buyer = `${caller.name} ${caller.last_name}`.trim() || "A customer";
    await notify((await shopStaffIds(shop_id)).filter((id) => id !== caller.id), {
      type: "purchase_made",
      title: `New order at ${shop.name}`,
      body: `${buyer} ordered ${order.item_count} item${order.item_count === 1 ? "" : "s"} · ${
        formatMoney(order.total)
      } (${payment_method === "card" ? "card" : "pay at pickup"}).`,
      metadata: { order_id: orderId, shop_id, shop_name: shop.name },
    });
    return json(order, 201);
  }

  // ── GET /orders — mine, or ?shop_id= for shop staff; optional ?status= ───────
  if (route.name === "collection" && req.method === "GET") {
    const shopId = url.searchParams.get("shop_id");
    const status = url.searchParams.get("status");
    let query = orderQuery();
    if (shopId) {
      if (!isUuid(shopId)) return jsonError("Invalid shop_id", 400);
      if (!(await canStaffShop(caller, shopId))) return forbidden();
      query = query.where("o.shop_id", "=", shopId);
    } else {
      query = query.where("o.user_id", "=", caller.id);
    }
    if (status) {
      if (!STATUSES.includes(status as OrderStatus)) {
        return jsonError("status must be 'pending', 'paid', 'fulfilled' or 'cancelled'", 400);
      }
      query = query.where("o.status", "=", status as OrderStatus);
    }
    const rows = await query.orderBy("o.created_at", "desc").limit(200).execute();
    return json(await withItems(rows));
  }

  // ── GET /orders/:id — buyer or shop staff ────────────────────────────────────
  if (route.name === "one" && req.method === "GET") {
    const order = await loadOrder(route.id);
    if (!order) return jsonError("Order not found", 404);
    if (order.user_id !== caller.id && !(await canStaffShop(caller, order.shop_id!))) return forbidden();
    return json(order);
  }

  // ── PUT /orders/:id/status { status } ────────────────────────────────────────
  if (route.name === "status" && req.method === "PUT") {
    const body = await req.json().catch(() => null);
    const to = body?.status as OrderStatus;
    if (!STATUSES.includes(to)) {
      return jsonError("status must be 'pending', 'paid', 'fulfilled' or 'cancelled'", 400);
    }

    const current = await db.selectFrom("invoice").select(["id", "user_id", "shop_id"])
      .where("id", "=", route.id).where("shop_id", "is not", null).executeTakeFirst();
    if (!current) return jsonError("Order not found", 404);
    const isStaff = await canStaffShop(caller, current.shop_id!);
    const isBuyer = current.user_id === caller.id;
    if (!isStaff && !isBuyer) return forbidden();

    try {
      await db.transaction().execute(async (trx) => {
        const locked = await trx.selectFrom("invoice").select(["status"]).where("id", "=", route.id).forUpdate()
          .executeTakeFirstOrThrow();
        if (locked.status === to) throw new OrderError(`This order ${STATUS_COPY[to]} already`, 409);
        if (!allowedTransition(locked.status, to, isStaff, isBuyer)) {
          throw new OrderError(
            isStaff ? `Can't change an order from ${locked.status} to ${to}` : "You can only cancel an order while it's pending",
            isStaff ? 409 : 403,
          );
        }
        const stamp = to === "paid" ? { paid_at: sql<string>`NOW()` }
          : to === "fulfilled" ? { fulfilled_at: sql<string>`NOW()` }
          : to === "cancelled" ? { cancelled_at: sql<string>`NOW()` }
          : {};
        await trx.updateTable("invoice").set({ status: to, ...stamp }).where("id", "=", route.id).execute();
        if (to === "cancelled") {
          // Return the reserved stock.
          await sql`
            UPDATE shop_item si SET quantity = si.quantity + ii.quantity
            FROM invoice_item ii
            WHERE ii.invoice_id = ${route.id} AND si.id = ii.shop_item_id
          `.execute(trx);
        }
      });
    } catch (err) {
      if (err instanceof OrderError) return jsonError(err.message, err.status, err.extra);
      throw err;
    }

    const refund = to === "cancelled" ? await settleCancelledPayments(route.id) : null;
    const order = (await loadOrder(route.id))!;

    const notice = {
      type: "order_update" as const,
      title: `Order at ${order.shop_name ?? "the shop"} ${STATUS_COPY[to]}`,
      body: to === "cancelled"
        ? refund === "refunded"
          ? "Your card payment has been refunded."
          : refund === "failed" || refund === "manual"
          ? "Contact the shop about refunding your card payment."
          : "The items were returned to the shop."
        : to === "fulfilled"
        ? "Thanks for your purchase!"
        : `Total ${formatMoney(order.total)}.`,
      metadata: { order_id: order.id, shop_id: order.shop_id, status: to, shop_name: order.shop_name },
    };
    if (isBuyer && !isStaff) {
      // The buyer backed out: tell the shop instead.
      const who = order.buyer_name ?? "The customer";
      await notify((await shopStaffIds(order.shop_id!)).filter((id) => id !== caller.id), {
        ...notice,
        title: `${who} cancelled an order`,
        body: `${order.item_count} item${order.item_count === 1 ? "" : "s"} were returned to stock.`,
      });
    } else if (order.user_id && order.user_id !== caller.id) {
      await notify([order.user_id], notice);
    }

    return json({ ...order, ...(refund && { refund_status: refund }) });
  }

  return jsonError("Not found", 404);
});
