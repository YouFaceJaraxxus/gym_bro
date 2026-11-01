// deno-lint-ignore-file no-explicit-any
// Challenges and Wrapped: who may create, see, join and edit a gym or
// platform challenge, progress moving with a logged workout, completion and
// its notification, the leaderboard's opt-out, profile medals, and the
// yearly recap's availability and numbers. Every challenge, workout and
// notification made here is deleted in `finally`, and settings are put back.
import { call, checker, seededUsers, short, suite } from "./_client.ts";
import { sql } from "./_db.ts";

const TZ = "Europe/Belgrade";
const tzq = `tz=${encodeURIComponent(TZ)}`;

function addDays(day: string, n: number): string {
  const d = new Date(`${day}T00:00:00Z`);
  d.setUTCDate(d.getUTCDate() + n);
  return d.toISOString().slice(0, 10);
}

async function logWorkout(token: string, startedAt: Date): Promise<string | null> {
  const ex = ((await call("GET", "/exercises?page_size=1")).data as any[])[0];
  const r = await call("POST", "/training-sessions", token, {
    started_at: startedAt.toISOString(),
    ended_at: new Date(startedAt.getTime() + 45 * 60_000).toISOString(),
    sets: [{ exercise_id: ex.id, drops: [{ rep_type_actual: "count", rep_count_actual: 5, weight_kg_actual: 40 }] }],
  });
  return r.status === 201 ? r.data.id : null;
}

Deno.test({
  name: "features: challenges & wrapped",
  ...suite,
  async fn(t) {
    const { check, assertAll } = checker();
    const { member, owner, trainer, superU, vendor, gym } = await seededUsers();
    const today = (await call("GET", `/challenges?${tzq}`, member.token)).data?.today as string;
    const created: string[] = [];
    const everMade: string[] = [];
    const sessions: string[] = [];

    try {
      await t.step("who may create", async () => {
        const body = {
          business_id: gym.id,
          title: "Test: lift a ton",
          metric: "workouts",
          target: 1000,
          starts_on: addDays(today, -1),
          ends_on: addDays(today, 7),
        };
        check("a member can't create a gym challenge → 403",
          (await call("POST", "/challenges", member.token, body)).status === 403);
        const { business_id: _b, ...platform } = body;
        check("a member can't create a platform challenge → 403",
          (await call("POST", "/challenges", member.token, platform)).status === 403);
        check("check-ins need a gym → 400",
          (await call("POST", "/challenges", superU.token, { ...platform, metric: "check_ins" })).status === 400);
        check("bad dates → 400",
          (await call("POST", "/challenges", trainer.token, { ...body, ends_on: addDays(today, -3) })).status === 400);

        const r = await call("POST", `/challenges?${tzq}`, trainer.token, body);
        check("the gym's trainer creates one → 201", r.status === 201, short(r.data));
        if (r.data?.id) {
          created.push(r.data.id);
          everMade.push(r.data.id);
        }
        check("…active, with days left", r.data?.status === "active" && r.data?.days_left === 8, short(r.data));
        check("…the creator may edit it", r.data?.can_edit === true);

        const p = await call("POST", `/challenges?${tzq}`, superU.token, { ...platform, title: "Test: platform" });
        check("a super user creates a platform one → 201", p.status === 201 && p.data?.business === null, short(p.data));
        if (p.data?.id) {
          created.push(p.data.id);
          everMade.push(p.data.id);
        }
        assertAll();
      });

      const [gymChallenge, platformChallenge] = created;

      await t.step("who sees it", async () => {
        const list = await call("GET", `/challenges?gym_id=${gym.id}&${tzq}`, member.token);
        check("the gym's member lists it", list.data?.items?.some((c: any) => c.id === gymChallenge), short(list.data));
        const all = await call("GET", `/challenges?${tzq}`, vendor.token);
        check("an outsider sees the platform one", all.data?.items?.some((c: any) => c.id === platformChallenge));
        check("…but not the gym's", !all.data?.items?.some((c: any) => c.id === gymChallenge));
        check("…nor opens it → 404", (await call("GET", `/challenges/${gymChallenge}`, vendor.token)).status === 404);
        check("…nor lists the gym → 403",
          (await call("GET", `/challenges?gym_id=${gym.id}`, vendor.token)).status === 403);
        const n = (await call("GET", "/notifications?page_size=30", member.token)).data?.items ?? [];
        check("members hear about a new gym challenge",
          n.some((x: any) => x.type === "challenge" && x.metadata?.challenge_id === gymChallenge && x.metadata?.kind === "new"));
        assertAll();
      });

      await t.step("join, progress, completion", async () => {
        const joined = await call("POST", `/challenges/${gymChallenge}/join?${tzq}`, member.token);
        check("join → 200", joined.status === 200 && joined.data?.me?.joined === true, short(joined.data));
        const p0 = joined.data?.me?.progress ?? 0;
        check("…on the leaderboard", joined.data?.leaderboard?.some((e: any) => e.user?.id === member.profile.id));

        const id = await logWorkout(member.token, new Date(Date.now() - 60 * 60_000));
        if (id) sessions.push(id);
        check("log a workout", !!id);
        const after = await call("GET", `/challenges/${gymChallenge}?${tzq}`, member.token);
        check("progress moved", after.data?.me?.progress === p0 + 1, `${p0} → ${after.data?.me?.progress}`);

        check("a member can't edit it → 403",
          (await call("PATCH", `/challenges/${gymChallenge}`, member.token, { target: 1 })).status === 403);
        check("the metric is fixed once started → 400",
          (await call("PATCH", `/challenges/${gymChallenge}`, trainer.token, { metric: "minutes" })).status === 400);
        const edit = await call("PATCH", `/challenges/${gymChallenge}?${tzq}`, trainer.token, { target: p0 + 1 });
        check("the creator lowers the target → 200", edit.status === 200 && edit.data?.target === p0 + 1, short(edit.data));

        const done = await call("GET", `/challenges/${gymChallenge}?${tzq}`, member.token);
        check("…which completes it", typeof done.data?.me?.completed_at === "string", short(done.data?.me));
        const n = (await call("GET", "/notifications?page_size=30", member.token)).data?.items ?? [];
        check("a completion notification",
          n.some((x: any) => x.type === "challenge" && x.metadata?.challenge_id === gymChallenge && x.metadata?.kind === "completed"));

        const medals = await call("GET", `/challenges/completed?user_id=${member.profile.id}`, owner.token);
        check("it's on their profile", medals.status === 200 && medals.data?.items?.some((c: any) => c.id === gymChallenge),
          short(medals.data));

        await call("DELETE", `/training-sessions/${sessions.pop()}`, member.token);
        const back = await call("GET", `/challenges/${gymChallenge}?${tzq}`, member.token);
        check("deleting the workout moves progress back", back.data?.me?.progress === p0, `${back.data?.me?.progress}`);
        check("…but the medal stays", typeof back.data?.me?.completed_at === "string");
        assertAll();
      });

      await t.step("leaderboard opt-out, leaving, deleting", async () => {
        const before = (await call("GET", "/users/me/settings", member.token)).data;
        try {
          await call("PUT", "/users/me/settings", member.token, { show_on_gym_boards: false });
          const seen = await call("GET", `/challenges/${gymChallenge}`, trainer.token);
          check("an opted-out member isn't on others' leaderboard",
            seen.status === 200 && !seen.data?.leaderboard?.some((e: any) => e.user?.id === member.profile.id));
          const mine = await call("GET", `/challenges/${gymChallenge}`, member.token);
          check("…but sees themself", mine.data?.leaderboard?.some((e: any) => e.user?.id === member.profile.id));
        } finally {
          await call("PUT", "/users/me/settings", member.token, { show_on_gym_boards: before?.show_on_gym_boards ?? true });
        }
        check("leave → 204", (await call("DELETE", `/challenges/${gymChallenge}/join`, member.token)).status === 204);
        check("a member can't delete it → 403",
          (await call("DELETE", `/challenges/${platformChallenge}`, member.token)).status === 403);
        const del = await call("DELETE", `/challenges/${gymChallenge}`, owner.token);
        check("the gym's owner deletes it → 204", del.status === 204);
        if (del.status === 204) created.splice(created.indexOf(gymChallenge), 1);
        assertAll();
      });

      await t.step("wrapped", async () => {
        const idx = await call("GET", `/wrapped?${tzq}`, member.token);
        check("GET /wrapped → 200", idx.status === 200 && Array.isArray(idx.data?.years), short(idx.data));
        check("bad year → 400", (await call("GET", "/wrapped/1999", member.token)).status === 400);
        const year = Number(today.slice(0, 4));
        const now = await call("GET", `/wrapped/${year}?${tzq}`, member.token);
        if (today < `${year}-12-01`) {
          check("this year opens on Dec 1", now.data?.available === false && now.data?.available_from === `${year}-12-01`,
            short(now.data));
          const preview = await call("GET", `/wrapped/${year}?preview=1&${tzq}`, superU.token);
          check("super users can preview it", preview.data?.available === true && typeof preview.data?.totals === "object",
            short(preview.data));
          const ignored = await call("GET", `/wrapped/${year}?preview=1&${tzq}`, member.token);
          check("…members can't", ignored.data?.available === false);
        }

        // A workout last year opens last year's recap.
        const last = year - 1;
        const before = await call("GET", `/wrapped/${last}?${tzq}`, member.token);
        const id = await logWorkout(member.token, new Date(`${last}-06-15T10:00:00Z`));
        if (id) sessions.push(id);
        const r = await call("GET", `/wrapped/${last}?${tzq}`, member.token);
        check("a past year with data is available", r.data?.available === true, short(r.data));
        const prev = before.data?.available ? before.data.totals.workouts : 0;
        check("…and counts it", r.data?.totals?.workouts === prev + 1 && r.data?.by_month?.[5] >= 1, short(r.data?.totals));
        check("…with its top exercise", r.data?.top_exercises_by_sets?.length >= 1);
        check("…its volume", r.data?.totals?.volume_kg === (before.data?.totals?.volume_kg ?? 0) + 200, short(r.data?.totals));
        // 15 June of last year, as an ISO weekday.
        const dow = new Date(Date.UTC(last, 5, 15)).getUTCDay() || 7;
        check("…busiest weekday", prev > 0 || r.data?.busiest_weekday === dow, `${r.data?.busiest_weekday} vs ${dow}`);
        check("…fast", (r.data?.generated_in_ms ?? 9999) < 1500, `${r.data?.generated_in_ms} ms`);
        assertAll();
      });
    } finally {
      for (const id of sessions) await call("DELETE", `/training-sessions/${id}`, member.token);
      for (const id of created) await call("DELETE", `/challenges/${id}`, superU.token);
      // Every gym member was told about the new challenge.
      if (everMade.length) {
        await sql("DELETE FROM notification WHERE type = 'challenge' AND metadata->>'challenge_id' = ANY($1)", [everMade]);
      }
    }
  },
});
