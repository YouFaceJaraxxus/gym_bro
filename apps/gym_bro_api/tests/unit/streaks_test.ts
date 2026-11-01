import "./_env_stub.ts";
import { assertEquals } from "jsr:@std/assert@1";
import {
  doneEntryIds,
  isoDow,
  live,
  nextTier,
  settle,
  type SimEntry,
  type SimState,
  type SimWorkout,
  tierFor,
  weekRequirement,
  weekStart,
} from "../../supabase/functions/_shared/streaks.ts";

// Weeks used below (ISO, Monday–Sunday): 2026-10-05…11, 10-12…18, 10-19…25.
const ZERO: SimState = { current: 0, since: null, best: 0, freezes: 0 };
const w = (day: string, planEntryId: string | null = null): SimWorkout => ({ day, planEntryId });
const e = (id: string, day: string, skipped = false): SimEntry => ({ id, day, skipped });
const run = (state: SimState, from: string, through: string, workouts: SimWorkout[], entries: SimEntry[] = []) =>
  settle(state, { from, through, workouts, entries, target: 3 });

Deno.test("tiers follow the ladder", () => {
  assertEquals(tierFor(9), null);
  assertEquals(tierFor(10), "bronze");
  assertEquals(tierFor(99), "silver");
  assertEquals(tierFor(365), "emerald");
  assertEquals(tierFor(5000), "diamond");
  assertEquals(nextTier(0), { tier: "bronze", at: 10 });
  assertEquals(nextTier(100), { tier: "ruby", at: 200 });
  assertEquals(nextTier(1000), null);
});

Deno.test("local week helpers", () => {
  assertEquals(isoDow("2026-11-01"), 7);
  assertEquals(isoDow("2026-10-26"), 1);
  assertEquals(weekStart("2026-11-01"), "2026-10-26");
  assertEquals(weekStart("2026-10-26"), "2026-10-26");
});

Deno.test("a week on target keeps the streak and earns a freeze", () => {
  const r = run(ZERO, "2026-10-05", "2026-10-11", [w("2026-10-05"), w("2026-10-07"), w("2026-10-09")]);
  assertEquals(r.state, { current: 3, since: "2026-10-05", best: 3, freezes: 1 });
  assertEquals(r.events.map((x) => x.kind), ["freeze_earned"]);
});

Deno.test("a week under target ends the streak, unless a freeze covers it", () => {
  const start: SimState = { current: 12, since: "2026-09-01", best: 12, freezes: 0 };
  const broken = run(start, "2026-10-05", "2026-10-11", [w("2026-10-06")]);
  assertEquals(broken.state.current, 0);
  assertEquals(broken.state.best, 13);
  assertEquals(broken.events.at(-1), { kind: "broken", day: "2026-10-11", streak: 13, planEntryId: null });

  const frozen = run({ ...start, freezes: 1 }, "2026-10-05", "2026-10-11", [w("2026-10-06")]);
  assertEquals(frozen.state, { current: 13, since: "2026-09-01", best: 13, freezes: 0 });
  assertEquals(frozen.events.map((x) => x.kind), ["freeze_used"]);
});

Deno.test("the week a streak starts in is prorated", () => {
  assertEquals(weekRequirement(3, "2026-10-05", null), 3);
  assertEquals(weekRequirement(3, "2026-10-05", "2026-10-01"), 3);
  assertEquals(weekRequirement(3, "2026-10-05", "2026-10-10"), 1); // Saturday: 2 days left
  assertEquals(weekRequirement(5, "2026-10-05", "2026-10-08"), 3); // Thursday: 4 days left
  const r = run(ZERO, "2026-10-10", "2026-10-11", [w("2026-10-10")]);
  assertEquals(r.state.current, 1);
  assertEquals(r.state.freezes, 1);
});

Deno.test("a missed planned workout ends the streak before that day's workouts", () => {
  const start: SimState = { current: 5, since: "2026-09-20", best: 5, freezes: 0 };
  // Planned Monday and Wednesday; Monday's not done, Wednesday's is.
  const r = run(start, "2026-10-05", "2026-10-11", [w("2026-10-07", "wed")], [e("mon", "2026-10-05"), e("wed", "2026-10-07")]);
  assertEquals(r.events.map((x) => x.kind), ["broken"]);
  assertEquals(r.events[0].planEntryId, "mon");
  // A planned week doesn't use the target, but it wasn't perfect: no freeze.
  assertEquals(r.state, { current: 1, since: "2026-10-07", best: 5, freezes: 0 });
});

Deno.test("planned weeks only need what's planned", () => {
  const r = run(ZERO, "2026-10-05", "2026-10-11", [w("2026-10-08", "thu")], [e("thu", "2026-10-08")]);
  assertEquals(r.state, { current: 1, since: "2026-10-08", best: 1, freezes: 1 });
});

Deno.test("skipping counts as a miss, but a workout that day still does it", () => {
  const start: SimState = { current: 4, since: "2026-09-20", best: 4, freezes: 2 };
  const skipped = run(start, "2026-10-05", "2026-10-11", [], [e("mon", "2026-10-05", true)]);
  assertEquals(skipped.state.freezes, 1);
  assertEquals(skipped.events.map((x) => x.kind), ["freeze_used"]);

  const trainedAnyway = run(start, "2026-10-05", "2026-10-11", [w("2026-10-05")], [e("mon", "2026-10-05", true)]);
  assertEquals(trainedAnyway.state.current, 5);
  assertEquals(trainedAnyway.events.map((x) => x.kind), []); // already holds two freezes
});

Deno.test("one miss per day, however many entries it had", () => {
  const start: SimState = { current: 4, since: "2026-09-20", best: 4, freezes: 2 };
  const r = run(start, "2026-10-05", "2026-10-05", [], [e("a", "2026-10-05"), e("b", "2026-10-05")]);
  assertEquals(r.state.freezes, 1);
});

Deno.test("a workout linked to an entry does that entry even on another day", () => {
  const done = doneEntryIds([e("mon", "2026-10-05"), e("tue", "2026-10-06")], [w("2026-10-06", "mon"), w("2026-10-06")]);
  assertEquals([...done].sort(), ["mon", "tue"]);
});

Deno.test("misses at zero change nothing; freezes cap at two", () => {
  assertEquals(run(ZERO, "2026-10-05", "2026-10-11", [], [e("mon", "2026-10-05")]).events, []);
  const weeks = [
    "2026-10-05", "2026-10-07", "2026-10-09",
    "2026-10-12", "2026-10-14", "2026-10-16",
    "2026-10-19", "2026-10-21", "2026-10-23",
  ].map((d) => w(d));
  const r = run(ZERO, "2026-10-05", "2026-10-25", weeks);
  assertEquals(r.state.freezes, 2);
  assertEquals(r.events.filter((x) => x.kind === "freeze_earned").length, 2);
});

Deno.test("live adds the open days and badges on the way up", () => {
  const settled: SimState = { current: 9, since: "2026-09-01", best: 9, freezes: 0 };
  const r = live(settled, "2026-10-09", [w("2026-10-08"), w("2026-10-10"), w("2026-10-11")]);
  assertEquals(r.state.current, 11);
  assertEquals(r.state.best, 11);
  assertEquals(r.events, [{ kind: "tier", day: "2026-10-10", streak: 10, tier: "bronze" }]);
  // Badges are only ever earned once.
  assertEquals(live({ ...r.state, current: 0 }, null, Array(12).fill(w("2026-10-20"))).events, []);
});
