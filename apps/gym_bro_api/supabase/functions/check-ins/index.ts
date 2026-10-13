import { sql } from "npm:kysely@^0.27";
import { db } from "../_shared/config.ts";
import { type Caller, canStaffGym, forbidden, json, jsonError, requireCaller } from "../_shared/auth.ts";
import { optionalSecret } from "../_shared/notify.ts";
import { pgCode } from "../_shared/roles.ts";

// Gym check-ins. A member shows a short-lived signed QR token
// (GET /check-ins/token); front-desk staff scan it (POST /check-ins {token}) or
// check a member in by hand (POST /check-ins {gym_id, user_id}).
//
// Token = base64url(JSON {u, g, exp}) + "." + base64url(HMAC-SHA256(payload)).
// The key is CHECKIN_SECRET, else derived from SUPABASE_SERVICE_ROLE_KEY.
//
// Day boundaries use the client's UTC offset: pass ?tz_offset=<minutes east of
// UTC> (Dart: DateTime.now().timeZoneOffset.inMinutes). Defaults to 0 (UTC).

const TOKEN_TTL_SECONDS = 5 * 60;
const DUPLICATE_WINDOW_MINUTES = 30;
const DAY_MS = 24 * 60 * 60 * 1000;
const KEY_LABEL = "gym_bro:check_in_token:v1";

const CHECK_IN_COLS = ["check_in.id", "check_in.gym_id", "check_in.user_id", "check_in.checked_in_at", "check_in.checked_in_by", "check_in.method"] as const;

// ── Path parsing ──────────────────────────────────────────────────────────────

function parseAction(pathname: string): string | null | undefined {
  if (/^\/check-ins\/?$/.test(pathname)) return null;
  const m = pathname.match(/^\/check-ins\/([^/]+)$/);
  return m ? m[1] : undefined; // undefined = unknown route
}

// ── Token signing ─────────────────────────────────────────────────────────────

const encoder = new TextEncoder();
let keyPromise: Promise<CryptoKey> | null = null;

function base64url(bytes: Uint8Array): string {
  let bin = "";
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function fromBase64url(s: string): Uint8Array | null {
  if (!/^[A-Za-z0-9_-]*$/.test(s)) return null;
  try {
    const padded = s.replace(/-/g, "+").replace(/_/g, "/") + "=".repeat((4 - (s.length % 4)) % 4);
    const bin = atob(padded);
    return Uint8Array.from(bin, (c) => c.charCodeAt(0));
  } catch {
    return null;
  }
}

async function importHmacKey(raw: Uint8Array<ArrayBuffer>): Promise<CryptoKey> {
  return await crypto.subtle.importKey("raw", raw, { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
}

/** HMAC key for tokens, or null when neither secret is configured. */
function signingKey(): Promise<CryptoKey> | null {
  if (keyPromise) return keyPromise;
  const secret = optionalSecret("CHECKIN_SECRET");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (secret) {
    keyPromise = importHmacKey(encoder.encode(secret));
  } else if (serviceKey) {
    // Derive a dedicated key so the service-role key itself never signs tokens.
    keyPromise = (async () => {
      const base = await importHmacKey(encoder.encode(serviceKey));
      const derived = new Uint8Array(await crypto.subtle.sign("HMAC", base, encoder.encode(KEY_LABEL)));
      return importHmacKey(derived);
    })();
  } else {
    return null;
  }
  return keyPromise;
}

function timingSafeEqual(a: Uint8Array, b: Uint8Array): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a[i] ^ b[i];
  return diff === 0;
}

async function sign(key: CryptoKey, payload: string): Promise<Uint8Array> {
  return new Uint8Array(await crypto.subtle.sign("HMAC", key, encoder.encode(payload)));
}

async function createToken(key: CryptoKey, userId: string, gymId: string, exp: number): Promise<string> {
  const payload = base64url(encoder.encode(JSON.stringify({ u: userId, g: gymId, exp })));
  return `${payload}.${base64url(await sign(key, payload))}`;
}

type TokenResult =
  | { ok: true; userId: string; gymId: string }
  | { ok: false; reason: "invalid" | "expired" };

async function verifyToken(key: CryptoKey, token: string): Promise<TokenResult> {
  const parts = token.trim().split(".");
  if (parts.length !== 2) return { ok: false, reason: "invalid" };
  const [payload, sigPart] = parts;
  const given = fromBase64url(sigPart);
  if (!given) return { ok: false, reason: "invalid" };
  if (!timingSafeEqual(await sign(key, payload), given)) return { ok: false, reason: "invalid" };

  const raw = fromBase64url(payload);
  if (!raw) return { ok: false, reason: "invalid" };
  let data: { u?: unknown; g?: unknown; exp?: unknown };
  try {
    data = JSON.parse(new TextDecoder().decode(raw));
  } catch {
    return { ok: false, reason: "invalid" };
  }
  if (typeof data.u !== "string" || typeof data.g !== "string" || typeof data.exp !== "number") {
    return { ok: false, reason: "invalid" };
  }
  if (data.exp * 1000 < Date.now()) return { ok: false, reason: "expired" };
  return { ok: true, userId: data.u, gymId: data.g };
}

const notConfigured = () =>
  jsonError("Check-ins are not configured on this server", 503, { code: "not_configured" });

// ── Lookups ───────────────────────────────────────────────────────────────────

async function isMember(userId: string, gymId: string): Promise<boolean> {
  const row = await db
    .selectFrom("member")
    .select("id")
    .where("user_id", "=", userId)
    .where("gym_id", "=", gymId)
    .executeTakeFirst();
  return !!row;
}

async function gymName(gymId: string): Promise<string | null> {
  const row = await db
    .selectFrom("gym")
    .innerJoin("business", "business.id", "gym.id")
    .select("business.name")
    .where("gym.id", "=", gymId)
    .executeTakeFirst();
  return row?.name ?? null;
}

/** The member's best membership at the gym: active ones first, then the latest end date. */
async function membershipAt(userId: string, gymId: string) {
  const row = await db
    .selectFrom("membership")
    .innerJoin("gym_membership_type", "gym_membership_type.id", "membership.current_membership_type_id")
    .select([
      sql<boolean>`(membership.is_active AND membership.to_date >= CURRENT_DATE)`.as("is_active"),
      sql<string>`to_char(membership.to_date, 'YYYY-MM-DD')`.as("to_date"),
      "gym_membership_type.name as type_name",
    ])
    .where("membership.user_id", "=", userId)
    .where("gym_membership_type.gym_id", "=", gymId)
    .orderBy(sql`(membership.is_active AND membership.to_date >= CURRENT_DATE)`, "desc")
    .orderBy("membership.to_date", "desc")
    .executeTakeFirst();
  return row ?? null;
}

// ── Check-in recording ────────────────────────────────────────────────────────

async function recordCheckIn(
  caller: Caller,
  gymId: string,
  userId: string,
  method: "qr" | "manual",
): Promise<Response> {
  const member = await db
    .selectFrom("users")
    .select(["id", "name", "last_name", "avatar_url"])
    .where("id", "=", userId)
    .executeTakeFirst();
  if (!member) return jsonError("Member not found", 404);

  // Serialize concurrent scans of the same member at the same gym so the
  // duplicate window holds.
  const { checkIn, duplicate } = await db.transaction().execute(async (trx) => {
    await sql`SELECT pg_advisory_xact_lock(hashtext(${`check_in:${gymId}:${userId}`}))`.execute(trx);
    const recent = await trx
      .selectFrom("check_in")
      .select(CHECK_IN_COLS)
      .where("gym_id", "=", gymId)
      .where("user_id", "=", userId)
      .where(sql<boolean>`checked_in_at > now() - make_interval(mins => ${DUPLICATE_WINDOW_MINUTES})`)
      .orderBy("checked_in_at", "desc")
      .executeTakeFirst();
    if (recent) return { checkIn: recent, duplicate: true };
    const created = await trx
      .insertInto("check_in")
      .values({ gym_id: gymId, user_id: userId, checked_in_by: caller.id, method })
      .returning(["id", "gym_id", "user_id", "checked_in_at", "checked_in_by", "method"])
      .executeTakeFirstOrThrow();
    return { checkIn: created, duplicate: false };
  });

  const membership = await membershipAt(userId, gymId);
  return json({
    check_in: checkIn,
    duplicate,
    member,
    membership,
    warning: membership?.is_active ? null : "no_active_membership",
  }, duplicate ? 200 : 201);
}

// ── Date helpers (client-local days via tz_offset) ────────────────────────────

function parseOffset(url: URL): number {
  const n = parseInt(url.searchParams.get("tz_offset") ?? "0");
  return Number.isFinite(n) && Math.abs(n) <= 14 * 60 ? n : 0;
}

/** YYYY-MM-DD of the client-local day containing `ms`. */
function localDay(ms: number, offsetMin: number): string {
  return new Date(ms + offsetMin * 60_000).toISOString().slice(0, 10);
}

/** UTC instant of local midnight for a YYYY-MM-DD day. */
function localMidnightUtc(day: string, offsetMin: number): number {
  return Date.parse(`${day}T00:00:00Z`) - offsetMin * 60_000;
}

function addDays(day: string, n: number): string {
  return new Date(Date.parse(`${day}T00:00:00Z`) + n * DAY_MS).toISOString().slice(0, 10);
}

/** Monday of the week containing `day`. */
function weekStart(day: string): string {
  const dow = new Date(`${day}T00:00:00Z`).getUTCDay(); // 0 = Sunday
  return addDays(day, -((dow + 6) % 7));
}

const isDay = (s: string | null): s is string => !!s && /^\d{4}-\d{2}-\d{2}$/.test(s) && !isNaN(Date.parse(s));

// ── Handler ───────────────────────────────────────────────────────────────────

async function handler(req: Request): Promise<Response> {
  const url = new URL(req.url);
  const action = parseAction(url.pathname);
  if (action === undefined) return jsonError("Not found", 404);

  const { caller, response } = await requireCaller(req);
  if (!caller) return response;

  // ── GET /check-ins/gyms — gyms the caller can check in at ────────────────────
  // Member gyms, plus staffed gyms (flagged) so staff can test the flow.
  if (req.method === "GET" && action === "gyms") {
    const rows = await sql<{ gym_id: string; name: string; logo: string | null; is_member: boolean; is_staff: boolean }>`
      SELECT b.id AS gym_id, b.name, b.logo,
        EXISTS (SELECT 1 FROM member m WHERE m.gym_id = b.id AND m.user_id = ${caller.id}) AS is_member,
        (EXISTS (SELECT 1 FROM gym_owner o WHERE o.gym_id = b.id AND o.user_id = ${caller.id})
          OR EXISTS (SELECT 1 FROM employee e WHERE e.gym_id = b.id AND e.user_id = ${caller.id})
          OR EXISTS (SELECT 1 FROM employee_trainer et WHERE et.gym_id = b.id AND et.user_id = ${caller.id})) AS is_staff
      FROM gym g JOIN business b ON b.id = g.id
      WHERE EXISTS (SELECT 1 FROM member m WHERE m.gym_id = g.id AND m.user_id = ${caller.id})
         OR EXISTS (SELECT 1 FROM gym_owner o WHERE o.gym_id = g.id AND o.user_id = ${caller.id})
         OR EXISTS (SELECT 1 FROM employee e WHERE e.gym_id = g.id AND e.user_id = ${caller.id})
         OR EXISTS (SELECT 1 FROM employee_trainer et WHERE et.gym_id = g.id AND et.user_id = ${caller.id})
      ORDER BY is_member DESC, b.name
    `.execute(db);
    return json(rows.rows);
  }

  // ── GET /check-ins/token?gym_id= — member's QR token, valid 5 minutes ────────
  if (req.method === "GET" && action === "token") {
    const gymId = url.searchParams.get("gym_id");
    if (!gymId) return jsonError("gym_id is required", 400);
    const name = await gymName(gymId);
    if (!name) return jsonError("Gym not found", 404);
    if (!(await isMember(caller.id, gymId)) && !(await canStaffGym(caller, gymId))) {
      return forbidden("You are not a member of this gym");
    }
    const key = signingKey();
    if (!key) return notConfigured();

    const exp = Math.floor(Date.now() / 1000) + TOKEN_TTL_SECONDS;
    return json({
      token: await createToken(await key, caller.id, gymId, exp),
      expires_at: new Date(exp * 1000).toISOString(),
      ttl_seconds: TOKEN_TTL_SECONDS,
      gym_id: gymId,
      gym_name: name,
    });
  }

  // ── GET /check-ins/members?gym_id=&q= — staff: member search for manual check-in
  if (req.method === "GET" && action === "members") {
    const gymId = url.searchParams.get("gym_id");
    if (!gymId) return jsonError("gym_id is required", 400);
    if (!(await canStaffGym(caller, gymId))) return forbidden();
    const q = (url.searchParams.get("q") ?? "").trim();
    let query = db
      .selectFrom("member")
      .innerJoin("users", "users.id", "member.user_id")
      .select(["users.id", "users.name", "users.last_name", "users.email", "users.avatar_url"])
      .where("member.gym_id", "=", gymId);
    if (q) {
      const like = `%${q.replace(/[\\%_]/g, (c) => `\\${c}`)}%`;
      query = query.where((eb) =>
        eb.or([
          eb("users.name", "ilike", like),
          eb("users.last_name", "ilike", like),
          eb("users.email", "ilike", like),
          eb(sql`users.name || ' ' || users.last_name`, "ilike", like),
        ])
      );
    }
    return json(await query.orderBy("users.name").orderBy("users.last_name").limit(50).execute());
  }

  // ── GET /check-ins/stats ─────────────────────────────────────────────────────
  // ?mine=true → {total, this_month, this_week, last_check_in_at}
  // ?gym_id=&days=30 (staff) → {today, this_week, unique_members, total, per_day, busiest_hours, top_members}
  if (req.method === "GET" && action === "stats") {
    const offset = parseOffset(url);
    const today = localDay(Date.now(), offset);

    if (url.searchParams.get("mine") === "true") {
      const monthStart = `${today.slice(0, 8)}01`;
      const week = weekStart(today);
      const row = await db
        .selectFrom("check_in")
        .select([
          sql<number>`count(*)::int`.as("total"),
          sql<number>`(count(*) FILTER (WHERE checked_in_at >= ${new Date(localMidnightUtc(monthStart, offset)).toISOString()}::timestamptz))::int`.as("this_month"),
          sql<number>`(count(*) FILTER (WHERE checked_in_at >= ${new Date(localMidnightUtc(week, offset)).toISOString()}::timestamptz))::int`.as("this_week"),
          sql<string | null>`max(checked_in_at)`.as("last_check_in_at"),
        ])
        .where("user_id", "=", caller.id)
        .executeTakeFirstOrThrow();
      return json(row);
    }

    const gymId = url.searchParams.get("gym_id");
    if (!gymId) return jsonError("gym_id or mine=true is required", 400);
    if (!(await canStaffGym(caller, gymId))) return forbidden();
    const days = Math.min(365, Math.max(1, parseInt(url.searchParams.get("days") ?? "30") || 30));

    const periodStartDay = addDays(today, -(days - 1));
    const week = weekStart(today);
    const queryStartDay = periodStartDay < week ? periodStartDay : week;
    const queryStart = new Date(localMidnightUtc(queryStartDay, offset)).toISOString();
    const periodStart = new Date(localMidnightUtc(periodStartDay, offset)).toISOString();
    const localTs = sql`(check_in.checked_in_at AT TIME ZONE 'UTC') + make_interval(mins => ${offset})`;

    const [buckets, top, unique] = await Promise.all([
      db
        .selectFrom("check_in")
        .select([
          sql<string>`to_char(${localTs}, 'YYYY-MM-DD')`.as("day"),
          sql<number>`extract(hour FROM ${localTs})::int`.as("hour"),
          sql<number>`count(*)::int`.as("n"),
        ])
        .where("gym_id", "=", gymId)
        .where("checked_in_at", ">=", queryStart)
        .groupBy(["day", "hour"])
        .execute(),
      db
        .selectFrom("check_in")
        .innerJoin("users", "users.id", "check_in.user_id")
        .select([
          "users.id",
          "users.name",
          "users.last_name",
          "users.avatar_url",
          sql<number>`count(*)::int`.as("visits"),
          sql<string>`max(check_in.checked_in_at)`.as("last_check_in_at"),
        ])
        .where("check_in.gym_id", "=", gymId)
        .where("check_in.checked_in_at", ">=", periodStart)
        .groupBy(["users.id", "users.name", "users.last_name", "users.avatar_url"])
        .orderBy("visits", "desc")
        .orderBy("users.name")
        .limit(10)
        .execute(),
      db
        .selectFrom("check_in")
        .select(sql<number>`count(DISTINCT user_id)::int`.as("n"))
        .where("gym_id", "=", gymId)
        .where("checked_in_at", ">=", periodStart)
        .executeTakeFirstOrThrow(),
    ]);

    const perDayMap: Record<string, number> = {};
    const hours = new Array<number>(24).fill(0);
    let thisWeek = 0;
    let total = 0;
    for (const b of buckets) {
      if (b.day >= week) thisWeek += b.n;
      if (b.day < periodStartDay) continue;
      perDayMap[b.day] = (perDayMap[b.day] ?? 0) + b.n;
      hours[b.hour] += b.n;
      total += b.n;
    }
    const perDay = Array.from({ length: days }, (_, i) => {
      const day = addDays(periodStartDay, i);
      return { date: day, count: perDayMap[day] ?? 0 };
    });

    return json({
      gym_id: gymId,
      days,
      today: perDayMap[today] ?? 0,
      this_week: thisWeek,
      total,
      unique_members: unique.n,
      per_day: perDay,
      busiest_hours: hours.map((count, hour) => ({ hour, count })),
      top_members: top,
    });
  }

  // ── GET /check-ins ───────────────────────────────────────────────────────────
  // ?mine=true[&gym_id=][&page=&page_size=] → own history, newest first, with gym_name
  // ?gym_id=&date=YYYY-MM-DD (staff, default today) → that day's check-ins with member names
  if (req.method === "GET" && action === null) {
    if (url.searchParams.get("mine") === "true") {
      const page = Math.max(0, parseInt(url.searchParams.get("page") ?? "0") || 0);
      const pageSize = Math.min(100, Math.max(1, parseInt(url.searchParams.get("page_size") ?? "30") || 30));
      const gymId = url.searchParams.get("gym_id");
      let query = db
        .selectFrom("check_in")
        .innerJoin("business", "business.id", "check_in.gym_id")
        .select([...CHECK_IN_COLS, "business.name as gym_name"])
        .where("check_in.user_id", "=", caller.id);
      if (gymId) query = query.where("check_in.gym_id", "=", gymId);
      return json(
        await query.orderBy("check_in.checked_in_at", "desc").limit(pageSize).offset(page * pageSize).execute(),
      );
    }

    const gymId = url.searchParams.get("gym_id");
    if (!gymId) return jsonError("gym_id or mine=true is required", 400);
    if (!(await canStaffGym(caller, gymId))) return forbidden();
    const offset = parseOffset(url);
    const dateParam = url.searchParams.get("date");
    if (dateParam && !isDay(dateParam)) return jsonError("date must be YYYY-MM-DD", 400);
    const day = dateParam ?? localDay(Date.now(), offset);
    const from = localMidnightUtc(day, offset);

    const rows = await db
      .selectFrom("check_in")
      .innerJoin("users", "users.id", "check_in.user_id")
      .select([...CHECK_IN_COLS, "users.name", "users.last_name", "users.avatar_url"])
      .where("check_in.gym_id", "=", gymId)
      .where("check_in.checked_in_at", ">=", new Date(from).toISOString())
      .where("check_in.checked_in_at", "<", new Date(from + DAY_MS).toISOString())
      .orderBy("check_in.checked_in_at", "desc")
      .execute();
    return json(rows);
  }

  // ── POST /check-ins — {token} (QR scan) or {gym_id, user_id} (manual) ────────
  if (req.method === "POST" && action === null) {
    const body = await req.json().catch(() => null);

    if (typeof body?.token === "string") {
      const key = signingKey();
      if (!key) return notConfigured();
      const result = await verifyToken(await key, body.token);
      if (!result.ok) {
        return result.reason === "expired"
          ? jsonError("This QR code has expired. Ask the member to refresh it.", 400, { code: "token_expired" })
          : jsonError("Invalid check-in code", 400, { code: "token_invalid" });
      }
      // A gym id in the body (the scanner's gym) must match the token's gym.
      if (body.gym_id && body.gym_id !== result.gymId) {
        return jsonError("This code is for a different gym", 400, { code: "wrong_gym" });
      }
      if (!(await canStaffGym(caller, result.gymId))) return forbidden("You don't staff this gym");
      return await recordCheckIn(caller, result.gymId, result.userId, "qr");
    }

    const { gym_id, user_id } = body ?? {};
    if (!gym_id || !user_id) return jsonError("Provide token, or gym_id and user_id", 400);
    if (!(await canStaffGym(caller, gym_id))) return forbidden();
    if (!(await isMember(user_id, gym_id))) return jsonError("User is not a member of this gym", 400);
    return await recordCheckIn(caller, gym_id, user_id, "manual");
  }

  return jsonError("Not found", 404);
}

Deno.serve(async (req: Request) => {
  try {
    return await handler(req);
  } catch (e) {
    switch (pgCode(e)) {
      case "23503":
        return jsonError("Referenced gym or user does not exist", 400);
      case "22P02":
        return jsonError("Invalid id", 400);
    }
    console.error("check-ins error", e);
    return jsonError("Internal error", 500);
  }
});
