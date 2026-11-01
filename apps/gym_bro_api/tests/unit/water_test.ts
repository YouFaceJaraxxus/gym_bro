import { assertEquals } from "jsr:@std/assert@1";
import {
  baseGoalMl,
  dayGoalMl,
  DEFAULT_HISTORY_DAYS,
  readDays,
  readLoggedAt,
  readMl,
} from "../../supabase/functions/water-logs/rules.ts";

Deno.test("water goal: chosen, from body weight, or the default", () => {
  assertEquals(baseGoalMl(3200, 80), 3200);
  assertEquals(baseGoalMl(null, null), 2500);
  assertEquals(baseGoalMl(undefined, 0), 2500);
  // 35 ml/kg, rounded to 50 ml
  assertEquals(baseGoalMl(null, 80), 2800);
  assertEquals(baseGoalMl(null, 71.3), 2500); // 2495.5 → 2500
  assertEquals(baseGoalMl(null, 70.6), 2450); // 2471 → 2450
  // clamped to 1.5–5 l
  assertEquals(baseGoalMl(null, 30), 1500);
  assertEquals(baseGoalMl(null, 200), 5000);
});

Deno.test("water goal: +500 ml on a workout day", () => {
  assertEquals(dayGoalMl(2500, false), 2500);
  assertEquals(dayGoalMl(2500, true), 3000);
});

Deno.test("water input validation", () => {
  assertEquals(readMl(250), 250);
  assertEquals(readMl(3000), 3000);
  assertEquals(typeof readMl(0), "string");
  assertEquals(typeof readMl(3001), "string");
  assertEquals(typeof readMl(2.5), "string");
  assertEquals(typeof readMl("250"), "string");

  const now = Date.parse("2026-11-01T12:00:00Z");
  assertEquals(readLoggedAt(undefined, now), undefined);
  assertEquals(readLoggedAt(null, now), undefined);
  assertEquals((readLoggedAt("2026-11-01T09:30:00Z", now) as Date).toISOString(), "2026-11-01T09:30:00.000Z");
  assertEquals(typeof readLoggedAt("yesterday", now), "string");
  assertEquals(typeof readLoggedAt(123, now), "string");
  assertEquals(typeof readLoggedAt("2026-11-01T13:00:00Z", now), "string"); // future
  assertEquals(typeof readLoggedAt("2026-09-01T12:00:00Z", now), "string"); // too old

  assertEquals(readDays(null), DEFAULT_HISTORY_DAYS);
  assertEquals(readDays("14"), 14);
  assertEquals(typeof readDays("0"), "string");
  assertEquals(typeof readDays("91"), "string");
  assertEquals(typeof readDays("7.5"), "string");
});
