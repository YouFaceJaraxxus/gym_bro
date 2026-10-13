import { assertEquals } from "jsr:@std/assert@1";
import { pgCode } from "../../supabase/functions/_shared/roles.ts";

Deno.test("pgCode reads the code from a pg error", () => {
  assertEquals(pgCode({ code: "23505", detail: "duplicate key" }), "23505");
  assertEquals(pgCode(Object.assign(new Error("fk"), { code: "23503" })), "23503");
});

Deno.test("pgCode stringifies non-string codes", () => {
  assertEquals(pgCode({ code: 42 }), "42");
});

Deno.test("pgCode is undefined for anything without a code", () => {
  assertEquals(pgCode(new Error("boom")), undefined);
  assertEquals(pgCode("23505"), undefined);
  assertEquals(pgCode(null), undefined);
  assertEquals(pgCode(undefined), undefined);
  assertEquals(pgCode({}), undefined);
});
