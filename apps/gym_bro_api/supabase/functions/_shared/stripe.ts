// ── Stripe over plain REST ────────────────────────────────────────────────────
// No SDK: Stripe's API takes form-encoded bodies with bracketed keys
// (`line_items[0][price_data][currency]=usd`) and returns JSON. Payments are
// optional — every caller checks `stripeEnabled()` first and degrades to a 503
// `{ code: "not_configured" }` when STRIPE_SECRET_KEY is missing.

import { jsonError } from "./auth.ts";
import { optionalSecret } from "./notify.ts";

const STRIPE_API = "https://api.stripe.com/v1";

export function stripeSecretKey(): string | null {
  return optionalSecret("STRIPE_SECRET_KEY");
}

/** Endpoint secret for verifying webhook signatures, or null when unset. */
export function stripeWebhookSecret(): string | null {
  return optionalSecret("STRIPE_WEBHOOK_SECRET");
}

export function stripeEnabled(): boolean {
  return stripeSecretKey() !== null;
}

/** Lower-case ISO currency for all charges (PAYMENTS_CURRENCY, default usd). */
export function paymentsCurrency(): string {
  return (optionalSecret("PAYMENTS_CURRENCY") ?? "usd").toLowerCase();
}

export function notConfigured(): Response {
  return jsonError("Payments are not configured", 503, { code: "not_configured" });
}

// Currencies Stripe charges in whole units (no cents).
const ZERO_DECIMAL = new Set([
  "bif", "clp", "djf", "gnf", "jpy", "kmf", "krw", "mga", "pyg", "rwf", "ugx", "vnd", "vuv", "xaf",
  "xof", "xpf",
]);

/** Converts a decimal amount ("12.50" or 12.5) to Stripe's integer minor units. */
export function toMinorUnits(amount: string | number, currency: string): number {
  const n = typeof amount === "number" ? amount : Number(amount);
  return ZERO_DECIMAL.has(currency.toLowerCase()) ? Math.round(n) : Math.round(n * 100);
}

/** Converts Stripe minor units back to a decimal amount. */
export function fromMinorUnits(minor: number, currency: string): number {
  return ZERO_DECIMAL.has(currency.toLowerCase()) ? minor : minor / 100;
}

// ── Form encoding ─────────────────────────────────────────────────────────────

export type StripeParams = { [key: string]: StripeValue };
type StripeValue = string | number | boolean | null | undefined | StripeParams | StripeValue[];

/**
 * Flattens nested params into Stripe's bracket notation:
 * `{ line_items: [{ price_data: { currency: "usd" } }] }` →
 * `line_items[0][price_data][currency]=usd`. null/undefined are skipped.
 */
export function flattenParams(params: StripeParams, prefix = "", out = new URLSearchParams()): URLSearchParams {
  for (const [key, value] of Object.entries(params)) {
    const name = prefix ? `${prefix}[${key}]` : key;
    appendValue(name, value, out);
  }
  return out;
}

function appendValue(name: string, value: StripeValue, out: URLSearchParams): void {
  if (value === null || value === undefined) return;
  if (Array.isArray(value)) {
    value.forEach((v, i) => appendValue(`${name}[${i}]`, v, out));
  } else if (typeof value === "object") {
    flattenParams(value, name, out);
  } else {
    out.append(name, String(value));
  }
}

// ── Requests ──────────────────────────────────────────────────────────────────

export class StripeError extends Error {
  constructor(message: string, readonly status: number, readonly code?: string) {
    super(message);
  }
}

// deno-lint-ignore no-explicit-any
export type StripeObject = Record<string, any>;

/** Calls the Stripe API. Throws StripeError on a non-2xx response. */
export async function stripeRequest(
  method: "GET" | "POST" | "DELETE",
  path: string,
  params?: StripeParams,
  idempotencyKey?: string,
): Promise<StripeObject> {
  const key = stripeSecretKey();
  if (!key) throw new StripeError("Payments are not configured", 503, "not_configured");

  const headers: Record<string, string> = { Authorization: `Bearer ${key}` };
  let url = `${STRIPE_API}${path}`;
  let body: string | undefined;
  if (params && method === "GET") {
    url += `?${flattenParams(params).toString()}`;
  } else if (params) {
    headers["Content-Type"] = "application/x-www-form-urlencoded";
    body = flattenParams(params).toString();
  }
  if (idempotencyKey) headers["Idempotency-Key"] = idempotencyKey;

  const res = await fetch(url, { method, headers, body });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    const err = data?.error ?? {};
    throw new StripeError(err.message ?? `Stripe request failed (${res.status})`, res.status, err.code);
  }
  return data;
}

// ── Webhook signatures ────────────────────────────────────────────────────────

function toHex(buf: ArrayBuffer): string {
  return Array.from(new Uint8Array(buf)).map((b) => b.toString(16).padStart(2, "0")).join("");
}

function constantTimeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

/**
 * Verifies a `Stripe-Signature` header (`t=…,v1=…[,v1=…]`): HMAC-SHA256 of
 * `${t}.${rawBody}` keyed with the endpoint secret, compared in constant time,
 * with the timestamp no more than `toleranceSec` away from now.
 */
export async function verifyStripeSignature(
  header: string | null,
  rawBody: string,
  secret: string,
  toleranceSec = 300,
): Promise<boolean> {
  if (!header) return false;
  let timestamp: string | null = null;
  const signatures: string[] = [];
  for (const part of header.split(",")) {
    const [k, v] = part.split("=", 2).map((s) => s?.trim());
    if (k === "t") timestamp = v;
    else if (k === "v1" && v) signatures.push(v);
  }
  if (!timestamp || signatures.length === 0) return false;
  const t = Number(timestamp);
  if (!Number.isFinite(t) || Math.abs(Date.now() / 1000 - t) > toleranceSec) return false;

  const enc = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    enc.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const expected = toHex(await crypto.subtle.sign("HMAC", key, enc.encode(`${timestamp}.${rawBody}`)));
  return signatures.some((s) => constantTimeEqual(s, expected));
}

// ── Common operations ─────────────────────────────────────────────────────────

/** Stops a subscription from renewing; it stays active until the period ends. */
export async function cancelSubscriptionAtPeriodEnd(subscriptionId: string): Promise<void> {
  await stripeRequest("POST", `/subscriptions/${encodeURIComponent(subscriptionId)}`, {
    cancel_at_period_end: true,
  });
}

/** Refunds the whole of a payment intent. */
export async function refundPaymentIntent(paymentIntentId: string, idempotencyKey?: string): Promise<StripeObject> {
  return await stripeRequest("POST", "/refunds", { payment_intent: paymentIntentId }, idempotencyKey);
}
