import { type Kysely, sql, type Transaction } from "npm:kysely@^0.27";
import { db } from "../_shared/config.ts";
import {
  type Caller,
  canStaffGym,
  forbidden,
  isSuperUser,
  json,
  jsonError,
  requireCaller,
} from "../_shared/auth.ts";
import { businessName, gymOwnerIds, notify, optionalSecret } from "../_shared/notify.ts";
import {
  cancelSubscriptionAtPeriodEnd,
  fromMinorUnits,
  notConfigured,
  paymentsCurrency,
  refundPaymentIntent,
  StripeError,
  type StripeObject,
  type StripeParams,
  stripeEnabled,
  stripeRequest,
  stripeWebhookSecret,
  toMinorUnits,
  verifyStripeSignature,
} from "../_shared/stripe.ts";
import type { Database, PaymentKind } from "../../types/schema/public.ts";

// verify_jwt is off for this function (Stripe calls the webhook without a JWT),
// so every route except the webhook authenticates with requireCaller itself.

const PAYMENT_COLS = [
  "id",
  "user_id",
  "kind",
  "membership_invoice_id",
  "order_id",
  "membership_type_id",
  "membership_id",
  "stripe_checkout_session_id",
  "stripe_payment_intent_id",
  "stripe_subscription_id",
  "amount",
  "currency",
  "status",
  "created_at",
  "updated_at",
] as const;

const MONTH_OPTIONS = [1, 3, 6, 12];

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const isUuid = (v: unknown): v is string => typeof v === "string" && UUID_RE.test(v);

// The app listens for this scheme. NOTE: Stripe accepts custom-scheme
// success/cancel URLs in test mode, but live mode may require https — set
// PAYMENT_RETURN_URL to an https page (that redirects into the app) for live.
const DEFAULT_RETURN_URL = "gymbroo://payments/return";

type Db = Kysely<Database> | Transaction<Database>;

// ── Path parsing ──────────────────────────────────────────────────────────────

type Route =
  | { name: "config" | "checkout" | "webhook" | "gyms" | "list" }
  | { name: "one"; id: string }
  | { name: "cancelAutoRenew"; id: string }
  | { name: "cancel"; id: string }
  | null;

function parseRoute(pathname: string): Route {
  const path = pathname.replace(/\/+$/, "");
  if (path === "/payments") return { name: "list" };
  if (path === "/payments/config") return { name: "config" };
  if (path === "/payments/checkout") return { name: "checkout" };
  if (path === "/payments/webhook") return { name: "webhook" };
  if (path === "/payments/gyms") return { name: "gyms" };
  const cancel = path.match(/^\/payments\/memberships\/([^/]+)\/cancel-auto-renew$/);
  if (cancel && isUuid(cancel[1])) return { name: "cancelAutoRenew", id: cancel[1] };
  const cancelPayment = path.match(/^\/payments\/([^/]+)\/cancel$/);
  if (cancelPayment && isUuid(cancelPayment[1])) return { name: "cancel", id: cancelPayment[1] };
  const one = path.match(/^\/payments\/([^/]+)$/);
  if (one && isUuid(one[1])) return { name: "one", id: one[1] };
  return null;
}

// ── Helpers ───────────────────────────────────────────────────────────────────

function returnUrls(paymentId: string): { success_url: string; cancel_url: string } {
  const base = optionalSecret("PAYMENT_RETURN_URL") ?? DEFAULT_RETURN_URL;
  const sep = base.includes("?") ? "&" : "?";
  return {
    success_url: `${base}${sep}status=success&payment_id=${paymentId}`,
    cancel_url: `${base}${sep}status=cancelled&payment_id=${paymentId}`,
  };
}

function stripeFailure(err: unknown): Response {
  if (err instanceof StripeError) {
    if (err.code === "not_configured") return notConfigured();
    console.error("stripe error", err.status, err.code, err.message);
    return jsonError(`Payment provider error: ${err.message}`, 502, { code: "stripe_error" });
  }
  throw err;
}

/**
 * Creates the Checkout Session for a pending payment row and stores its id.
 * On failure the payment is marked failed and the error response returned.
 */
async function startCheckout(
  caller: Caller,
  paymentId: string,
  params: StripeParams,
): Promise<Response> {
  let session: StripeObject;
  try {
    session = await stripeRequest("POST", "/checkout/sessions", {
      ...returnUrls(paymentId),
      client_reference_id: paymentId,
      customer_email: caller.email || undefined,
      ...params,
      metadata: { payment_id: paymentId, ...(params.metadata as StripeParams | undefined) },
    }, `checkout-${paymentId}`);
  } catch (err) {
    await db.updateTable("payment").set({ status: "failed", updated_at: sql`NOW()` })
      .where("id", "=", paymentId).execute();
    return stripeFailure(err);
  }
  await db.updateTable("payment")
    .set({ stripe_checkout_session_id: session.id, updated_at: sql`NOW()` })
    .where("id", "=", paymentId)
    .execute();
  return json({ url: session.url, payment_id: paymentId }, 201);
}

function lineItem(name: string, unitAmount: number, quantity: number, currency: string): StripeParams {
  return { price_data: { currency, unit_amount: unitAmount, product_data: { name } }, quantity };
}

function paymentMetadata(p: {
  id: string;
  kind: PaymentKind;
  membership_invoice_id: string | null;
  order_id: string | null;
  membership_id: string | null;
}): Record<string, unknown> {
  return {
    payment_id: p.id,
    kind: p.kind,
    ...(p.membership_invoice_id && { invoice_id: p.membership_invoice_id }),
    ...(p.order_id && { order_id: p.order_id }),
    ...(p.membership_id && { membership_id: p.membership_id }),
  };
}

function formatMoney(amount: string | number, currency: string): string {
  try {
    return new Intl.NumberFormat("en-US", { style: "currency", currency: currency.toUpperCase() })
      .format(Number(amount));
  } catch {
    return `${Number(amount).toFixed(2)} ${currency.toUpperCase()}`;
  }
}

/** Active membership of the user at the gym, newest end date first. */
function activeMembershipAt(q: Db, userId: string, gymId: string) {
  return q
    .selectFrom("membership as m")
    .innerJoin("gym_membership_type as t", "t.id", "m.current_membership_type_id")
    .select(["m.id", "m.auto_renew", "m.stripe_subscription_id"])
    .where("m.user_id", "=", userId)
    .where("t.gym_id", "=", gymId)
    .where("m.is_active", "=", true)
    .orderBy("m.to_date", "desc");
}

// ── Checkout ──────────────────────────────────────────────────────────────────

async function checkoutInvoice(caller: Caller, invoiceId: unknown): Promise<Response> {
  if (!isUuid(invoiceId)) return jsonError("invoice_id must be a valid id", 400);
  const inv = await db
    .selectFrom("membership_invoice as mi")
    .innerJoin("membership as m", "m.id", "mi.membership_id")
    .innerJoin("gym_membership_type as t", "t.id", "mi.membership_type_id")
    .innerJoin("business as b", "b.id", "t.gym_id")
    .select(["mi.id", "mi.amount", "mi.status", "mi.membership_id", "mi.membership_type_id", "m.user_id",
      "t.name as type_name", "b.name as gym_name"])
    .where("mi.id", "=", invoiceId)
    .executeTakeFirst();
  if (!inv) return jsonError("Invoice not found", 404);
  if (inv.user_id !== caller.id) return forbidden("Only the member on this invoice can pay it");
  if (inv.status !== "unpaid") return jsonError(`This invoice is already ${inv.status}`, 409);

  const currency = paymentsCurrency();
  const payment = await db
    .insertInto("payment")
    .values({
      user_id: caller.id,
      kind: "invoice",
      membership_invoice_id: inv.id,
      membership_id: inv.membership_id,
      membership_type_id: inv.membership_type_id,
      amount: inv.amount,
      currency,
    })
    .returning("id")
    .executeTakeFirstOrThrow();

  return startCheckout(caller, payment.id, {
    mode: "payment",
    line_items: [lineItem(`${inv.gym_name} · ${inv.type_name} invoice`, toMinorUnits(inv.amount, currency), 1,
      currency)],
    payment_intent_data: { metadata: { payment_id: payment.id } },
  });
}

async function checkoutOrder(caller: Caller, orderId: unknown): Promise<Response> {
  if (!isUuid(orderId)) return jsonError("order_id must be a valid id", 400);
  const order = await db
    .selectFrom("invoice as o")
    .leftJoin("business as b", "b.id", "o.shop_id")
    .select(["o.id", "o.user_id", "o.status", "o.payment_method", "o.total", "b.name as shop_name"])
    .where("o.id", "=", orderId)
    .executeTakeFirst();
  if (!order) return jsonError("Order not found", 404);
  if (order.user_id !== caller.id) return forbidden("Only the buyer can pay for this order");
  if (order.status !== "pending") return jsonError(`This order is already ${order.status}`, 409);
  if (order.payment_method !== "card") return jsonError("This order is paid at pickup", 400);

  const paid = await db.selectFrom("payment").select("id")
    .where("order_id", "=", order.id).where("status", "=", "succeeded").executeTakeFirst();
  if (paid) return jsonError("This order is already paid", 409);

  const items = await db
    .selectFrom("invoice_item as ii")
    .innerJoin("shop_item as si", "si.id", "ii.shop_item_id")
    .select(["si.name", "ii.quantity", sql<string>`COALESCE(ii.unit_price, si.price)`.as("unit_price")])
    .where("ii.invoice_id", "=", order.id)
    .execute();
  if (items.length === 0) return jsonError("This order has no items", 400);

  const currency = paymentsCurrency();
  const payment = await db
    .insertInto("payment")
    .values({ user_id: caller.id, kind: "order", order_id: order.id, amount: order.total, currency })
    .returning("id")
    .executeTakeFirstOrThrow();

  return startCheckout(caller, payment.id, {
    mode: "payment",
    line_items: items.map((i) => lineItem(i.name, toMinorUnits(i.unit_price, currency), i.quantity, currency)),
    payment_intent_data: {
      metadata: { payment_id: payment.id },
      description: `Order at ${order.shop_name ?? "shop"}`,
    },
  });
}

async function checkoutMembership(
  caller: Caller,
  body: { membership_type_id?: unknown; months?: unknown; auto_renew?: unknown },
): Promise<Response> {
  const typeId = body.membership_type_id;
  if (!isUuid(typeId)) return jsonError("membership_type_id must be a valid id", 400);
  const autoRenew = body.auto_renew === true;
  const months = body.months == null ? 1 : Number(body.months);
  if (!autoRenew && !MONTH_OPTIONS.includes(months)) {
    return jsonError("months must be 1, 3, 6 or 12", 400);
  }

  const type = await db
    .selectFrom("gym_membership_type as t")
    .innerJoin("business as b", "b.id", "t.gym_id")
    .select(["t.id", "t.name", "t.monthly_cost", "t.gym_id", "t.is_active", "b.name as gym_name"])
    .where("t.id", "=", typeId)
    .executeTakeFirst();
  if (!type) return jsonError("Membership type not found", 404);
  if (!type.is_active) return jsonError("This membership type is no longer offered", 400);
  if (Number(type.monthly_cost) <= 0) return jsonError("This membership is free — ask the front desk", 400);

  if (autoRenew) {
    const existing = await activeMembershipAt(db, caller.id, type.gym_id)
      .where("m.auto_renew", "=", true)
      .executeTakeFirst();
    if (existing) return jsonError("You already have an auto-renewing membership at this gym", 409);
  }

  const currency = paymentsCurrency();
  const unit = toMinorUnits(type.monthly_cost, currency);
  const qty = autoRenew ? 1 : months;
  const payment = await db
    .insertInto("payment")
    .values({
      user_id: caller.id,
      kind: "membership",
      membership_type_id: type.id,
      amount: (Number(type.monthly_cost) * qty).toFixed(2),
      currency,
    })
    .returning("id")
    .executeTakeFirstOrThrow();

  const metadata = { payment_id: payment.id, months: String(qty), auto_renew: String(autoRenew) };
  if (autoRenew) {
    return startCheckout(caller, payment.id, {
      mode: "subscription",
      line_items: [{
        price_data: {
          currency,
          unit_amount: unit,
          recurring: { interval: "month" },
          product_data: { name: `${type.gym_name} · ${type.name} (monthly)` },
        },
        quantity: 1,
      }],
      metadata,
      subscription_data: { metadata },
    });
  }
  return startCheckout(caller, payment.id, {
    mode: "payment",
    line_items: [lineItem(`${type.gym_name} · ${type.name} (per month)`, unit, months, currency)],
    metadata,
    payment_intent_data: { metadata: { payment_id: payment.id } },
  });
}

// ── Webhook: fulfilment ───────────────────────────────────────────────────────

type Fulfilled = {
  payment: {
    id: string;
    user_id: string | null;
    kind: PaymentKind;
    amount: string;
    currency: string;
    membership_invoice_id: string | null;
    order_id: string | null;
    membership_id: string | null;
  };
  newMemberGymId?: string;
  refundIntentId?: string; // order was cancelled while the buyer was paying
};

/** Idempotently applies a successful Checkout Session. Returns null if already applied. */
async function fulfilCheckout(session: StripeObject): Promise<Fulfilled | null> {
  const paymentId: string | undefined = session.metadata?.payment_id ?? session.client_reference_id;
  if (!paymentId) {
    console.warn("checkout session without payment_id", session.id);
    return null;
  }
  const intentId = typeof session.payment_intent === "string" ? session.payment_intent : session.payment_intent?.id;
  const subscriptionId = typeof session.subscription === "string"
    ? session.subscription
    : session.subscription?.id;

  return await db.transaction().execute(async (trx) => {
    const p = await trx.selectFrom("payment").selectAll().where("id", "=", paymentId).forUpdate()
      .executeTakeFirst();
    if (!p) {
      console.warn("webhook for unknown payment", paymentId);
      return null;
    }
    if (p.status === "succeeded" || p.status === "refunded") return null;

    const result: Fulfilled = {
      payment: {
        id: p.id,
        user_id: p.user_id,
        kind: p.kind,
        amount: p.amount,
        currency: p.currency,
        membership_invoice_id: p.membership_invoice_id,
        order_id: p.order_id,
        membership_id: p.membership_id,
      },
    };

    await trx.updateTable("payment").set({
      status: "succeeded",
      stripe_checkout_session_id: session.id,
      stripe_payment_intent_id: intentId ?? null,
      stripe_subscription_id: subscriptionId ?? null,
      updated_at: sql`NOW()`,
    }).where("id", "=", p.id).execute();

    if (p.kind === "invoice" && p.membership_invoice_id) {
      await trx.updateTable("membership_invoice")
        .set({ status: "paid", paid_at: sql`NOW()` })
        .where("id", "=", p.membership_invoice_id)
        .where("status", "!=", "paid")
        .execute();
    } else if (p.kind === "order" && p.order_id) {
      const updated = await trx.updateTable("invoice")
        .set({ status: "paid", paid_at: sql`NOW()` })
        .where("id", "=", p.order_id)
        .where("status", "=", "pending")
        .returning("id")
        .executeTakeFirst();
      if (!updated) {
        const order = await trx.selectFrom("invoice").select("status").where("id", "=", p.order_id)
          .executeTakeFirst();
        if (order?.status === "cancelled" && intentId) result.refundIntentId = intentId;
      }
    } else if (p.kind === "membership" && p.user_id && p.membership_type_id) {
      const months = Math.max(1, Number(session.metadata?.months ?? 1) || 1);
      const applied = await applyMembershipPurchase(trx, {
        paymentId: p.id,
        userId: p.user_id,
        typeId: p.membership_type_id,
        amount: p.amount,
        months: subscriptionId ? 1 : months,
        subscriptionId: subscriptionId ?? null,
      });
      result.payment.membership_id = applied.membershipId;
      result.payment.membership_invoice_id = applied.invoiceId;
      if (applied.newMember) result.newMemberGymId = applied.gymId;
    }
    return result;
  });
}

/**
 * Adds the member row if missing, extends the user's active membership at the
 * gym (or creates one from today) and records a paid membership invoice.
 */
async function applyMembershipPurchase(
  trx: Transaction<Database>,
  p: {
    paymentId: string;
    userId: string;
    typeId: string;
    amount: string;
    months: number;
    subscriptionId: string | null;
  },
): Promise<{ membershipId: string; invoiceId: string; gymId: string; newMember: boolean }> {
  const type = await trx.selectFrom("gym_membership_type").select(["id", "gym_id"])
    .where("id", "=", p.typeId).executeTakeFirstOrThrow();

  const member = await trx.insertInto("member")
    .values({ user_id: p.userId, gym_id: type.gym_id })
    .onConflict((oc) => oc.columns(["user_id", "gym_id"]).doNothing())
    .returning("id")
    .executeTakeFirst();

  const subFields = p.subscriptionId ? { auto_renew: true, stripe_subscription_id: p.subscriptionId } : {};
  const existing = await activeMembershipAt(trx, p.userId, type.gym_id).forUpdate().executeTakeFirst();
  let membershipId: string;
  if (existing) {
    await trx.updateTable("membership").set({
      current_membership_type_id: type.id,
      to_date: sql`(GREATEST(to_date, CURRENT_DATE) + make_interval(months => ${p.months}))::date`,
      last_updated_date: sql`NOW()`,
      ...subFields,
    }).where("id", "=", existing.id).execute();
    membershipId = existing.id;
  } else {
    const created = await trx.insertInto("membership").values({
      user_id: p.userId,
      current_membership_type_id: type.id,
      from_date: sql`CURRENT_DATE`,
      to_date: sql`(CURRENT_DATE + make_interval(months => ${p.months}))::date`,
      ...subFields,
    }).returning("id").executeTakeFirstOrThrow();
    membershipId = created.id;
  }

  const invoice = await trx.insertInto("membership_invoice").values({
    membership_id: membershipId,
    membership_type_id: type.id,
    amount: p.amount,
    status: "paid",
    paid_at: sql`NOW()`,
  }).returning("id").executeTakeFirstOrThrow();

  await trx.updateTable("payment")
    .set({ membership_id: membershipId, membership_invoice_id: invoice.id })
    .where("id", "=", p.paymentId)
    .execute();

  return { membershipId, invoiceId: invoice.id, gymId: type.gym_id, newMember: !!member };
}

async function notifyFulfilled(f: Fulfilled): Promise<void> {
  const p = f.payment;
  if (!p.user_id) return;
  const amount = formatMoney(p.amount, p.currency);
  const what = p.kind === "order" ? "your order" : p.kind === "invoice" ? "your invoice" : "your membership";
  await notify([p.user_id], {
    type: "payment_received",
    title: "Payment received",
    body: `We received ${amount} for ${what}.`,
    metadata: paymentMetadata(p),
  });

  if (p.kind === "order" && p.order_id) {
    const order = await db.selectFrom("invoice").select(["shop_id"]).where("id", "=", p.order_id)
      .executeTakeFirst();
    if (order?.shop_id && !f.refundIntentId) {
      const staff = await db.selectFrom("shop_owner").select("user_id").where("shop_id", "=", order.shop_id)
        .union(db.selectFrom("shop_vendor").select("user_id").where("shop_id", "=", order.shop_id))
        .execute();
      await notify(staff.map((s) => s.user_id), {
        type: "purchase_made",
        title: "Order paid",
        body: `An order was paid by card (${amount}).`,
        metadata: { order_id: p.order_id, shop_id: order.shop_id },
      });
    }
  }

  if (f.newMemberGymId) {
    const gymId = f.newMemberGymId;
    const [gymName, user] = await Promise.all([
      businessName(gymId),
      db.selectFrom("users").select(["name", "last_name"]).where("id", "=", p.user_id).executeTakeFirst(),
    ]);
    const fullName = user ? `${user.name} ${user.last_name}`.trim() : "A new member";
    const owners = (await gymOwnerIds(gymId)).filter((id) => id !== p.user_id);
    await notify(owners, {
      type: "member_join",
      title: `${fullName} joined ${gymName}`,
      body: `${fullName} bought a membership in the app.`,
      metadata: { gym_id: gymId, user_id: p.user_id, gym_name: gymName },
    });
  }
}

/** Refunds a card payment for an order that was cancelled before the payment landed. */
async function refundCancelledOrder(f: Fulfilled): Promise<void> {
  if (!f.refundIntentId) return;
  try {
    await refundPaymentIntent(f.refundIntentId, `refund-${f.payment.id}`);
    await db.updateTable("payment").set({ status: "refunded", updated_at: sql`NOW()` })
      .where("id", "=", f.payment.id).execute();
    if (f.payment.user_id) {
      await notify([f.payment.user_id], {
        type: "order_update",
        title: "Payment refunded",
        body: "Your order was cancelled before the payment completed, so it was refunded.",
        metadata: { order_id: f.payment.order_id, status: "cancelled" },
      });
    }
  } catch (err) {
    console.error("refund for cancelled order failed", f.payment.id, err);
  }
}

/** Renewal of an auto-renewing membership: one more month + a paid invoice. */
async function handleInvoicePaid(invoice: StripeObject): Promise<void> {
  if (invoice.billing_reason !== "subscription_cycle") return;
  // `invoice.subscription` on older API versions, `parent.subscription_details` on newer ones.
  const sub = invoice.subscription ?? invoice.parent?.subscription_details?.subscription;
  const subscriptionId = typeof sub === "string" ? sub : sub?.id;
  if (!subscriptionId) return;

  const done = await db.transaction().execute(async (trx) => {
    const m = await trx.selectFrom("membership")
      .select(["id", "user_id", "current_membership_type_id"])
      .where("stripe_subscription_id", "=", subscriptionId)
      .forUpdate()
      .executeTakeFirst();
    if (!m) {
      console.warn("invoice.paid for unknown subscription", subscriptionId);
      return null;
    }
    const currency = String(invoice.currency ?? paymentsCurrency());
    const amount = fromMinorUnits(Number(invoice.amount_paid ?? 0), currency).toFixed(2);
    const intent = typeof invoice.payment_intent === "string" ? invoice.payment_intent : null;

    const payment = await trx.insertInto("payment").values({
      user_id: m.user_id,
      kind: "membership",
      membership_type_id: m.current_membership_type_id,
      membership_id: m.id,
      stripe_subscription_id: subscriptionId,
      stripe_invoice_id: invoice.id,
      stripe_payment_intent_id: intent,
      amount,
      currency,
      status: "succeeded",
    }).onConflict((oc) => oc.column("stripe_invoice_id").doNothing()).returning("id").executeTakeFirst();
    if (!payment) return null; // redelivered webhook

    await trx.updateTable("membership").set({
      to_date: sql`(GREATEST(to_date, CURRENT_DATE) + INTERVAL '1 month')::date`,
      is_active: true,
      last_updated_date: sql`NOW()`,
    }).where("id", "=", m.id).execute();

    const inv = await trx.insertInto("membership_invoice").values({
      membership_id: m.id,
      membership_type_id: m.current_membership_type_id,
      amount,
      status: "paid",
      paid_at: sql`NOW()`,
    }).returning("id").executeTakeFirstOrThrow();
    await trx.updateTable("payment").set({ membership_invoice_id: inv.id }).where("id", "=", payment.id).execute();

    return {
      id: payment.id,
      user_id: m.user_id,
      kind: "membership" as const,
      amount,
      currency,
      membership_invoice_id: inv.id,
      order_id: null,
      membership_id: m.id,
    };
  });
  if (done) await notifyFulfilled({ payment: done });
}

async function markCheckoutClosed(session: StripeObject, status: "cancelled" | "failed"): Promise<void> {
  const paymentId: string | undefined = session.metadata?.payment_id ?? session.client_reference_id;
  if (!paymentId) return;
  await db.updateTable("payment")
    .set({ status, updated_at: sql`NOW()` })
    .where("id", "=", paymentId)
    .where("status", "=", "pending")
    .execute();
}

async function handleEvent(event: StripeObject): Promise<void> {
  const obj = event.data?.object ?? {};
  switch (event.type) {
    case "checkout.session.completed":
    case "checkout.session.async_payment_succeeded": {
      // Delayed payment methods complete the session before the money arrives.
      if (event.type === "checkout.session.completed" && obj.payment_status === "unpaid") return;
      const f = await fulfilCheckout(obj);
      if (f) {
        await refundCancelledOrder(f);
        await notifyFulfilled(f);
      }
      return;
    }
    case "checkout.session.expired":
      return markCheckoutClosed(obj, "cancelled");
    case "checkout.session.async_payment_failed":
      return markCheckoutClosed(obj, "failed");
    case "invoice.paid":
      return handleInvoicePaid(obj);
    case "customer.subscription.updated":
      if (obj.cancel_at_period_end === true || obj.status === "canceled") {
        await db.updateTable("membership").set({ auto_renew: false })
          .where("stripe_subscription_id", "=", obj.id).execute();
      }
      return;
    case "customer.subscription.deleted":
      await db.updateTable("membership").set({ auto_renew: false })
        .where("stripe_subscription_id", "=", obj.id).execute();
      return;
    default:
      return;
  }
}

// ── Handler ───────────────────────────────────────────────────────────────────

Deno.serve(async (req: Request) => {
  const url = new URL(req.url);
  const route = parseRoute(url.pathname);
  if (!route) return jsonError("Not found", 404);

  // ── POST /payments/webhook — Stripe only, authenticated by signature ─────────
  if (route.name === "webhook") {
    if (req.method !== "POST") return jsonError("Not found", 404);
    const secret = stripeWebhookSecret();
    if (!stripeEnabled() || !secret) return notConfigured();

    // The signature covers the exact bytes, so read the raw text before parsing.
    const raw = await req.text();
    if (!(await verifyStripeSignature(req.headers.get("Stripe-Signature"), raw, secret))) {
      return jsonError("Invalid signature", 400);
    }
    let event: StripeObject;
    try {
      event = JSON.parse(raw);
    } catch {
      return jsonError("Invalid payload", 400);
    }
    try {
      await handleEvent(event);
    } catch (err) {
      // A 500 makes Stripe retry later; handlers are idempotent.
      console.error("webhook handling failed", event.type, event.id, err);
      return jsonError("Webhook handling failed", 500);
    }
    return json({ received: true });
  }

  const { caller, response } = await requireCaller(req);
  if (response) return response;

  // ── GET /payments/config ─────────────────────────────────────────────────────
  if (route.name === "config" && req.method === "GET") {
    return json({ enabled: stripeEnabled(), currency: paymentsCurrency() });
  }

  if (!stripeEnabled()) return notConfigured();

  // ── POST /payments/checkout ──────────────────────────────────────────────────
  // { kind: "invoice", invoice_id } | { kind: "order", order_id } |
  // { kind: "membership", membership_type_id, months?, auto_renew? } → { url, payment_id }
  if (route.name === "checkout" && req.method === "POST") {
    const body = await req.json().catch(() => null);
    if (!body || typeof body !== "object") return jsonError("Body must not be empty", 400);
    switch (body.kind) {
      case "invoice":
        return checkoutInvoice(caller, body.invoice_id);
      case "order":
        return checkoutOrder(caller, body.order_id);
      case "membership":
        return checkoutMembership(caller, body);
      default:
        return jsonError("kind must be 'invoice', 'order' or 'membership'", 400);
    }
  }

  // ── GET /payments — the caller's own payments, newest first ──────────────────
  if (route.name === "list" && req.method === "GET") {
    const rows = await db.selectFrom("payment").select(PAYMENT_COLS)
      .where("user_id", "=", caller.id)
      .orderBy("created_at", "desc")
      .limit(200)
      .execute();
    return json(rows);
  }

  // ── GET /payments/gyms — gyms with active membership types (buy flow) ────────
  if (route.name === "gyms" && req.method === "GET") {
    const gyms = await db
      .selectFrom("gym")
      .innerJoin("business as b", "b.id", "gym.id")
      .select(["b.id", "b.name", "b.location", "b.logo"])
      .orderBy("b.name")
      .execute();
    const types = await db
      .selectFrom("gym_membership_type")
      .select(["id", "gym_id", "name", "monthly_cost"])
      .where("is_active", "=", true)
      .orderBy("monthly_cost")
      .execute();
    const byGym = new Map<string, { id: string; name: string; monthly_cost: string }[]>();
    for (const t of types) {
      const list = byGym.get(t.gym_id) ?? [];
      list.push({ id: t.id, name: t.name, monthly_cost: t.monthly_cost });
      byGym.set(t.gym_id, list);
    }
    return json(
      gyms
        .map((g) => ({ ...g, types: byGym.get(g.id) ?? [] }))
        .filter((g) => g.types.length > 0),
    );
  }

  // ── POST /payments/memberships/:id/cancel-auto-renew ─────────────────────────
  if (route.name === "cancelAutoRenew" && req.method === "POST") {
    const m = await db
      .selectFrom("membership as m")
      .innerJoin("gym_membership_type as t", "t.id", "m.current_membership_type_id")
      .select(["m.id", "m.user_id", "m.stripe_subscription_id", "t.gym_id"])
      .where("m.id", "=", route.id)
      .executeTakeFirst();
    if (!m) return jsonError("Membership not found", 404);
    if (m.user_id !== caller.id && !(await canStaffGym(caller, m.gym_id))) return forbidden();

    if (m.stripe_subscription_id) {
      try {
        await cancelSubscriptionAtPeriodEnd(m.stripe_subscription_id);
      } catch (err) {
        // Already gone on Stripe's side: nothing left to cancel.
        if (!(err instanceof StripeError && err.code === "resource_missing")) return stripeFailure(err);
      }
    }
    const row = await db.updateTable("membership")
      .set({ auto_renew: false, last_updated_date: sql`NOW()` })
      .where("id", "=", m.id)
      .returningAll()
      .executeTakeFirstOrThrow();
    return json(row);
  }

  // ── POST /payments/:id/cancel — the payer backed out of Checkout ─────────────
  // Expires the Checkout Session so it can't be completed later, then marks the
  // payment cancelled. A session that already completed wins (409).
  if (route.name === "cancel" && req.method === "POST") {
    const p = await db.selectFrom("payment").select(["id", "user_id", "status", "stripe_checkout_session_id"])
      .where("id", "=", route.id).executeTakeFirst();
    if (!p) return jsonError("Payment not found", 404);
    if (p.user_id !== caller.id) return forbidden();
    if (p.status !== "pending") return jsonError(`This payment is already ${p.status}`, 409);
    if (p.stripe_checkout_session_id) {
      try {
        await stripeRequest("POST", `/checkout/sessions/${encodeURIComponent(p.stripe_checkout_session_id)}/expire`);
      } catch (err) {
        // Stripe refuses to expire a completed session; the webhook will settle it.
        if (err instanceof StripeError && err.status === 400) {
          return jsonError("This payment can no longer be cancelled", 409);
        }
        return stripeFailure(err);
      }
    }
    const row = await db.updateTable("payment").set({ status: "cancelled", updated_at: sql`NOW()` })
      .where("id", "=", p.id).where("status", "=", "pending")
      .returning(PAYMENT_COLS).executeTakeFirst();
    return row ? json(row) : jsonError("This payment was just updated, refresh to see it", 409);
  }

  // ── GET /payments/:id — owner or super user (polled after Checkout) ──────────
  if (route.name === "one" && req.method === "GET") {
    const row = await db.selectFrom("payment").select(PAYMENT_COLS).where("id", "=", route.id)
      .executeTakeFirst();
    if (!row) return jsonError("Payment not found", 404);
    if (row.user_id !== caller.id && !isSuperUser(caller)) return forbidden();
    return json(row);
  }

  return jsonError("Not found", 404);
});
