// deno-lint-ignore-file no-explicit-any
// Workout streaks and gym boards: the member's streak status, a logged
// workout moving it (and deleting it moving it back), someone else's public
// streak, board access and the streak settings. The workout logged here is
// deleted through the API in `finally`, and the settings are put back.
import { call, checker, seededUsers, short, suite } from "./_client.ts";

const TZ = "Europe/Belgrade";

Deno.test({
  name: "features: workout streaks & gym boards",
  ...suite,
  async fn(t) {
    const { check, assertAll } = checker();
    const { member, owner, vendor, gym } = await seededUsers();

    await t.step("streak status", async () => {
      const r = await call("GET", `/streaks?tz=${encodeURIComponent(TZ)}`, member.token);
      check("GET /streaks → 200", r.status === 200, short(r.data));
      check("has the counters", typeof r.data?.current === "number" && typeof r.data?.freezes === "number");
      check("lists the badge ladder", r.data?.tiers?.length === 7 && r.data.tiers[0].tier === "bronze");
      check("has this week", typeof r.data?.week?.target === "number" && Array.isArray(r.data?.week?.entries));
      check("bad tz → 400", (await call("GET", "/streaks?tz=Mars/Base", member.token)).status === 400);

      const theirs = await call("GET", `/streaks?user_id=${member.profile.id}`, owner.token);
      check("someone's public streak → 200", theirs.status === 200, short(theirs.data));
      check("…without their freezes", theirs.data && !("freezes" in theirs.data) && "best_tier" in theirs.data);
      assertAll();
    });

    await t.step("a logged workout moves the streak", async () => {
      let sessionId: string | null = null;
      try {
        const before = (await call("GET", `/streaks?tz=${encodeURIComponent(TZ)}`, member.token)).data;
        const ex = ((await call("GET", "/exercises?page_size=1")).data as any[])[0];
        const now = Date.now();
        const logged = await call("POST", "/training-sessions", member.token, {
          started_at: new Date(now - 60 * 60_000).toISOString(),
          ended_at: new Date(now - 5 * 60_000).toISOString(),
          sets: [{ exercise_id: ex.id, drops: [{ rep_type: "count", rep_count: 5, weight_kg: 40 }] }],
        });
        sessionId = logged.data?.id ?? null;
        check("log a finished workout → 201", logged.status === 201, short(logged.data));
        check("returns the streak", logged.data?.streak?.current === before.current + 1, short(logged.data?.streak));
        check("…and where it was", logged.data?.streak?.previous === before.current);

        const del = await call("DELETE", `/training-sessions/${sessionId}`, member.token);
        check("delete it → 204", del.status === 204);
        sessionId = null;
        const after = (await call("GET", "/streaks", member.token)).data;
        check("the streak goes back", after?.current === before.current, `${after?.current} vs ${before.current}`);
      } finally {
        if (sessionId) await call("DELETE", `/training-sessions/${sessionId}`, member.token);
      }
      assertAll();
    });

    await t.step("gym boards", async () => {
      for (const board of ["streak", "workouts", "check_ins"]) {
        const r = await call("GET", `/streaks/boards/${gym.id}?board=${board}&tz=${encodeURIComponent(TZ)}`, owner.token);
        check(`owner sees the ${board} board`, r.status === 200 && Array.isArray(r.data?.entries), short(r.data));
        const ranks = (r.data?.entries ?? []).map((e: any) => e.rank);
        check(`${board} ranks ascend`, ranks.every((x: number, i: number) => i === 0 || x >= ranks[i - 1]));
      }
      check("bad board → 400", (await call("GET", `/streaks/boards/${gym.id}?board=volume`, owner.token)).status === 400);
      const outsider = await call("GET", `/streaks/boards/${gym.id}`, vendor.token);
      check("non-members can't see it → 403", outsider.status === 403, short(outsider.data));
      assertAll();
    });

    await t.step("streak settings", async () => {
      const before = (await call("GET", "/users/me/settings", member.token)).data;
      try {
        check(
          "target out of range → 400",
          (await call("PUT", "/users/me/settings", member.token, { weekly_workout_target: 15 })).status === 400,
        );
        const r = await call("PUT", "/users/me/settings", member.token, {
          weekly_workout_target: 4,
          show_on_gym_boards: false,
        });
        check("save target and board visibility", r.status === 200 && r.data?.weekly_workout_target === 4 &&
          r.data?.show_on_gym_boards === false, short(r.data));
      } finally {
        await call("PUT", "/users/me/settings", member.token, {
          weekly_workout_target: before?.weekly_workout_target ?? 3,
          show_on_gym_boards: before?.show_on_gym_boards ?? true,
        });
      }
      assertAll();
    });
  },
});
