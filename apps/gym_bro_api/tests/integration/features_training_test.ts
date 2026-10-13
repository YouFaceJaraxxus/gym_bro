// deno-lint-ignore-file no-explicit-any
// Progress & body measurements, routine assignments, session comments and PR
// detection. Everything created is deleted through the API in `finally`.
import { call, checker, dayFromToday, deleteNotifications, notificationsOf, seededUsers, short, suite } from "./_client.ts";

Deno.test({
  name: "features: progress, body, routines, session comments",
  ...suite,
  async fn(t) {
    const { check, assertAll } = checker();
    const { member, trainer, vendor } = await seededUsers();

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
  },
});
