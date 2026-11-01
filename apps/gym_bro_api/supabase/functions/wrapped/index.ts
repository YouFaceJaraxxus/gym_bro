import { isSuperUser, json, jsonError, requireCaller } from "../_shared/auth.ts";
import { isTimezone } from "../_shared/plans.ts";
import { localDate, refreshStreak } from "../_shared/streaks.ts";
import { zoneOf } from "../_shared/challenges.ts";
import { availability, buildWrapped, FIRST_YEAR, yearsWithData } from "../_shared/wrapped.ts";

// Gym Bro Wrapped, the caller's own yearly recap (rules in _shared/wrapped.ts).
//
//   GET /wrapped?tz=          the years there is (or will be) a recap for:
//                             { today, current_year, years: [{year, available,
//                             available_from, reason?}] }, newest first
//   GET /wrapped/:year?tz=    the recap, or { year, available: false,
//                             available_from, reason: not_yet | no_data } (200).
//                             Super users may add ?preview=1 to open the
//                             current year before December.

async function handler(req: Request): Promise<Response> {
  const { caller, response } = await requireCaller(req);
  if (!caller) return response;
  if (req.method !== "GET") return jsonError("Not found", 404);
  const url = new URL(req.url);
  const parts = url.pathname.replace(/^\/wrapped\/?/, "").split("/").filter(Boolean);
  const tzParam = url.searchParams.get("tz");
  if (tzParam && !isTimezone(tzParam)) return jsonError("tz must be an IANA zone", 400);
  const tz = await zoneOf(caller.id, tzParam);
  const today = localDate(new Date(), tz);
  const currentYear = Number(today.slice(0, 4));

  // ── GET /wrapped ──────────────────────────────────────────────────────────────
  if (parts.length === 0) {
    const years = await yearsWithData(caller.id, tz);
    const all = [...new Set([currentYear, ...years.filter((y) => y <= currentYear)])].sort((a, b) => b - a);
    return json({
      today,
      current_year: currentYear,
      years: all.map((y) => availability(y, today, years.includes(y))),
    });
  }

  // ── GET /wrapped/:year ────────────────────────────────────────────────────────
  if (parts.length === 1) {
    const year = /^\d{4}$/.test(parts[0]) ? Number(parts[0]) : Number.NaN;
    if (!Number.isInteger(year) || year < FIRST_YEAR) return jsonError("year must be a year, e.g. 2026", 400);
    const preview = url.searchParams.get("preview") === "1" && isSuperUser(caller);
    const hasData = year < currentYear ? (await yearsWithData(caller.id, tz)).includes(year) : true;
    const a = availability(year, today, hasData, preview);
    if (!a.available) return json(a);
    const started = Date.now();
    // The longest streak reads the streak engine's history: bring it up to date.
    await refreshStreak(caller.id, { tz: tzParam }).catch((err) => console.error("wrapped streak", err));
    const recap = await buildWrapped(caller.id, tz, year);
    return json({ ...a, ...recap, generated_in_ms: Date.now() - started });
  }

  return jsonError("Not found", 404);
}

Deno.serve(async (req: Request) => {
  try {
    return await handler(req);
  } catch (e) {
    console.error("wrapped", e);
    return jsonError("Something went wrong", 500);
  }
});
