import { sql } from "npm:kysely@^0.27";
import { db } from "./config.ts";
import type { NotificationType } from "../../types/schema/public.ts";
import { broadcastToUsers } from "./realtime.ts";

/**
 * Reads an optional secret. An `env(NAME)` reference in config.toml whose
 * variable isn't exported can reach the function as that literal string, so
 * treat it (and blank values) as unset.
 */
export function optionalSecret(name: string): string | null {
  const value = Deno.env.get(name)?.trim();
  if (!value || /^env\(.*\)$/.test(value)) return null;
  return value;
}

type NotificationInput = {
  type: NotificationType;
  title: string;
  body: string;
  metadata?: Record<string, unknown>;
};

/**
 * Inserts the same in-app notification for each user, then (in the background)
 * sends it as a push notification to their registered devices. Notifications
 * are only ever created by the server; clients can read, mark read and delete
 * their own. Failures are logged, never thrown, so a notification can't break
 * the action that triggered it.
 */
export async function notify(userIds: string[], n: NotificationInput): Promise<void> {
  const unique = [...new Set(userIds)].filter(Boolean);
  if (unique.length === 0) return;
  let rows: { id: string; user_id: string }[];
  try {
    rows = await db
      .insertInto("notification")
      .values(unique.map((user_id) => ({
        user_id,
        type: n.type,
        title: n.title,
        body: n.body,
        // pg serializes plain objects to JSON for the jsonb column.
        metadata: n.metadata ?? {},
      })))
      .returning(["id", "user_id"])
      .execute();
  } catch (err) {
    console.error("notify failed", n.type, err);
    return;
  }
  // Live badge/list update for open apps.
  for (const row of rows) {
    await broadcastToUsers([row.user_id], "notification", {
      id: row.id,
      type: n.type,
      title: n.title,
      body: n.body,
      metadata: n.metadata ?? {},
    });
  }
  schedulePush(rows, n);
}

/**
 * Push only, without an in-app notification row — for high-volume events
 * like chat messages, whose in-app state is the inbox itself.
 */
export function pushOnly(userIds: string[], n: NotificationInput): void {
  const unique = [...new Set(userIds)].filter(Boolean);
  schedulePush(unique.map((user_id) => ({ id: "", user_id })), n);
}

/** User ids of everyone who owns the gym. */
export async function gymOwnerIds(gymId: string): Promise<string[]> {
  const rows = await db.selectFrom("gym_owner").select("user_id").where("gym_id", "=", gymId).execute();
  return rows.map((r) => r.user_id);
}

/** User ids of everyone who owns the shop. */
export async function shopOwnerIds(shopId: string): Promise<string[]> {
  const rows = await db.selectFrom("shop_owner").select("user_id").where("shop_id", "=", shopId).execute();
  return rows.map((r) => r.user_id);
}

export async function businessName(businessId: string): Promise<string> {
  const row = await db.selectFrom("business").select("name").where("id", "=", businessId).executeTakeFirst();
  return row?.name ?? "the business";
}

// ── Push (FCM HTTP v1) ────────────────────────────────────────────────────────
// Enabled by FCM_SERVICE_ACCOUNT_B64: a Firebase service account JSON key,
// base64-encoded (Firebase console → Project settings → Service accounts →
// Generate new private key; then `base64 -i key.json | tr -d '\n'`).

/** Supabase's edge runtime global: keeps the worker alive for background work. */
type EdgeRuntimeGlobal = { EdgeRuntime?: { waitUntil?: (promise: Promise<unknown>) => void } };

type ServiceAccount = { project_id: string; client_email: string; private_key: string; token_uri?: string };

const FCM_SCOPE = "https://www.googleapis.com/auth/firebase.messaging";
const GOOGLE_TOKEN_URL = "https://oauth2.googleapis.com/token";
const PUSH_CONCURRENCY = 20;

let cachedAccount: ServiceAccount | null | undefined;
let cachedToken: { value: string; expiresAt: number } | null = null;
let pendingToken: Promise<string> | null = null;
let cachedKey: CryptoKey | null = null;

function serviceAccount(): ServiceAccount | null {
  if (cachedAccount !== undefined) return cachedAccount;
  const b64 = optionalSecret("FCM_SERVICE_ACCOUNT_B64");
  if (!b64) return (cachedAccount = null);
  try {
    const parsed = JSON.parse(new TextDecoder().decode(base64ToBytes(b64))) as ServiceAccount;
    if (!parsed.project_id || !parsed.client_email || !parsed.private_key) {
      throw new Error("missing project_id, client_email or private_key");
    }
    cachedAccount = parsed;
  } catch (err) {
    console.error("FCM_SERVICE_ACCOUNT_B64 is not a valid base64 service account JSON; push disabled", err);
    cachedAccount = null;
  }
  return cachedAccount;
}

/** Runs the push send after the response, without delaying it. */
function schedulePush(rows: { id: string; user_id: string }[], n: NotificationInput): void {
  if (rows.length === 0 || !serviceAccount()) return;
  const task = sendPush(rows, n).catch((err) => console.error("push failed", n.type, err));
  const runtime = (globalThis as unknown as EdgeRuntimeGlobal).EdgeRuntime;
  if (typeof runtime?.waitUntil === "function") runtime.waitUntil(task);
  // Otherwise fire-and-forget: the promise logs its own errors.
}

async function sendPush(rows: { id: string; user_id: string }[], n: NotificationInput): Promise<void> {
  const account = serviceAccount();
  if (!account) return;

  const notificationIdByUser = new Map(rows.map((r) => [r.user_id, r.id]));
  const userIds = [...notificationIdByUser.keys()];

  // Devices of users who allow push and haven't muted this type.
  const { rows: devices } = await sql<{ token: string; user_id: string }>`
    SELECT dt.token, dt.user_id
    FROM device_token dt
    LEFT JOIN user_settings us ON us.user_id = dt.user_id
    WHERE dt.user_id = ANY(${userIds}::uuid[])
      AND COALESCE(us.push_enabled, TRUE)
      AND NOT (COALESCE(us.muted_types, '{}') @> ARRAY[${n.type}::notification_type])
  `.execute(db);
  if (devices.length === 0) return;

  const accessToken = await getAccessToken(account);
  const metadata = JSON.stringify(n.metadata ?? {});
  const staleTokens: string[] = [];

  for (let i = 0; i < devices.length; i += PUSH_CONCURRENCY) {
    const batch = devices.slice(i, i + PUSH_CONCURRENCY);
    await Promise.all(batch.map(async (device) => {
      const result = await sendOne(account, accessToken, device.token, {
        notification: { title: n.title, body: n.body },
        data: {
          type: n.type,
          notification_id: notificationIdByUser.get(device.user_id) ?? "",
          metadata,
        },
      });
      if (result === "stale") staleTokens.push(device.token);
    }));
  }

  if (staleTokens.length > 0) {
    await db.deleteFrom("device_token").where("token", "in", staleTokens).execute();
  }
}

type FcmError = { error?: { status?: string; message?: string; details?: { errorCode?: string }[] } };

async function sendOne(
  account: ServiceAccount,
  accessToken: string,
  token: string,
  payload: { notification: { title: string; body: string }; data: Record<string, string> },
): Promise<"ok" | "stale" | "failed"> {
  const res = await fetch(`https://fcm.googleapis.com/v1/projects/${account.project_id}/messages:send`, {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${accessToken}` },
    body: JSON.stringify({
      message: {
        token,
        ...payload,
        android: { priority: "HIGH", notification: { channel_id: "gym_bro_default" } },
        apns: { payload: { aps: { sound: "default" } } },
      },
    }),
  });
  if (res.ok) return "ok";

  const body = (await res.json().catch(() => ({}))) as FcmError;
  const codes = (body.error?.details ?? []).map((d) => d.errorCode).filter(Boolean);
  const message = body.error?.message ?? "";
  const unregistered = codes.includes("UNREGISTERED") || codes.includes("SENDER_ID_MISMATCH") ||
    (res.status === 404 && body.error?.status === "NOT_FOUND");
  // INVALID_ARGUMENT can also mean a bad payload; only drop the token when
  // FCM says the token itself is malformed.
  const invalidToken = (codes.includes("INVALID_ARGUMENT") || body.error?.status === "INVALID_ARGUMENT") &&
    /registration token/i.test(message);
  if (unregistered || invalidToken) return "stale";

  if (res.status === 401) cachedToken = null; // force a fresh OAuth token next time
  console.error("FCM send failed", res.status, codes.join(",") || body.error?.status, message);
  return "failed";
}

// ── Google OAuth (service account JWT → access token) ─────────────────────────

function getAccessToken(account: ServiceAccount): Promise<string> {
  if (cachedToken && cachedToken.expiresAt - 60_000 > Date.now()) return Promise.resolve(cachedToken.value);
  if (pendingToken) return pendingToken;
  pendingToken = fetchAccessToken(account).finally(() => {
    pendingToken = null;
  });
  return pendingToken;
}

async function fetchAccessToken(account: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const tokenUrl = account.token_uri ?? GOOGLE_TOKEN_URL;
  const header = { alg: "RS256", typ: "JWT" };
  const claims = { iss: account.client_email, scope: FCM_SCOPE, aud: tokenUrl, iat: now, exp: now + 3600 };
  const unsigned = `${base64UrlJson(header)}.${base64UrlJson(claims)}`;

  const key = await signingKey(account.private_key);
  const signature = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(unsigned));
  const assertion = `${unsigned}.${base64Url(new Uint8Array(signature))}`;

  const res = await fetch(tokenUrl, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer", assertion }),
  });
  const body = await res.json().catch(() => ({})) as { access_token?: string; expires_in?: number; error?: string };
  if (!res.ok || !body.access_token) {
    throw new Error(`Google OAuth token exchange failed (${res.status}): ${body.error ?? "no access_token"}`);
  }
  cachedToken = { value: body.access_token, expiresAt: Date.now() + (body.expires_in ?? 3600) * 1000 };
  return body.access_token;
}

async function signingKey(pem: string): Promise<CryptoKey> {
  if (cachedKey) return cachedKey;
  const b64 = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\\n/g, "")
    .replace(/\s+/g, "");
  cachedKey = await crypto.subtle.importKey(
    "pkcs8",
    base64ToBytes(b64),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  return cachedKey;
}

function base64ToBytes(b64: string): Uint8Array<ArrayBuffer> {
  const binary = atob(b64.trim());
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes;
}

function base64Url(bytes: Uint8Array): string {
  let binary = "";
  for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function base64UrlJson(value: unknown): string {
  return base64Url(new TextEncoder().encode(JSON.stringify(value)));
}
