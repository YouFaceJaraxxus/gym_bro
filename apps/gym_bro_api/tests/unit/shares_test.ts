import "./_env_stub.ts";
import { assert, assertEquals } from "jsr:@std/assert@1";
import { SHARE_KINDS, shareSummary, STORY_SHARE_KINDS, unresolved } from "../../supabase/functions/_shared/shares.ts";

Deno.test("stories share anything but accounts and stories", () => {
  for (const k of ["user", "business", "story"] as const) assert(!(STORY_SHARE_KINDS as readonly string[]).includes(k), k);
  assertEquals(STORY_SHARE_KINDS.length, SHARE_KINDS.length - 3);
  assert(STORY_SHARE_KINDS.includes("post"));
  assert(STORY_SHARE_KINDS.includes("workout"));
  assert(STORY_SHARE_KINDS.includes("meal_plan"));
});

Deno.test("shareSummary words each kind for pushes", () => {
  assertEquals(shareSummary("post"), "Shared a post");
  assertEquals(shareSummary("user"), "Shared a profile");
  assertEquals(shareSummary("exercise"), "Shared an exercise");
  assertEquals(shareSummary("training"), "Shared a workout");
  assertEquals(shareSummary("workout"), "Shared a workout");
  assertEquals(shareSummary("meal"), "Shared a meal");
  assertEquals(shareSummary("meal_plan"), "Shared a meal plan");
});

Deno.test("unresolved: references wait for a viewer, snapshots don't", () => {
  assertEquals(unresolved({ kind: "post", ref_id: "p1", snapshot: null }), {
    kind: "post",
    ref_id: "p1",
    available: null,
  });
  assertEquals(unresolved({ kind: "workout", ref_id: "s1", snapshot: { duration_minutes: 30 } }), {
    kind: "workout",
    ref_id: "s1",
    available: true,
    preview: { duration_minutes: 30 },
  });
  assertEquals(unresolved({ kind: "meal", ref_id: null, snapshot: null }), {
    kind: "meal",
    ref_id: null,
    available: false,
    reason: "unavailable",
  });
});
