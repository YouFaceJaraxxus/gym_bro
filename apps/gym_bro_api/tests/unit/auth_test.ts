import "./_env_stub.ts"; // must come before auth.ts (it loads config.ts)
import { assertEquals } from "jsr:@std/assert@1";
import {
  type Caller,
  canEditAuthored,
  forbidden,
  isSuperUser,
  json,
  jsonError,
} from "../../supabase/functions/_shared/auth.ts";

const caller = (id: string, is_super_user = false) => ({ id, is_super_user, is_trainer: false }) as unknown as Caller;

Deno.test("json() serialises the body with a JSON content type", async () => {
  const res = json({ ok: true, n: 1 }, 201);
  assertEquals(res.status, 201);
  assertEquals(res.headers.get("Content-Type"), "application/json");
  assertEquals(await res.json(), { ok: true, n: 1 });
});

Deno.test("json() defaults to 200", () => {
  assertEquals(json([]).status, 200);
});

Deno.test("jsonError() puts the message under `error` and merges extras", async () => {
  const res = jsonError("Not configured", 503, { code: "not_configured" });
  assertEquals(res.status, 503);
  assertEquals(await res.json(), { error: "Not configured", code: "not_configured" });
});

Deno.test("forbidden() is a 403 with a default message", async () => {
  const res = forbidden();
  assertEquals(res.status, 403);
  assertEquals(typeof (await res.json()).error, "string");
  assertEquals((await forbidden("nope").json()).error, "nope");
});

Deno.test("isSuperUser follows the is_super_user flag (being a trainer doesn't matter)", () => {
  assertEquals(isSuperUser({ is_super_user: true }), true);
  assertEquals(isSuperUser({ is_super_user: false }), false);
  assertEquals(isSuperUser(caller("t1")), false);
  assertEquals(isSuperUser({ ...caller("t1"), is_trainer: true } as Caller), false);
});

Deno.test("canEditAuthored: author or super user", () => {
  assertEquals(canEditAuthored(caller("u1"), "u1"), true);
  assertEquals(canEditAuthored(caller("u1"), "u2"), false);
  assertEquals(canEditAuthored(caller("u1"), null), false);
  assertEquals(canEditAuthored(caller("admin", true), "u2"), true);
  assertEquals(canEditAuthored(caller("admin", true), null), true);
});
