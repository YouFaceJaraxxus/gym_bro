// deno-lint-ignore-file no-explicit-any
// Shared helpers for the integration suites. They run against a live stack:
//   API_URL=http://127.0.0.1:54321 ANON_KEY=<anon key> SEED_PASSWORD=<seed password> deno task test:integration
// Without API_URL / ANON_KEY / SEED_PASSWORD every suite is skipped (ignored),
// so `deno task test:integration` is safe to run anywhere.
import { assert } from "jsr:@std/assert@1";

export const API = Deno.env.get("API_URL")?.replace(/\/$/, "") ?? "";
export const ANON = Deno.env.get("ANON_KEY") ?? "";
export const PW = Deno.env.get("SEED_PASSWORD") ?? "";
export const configured = API !== "" && ANON !== "" && PW !== "";
export const FN = `${API}/functions/v1`;

if (!configured) {
  console.warn("API_URL / ANON_KEY / SEED_PASSWORD not set — skipping integration tests.");
}

export type CallResult = { status: number; data: any };

export async function call(method: string, path: string, token?: string, body?: unknown): Promise<CallResult> {
  const res = await fetch(`${FN}${path}`, {
    method,
    headers: {
      "Content-Type": "application/json",
      apikey: ANON,
      Authorization: `Bearer ${token ?? ANON}`,
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await res.text();
  let data: any = text;
  try {
    data = JSON.parse(text);
  } catch { /* not JSON */ }
  return { status: res.status, data };
}

export const short = (x: unknown) => JSON.stringify(x)?.slice(0, 160) ?? String(x);

export type Session = { token: string; refresh: string; profile: any };

export async function signin(email: string, password = PW): Promise<Session> {
  const r = await call("POST", "/users/signin", undefined, { email, password });
  if (r.status !== 200) throw new Error(`signin ${email}: ${r.status} ${short(r.data)}`);
  return { token: r.data.access_token as string, refresh: r.data.refresh_token as string, profile: r.data.profile };
}

/**
 * Collects named checks like the original smoke scripts (logging PASS/FAIL
 * for each) so one run reports every failure; `assertAll()` fails the
 * current test/step if any check in it failed.
 */
export function checker() {
  let failures: string[] = [];
  return {
    check(name: string, ok: boolean, detail = "") {
      console.log(`${ok ? "PASS" : "FAIL"}  ${name}${detail ? `  (${detail})` : ""}`);
      if (!ok) failures.push(`${name}${detail ? ` (${detail})` : ""}`);
    },
    assertAll() {
      const f = failures;
      failures = [];
      assert(f.length === 0, `${f.length} check(s) failed:\n  - ${f.join("\n  - ")}`);
    },
  };
}

/** Deno.test options shared by the suites. */
export const suite = {
  ignore: !configured,
  // Requests to the local stack keep pooled connections alive.
  sanitizeResources: false,
  sanitizeOps: false,
};

/** The caller's most recent notifications (newest first). */
export async function notificationsOf(token: string, pageSize = 50): Promise<any[]> {
  const r = await call("GET", `/notifications?page_size=${pageSize}`, token);
  return r.status === 200 && Array.isArray(r.data?.items) ? r.data.items : [];
}

/** Deletes the caller's notifications matching `pred` (best effort). */
export async function deleteNotifications(token: string, pred: (n: any) => boolean): Promise<void> {
  for (const n of (await notificationsOf(token)).filter(pred)) {
    await call("DELETE", `/notifications/${n.id}`, token);
  }
}

/** ISO timestamp `days` from now, at `hour`:`minute` UTC. */
export function futureAt(days: number, hour: number, minute = 0): string {
  const d = new Date(Date.now() + days * 86_400_000);
  d.setUTCHours(hour, minute, 0, 0);
  return d.toISOString();
}

/** YYYY-MM-DD in UTC, `days` from today. */
export function dayFromToday(days: number): string {
  return new Date(Date.now() + days * 86_400_000).toISOString().slice(0, 10);
}

export const IRONCLAD = "Ironclad Fitness";

/** The seeded users the feature suites act as. */
export async function seededUsers() {
  const [member, owner, trainer, employee, superU, vendor] = await Promise.all([
    signin("liam.oconnor@example.com"),
    signin("marcus.bennett@example.com"),
    signin("elena.vasquez@example.com"),
    signin("priya.nair@example.com"),
    signin("chloe.anderson@example.com"),
    signin("ravi.deshmukh@example.com"),
  ]);
  const gyms = (await call("GET", "/businesses", owner.token)).data as any[];
  const gym = gyms.find((b) => b.type === "gym" && b.name === IRONCLAD) ?? gyms.find((b) => b.type === "gym");
  return { member, owner, trainer, employee, superU, vendor, gym };
}

/** A 1×1 PNG, for upload tests. */
export const PNG = Uint8Array.from(
  atob("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="),
  (c) => c.charCodeAt(0),
);

/** Uploads bytes through a slot from an /uploads endpoint; returns the storage status. */
export async function uploadTo(slot: any, bytes: Uint8Array<ArrayBuffer>, type: string): Promise<number> {
  const res = await fetch(`${API}${slot.upload_url}`, {
    method: "PUT",
    headers: { "Content-Type": type, "x-upsert": "false" },
    body: bytes,
  });
  await res.body?.cancel();
  return res.status;
}

/** GETs a relative storage URL (signed or public); returns the status. */
export async function fetchStatus(relativeUrl: string): Promise<number> {
  const res = await fetch(`${API}${relativeUrl}`);
  await res.body?.cancel();
  return res.status;
}
