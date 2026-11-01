// deno-lint-ignore-file no-explicit-any
// Water tracking: today's summary and goal, adding drinks (validation
// included), history, and deleting only my own entries. Every entry added
// here is deleted again in `finally`, and the water goal is put back.
import { call, checker, seededUsers, short, suite } from "./_client.ts";

const TZ = "Europe/Belgrade";
const q = `tz=${encodeURIComponent(TZ)}`;

Deno.test({
  name: "features: water tracking",
  ...suite,
  async fn(t) {
    const { check, assertAll } = checker();
    const { member, owner } = await seededUsers();
    const added: string[] = [];

    try {
      await t.step("today and adding drinks", async () => {
        const before = await call("GET", `/water-logs/today?${q}`, member.token);
        check("GET /water-logs/today → 200", before.status === 200, short(before.data));
        check("has the day and total", /^\d{4}-\d{2}-\d{2}$/.test(before.data?.date) && typeof before.data?.total_ml === "number");
        check("has a goal", before.data?.goal_ml >= before.data?.base_goal_ml && before.data?.base_goal_ml >= 500);
        check("goal includes the workout bonus", before.data?.goal_ml === before.data?.base_goal_ml + before.data?.workout_bonus_ml);
        check("bad tz → 400", (await call("GET", "/water-logs/today?tz=Mars/Base", member.token)).status === 400);
        check("anonymous → 401", (await call("GET", "/water-logs/today")).status === 401);

        const r = await call("POST", `/water-logs?${q}`, member.token, { ml: 330 });
        if (r.data?.entry?.id) added.push(r.data.entry.id);
        check("POST → 201", r.status === 201, short(r.data));
        check("returns the entry", r.data?.entry?.ml === 330 && typeof r.data?.entry?.logged_at === "string");
        check("…and today's new total", r.data?.today?.total_ml === before.data.total_ml + 330, short(r.data?.today));
        check("…with the entry first", r.data?.today?.entries?.[0]?.id === r.data?.entry?.id);

        const back = await call("POST", `/water-logs?${q}`, member.token, {
          ml: 200,
          logged_at: new Date(Date.now() - 3 * 86_400_000).toISOString(),
        });
        if (back.data?.entry?.id) added.push(back.data.entry.id);
        check("backdated drink → 201", back.status === 201, short(back.data));
        check("…not counted today", back.data?.today?.total_ml === before.data.total_ml + 330);

        for (const [name, body] of [
          ["ml 0", { ml: 0 }],
          ["ml too big", { ml: 3001 }],
          ["ml not a number", { ml: "250" }],
          ["ml fractional", { ml: 2.5 }],
          ["future logged_at", { ml: 100, logged_at: new Date(Date.now() + 3_600_000).toISOString() }],
          ["logged_at too old", { ml: 100, logged_at: new Date(Date.now() - 60 * 86_400_000).toISOString() }],
          ["bad logged_at", { ml: 100, logged_at: "yesterday" }],
        ] as const) {
          const bad = await call("POST", "/water-logs", member.token, body);
          if (bad.data?.entry?.id) added.push(bad.data.entry.id);
          check(`${name} → 400`, bad.status === 400, short(bad.data));
        }
        assertAll();
      });

      await t.step("history", async () => {
        const r = await call("GET", `/water-logs/history?days=7&${q}`, member.token);
        check("GET /water-logs/history → 200", r.status === 200, short(r.data));
        const days = r.data?.days ?? [];
        check("one row per day", days.length === 7, `${days.length}`);
        check("oldest first, ending today", days[0]?.date === r.data?.from && days[6]?.date === r.data?.to);
        const threeAgo = days[3];
        check("the backdated drink lands on its day", threeAgo?.total_ml >= 200, short(threeAgo));
        check("each day has a goal", days.every((d: any) => d.goal_ml >= r.data.base_goal_ml));
        check("days=0 → 400", (await call("GET", "/water-logs/history?days=0", member.token)).status === 400);
        check("days=91 → 400", (await call("GET", "/water-logs/history?days=91", member.token)).status === 400);
        assertAll();
      });

      await t.step("the goal follows the setting", async () => {
        const settings = (await call("GET", "/users/me/settings", member.token)).data;
        try {
          await call("PUT", "/users/me/settings", member.token, { water_goal_ml: 3100 });
          const r = await call("GET", `/water-logs/today?${q}`, member.token);
          check("custom goal used", r.data?.base_goal_ml === 3100 && r.data?.auto_goal === false, short(r.data));
          await call("PUT", "/users/me/settings", member.token, { water_goal_ml: null });
          const auto = await call("GET", `/water-logs/today?${q}`, member.token);
          check("auto goal again", auto.data?.auto_goal === true, short(auto.data));
        } finally {
          await call("PUT", "/users/me/settings", member.token, { water_goal_ml: settings?.water_goal_ml ?? null });
        }
        assertAll();
      });

      await t.step("deleting", async () => {
        const id = added[0];
        const theirs = await call("DELETE", `/water-logs/${id}`, owner.token);
        check("someone else's entry → 404", theirs.status === 404, short(theirs.data));
        check("bad id → 404", (await call("DELETE", "/water-logs/not-a-uuid", member.token)).status === 404);
        const before = (await call("GET", `/water-logs/today?${q}`, member.token)).data;
        const del = await call("DELETE", `/water-logs/${id}?${q}`, member.token);
        check("delete mine → 200", del.status === 200, short(del.data));
        check("…returns the new total", del.data?.today?.total_ml === before.total_ml - 330);
        added.shift();
        check("deleting again → 404", (await call("DELETE", `/water-logs/${id}`, member.token)).status === 404);
        assertAll();
      });
    } finally {
      for (const id of added) await call("DELETE", `/water-logs/${id}`, member.token);
    }
  },
});
