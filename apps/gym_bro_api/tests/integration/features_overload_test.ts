// deno-lint-ignore-file no-explicit-any
// GET /training-sessions/last-sets: per exercise, the sets of the caller's
// most recent finished session (what progressive-overload suggestions are
// built from). A private exercise and back-dated sessions are created and
// deleted through the API in `finally`.
import { call, checker, seededUsers, short, suite } from "./_client.ts";

const uniq = () => `it-${crypto.randomUUID().slice(0, 8)}`;
const daysAgo = (d: number) => new Date(Date.now() - d * 86_400_000);

Deno.test({
  name: "features: last sets for progressive overload",
  ...suite,
  async fn() {
    const { check, assertAll } = checker();
    const { member, trainer, vendor } = await seededUsers();
    const name = uniq();
    const sessionIds: string[] = [];
    let exerciseId: string | null = null;
    let otherId: string | null = null;

    const logSession = async (startedDaysAgo: number, drops: any[], ended = true) => {
      const start = daysAgo(startedDaysAgo);
      const r = await call("POST", "/training-sessions", member.token, {
        started_at: start.toISOString(),
        ...(ended && { ended_at: new Date(start.getTime() + 3600_000).toISOString() }),
        notes: "overload test",
        sets: [{ exercise_id: exerciseId, drops }],
      });
      if (r.data?.id) sessionIds.push(r.data.id);
      return r;
    };

    try {
      const ex = await call("POST", "/exercises", member.token, { name: `${name} bench`, primary_muscles: ["chest_all"], is_public: false });
      exerciseId = ex.data?.id ?? null;
      const other = await call("POST", "/exercises", member.token, { name: `${name} never`, is_public: false });
      otherId = other.data?.id ?? null;
      check("creates test exercises", ex.status === 201 && other.status === 201, short(ex.data));

      const older = await logSession(40, [{ rep_count_actual: 10, weight_kg_actual: 70 }]);
      const newer = await logSession(3, [
        { rep_count_actual: 8, weight_kg_actual: 80 },
        { rep_count_actual: 8, weight_kg_actual: 80 },
        { rep_count_actual: 7, weight_kg_actual: 80 },
      ]);
      // Not counted: still running (no ended_at), and one logged ahead of time.
      const live = await logSession(1, [{ rep_count_actual: 12, weight_kg_actual: 90 }], false);
      const ahead = await call("POST", "/training-sessions", member.token, {
        started_at: new Date(Date.now() + 3 * 86_400_000).toISOString(),
        ended_at: new Date(Date.now() + 3 * 86_400_000 + 3600_000).toISOString(),
        sets: [{ exercise_id: exerciseId, drops: [{ rep_count_actual: 5, weight_kg_actual: 100 }] }],
      });
      if (ahead.data?.id) sessionIds.push(ahead.data.id);
      check(
        "logs the history",
        older.status === 201 && newer.status === 201 && live.status === 201 && ahead.status === 201,
        `${older.status} ${newer.status} ${live.status} ${ahead.status}`,
      );

      const ids = `${exerciseId},${otherId}`;
      const r = await call("GET", `/training-sessions/last-sets?exercise_ids=${ids}`, member.token);
      const row = (r.data as any[])?.find((x) => x.exercise_id === exerciseId);
      check(
        "returns the latest finished session's sets in order",
        r.status === 200 && r.data.length === 1 && !!row && row.session_id === newer.data.id &&
          row.sets.length === 3 && row.sets.map((s: any) => s.reps).join() === "8,8,7" &&
          row.sets.every((s: any) => s.weight_kg === 80 && s.rep_type === "count") &&
          new Date(row.started_at).getTime() === new Date(newer.data.started_at).getTime(),
        short(r.data),
      );

      const before = await call(
        "GET",
        `/training-sessions/last-sets?exercise_ids=${exerciseId}&before=${encodeURIComponent(daysAgo(10).toISOString())}`,
        member.token,
      );
      check(
        "before= looks further back",
        before.status === 200 && before.data[0]?.session_id === older.data.id && before.data[0]?.sets[0]?.weight_kg === 70,
        short(before.data),
      );

      const coach = await call("GET", `/training-sessions/last-sets?exercise_ids=${exerciseId}&user_id=${member.profile.id}`, trainer.token);
      check("a trainer reads a client's last sets", coach.status === 200 && coach.data[0]?.session_id === newer.data.id, short(coach.data));
      const own = await call("GET", `/training-sessions/last-sets?exercise_ids=${exerciseId}`, trainer.token);
      check("without user_id it's the caller's own history", own.status === 200 && own.data.length === 0, short(own.data));
      const stranger = await call("GET", `/training-sessions/last-sets?exercise_ids=${exerciseId}&user_id=${member.profile.id}`, vendor.token);
      check("someone who doesn't coach them is refused", stranger.status === 403, `status ${stranger.status}`);

      const empty = await call("GET", "/training-sessions/last-sets", member.token);
      check("no exercise_ids is an empty list", empty.status === 200 && Array.isArray(empty.data) && empty.data.length === 0, short(empty.data));
      const bad = await call("GET", "/training-sessions/last-sets?exercise_ids=nope", member.token);
      check("malformed exercise id is 400", bad.status === 400, `status ${bad.status}`);
      const badBefore = await call("GET", `/training-sessions/last-sets?exercise_ids=${exerciseId}&before=nope`, member.token);
      check("malformed before is 400", badBefore.status === 400, `status ${badBefore.status}`);
      const badUser = await call("GET", `/training-sessions/last-sets?exercise_ids=${exerciseId}&user_id=nope`, trainer.token);
      check("malformed user_id is 400", badUser.status === 400, `status ${badUser.status}`);
      const post = await call("POST", "/training-sessions/last-sets", member.token, {});
      check("only GET", post.status === 405, `status ${post.status}`);
      const anon = await call("GET", `/training-sessions/last-sets?exercise_ids=${exerciseId}`);
      check("needs a signed-in user", anon.status === 401, `status ${anon.status}`);
    } finally {
      for (const id of sessionIds) await call("DELETE", `/training-sessions/${id}`, member.token);
      for (const id of [exerciseId, otherId]) if (id) await call("DELETE", `/exercises/${id}`, member.token);
    }
    assertAll();
  },
});
