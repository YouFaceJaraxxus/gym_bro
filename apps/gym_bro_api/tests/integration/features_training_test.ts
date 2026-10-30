// deno-lint-ignore-file no-explicit-any
// Progress & body measurements, routine assignments, session comments and PR
// detection; exercise / training / routine CRUD with nested sets, and a full
// session lifecycle whose PRs show up in /progress. Everything created
// (exercises, trainings, routines, sessions, assignments, notifications) is
// deleted through the API in `finally`.
import { call, checker, dayFromToday, deleteNotifications, notificationsOf, seededUsers, short, suite } from "./_client.ts";

/** muscle_group[] columns come back as JSON arrays; joined for comparison (undefined for anything else). */
const muscles = (x: any): string | undefined => Array.isArray(x) ? x.join() : undefined;
const uniq = () => `it-${crypto.randomUUID().slice(0, 8)}`;

Deno.test({
  name: "features: progress, body, routines, session comments",
  ...suite,
  async fn(t) {
    const { check, assertAll } = checker();
    const { member, trainer, vendor, employee, superU } = await seededUsers();

    await t.step("6. progress and body measurements", async () => {
      const summary = await call("GET", "/progress/summary", member.token);
      check(
        "member reads own progress summary",
        summary.status === 200 && summary.data.user_id === member.profile.id && summary.data.sessions_total >= 1 &&
          typeof summary.data.streak_weeks === "number" && Array.isArray(summary.data.recent_prs),
        short(summary.data),
      );
      const exercises = await call("GET", "/progress/exercises", member.token);
      const ex = (exercises.data as any[])?.find((e) => e.best_e1rm != null);
      check("member lists performed exercises", exercises.status === 200 && !!ex && Array.isArray(ex.trend), short(exercises.data?.[0]));
      if (ex) {
        const detail = await call("GET", `/progress/exercises/${ex.id}`, member.token);
        check(
          "exercise detail has series and all-time PRs",
          detail.status === 200 && detail.data.exercise.id === ex.id && detail.data.series.length >= 1 &&
            detail.data.prs.best_e1rm?.value === ex.best_e1rm,
          short(detail.data?.prs),
        );
        const ranged = await call("GET", `/progress/exercises/${ex.id}?from=2000-01-01&to=2000-01-02`, member.token);
        check("from/to narrows the series", ranged.status === 200 && ranged.data.series.length === 0 && ranged.data.prs.best_e1rm != null, short(ranged.data));
      }
      const badRange = await call("GET", `/progress/exercises/${crypto.randomUUID()}?from=nope`, member.token);
      check("invalid from is 400", badRange.status === 400, `status ${badRange.status}`);
      const unknownEx = await call("GET", `/progress/exercises/${crypto.randomUUID()}`, member.token);
      check("unknown exercise is 404", unknownEx.status === 404, `status ${unknownEx.status}`);
      const badId = await call("GET", "/progress/exercises/not-a-uuid", member.token);
      check("malformed exercise id is 400", badId.status === 400, `status ${badId.status}`);

      const coach = await call("GET", `/progress/summary?user_id=${member.profile.id}`, trainer.token);
      check("trainer reads the member's progress", coach.status === 200 && coach.data.user_id === member.profile.id, `status ${coach.status}`);
      const coachEx = await call("GET", `/progress/exercises?user_id=${member.profile.id}`, trainer.token);
      check("trainer reads the member's exercises", coachEx.status === 200, `status ${coachEx.status}`);
      const vendorRead = await call("GET", `/progress/summary?user_id=${member.profile.id}`, vendor.token);
      check("vendor can't read the member's progress", vendorRead.status === 403, `status ${vendorRead.status}`);
      const badUser = await call("GET", "/progress/summary?user_id=nope", trainer.token);
      check("malformed user_id is 400", badUser.status === 400, `status ${badUser.status}`);

      // ── Body measurements ──
      let measurementId: string | null = null;
      try {
        const date = dayFromToday(0);
        const created = await call("POST", "/body-measurements", member.token, { measured_on: date, weight_kg: 81.4, note: "  test  " });
        measurementId = created.data?.id ?? null;
        check(
          "member logs a measurement",
          created.status === 201 && created.data.weight_kg === 81.4 && created.data.body_fat_pct === null &&
            created.data.measured_on === date && created.data.note === "test",
          short(created.data),
        );
        const empty = await call("POST", "/body-measurements", member.token, { note: "x" });
        check("measurement needs a value", empty.status === 400, `status ${empty.status}`);
        const badFat = await call("POST", "/body-measurements", member.token, { body_fat_pct: 120 });
        check("body_fat_pct must be below 100", badFat.status === 400, `status ${badFat.status}`);
        const badDate = await call("POST", "/body-measurements", member.token, { weight_kg: 80, measured_on: "13/10/2026" });
        check("measured_on must be YYYY-MM-DD", badDate.status === 400, `status ${badDate.status}`);

        const upd = await call("PUT", `/body-measurements/${measurementId}`, member.token, { body_fat_pct: 15.5 });
        check("member updates the measurement", upd.status === 200 && upd.data.body_fat_pct === 15.5 && upd.data.weight_kg === 81.4, short(upd.data));
        const clearAll = await call("PUT", `/body-measurements/${measurementId}`, member.token, { weight_kg: null, body_fat_pct: null });
        check("can't clear both values", clearAll.status === 400, `status ${clearAll.status}`);
        const noop = await call("PUT", `/body-measurements/${measurementId}`, member.token, {});
        check("empty update is 400", noop.status === 400, `status ${noop.status}`);

        const list = await call("GET", `/body-measurements?from=${date}&to=${date}`, member.token);
        check("member lists measurements", list.status === 200 && (list.data as any[]).some((m) => m.id === measurementId), `status ${list.status}`);
        const coachList = await call("GET", `/body-measurements?user_id=${member.profile.id}`, trainer.token);
        check("trainer reads the member's measurements", coachList.status === 200 && (coachList.data as any[]).some((m) => m.id === measurementId), `status ${coachList.status}`);
        const vendorList = await call("GET", `/body-measurements?user_id=${member.profile.id}`, vendor.token);
        check("vendor can't read the member's measurements", vendorList.status === 403, `status ${vendorList.status}`);
        const coachEdit = await call("PUT", `/body-measurements/${measurementId}`, trainer.token, { weight_kg: 1 });
        check("trainer can't edit the member's measurement", coachEdit.status === 403, `status ${coachEdit.status}`);
        const vendorDel = await call("DELETE", `/body-measurements/${measurementId}`, vendor.token);
        check("vendor can't delete it", vendorDel.status === 403, `status ${vendorDel.status}`);
        const missing = await call("DELETE", `/body-measurements/${crypto.randomUUID()}`, member.token);
        check("deleting an unknown measurement is 404", missing.status === 404, `status ${missing.status}`);
        const putMissing = await call("PUT", `/body-measurements/${crypto.randomUUID()}`, member.token, { weight_kg: 80 });
        check("updating an unknown measurement is 404", putMissing.status === 404, `status ${putMissing.status}`);
        const badFrom = await call("GET", "/body-measurements?from=13/10/2026", member.token);
        check("from must be YYYY-MM-DD", badFrom.status === 400, `status ${badFrom.status}`);
        const superEdit = await call("PUT", `/body-measurements/${measurementId}`, superU.token, { note: "checked" });
        check("super user can correct a measurement", superEdit.status === 200 && superEdit.data.note === "checked" && superEdit.data.user_id === member.profile.id, short(superEdit.data));

        const del = await call("DELETE", `/body-measurements/${measurementId}`, member.token);
        check("member deletes the measurement", del.status === 204, `status ${del.status}`);
        if (del.status === 204) measurementId = null;
      } finally {
        if (measurementId) await call("DELETE", `/body-measurements/${measurementId}`, member.token);
      }
      assertAll();
    });

    await t.step("7. routine assignments, session comments and PRs", async () => {
      // ── Routine assignment ──
      let assignmentId: string | null = null;
      try {
        const routines = (await call("GET", "/routines", trainer.token)).data as any[];
        const routine = routines.find((r) => r.is_public);
        check("a public routine exists", !!routine, `n=${routines?.length}`);

        const asg = await call("POST", "/routine-assignments", trainer.token, {
          routine_id: routine.id, user_id: member.profile.id, start_date: dayFromToday(1), note: "integration test",
        });
        assignmentId = asg.data?.id ?? null;
        check(
          "trainer assigns a public routine to the member",
          asg.status === 201 && asg.data.routine_name === routine.name && asg.data.assigned_by_id === trainer.profile.id,
          short(asg.data),
        );
        const vendorAsg = await call("POST", "/routine-assignments", vendor.token, { routine_id: routine.id, user_id: member.profile.id });
        check("vendor can't assign routines to the member", vendorAsg.status === 403, `status ${vendorAsg.status}`);
        if (vendorAsg.status === 201) await call("DELETE", `/routine-assignments/${vendorAsg.data.id}`, vendor.token);
        const badDates = await call("POST", "/routine-assignments", trainer.token, {
          routine_id: routine.id, user_id: member.profile.id, start_date: dayFromToday(5), end_date: dayFromToday(1),
        });
        check("end_date before start_date is 400", badDates.status === 400, `status ${badDates.status}`);
        if (badDates.status === 201) await call("DELETE", `/routine-assignments/${badDates.data.id}`, trainer.token);

        const notif = (await notificationsOf(member.token)).find((n) => n.metadata?.routine_assignment_id === assignmentId);
        check("member got a training notification", notif?.type === "training", short(notif));
        const mine = await call("GET", "/routine-assignments", member.token);
        check("member lists the assignment", mine.status === 200 && (mine.data as any[]).some((a) => a.id === assignmentId), `status ${mine.status}`);
        const vendorList = await call("GET", `/routine-assignments?user_id=${member.profile.id}`, vendor.token);
        check("vendor's list never includes the member's assignments", vendorList.status === 200 && !(vendorList.data as any[]).some((a) => a.id === assignmentId), `status ${vendorList.status}`);
        const vendorDel = await call("DELETE", `/routine-assignments/${assignmentId}`, vendor.token);
        check("vendor can't delete the assignment", vendorDel.status === 403, `status ${vendorDel.status}`);
        const del = await call("DELETE", `/routine-assignments/${assignmentId}`, trainer.token);
        check("trainer removes the assignment", del.status === 204, `status ${del.status}`);
        if (del.status === 204) {
          await deleteNotifications(member.token, (n) => n.metadata?.routine_assignment_id === assignmentId);
          assignmentId = null;
        }
      } finally {
        if (assignmentId) {
          await deleteNotifications(member.token, (n) => n.metadata?.routine_assignment_id === assignmentId);
          await call("DELETE", `/routine-assignments/${assignmentId}`, trainer.token);
        }
      }

      // ── Session comments + PR detection ──
      let sessionId: string | null = null;
      try {
        const exercises = (await call("GET", "/progress/exercises", member.token)).data as any[];
        const ex = exercises.find((e) => e.best_e1rm != null && e.best_weight_kg != null);
        check("member has an exercise with history", !!ex);

        const s = await call("POST", "/training-sessions", member.token, { notes: "integration test" });
        sessionId = s.data?.id ?? null;
        check("member starts a session", s.status === 201 && s.data.comment_count === 0, short(s.data));

        const light = await call("POST", `/training-sessions/${sessionId}/sets`, member.token, {
          exercise_id: ex.id, position: 0, drops: [{ drop_number: 1, rep_type_actual: "count", rep_count_actual: 1, weight_kg_actual: 1 }],
        });
        check("a light set is not a PR", light.status === 201 && light.data.is_pr === false, short(light.data));
        const heavyWeight = Math.ceil(ex.best_weight_kg) + 50;
        const heavy = await call("POST", `/training-sessions/${sessionId}/sets`, member.token, {
          exercise_id: ex.id, position: 1, drops: [{ drop_number: 1, rep_type_actual: "count", rep_count_actual: 5, weight_kg_actual: heavyWeight }],
        });
        check(
          "a heavy set is flagged is_pr with the previous best",
          heavy.status === 201 && heavy.data.is_pr === true && heavy.data.pr_exercise_id === ex.id &&
            heavy.data.previous_e1rm === ex.best_e1rm && heavy.data.pr_e1rm > ex.best_e1rm,
          short(heavy.data),
        );

        const own = await call("POST", `/training-sessions/${sessionId}/comments`, member.token, { body: "  felt strong  " });
        check("member comments on own session", own.status === 201 && own.data.body === "felt strong" && own.data.author_id === member.profile.id, short(own.data));
        const coach = await call("POST", `/training-sessions/${sessionId}/comments`, trainer.token, { body: "Great PR!" });
        check("trainer comments on the member's session", coach.status === 201 && !!coach.data.author_name, short(coach.data));
        const vendorComment = await call("POST", `/training-sessions/${sessionId}/comments`, vendor.token, { body: "hi" });
        check("vendor can't comment", vendorComment.status === 403, `status ${vendorComment.status}`);
        const vendorRead = await call("GET", `/training-sessions/${sessionId}/comments`, vendor.token);
        check("vendor can't read comments", vendorRead.status === 403, `status ${vendorRead.status}`);
        const empty = await call("POST", `/training-sessions/${sessionId}/comments`, member.token, { body: "   " });
        check("empty comment is 400", empty.status === 400, `status ${empty.status}`);
        const tooLong = await call("POST", `/training-sessions/${sessionId}/comments`, member.token, { body: "x".repeat(4001) });
        check("comment over 4000 chars is 400", tooLong.status === 400, `status ${tooLong.status}`);

        const notice = (await notificationsOf(member.token)).find((n) => n.metadata?.comment_id === coach.data?.id);
        check("member got a session_comment notification", notice?.type === "session_comment", short(notice));
        const reply = await call("POST", `/training-sessions/${sessionId}/comments`, member.token, { body: "thanks coach" });
        const replyNotice = (await notificationsOf(trainer.token)).find((n) => n.metadata?.comment_id === reply.data?.id);
        check("trainer is notified of the member's reply", reply.status === 201 && replyNotice?.type === "session_comment", short(replyNotice));

        const list = await call("GET", `/training-sessions/${sessionId}/comments`, trainer.token);
        check("trainer reads the thread oldest-first", list.status === 200 && list.data.length === 3 && list.data[0].id === own.data.id, `n=${list.data?.length}`);
        const detail = await call("GET", `/training-sessions/${sessionId}`, member.token);
        check("session detail has comment_count", detail.status === 200 && detail.data.comment_count === 3, short(detail.data?.comment_count));

        const coachEdit = await call("PUT", `/training-sessions/comments/${own.data.id}`, trainer.token, { body: "x" });
        check("trainer can't edit the member's comment", coachEdit.status === 403, `status ${coachEdit.status}`);
        const edit = await call("PUT", `/training-sessions/comments/${own.data.id}`, member.token, { body: "felt very strong" });
        check("member edits own comment", edit.status === 200 && edit.data.body === "felt very strong", short(edit.data));
        const memberDelCoach = await call("DELETE", `/training-sessions/comments/${coach.data.id}`, member.token);
        check("member can't delete the trainer's comment", memberDelCoach.status === 403, `status ${memberDelCoach.status}`);
        const coachDel = await call("DELETE", `/training-sessions/comments/${coach.data.id}`, trainer.token);
        check("trainer deletes own comment", coachDel.status === 204, `status ${coachDel.status}`);
      } finally {
        if (sessionId) {
          await deleteNotifications(member.token, (n) => n.metadata?.session_id === sessionId);
          await deleteNotifications(trainer.token, (n) => n.metadata?.session_id === sessionId);
          const del = await call("DELETE", `/training-sessions/${sessionId}`, member.token);
          check("delete session (cleanup)", del.status === 204, `status ${del.status}`);
        }
      }
      assertAll();
    });

    await t.step("20. exercises: public vs private, who can edit", async () => {
      const ids: string[] = [];
      try {
        const name = uniq();
        const priv = await call("POST", "/exercises", member.token, {
          name: `${name} private`, primary_muscles: ["chest_all", "not_a_muscle"], secondary_muscles: ["triceps_all"], is_public: false,
        });
        if (priv.data?.id) ids.push(priv.data.id);
        check(
          "member creates a private exercise (unknown muscles dropped)",
          priv.status === 201 && priv.data.is_public === false && priv.data.author_id === member.profile.id &&
            muscles(priv.data.primary_muscles) === "chest_all" && muscles(priv.data.secondary_muscles) === "triceps_all",
          short(priv.data),
        );
        const pub = await call("POST", "/exercises", member.token, { name: `${name} public`, primary_muscles: ["calves"] });
        if (pub.data?.id) ids.push(pub.data.id);
        check("exercises default to public", pub.status === 201 && pub.data.is_public === true, short(pub.data));
        const noName = await call("POST", "/exercises", member.token, { primary_muscles: ["calves"] });
        check("exercise needs a name", noName.status === 400, `status ${noName.status}`);
        const anonPost = await call("POST", "/exercises", undefined, { name: "x" });
        check("creating an exercise needs a signed-in user", anonPost.status === 401, `status ${anonPost.status}`);

        // ── Reads ──
        const own = await call("GET", `/exercises/${priv.data?.id}`, member.token);
        check(
          "author reads the private exercise, muscles as arrays",
          own.status === 200 && own.data.id === priv.data.id && muscles(own.data.primary_muscles) === "chest_all" &&
            muscles(own.data.secondary_muscles) === "triceps_all",
          short(own.data),
        );
        const sup = await call("GET", `/exercises/${priv.data?.id}`, superU.token);
        check("super user reads the private exercise", sup.status === 200, `status ${sup.status}`);
        const other = await call("GET", `/exercises/${priv.data?.id}`, trainer.token);
        check("another user gets 404 for the private exercise", other.status === 404, `status ${other.status}`);
        const anon = await call("GET", `/exercises/${priv.data?.id}`);
        check("anonymous gets 404 for the private exercise", anon.status === 404, `status ${anon.status}`);
        const anonPub = await call("GET", `/exercises/${pub.data?.id}`);
        check("anonymous reads a public exercise", anonPub.status === 200 && anonPub.data.id === pub.data.id, `status ${anonPub.status}`);
        const unknown = await call("GET", `/exercises/${crypto.randomUUID()}`);
        check("unknown exercise is 404", unknown.status === 404, `status ${unknown.status}`);
        const badId = await call("GET", "/exercises/not-a-uuid");
        check("malformed exercise id is 400", badId.status === 400, `status ${badId.status}`);

        const privList = await call("GET", "/exercises?is_public=false&page_size=100", member.token);
        check("is_public=false lists the author's private exercise", privList.status === 200 && (privList.data as any[]).some((e) => e.id === priv.data?.id), `status ${privList.status}`);
        const otherPriv = await call("GET", "/exercises?is_public=false&page_size=100", trainer.token);
        check("another user's private list never includes it", otherPriv.status === 200 && !(otherPriv.data as any[]).some((e) => e.id === priv.data?.id), `status ${otherPriv.status}`);
        const anonPriv = await call("GET", "/exercises?is_public=false");
        check("is_public=false needs a signed-in user", anonPriv.status === 401, `status ${anonPriv.status}`);
        const byAuthor = await call("GET", `/exercises?author_id=${member.profile.id}&muscle=calves&page_size=100`);
        const byAuthorIds = ((byAuthor.data as any[]) ?? []).map((e) => e.id);
        check(
          "author_id + muscle filters find only the public exercise",
          byAuthor.status === 200 && byAuthorIds.includes(pub.data?.id) && !byAuthorIds.includes(priv.data?.id) &&
            muscles((byAuthor.data as any[]).find((e) => e.id === pub.data?.id)?.primary_muscles) === "calves",
          short(byAuthorIds),
        );
        const wrongMuscle = await call("GET", `/exercises?author_id=${member.profile.id}&muscle=neck`);
        check("muscle filter excludes non-matching exercises", wrongMuscle.status === 200 && !(wrongMuscle.data as any[]).some((e) => e.id === pub.data?.id), `status ${wrongMuscle.status}`);
        const badPage = await call("GET", "/exercises?page_size=abc");
        check("non-numeric page_size is 400", badPage.status === 400, `status ${badPage.status}`);

        // ── Edits: author or super user only ──
        const coachEdit = await call("PUT", `/exercises/${pub.data?.id}`, trainer.token, { name: "hijack" });
        check("trainer can't edit the member's exercise", coachEdit.status === 403, `status ${coachEdit.status}`);
        const vendorDel = await call("DELETE", `/exercises/${pub.data?.id}`, vendor.token);
        check("vendor can't delete it", vendorDel.status === 403, `status ${vendorDel.status}`);
        const seeded = ((await call("GET", "/exercises?page_size=100")).data as any[]).find((e) => e.author_id !== member.profile.id);
        const seededEdit = await call("PUT", `/exercises/${seeded?.id}`, member.token, { name: "hijack" });
        check("member can't edit someone else's public exercise", seededEdit.status === 403, `status ${seededEdit.status}`);
        const empty = await call("PUT", `/exercises/${priv.data?.id}`, member.token, {});
        check("empty exercise update is 400", empty.status === 400, `status ${empty.status}`);
        const missing = await call("PUT", `/exercises/${crypto.randomUUID()}`, member.token, { name: "x" });
        check("updating an unknown exercise is 404", missing.status === 404, `status ${missing.status}`);
        const publish = await call("PUT", `/exercises/${priv.data?.id}`, member.token, { is_public: true, primary_muscles: ["biceps"], note: "cue" });
        check(
          "author publishes the exercise and replaces only the sent fields",
          publish.status === 200 && publish.data.is_public === true && muscles(publish.data.primary_muscles) === "biceps" &&
            muscles(publish.data.secondary_muscles) === "triceps_all" && publish.data.note === "cue",
          short(publish.data),
        );
        const nowVisible = await call("GET", `/exercises/${priv.data?.id}`, trainer.token);
        check("the published exercise is readable by others", nowVisible.status === 200, `status ${nowVisible.status}`);
        const superEdit = await call("PUT", `/exercises/${priv.data?.id}`, superU.token, { description: "moderated" });
        check(
          "super user can edit any exercise (author unchanged)",
          superEdit.status === 200 && superEdit.data.description === "moderated" && superEdit.data.author_id === member.profile.id,
          short(superEdit.data),
        );

        // ── Delete ──
        const delMissing = await call("DELETE", `/exercises/${crypto.randomUUID()}`, member.token);
        check("deleting an unknown exercise is 404", delMissing.status === 404, `status ${delMissing.status}`);
        for (const id of [...ids]) {
          const del = await call("DELETE", `/exercises/${id}`, member.token);
          check("author deletes the exercise", del.status === 204, `status ${del.status}`);
          if (del.status === 204) ids.splice(ids.indexOf(id), 1);
        }
        const gone = await call("GET", `/exercises/${pub.data?.id}`);
        check("a deleted exercise is 404", gone.status === 404, `status ${gone.status}`);
      } finally {
        for (const id of ids) await call("DELETE", `/exercises/${id}`, member.token);
      }
      assertAll();
    });

    await t.step("21. trainings: nested sets, privacy, delete guards", async () => {
      let exerciseId: string | null = null;
      let trainingId: string | null = null;
      try {
        const name = uniq();
        const ex = await call("POST", "/exercises", member.token, { name: `${name} curl`, is_public: false });
        exerciseId = ex.data?.id ?? null;
        const pubEx = ((await call("GET", "/exercises?page_size=1")).data as any[])[0];
        const created = await call("POST", "/trainings", member.token, {
          name: `${name} day`, notes: "test",
          sets: [
            {
              type: "superset", rest_seconds: 90, exercises: [
                { exercise_id: exerciseId, drops: [{ rep_type: "count", rep_count: 8, weight_kg: 20 }, { rep_type: "bogus", rep_count: 6, side: "bogus" }] },
                { exercise_id: pubEx.id, is_alternating: true, drops: [{ rep_type: "failure" }] },
              ],
            },
            { type: "bogus", exercises: [{ note: "no exercise_id, skipped" }] },
          ],
        });
        trainingId = created.data?.id ?? null;
        const s0 = created.data?.sets?.[0];
        check(
          "member creates a private training with nested sets (bad enums fall back to defaults)",
          created.status === 201 && created.data.is_public === false && created.data.sets.length === 2 &&
            s0.type === "superset" && s0.rest_seconds === 90 && s0.exercises.length === 2 &&
            s0.exercises[0].exercise_id === exerciseId && s0.exercises[0].drops.length === 2 &&
            s0.exercises[0].drops[1].rep_type === "count" && s0.exercises[0].drops[1].side === "both" &&
            s0.exercises[1].is_alternating === true && s0.exercises[1].drops[0].rep_type === "failure" &&
            created.data.sets[1].type === "standard" && created.data.sets[1].exercises.length === 0,
          short(created.data?.sets),
        );
        const noName = await call("POST", "/trainings", member.token, { sets: [] });
        check("training needs a name", noName.status === 400, `status ${noName.status}`);
        const badEx = await call("POST", "/trainings", member.token, { name: `${name} bad`, sets: [{ exercises: [{ exercise_id: crypto.randomUUID() }] }] });
        check("unknown exercise in a set is 400", badEx.status === 400, `status ${badEx.status}`);
        if (badEx.status === 201) await call("DELETE", `/trainings/${badEx.data.id}`, member.token);

        // ── Reads: private until published ──
        const anon = await call("GET", `/trainings/${trainingId}`);
        check("anonymous gets 404 for a private training", anon.status === 404, `status ${anon.status}`);
        const coach = await call("GET", `/trainings/${trainingId}`, trainer.token);
        check("another user gets 404 for it", coach.status === 404, `status ${coach.status}`);
        const sup = await call("GET", `/trainings/${trainingId}`, superU.token);
        check("super user reads it", sup.status === 200 && sup.data.sets.length === 2, `status ${sup.status}`);
        const mine = await call("GET", "/trainings?mine=true&page_size=100", member.token);
        check("mine=true lists it", mine.status === 200 && (mine.data as any[]).some((x) => x.id === trainingId && "thumbnail" in x), `status ${mine.status}`);
        const anonMine = await call("GET", "/trainings?mine=true");
        check("mine=true needs a signed-in user", anonMine.status === 401, `status ${anonMine.status}`);
        const pubList = await call("GET", `/trainings?author_id=${member.profile.id}&page_size=100`);
        check("the public list hides the private training", pubList.status === 200 && !(pubList.data as any[]).some((x) => x.id === trainingId), `status ${pubList.status}`);

        // ── Edits ──
        const coachPut = await call("PUT", `/trainings/${trainingId}`, trainer.token, { name: "hijack" });
        check("trainer can't edit the member's training", coachPut.status === 403, `status ${coachPut.status}`);
        const missing = await call("PUT", `/trainings/${crypto.randomUUID()}`, member.token, { name: "x" });
        check("updating an unknown training is 404", missing.status === 404, `status ${missing.status}`);
        const rename = await call("PUT", `/trainings/${trainingId}`, member.token, { name: `${name} renamed` });
        check("PUT without sets keeps the sets", rename.status === 200 && rename.data.name === `${name} renamed` && rename.data.sets.length === 2, short(rename.data?.name));
        const replace = await call("PUT", `/trainings/${trainingId}`, member.token, {
          is_public: true, images: [{ url: "https://example.com/t1.jpg" }, { url: "https://example.com/t2.jpg" }],
          sets: [{ exercises: [{ exercise_id: exerciseId, drops: [{ rep_count: 10, weight_kg: 25 }] }] }],
        });
        check(
          "PUT replaces sets and images and publishes",
          replace.status === 200 && replace.data.is_public === true && replace.data.sets.length === 1 && replace.data.sets[0].type === "standard" &&
            replace.data.sets[0].exercises[0].drops.length === 1 && replace.data.images.length === 2 &&
            replace.data.images[0].is_thumbnail === true && replace.data.images[1].is_thumbnail === false,
          short(replace.data),
        );
        const listed = await call("GET", `/trainings?author_id=${member.profile.id}&name=${encodeURIComponent(name)}`);
        const row = (listed.data as any[])?.find((x) => x.id === trainingId);
        check("the published training is listed with its thumbnail", listed.status === 200 && row?.thumbnail?.url === "https://example.com/t1.jpg", short(row));
        const anonRead = await call("GET", `/trainings/${trainingId}`);
        check("anonymous reads the published training", anonRead.status === 200, `status ${anonRead.status}`);

        // ── Delete guards ──
        const exInUse = await call("DELETE", `/exercises/${exerciseId}`, member.token);
        check("an exercise used by a training can't be deleted", exInUse.status === 409, `status ${exInUse.status}`);
        const vendorDel = await call("DELETE", `/trainings/${trainingId}`, vendor.token);
        check("vendor can't delete the training", vendorDel.status === 403, `status ${vendorDel.status}`);
        const delMissing = await call("DELETE", `/trainings/${crypto.randomUUID()}`, member.token);
        check("deleting an unknown training is 404", delMissing.status === 404, `status ${delMissing.status}`);
        const del = await call("DELETE", `/trainings/${trainingId}`, member.token);
        check("author deletes the training", del.status === 204, `status ${del.status}`);
        if (del.status === 204) trainingId = null;
        const exDel = await call("DELETE", `/exercises/${exerciseId}`, member.token);
        check("then the exercise can be deleted", exDel.status === 204, `status ${exDel.status}`);
        if (exDel.status === 204) exerciseId = null;
      } finally {
        if (trainingId) await call("DELETE", `/trainings/${trainingId}`, member.token);
        if (exerciseId) await call("DELETE", `/exercises/${exerciseId}`, member.token);
      }
      assertAll();
    });

    await t.step("22. routines: scheduled trainings, privacy, assignment and notifications", async () => {
      let trainingId: string | null = null;
      let routineId: string | null = null;
      const assignmentIds: string[] = [];
      const strayRoutines: string[] = [];
      try {
        const name = uniq();
        const pubEx = ((await call("GET", "/exercises?page_size=1")).data as any[])[0];
        const tr = await call("POST", "/trainings", member.token, { name: `${name} push`, sets: [{ exercises: [{ exercise_id: pubEx.id, drops: [{ rep_count: 5 }] }] }] });
        trainingId = tr.data?.id ?? null;
        check("member creates a training for the routine", tr.status === 201, short(tr.data));

        const created = await call("POST", "/routines", member.token, {
          name: `${name} program`, description: "test", schedule_type: "fixed_weeks", num_weeks: 2,
          images: [{ url: "https://example.com/r1.jpg" }, { url: "https://example.com/r2.jpg" }],
          trainings: [
            { training_id: trainingId, week_number: 1, day_of_week: 1 },
            { training_id: trainingId, week_number: 2, day_of_week: 3, note: "heavy" },
          ],
        });
        routineId = created.data?.id ?? null;
        check(
          "member creates a private 2-week routine with scheduled trainings",
          created.status === 201 && created.data.is_public === false && created.data.schedule_type === "fixed_weeks" && created.data.num_weeks === 2 &&
            created.data.trainings.length === 2 && created.data.trainings[1].note === "heavy" && created.data.trainings[1].day_of_week === 3 &&
            created.data.trainings[0].training?.name === `${name} push` &&
            created.data.images[0].is_thumbnail === true && created.data.images[1].is_thumbnail === false,
          short(created.data),
        );

        const noWeeks = await call("POST", "/routines", member.token, { name: `${name} x`, schedule_type: "fixed_weeks" });
        check("fixed_weeks routine needs num_weeks", noWeeks.status === 400, `status ${noWeeks.status}`);
        const noName = await call("POST", "/routines", member.token, { schedule_type: "wildcard" });
        check("routine needs a name", noName.status === 400, `status ${noName.status}`);
        const wild = await call("POST", "/routines", member.token, { name: `${name} wild`, schedule_type: "bogus", num_weeks: 3 });
        if (wild.data?.id) strayRoutines.push(wild.data.id);
        check("unknown schedule_type falls back to wildcard without weeks", wild.status === 201 && wild.data.schedule_type === "wildcard" && wild.data.num_weeks === null, short(wild.data));
        const badDay = await call("POST", "/routines", member.token, { name: `${name} x`, trainings: [{ training_id: trainingId, day_of_week: 9 }] });
        if (badDay.status === 201) strayRoutines.push(badDay.data.id);
        check("day_of_week outside 1-7 is 400", badDay.status === 400, `status ${badDay.status}`);
        const badTraining = await call("POST", "/routines", member.token, { name: `${name} x`, trainings: [{ training_id: crypto.randomUUID() }] });
        if (badTraining.status === 201) strayRoutines.push(badTraining.data.id);
        check("unknown training is 400", badTraining.status === 400, `status ${badTraining.status}`);

        // ── Reads ──
        const coachRead = await call("GET", `/routines/${routineId}`, trainer.token);
        check("another user gets 404 for the private routine", coachRead.status === 404, `status ${coachRead.status}`);
        const anonRead = await call("GET", `/routines/${routineId}`);
        check("anonymous gets 404 for it", anonRead.status === 404, `status ${anonRead.status}`);
        const mine = await call("GET", "/routines?mine=true&page_size=100", member.token);
        const mineRow = (mine.data as any[])?.find((r) => r.id === routineId);
        check("mine=true lists it with its thumbnail", mine.status === 200 && mineRow?.thumbnail?.url === "https://example.com/r1.jpg", short(mineRow));
        const anonMine = await call("GET", "/routines?mine=true");
        check("mine=true needs a signed-in user", anonMine.status === 401, `status ${anonMine.status}`);
        const pubList = await call("GET", `/routines?author_id=${member.profile.id}&page_size=100`);
        check("the public list hides the private routine", pubList.status === 200 && !(pubList.data as any[]).some((r) => r.id === routineId), `status ${pubList.status}`);

        // ── Private routines can only be assigned by their author ──
        const coachAssign = await call("POST", "/routine-assignments", trainer.token, { routine_id: routineId, user_id: member.profile.id });
        check("trainer can't assign the member's private routine", coachAssign.status === 403, `status ${coachAssign.status}`);
        if (coachAssign.status === 201) assignmentIds.push(coachAssign.data.id);
        const selfAsg = await call("POST", "/routine-assignments", member.token, {
          routine_id: routineId, user_id: member.profile.id, start_date: dayFromToday(1), end_date: dayFromToday(30),
        });
        if (selfAsg.data?.id) assignmentIds.push(selfAsg.data.id);
        check(
          "member self-assigns the private routine",
          selfAsg.status === 201 && selfAsg.data.assigned_by_id === member.profile.id && selfAsg.data.routine_is_public === false &&
            selfAsg.data.routine_schedule_label === "2-Week Program" && selfAsg.data.start_date === dayFromToday(1) &&
            selfAsg.data.end_date === dayFromToday(30) && !!selfAsg.data.user_name,
          short(selfAsg.data),
        );
        const selfNotice = (await notificationsOf(member.token)).some((n) => n.metadata?.routine_assignment_id === selfAsg.data?.id);
        check("self-assignment sends no notification", !selfNotice);
        const trInUse = await call("DELETE", `/trainings/${trainingId}`, member.token);
        check("a training used by a routine can't be deleted", trInUse.status === 409, `status ${trInUse.status}`);

        // ── Edits ──
        const coachPut = await call("PUT", `/routines/${routineId}`, trainer.token, { name: "hijack" });
        check("trainer can't edit the member's routine", coachPut.status === 403, `status ${coachPut.status}`);
        const missing = await call("PUT", `/routines/${crypto.randomUUID()}`, member.token, { name: "x" });
        check("updating an unknown routine is 404", missing.status === 404, `status ${missing.status}`);
        const zeroWeeks = await call("PUT", `/routines/${routineId}`, member.token, { num_weeks: 0 });
        check("PUT num_weeks 0 on a fixed_weeks routine is 400", zeroWeeks.status === 400, `status ${zeroWeeks.status} num_weeks=${zeroWeeks.data?.num_weeks}`);
        const publish = await call("PUT", `/routines/${routineId}`, member.token, {
          is_public: true, num_weeks: 2, trainings: [{ training_id: trainingId, week_number: 1, day_of_week: 5 }],
        });
        check(
          "PUT publishes and replaces trainings, keeping images",
          publish.status === 200 && publish.data.is_public === true && publish.data.trainings.length === 1 &&
            publish.data.trainings[0].day_of_week === 5 && publish.data.images.length === 2,
          short(publish.data),
        );
        const coachSees = await call("GET", `/routines/${routineId}`, trainer.token);
        check("the published routine is readable by the trainer", coachSees.status === 200, `status ${coachSees.status}`);

        // ── Trainer assigns the now public routine ──
        const asg = await call("POST", "/routine-assignments", trainer.token, { routine_id: routineId, user_id: member.profile.id, note: "  go  " });
        if (asg.data?.id) assignmentIds.push(asg.data.id);
        check(
          "trainer assigns the public routine to the member",
          asg.status === 201 && asg.data.assigned_by_id === trainer.profile.id && asg.data.note === "go" && asg.data.start_date === null &&
            !!asg.data.assigned_by_name && asg.data.routine_is_public === true,
          short(asg.data),
        );
        const notice = (await notificationsOf(member.token)).find((n) => n.metadata?.routine_assignment_id === asg.data?.id);
        check("member is notified", notice?.type === "training" && notice.metadata.routine_id === routineId, short(notice));
        const staffView = await call("GET", `/routine-assignments?user_id=${member.profile.id}`, employee.token);
        check("gym staff see the member's assignments", staffView.status === 200 && (staffView.data as any[]).some((a) => a.id === asg.data?.id), `status ${staffView.status}`);
        const vendorByRoutine = await call("GET", `/routine-assignments?routine_id=${routineId}`, vendor.token);
        check("vendor's routine_id listing filters out the member's rows", vendorByRoutine.status === 200 && (vendorByRoutine.data as any[]).length === 0, `n=${vendorByRoutine.data?.length}`);
        const memberByRoutine = await call("GET", `/routine-assignments?routine_id=${routineId}`, member.token);
        check("member sees both assignments of the routine", memberByRoutine.status === 200 && (memberByRoutine.data as any[]).length === 2, `n=${memberByRoutine.data?.length}`);
        const byAssigner = await call("GET", `/routine-assignments?assigned_by_id=${trainer.profile.id}`, trainer.token);
        check("trainer lists the assignments they made", byAssigner.status === 200 && (byAssigner.data as any[]).some((a) => a.id === asg.data?.id), `status ${byAssigner.status}`);

        const noIds = await call("POST", "/routine-assignments", trainer.token, { routine_id: routineId });
        check("assignment needs routine_id and user_id", noIds.status === 400, `status ${noIds.status}`);
        const badDate = await call("POST", "/routine-assignments", trainer.token, { routine_id: routineId, user_id: member.profile.id, start_date: "2026/01/01" });
        check("start_date must be YYYY-MM-DD", badDate.status === 400, `status ${badDate.status}`);
        const unknownRoutine = await call("POST", "/routine-assignments", trainer.token, { routine_id: crypto.randomUUID(), user_id: member.profile.id });
        check("unknown routine is 404", unknownRoutine.status === 404, `status ${unknownRoutine.status}`);
        const unknownUser = await call("POST", "/routine-assignments", trainer.token, { routine_id: routineId, user_id: crypto.randomUUID() });
        check("unknown user is 404", unknownUser.status === 404, `status ${unknownUser.status}`);
        const delUnknown = await call("DELETE", `/routine-assignments/${crypto.randomUUID()}`, trainer.token);
        check("deleting an unknown assignment is 404", delUnknown.status === 404, `status ${delUnknown.status}`);
        for (const r of [noIds, badDate, unknownRoutine, unknownUser]) if (r.status === 201) assignmentIds.push(r.data.id);

        const targetDel = await call("DELETE", `/routine-assignments/${asg.data?.id}`, member.token);
        check("the assigned member can remove the trainer's assignment", targetDel.status === 204, `status ${targetDel.status}`);

        // ── Delete: cascades to assignments ──
        const vendorDel = await call("DELETE", `/routines/${routineId}`, vendor.token);
        check("vendor can't delete the routine", vendorDel.status === 403, `status ${vendorDel.status}`);
        const delMissing = await call("DELETE", `/routines/${crypto.randomUUID()}`, member.token);
        check("deleting an unknown routine is 404", delMissing.status === 404, `status ${delMissing.status}`);
        const del = await call("DELETE", `/routines/${routineId}`, member.token);
        check("author deletes the routine", del.status === 204, `status ${del.status}`);
        if (del.status === 204) {
          const left = await call("GET", `/routine-assignments?routine_id=${routineId}`, member.token);
          check("its assignments are gone too", left.status === 200 && (left.data as any[]).length === 0, `n=${left.data?.length}`);
          routineId = null;
        }
        const trDel = await call("DELETE", `/trainings/${trainingId}`, member.token);
        check("then the training can be deleted", trDel.status === 204, `status ${trDel.status}`);
        if (trDel.status === 204) trainingId = null;
      } finally {
        await deleteNotifications(member.token, (n) => assignmentIds.includes(n.metadata?.routine_assignment_id));
        for (const id of assignmentIds) await call("DELETE", `/routine-assignments/${id}`, member.token);
        for (const id of [...strayRoutines, routineId]) if (id) await call("DELETE", `/routines/${id}`, member.token);
        if (trainingId) await call("DELETE", `/trainings/${trainingId}`, member.token);
      }
      assertAll();
    });

    await t.step("23. session lifecycle: planned sets, drops, PRs in /progress, coach views", async () => {
      let exerciseId: string | null = null;
      let trainingId: string | null = null;
      const sessionIds: string[] = [];
      try {
        const name = uniq();
        const ex = await call("POST", "/exercises", member.token, { name: `${name} squat`, primary_muscles: ["quads_all"], is_public: false });
        exerciseId = ex.data?.id ?? null;
        const tr = await call("POST", "/trainings", member.token, {
          name: `${name} legs`, sets: [{ exercises: [{ exercise_id: exerciseId, drops: [{ rep_count: 5, weight_kg: 50 }] }] }],
        });
        trainingId = tr.data?.id ?? null;
        const plannedSet = tr.data?.sets?.[0];
        const plannedDrop = plannedSet?.exercises?.[0]?.drops?.[0];
        check("member creates a fresh exercise and a training for it", ex.status === 201 && tr.status === 201 && !!plannedDrop, short(tr.data));
        assertAll();

        const badCoach = await call("POST", "/training-sessions", member.token, { training_id: trainingId, trainer_id: vendor.profile.id });
        if (badCoach.status === 201) sessionIds.push(badCoach.data.id);
        check("trainer_id must be a trainer", badCoach.status === 400, `status ${badCoach.status}`);
        const s1 = await call("POST", "/training-sessions", member.token, { training_id: trainingId, trainer_id: trainer.profile.id, notes: "leg day" });
        if (s1.data?.id) sessionIds.push(s1.data.id);
        const sid = s1.data?.id;
        check(
          "member starts a planned, coached session",
          s1.status === 201 && s1.data.training_id === trainingId && s1.data.trainer_id === trainer.profile.id && s1.data.ended_at === null && s1.data.comment_count === 0,
          short(s1.data),
        );

        // ── Sets and drops ──
        // A planned set carries no exercise_id: progress resolves it through the planned drop.
        const planned = await call("POST", `/training-sessions/${sid}/sets`, member.token, {
          training_set_id: plannedSet.id, position: 0,
          drops: [{ training_set_drop_id: plannedDrop.id, drop_number: 1, rep_type_actual: "count", rep_count_actual: 5, weight_kg_actual: 50, side: "bogus" }],
        });
        const setId = planned.data?.id;
        check(
          "planned set logs; a first-ever log of an exercise is not a PR",
          planned.status === 201 && planned.data.training_set_id === plannedSet.id && planned.data.exercise_id === null &&
            planned.data.drop_logs.length === 1 && planned.data.drop_logs[0].side === "both" && planned.data.is_pr === false,
          short(planned.data),
        );
        const drops = await call("POST", `/training-sessions/sets/${setId}/drops`, member.token, [{ drop_number: 2, rep_count_actual: 3, weight_kg_actual: 40 }]);
        check("drops are appended to a set", drops.status === 201 && drops.data.length === 1 && drops.data[0].drop_number === 2 && drops.data[0].rep_type_actual === "count", short(drops.data));
        const single = await call("POST", `/training-sessions/sets/${setId}/drops`, member.token, { drop_number: 3, rep_type_actual: "failure" });
        check("a single drop object is accepted", single.status === 201 && single.data.length === 1 && single.data[0].rep_type_actual === "failure", short(single.data));
        const noDrops = await call("POST", `/training-sessions/sets/${setId}/drops`, member.token, []);
        check("an empty drop list is a no-op", noDrops.status === 201 && noDrops.data.length === 0, short(noDrops.data));
        const noBody = await call("POST", `/training-sessions/sets/${setId}/drops`, member.token);
        check("drops need a body", noBody.status === 400, `status ${noBody.status}`);
        const vendorDrops = await call("POST", `/training-sessions/sets/${setId}/drops`, vendor.token, [{ rep_count_actual: 1 }]);
        check("vendor can't add drops to the member's set", vendorDrops.status === 403, `status ${vendorDrops.status}`);
        const unknownSet = await call("POST", `/training-sessions/sets/${crypto.randomUUID()}/drops`, member.token, [{ rep_count_actual: 1 }]);
        check("drops on an unknown set log is 404", unknownSet.status === 404, `status ${unknownSet.status}`);

        const heavy = await call("POST", `/training-sessions/${sid}/sets`, member.token, {
          exercise_id: exerciseId, position: 1, drops: [{ drop_number: 1, rep_type_actual: "count", rep_count_actual: 5, weight_kg_actual: 60 }],
        });
        check(
          "a heavier set in the same session is a PR over the planned set (Epley)",
          heavy.status === 201 && heavy.data.is_pr === true && heavy.data.pr_exercise_id === exerciseId &&
            heavy.data.previous_e1rm === 58.33 && heavy.data.pr_e1rm === 70,
          short(heavy.data),
        );

        // ── Session reads and edits ──
        const detail = await call("GET", `/training-sessions/${sid}`, member.token);
        check(
          "session detail nests set logs and drops, with the trainer's name",
          detail.status === 200 && detail.data.set_logs.length === 2 && detail.data.set_logs[0].drop_logs.length === 3 &&
            !!detail.data.trainer_name && detail.data.comment_count === 0,
          short(detail.data?.set_logs?.map((s: any) => s.drop_logs.length)),
        );
        const coachDetail = await call("GET", `/training-sessions/${sid}`, trainer.token);
        check("the session's trainer reads it", coachDetail.status === 200, `status ${coachDetail.status}`);
        const vendorDetail = await call("GET", `/training-sessions/${sid}`, vendor.token);
        check("vendor can't read it", vendorDetail.status === 403, `status ${vendorDetail.status}`);
        const unknown = await call("GET", `/training-sessions/${crypto.randomUUID()}`, member.token);
        check("unknown session is 404", unknown.status === 404, `status ${unknown.status}`);
        const badId = await call("GET", "/training-sessions/not-a-uuid", member.token);
        check("malformed session id is 400", badId.status === 400, `status ${badId.status}`);

        const notes = await call("PUT", `/training-sessions/${sid}`, member.token, { notes: "felt good" });
        check("member edits session notes", notes.status === 200 && notes.data.notes === "felt good" && !!notes.data.trainer_name, short(notes.data));
        const badEnd = await call("PUT", `/training-sessions/${sid}`, member.token, { ended_at: "not a time" });
        check("invalid ended_at is 400", badEnd.status === 400, `status ${badEnd.status}`);
        const coachPut = await call("PUT", `/training-sessions/${sid}`, trainer.token, { notes: "x" });
        check("trainer can't edit the member's session", coachPut.status === 403, `status ${coachPut.status}`);
        const putMissing = await call("PUT", `/training-sessions/${crypto.randomUUID()}`, member.token, { notes: "x" });
        check("updating an unknown session is 404", putMissing.status === 404, `status ${putMissing.status}`);
        const end = await call("POST", `/training-sessions/${sid}/end`, member.token);
        check("member ends the session", end.status === 200 && !!end.data.ended_at && end.data.set_logs.length === 2, short(end.data?.ended_at));
        const endAgain = await call("POST", `/training-sessions/${sid}/end`, member.token);
        check("ending again keeps the original ended_at", endAgain.status === 200 && endAgain.data.ended_at === end.data?.ended_at, short(endAgain.data?.ended_at));
        const vendorEnd = await call("POST", `/training-sessions/${sid}/end`, vendor.token);
        check("vendor can't end it", vendorEnd.status === 403, `status ${vendorEnd.status}`);
        const endMissing = await call("POST", `/training-sessions/${crypto.randomUUID()}/end`, member.token);
        check("ending an unknown session is 404", endMissing.status === 404, `status ${endMissing.status}`);

        const arrayBody = await call("PUT", `/training-sessions/sets/${setId}`, member.token, []);
        check("set edit body must be an object", arrayBody.status === 400, `status ${arrayBody.status}`);
        const setMissing = await call("PUT", `/training-sessions/sets/${crypto.randomUUID()}`, member.token, { note: "x" });
        check("editing an unknown set log is 404", setMissing.status === 404, `status ${setMissing.status}`);
        const coachDelSet = await call("DELETE", `/training-sessions/sets/${setId}`, trainer.token);
        check("trainer can't delete the member's set", coachDelSet.status === 403, `status ${coachDelSet.status}`);
        const setsMissing = await call("POST", `/training-sessions/${crypto.randomUUID()}/sets`, member.token, { exercise_id: exerciseId });
        check("logging into an unknown session is 404", setsMissing.status === 404, `status ${setsMissing.status}`);
        const vendorSet = await call("POST", `/training-sessions/${sid}/sets`, vendor.token, { exercise_id: exerciseId });
        check("vendor can't log into the member's session", vendorSet.status === 403, `status ${vendorSet.status}`);

        // ── A second, heavier session: the PR shows up in /progress ──
        const s2 = await call("POST", "/training-sessions", member.token, { notes: "test" });
        if (s2.data?.id) sessionIds.push(s2.data.id);
        const pr = await call("POST", `/training-sessions/${s2.data?.id}/sets`, member.token, {
          exercise_id: exerciseId, drops: [{ rep_type_actual: "count", rep_count_actual: 3, weight_kg_actual: 80 }],
        });
        check("80 kg x 3 beats the first session", pr.status === 201 && pr.data.is_pr === true && pr.data.previous_e1rm === 70 && pr.data.pr_e1rm === 88, short(pr.data));
        await call("POST", `/training-sessions/${s2.data?.id}/end`, member.token);

        const summary = await call("GET", "/progress/summary", member.token);
        const hit = (summary.data?.recent_prs as any[])?.find((p) => p.exercise_id === exerciseId);
        check(
          "progress summary lists the PR from the second session",
          summary.status === 200 && hit?.session_id === s2.data?.id && hit.e1rm === 88 && hit.previous_e1rm === 70 &&
            hit.weight_kg === 80 && hit.reps === 3 && hit.exercise_name === `${name} squat` && summary.data.trained_this_week === true,
          short(hit),
        );
        const coachSummary = await call("GET", `/progress/summary?user_id=${member.profile.id}`, trainer.token);
        check("trainer sees the same PR", coachSummary.status === 200 && (coachSummary.data.recent_prs as any[]).some((p) => p.session_id === s2.data?.id), `status ${coachSummary.status}`);
        const list = await call("GET", "/progress/exercises", member.token);
        const row = (list.data as any[])?.find((e) => e.id === exerciseId);
        check(
          "performed exercises carry session count, bests and trend",
          list.status === 200 && row?.session_count === 2 && row.best_weight_kg === 80 && row.best_e1rm === 88 &&
            row.trend.join() === "70,88" && muscles(row.primary_muscles) === "quads_all",
          short(row),
        );
        const exDetail = await call("GET", `/progress/exercises/${exerciseId}`, member.token);
        const first = exDetail.data?.series?.[0];
        check(
          "exercise series has volume and reps per session; PRs are all-time",
          exDetail.status === 200 && exDetail.data.series.length === 2 && first?.session_id === sid && first.volume_kg === 670 &&
            first.total_reps === 13 && first.best_weight_kg === 60 && exDetail.data.prs.best_e1rm.value === 88 &&
            exDetail.data.prs.best_e1rm.session_id === s2.data?.id && exDetail.data.prs.best_volume_kg.value === 670 &&
            exDetail.data.prs.best_weight_kg.value === 80,
          short(exDetail.data),
        );
        const vendorProgress = await call("GET", `/progress/exercises/${exerciseId}?user_id=${member.profile.id}`, vendor.token);
        check("vendor can't read the member's exercise progress", vendorProgress.status === 403, `status ${vendorProgress.status}`);
        const staffProgress = await call("GET", `/progress/exercises?user_id=${member.profile.id}`, employee.token);
        check("gym staff read the member's exercise progress", staffProgress.status === 200 && (staffProgress.data as any[]).some((e) => e.id === exerciseId), `status ${staffProgress.status}`);
        const notFound = await call("GET", "/progress/nope", member.token);
        check("unknown progress route is 404", notFound.status === 404, `status ${notFound.status}`);

        // ── Session listings ──
        const byTraining = await call("GET", `/training-sessions?training_id=${trainingId}`, member.token);
        check("training_id filter lists only the planned session", byTraining.status === 200 && (byTraining.data as any[]).map((s) => s.id).join() === sid, short(byTraining.data?.map((s: any) => s.id)));
        const coachRuns = await call("GET", `/training-sessions?trainer_id=${trainer.profile.id}&page_size=100`, trainer.token);
        check(
          "trainer lists the sessions they run",
          coachRuns.status === 200 && (coachRuns.data as any[]).some((s) => s.id === sid && !!s.trainer_name),
          `status ${coachRuns.status}`,
        );
        const notTheirs = await call("GET", `/training-sessions?trainer_id=${trainer.profile.id}`, member.token);
        check("member can't list another trainer's sessions", notTheirs.status === 403, `status ${notTheirs.status}`);
        const vendorList = await call("GET", `/training-sessions?user_id=${member.profile.id}`, vendor.token);
        check("vendor can't list the member's sessions", vendorList.status === 403, `status ${vendorList.status}`);

        // ── Deleting a set updates progress; deleting the plan keeps history ──
        const delHeavy = await call("DELETE", `/training-sessions/sets/${heavy.data?.id}`, member.token);
        const afterDel = await call("GET", `/progress/exercises/${exerciseId}`, member.token);
        check(
          "deleting the heavy set lowers that session's best",
          delHeavy.status === 204 && afterDel.data?.series?.[0]?.best_e1rm === 58.33,
          `status ${delHeavy.status} ${short(afterDel.data?.series?.[0])}`,
        );
        const exInUse = await call("DELETE", `/exercises/${exerciseId}`, member.token);
        check("exercise used by the training can't be deleted", exInUse.status === 409, `status ${exInUse.status}`);
        const trDel = await call("DELETE", `/trainings/${trainingId}`, member.token);
        if (trDel.status === 204) trainingId = null;
        const orphan = await call("GET", `/training-sessions/${sid}`, member.token);
        check(
          "deleting the training keeps the session and its logs",
          trDel.status === 204 && orphan.status === 200 && orphan.data.training_id === null && orphan.data.set_logs.length === 1,
          `status ${trDel.status} ${short(orphan.data?.training_id)}`,
        );
        const exDel = await call("DELETE", `/exercises/${exerciseId}`, member.token);
        check("an exercise referenced only by history can be deleted", exDel.status === 204, `status ${exDel.status}`);
        if (exDel.status === 204) exerciseId = null;
      } finally {
        for (const id of sessionIds) {
          const del = await call("DELETE", `/training-sessions/${id}`, member.token);
          check("delete session (cleanup)", del.status === 204, `status ${del.status}`);
        }
        if (trainingId) await call("DELETE", `/trainings/${trainingId}`, member.token);
        if (exerciseId) await call("DELETE", `/exercises/${exerciseId}`, member.token);
      }
      assertAll();
    });

    await t.step("24. logging past workouts: suggestions, back-dated sessions, frozen sets, routine membership", async () => {
      let trainingId: string | null = null;
      let otherTrainingId: string | null = null;
      let routineId: string | null = null;
      let assignmentId: string | null = null;
      let sessionId: string | null = null;
      let memberRoutineId: string | null = null;
      try {
        const name = uniq();
        const pubEx = ((await call("GET", "/exercises?page_size=1")).data as any[])[0];
        const tr = await call("POST", "/trainings", trainer.token, {
          name: `${name} push`, is_public: false,
          sets: [{ exercises: [{ exercise_id: pubEx.id, drops: [{ rep_count: 8, weight_kg: 30 }] }] }],
        });
        trainingId = tr.data?.id ?? null;
        const plannedSet = tr.data?.sets?.[0];
        const plannedDrop = plannedSet?.exercises?.[0]?.drops?.[0];
        check(
          "training detail embeds each exercise and starts unused",
          tr.status === 201 && plannedSet?.exercises?.[0]?.exercise?.id === pubEx.id &&
            plannedSet.exercises[0].exercise.name === pubEx.name && tr.data.has_sessions === false &&
            Array.isArray(tr.data.routine_ids) && tr.data.routine_ids.length === 0,
          short(tr.data),
        );
        const routine = await call("POST", "/routines", trainer.token, {
          name: `${name} plan`, is_public: false, trainings: [{ training_id: trainingId }],
        });
        routineId = routine.data?.id ?? null;
        const asg = await call("POST", "/routine-assignments", trainer.token, { routine_id: routineId, user_id: member.profile.id });
        assignmentId = asg.data?.id ?? null;
        check("trainer assigns a private routine to the member", routine.status === 201 && asg.status === 201, `status ${routine.status}/${asg.status}`);
        assertAll();

        // ── Assignees read the coach's private routine and its trainings ──
        const readRoutine = await call("GET", `/routines/${routineId}`, member.token);
        const readTraining = await call("GET", `/trainings/${trainingId}`, member.token);
        check("the assignee reads the private routine and training", readRoutine.status === 200 && readTraining.status === 200, `status ${readRoutine.status}/${readTraining.status}`);
        const outsider = await call("GET", `/trainings/${trainingId}`, vendor.token);
        check("others still get 404", outsider.status === 404, `status ${outsider.status}`);

        // ── Suggestions before logging ──
        const before = await call("GET", `/trainings/suggestions?name=${encodeURIComponent(name)}`, member.token);
        const assignedRow = (before.data?.assigned as any[])?.find((x) => x.id === trainingId);
        check(
          "suggestions offer the coach's training under assigned",
          before.status === 200 && !!assignedRow && assignedRow.routine_name === `${name} plan` && !!assignedRow.assigned_by_name &&
            !(before.data.recent as any[]).some((x) => x.id === trainingId) &&
            !(before.data.library as any[]).some((x) => x.id === trainingId),
          short(before.data),
        );
        const anonSuggest = await call("GET", "/trainings/suggestions");
        check("suggestions need a signed-in user", anonSuggest.status === 401, `status ${anonSuggest.status}`);

        // ── Back-dated session in one request ──
        const start = new Date(Date.now() - 3 * 3600_000);
        const end = new Date(start.getTime() + 3600_000);
        const future = await call("POST", "/training-sessions", member.token, {
          started_at: new Date(Date.now() + 3600_000).toISOString(), sets: [{ exercise_id: pubEx.id }],
        });
        check("a session can be logged ahead of time", future.status === 201 && future.data.plan_entry_id === null, `status ${future.status}`);
        if (future.status === 201) await call("DELETE", `/training-sessions/${future.data.id}`, member.token);
        const backwards = await call("POST", "/training-sessions", member.token, { started_at: end.toISOString(), ended_at: start.toISOString() });
        check("ended_at must be after started_at", backwards.status === 400, `status ${backwards.status}`);
        const noIds = await call("POST", "/training-sessions", member.token, { started_at: start.toISOString(), sets: [{ drops: [] }] });
        check("each logged set needs an exercise or a planned set", noIds.status === 400, `status ${noIds.status}`);

        const logged = await call("POST", "/training-sessions", member.token, {
          training_id: trainingId, started_at: start.toISOString(), ended_at: end.toISOString(), notes: "from the calendar",
          sets: [
            {
              training_set_id: plannedSet.id, exercise_id: pubEx.id,
              drops: [{ training_set_drop_id: plannedDrop.id, rep_count_actual: 8, weight_kg_actual: 32.5 }],
            },
            { exercise_id: pubEx.id, drops: [{ rep_type_actual: "failure" }] },
          ],
        });
        if (logged.data?.id) sessionId = logged.data.id;
        check(
          "member logs a finished session with its sets in one request",
          logged.status === 201 && new Date(logged.data.started_at).getTime() === start.getTime() &&
            new Date(logged.data.ended_at).getTime() === end.getTime() && logged.data.training_name === `${name} push` &&
            logged.data.set_logs.length === 2 && logged.data.set_logs[0].training_set_id === plannedSet.id &&
            logged.data.set_logs[0].drop_logs[0].weight_kg_actual == 32.5 && logged.data.set_logs[1].position === 1,
          short(logged.data),
        );

        const from = new Date(start.getTime() - 60_000).toISOString();
        const to = new Date(end.getTime()).toISOString();
        const week = await call("GET", `/training-sessions?from=${encodeURIComponent(from)}&to=${encodeURIComponent(to)}&page_size=100`, member.token);
        const row = (week.data as any[])?.find((x) => x.id === sessionId);
        check("from/to lists the session with its training name", week.status === 200 && row?.training_name === `${name} push`, short(row));
        const later = await call("GET", `/training-sessions?from=${encodeURIComponent(to)}&page_size=100`, member.token);
        check("sessions starting before from are left out", later.status === 200 && !(later.data as any[]).some((x) => x.id === sessionId), `status ${later.status}`);
        const badFrom = await call("GET", "/training-sessions?from=nope", member.token);
        check("an invalid from is 400", badFrom.status === 400, `status ${badFrom.status}`);

        const after = await call("GET", `/trainings/suggestions?name=${encodeURIComponent(name)}`, member.token);
        const recentRow = (after.data?.recent as any[])?.find((x) => x.id === trainingId);
        check(
          "once logged it moves to recent (and isn't repeated under assigned)",
          after.status === 200 && !!recentRow && !!recentRow.last_used_at &&
            !(after.data.assigned as any[]).some((x) => x.id === trainingId),
          short(after.data),
        );

        // ── Frozen sets ──
        const used = await call("GET", `/trainings/${trainingId}`, trainer.token);
        check("the training now reports has_sessions", used.status === 200 && used.data.has_sessions === true && used.data.routine_ids.includes(routineId), short(used.data));
        const locked = await call("PUT", `/trainings/${trainingId}`, trainer.token, {
          sets: [{ exercises: [{ exercise_id: pubEx.id, drops: [{ rep_count: 12 }] }] }],
        });
        check("its sets can't be replaced any more", locked.status === 409 && locked.data.code === "exercises_locked", short(locked.data));
        const renamed = await call("PUT", `/trainings/${trainingId}`, trainer.token, {
          name: `${name} push v2`, notes: "still editable", images: [{ url: "https://example.com/p.jpg" }],
        });
        check(
          "its details still change and the sets stay put",
          renamed.status === 200 && renamed.data.name === `${name} push v2` && renamed.data.sets[0].id === plannedSet.id &&
            renamed.data.sets[0].exercises[0].drops[0].id === plannedDrop.id && renamed.data.images.length === 1,
          short(renamed.data),
        );

        // ── Routine membership from the training form ──
        const other = await call("POST", "/trainings", trainer.token, { name: `${name} pull`, routine_ids: [routineId] });
        otherTrainingId = other.data?.id ?? null;
        const withOther = await call("GET", `/routines/${routineId}`, trainer.token);
        const entries = withOther.data?.trainings as any[] | undefined;
        check(
          "routine_ids adds a new training at the end of the routine",
          other.status === 201 && other.data.routine_ids.includes(routineId) && entries?.length === 2 &&
            entries[1].training_id === otherTrainingId && entries[1].position > entries[0].position && entries[1].week_number === null,
          short(entries),
        );
        const memberRoutine = await call("POST", "/routines", member.token, { name: `${name} mine` });
        memberRoutineId = memberRoutine.data?.id ?? null;
        const foreign = await call("PUT", `/trainings/${otherTrainingId}`, trainer.token, { routine_ids: [memberRoutineId] });
        check("routine_ids must be the caller's own routines", foreign.status === 400, `status ${foreign.status}`);
        const removed = await call("PUT", `/trainings/${otherTrainingId}`, trainer.token, { routine_ids: [] });
        const without = await call("GET", `/routines/${routineId}`, trainer.token);
        check(
          "an empty routine_ids takes it out again",
          removed.status === 200 && removed.data.routine_ids.length === 0 &&
            !(without.data?.trainings as any[]).some((x) => x.training_id === otherTrainingId),
          short(without.data?.trainings),
        );
      } finally {
        if (sessionId) await call("DELETE", `/training-sessions/${sessionId}`, member.token);
        if (assignmentId) await call("DELETE", `/routine-assignments/${assignmentId}`, trainer.token);
        if (routineId) await call("DELETE", `/routines/${routineId}`, trainer.token);
        if (memberRoutineId) await call("DELETE", `/routines/${memberRoutineId}`, member.token);
        if (otherTrainingId) await call("DELETE", `/trainings/${otherTrainingId}`, trainer.token);
        if (trainingId) await call("DELETE", `/trainings/${trainingId}`, trainer.token);
      }
      assertAll();
    });
  },
});
