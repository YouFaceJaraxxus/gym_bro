import "./_env_stub.ts";
import { assert, assertEquals } from "jsr:@std/assert@1";
import {
  type ChallengeRow,
  daysLeft,
  goalText,
  isDay,
  isLive,
  monthlyChallenges,
  readChallengeInput,
  statusOf,
} from "../../supabase/functions/_shared/challenges.ts";
import { argMax, availability, inNoticeSeason } from "../../supabase/functions/_shared/wrapped.ts";

const NOV = { starts_on: "2026-11-01", ends_on: "2026-11-30" };

Deno.test("challenge status and days left", () => {
  assertEquals(statusOf(NOV, "2026-10-31"), "upcoming");
  assertEquals(daysLeft(NOV, "2026-10-31"), 1);
  assertEquals(statusOf(NOV, "2026-11-01"), "active");
  assertEquals(daysLeft(NOV, "2026-11-01"), 30);
  assertEquals(daysLeft(NOV, "2026-11-30"), 1);
  assertEquals(statusOf(NOV, "2026-12-01"), "past");
  assertEquals(daysLeft(NOV, "2026-12-01"), 0);
});

Deno.test("progress stays live a few days past the end (late logging)", () => {
  assert(isLive(NOV, "2026-10-31"));
  assert(!isLive(NOV, "2026-10-30"));
  assert(isLive(NOV, "2026-12-03"));
  assert(!isLive(NOV, "2026-12-04"));
});

Deno.test("monthly challenges: keys, titles and the month's window", () => {
  const [w, d] = monthlyChallenges(2026, 11);
  assertEquals(w.auto_key, "monthly:2026-11:workouts");
  assertEquals(w.title, "November Grind: 12 workouts");
  assertEquals(d.auto_key, "monthly:2026-11:active_days");
  assertEquals(d.title, "Active November: 20 days");
  assertEquals([w.starts_on, w.ends_on], ["2026-11-01", "2026-11-30"]);
  assertEquals(monthlyChallenges(2028, 2)[0].ends_on, "2028-02-29");
  assertEquals(monthlyChallenges(2026, 12)[0].ends_on, "2026-12-31");
});

Deno.test("goal text", () => {
  assertEquals(goalText("workouts", 1), "1 workout");
  assertEquals(goalText("active_days", 20), "20 active days");
  assertEquals(goalText("volume_kg", 50000), "50,000 kg lifted");
  assertEquals(goalText("check_ins", 3), "3 check-ins");
});

Deno.test("dates are strict", () => {
  assert(isDay("2026-02-28"));
  assert(!isDay("2026-02-30"));
  assert(!isDay("2026-2-3"));
  assert(!isDay(20260101));
});

Deno.test("create input", () => {
  const today = "2026-11-01";
  const ok = readChallengeInput(
    { title: "  Squat-a-thon ", metric: "volume_kg", target: 50000, starts_on: "2026-11-02", ends_on: "2026-11-30" },
    { today },
  );
  assert("values" in ok);
  assertEquals(ok.values.title, "Squat-a-thon");
  const err = (b: Record<string, unknown>) => {
    const r = readChallengeInput({ title: "x", metric: "workouts", target: 5, starts_on: today, ends_on: today, ...b }, {
      today,
    });
    return "error" in r ? r.error : null;
  };
  assertEquals(err({}), null);
  assert(err({ metric: "pushups" })?.includes("metric"));
  assert(err({ target: 0 })?.includes("target"));
  assert(err({ target: 2.5 })?.includes("target"));
  assert(err({ title: "" })?.includes("title"));
  assert(err({ ends_on: "2026-10-31", starts_on: "2026-10-01" })?.includes("past"));
  assert(err({ ends_on: "2026-10-31" })?.includes("after"));
  assert(err({ ends_on: "2028-01-01" })?.includes("366"));
  assert(err({ metric: "check_ins" })?.includes("gym"));
  assertEquals(err({ metric: "check_ins", business_id: "33cbc480-111b-4541-94d1-3843301f7d6e" }), null);
});

Deno.test("edit input: the metric and start are fixed once it started", () => {
  const existing: ChallengeRow = {
    id: "c",
    business_id: "g",
    created_by: "u",
    title: "Old",
    description: null,
    metric: "workouts",
    target: 10,
    starts_on: "2026-11-01",
    ends_on: "2026-11-30",
    auto_key: null,
    created_at: "",
  };
  const edit = (b: Record<string, unknown>, today = "2026-11-10") => readChallengeInput(b, { today, existing });
  const t = edit({ target: 8, description: "  " });
  assert("values" in t);
  assertEquals(t.values, { target: 8, description: null });
  assert("error" in edit({ metric: "minutes" }));
  assert("error" in edit({ starts_on: "2026-11-05" }));
  assert("values" in edit({ metric: "minutes", starts_on: "2026-11-05" }, "2026-10-20"));
  // Past challenges can't be pushed to end in the past either way.
  assert("error" in edit({ ends_on: "2026-11-05" }));
});

Deno.test("wrapped availability", () => {
  assertEquals(availability(2026, "2026-11-30", true), {
    year: 2026,
    available: false,
    available_from: "2026-12-01",
    reason: "not_yet",
  });
  assertEquals(availability(2026, "2026-12-01", false).available, true);
  assertEquals(availability(2026, "2026-11-01", true, true).available, true);
  assertEquals(availability(2025, "2026-03-01", true), { year: 2025, available: true, available_from: null });
  assertEquals(availability(2025, "2026-03-01", false).reason, "no_data");
  assertEquals(availability(2027, "2026-12-15", true).reason, "not_yet");
});

Deno.test("wrapped helpers", () => {
  assertEquals(argMax([0, 0, 0]), null);
  assertEquals(argMax([1, 3, 3, 2]), 1);
  assert(inNoticeSeason(new Date("2026-12-01T00:00:00Z")));
  assert(inNoticeSeason(new Date("2026-11-30T15:00:00Z")));
  assert(!inNoticeSeason(new Date("2026-11-01T15:00:00Z")));
  assert(!inNoticeSeason(new Date("2027-01-01T00:00:00Z")));
});
