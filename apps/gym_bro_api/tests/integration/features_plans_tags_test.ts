// deno-lint-ignore-file no-explicit-any
// Planned workouts and meals on the calendar (plan-entries) from routines and
// meal plans a member wrote and enrolled in themself, logging ahead of time,
// typed posts sharing a workout / meal / routine, and mentions + photo tags.
// Everything created (routines, trainings, plans, sessions, food logs, posts,
// uploads' posts, notifications) is deleted through the API in `finally`.
import {
  call,
  checker,
  dayFromToday,
  deleteNotifications,
  notificationsOf,
  PNG,
  seededUsers,
  short,
  suite,
  uploadTo,
} from "./_client.ts";

const uniq = () => `it-${crypto.randomUUID().slice(0, 8)}`;
const TZ = "Europe/Belgrade";

/** ISO weekday of a YYYY-MM-DD date. */
const isoDow = (ymd: string) => ((new Date(`${ymd}T00:00:00Z`).getUTCDay() + 6) % 7) + 1;

/** Local wall time "HH:MM" of an instant in TZ. */
const wallTime = (iso: string) =>
  new Intl.DateTimeFormat("en-GB", { timeZone: TZ, hour: "2-digit", minute: "2-digit", hourCycle: "h23" })
    .format(new Date(iso));

Deno.test({
  name: "features: planned workouts & meals, typed posts, tags",
  ...suite,
  async fn(t) {
    const { check, assertAll } = checker();
    const { member, trainer, vendor } = await seededUsers();
    const name = uniq();

    await t.step("planned workouts and meals", async () => {
      let trainingId: string | null = null;
      let routineId: string | null = null;
      let assignmentId: string | null = null;
      let dailyId: string | null = null;
      let mealPlanId: string | null = null;
      let mealAssignmentId: string | null = null;
      const sessions: string[] = [];
      try {
        // A week far ahead no other suite plans on: Monday and Wednesday.
        const base = dayFromToday(300);
        const monday = dayFromToday(300 + (8 - isoDow(base)) % 7);
        const wednesday = new Date(Date.parse(`${monday}T00:00:00Z`) + 2 * 86_400_000).toISOString().slice(0, 10);
        const from = `${monday}T00:00:00Z`;
        const to = new Date(Date.parse(from) + 7 * 86_400_000).toISOString();

        const pubEx = ((await call("GET", "/exercises?page_size=1")).data as any[])[0];
        const training = await call("POST", "/trainings", member.token, {
          name: `${name} day`,
          sets: [{ type: "standard", exercises: [{ exercise_id: pubEx.id, drops: [{ rep_type: "count", rep_count: 5, weight_kg: 50 }] }] }],
        });
        trainingId = training.data?.id ?? null;
        const routine = await call("POST", "/routines", member.token, {
          name: `${name} block`, schedule_type: "fixed_weeks", num_weeks: 1,
          trainings: [
            { training_id: trainingId, week_number: 1, day_of_week: 1 },
            { training_id: trainingId, week_number: 1, day_of_week: 3 },
          ],
        });
        routineId = routine.data?.id ?? null;
        check("a member (no trainer) writes a private routine", routine.status === 201 && routine.data.is_public === false, short(routine.data));

        const badTz = await call("POST", "/routine-assignments", member.token, {
          routine_id: routineId, user_id: member.profile.id, timezone: "Mars/Olympus",
        });
        const badTime = await call("POST", "/routine-assignments", member.token, {
          routine_id: routineId, user_id: member.profile.id, workout_time: "25:00",
        });
        check("timezone and workout_time are validated", badTz.status === 400 && badTime.status === 400, `status ${badTz.status}/${badTime.status}`);
        const enrolled = await call("POST", "/routine-assignments", member.token, {
          routine_id: routineId, user_id: member.profile.id, start_date: monday, timezone: TZ, workout_time: "06:30",
        });
        assignmentId = enrolled.data?.id ?? null;
        check(
          "member enrolls themself at their own workout time",
          enrolled.status === 201 && enrolled.data.workout_time === "06:30" && enrolled.data.timezone === TZ &&
            enrolled.data.assigned_by_id === member.profile.id,
          short(enrolled.data),
        );

        const list = await call("GET", `/plan-entries?from=${from}&to=${to}&tz=${TZ}`, member.token);
        const workouts = ((list.data ?? []) as any[]).filter((e) => e.routine_assignment_id === assignmentId);
        check(
          "the routine's days show up as planned workouts at 06:30 local",
          list.status === 200 && workouts.length === 2 && workouts.every((e) => wallTime(e.starts_at) === "06:30") &&
            workouts[0].plan_date === monday && workouts[1].plan_date === wednesday &&
            workouts.every((e) => e.status === "planned" && e.training_name === `${name} day` && e.routine_name === `${name} block`),
          short(workouts),
        );
        const again = await call("GET", `/plan-entries?from=${from}&to=${to}&tz=${TZ}`, member.token);
        check(
          "reading again doesn't duplicate entries",
          (again.data as any[]).filter((e) => e.routine_assignment_id === assignmentId).length === 2,
          `n=${again.data?.length}`,
        );
        const tooWide = await call("GET", `/plan-entries?from=${from}&to=${dayFromToday(500)}T00:00:00Z&tz=${TZ}`, member.token);
        const badZone = await call("GET", `/plan-entries?from=${from}&to=${to}&tz=Nowhere`, member.token);
        check("window and tz are validated", tooWide.status === 400 && badZone.status === 400, `status ${tooWide.status}/${badZone.status}`);

        const coach = await call("GET", `/plan-entries?from=${from}&to=${to}&tz=${TZ}&user_id=${member.profile.id}`, trainer.token);
        const stranger = await call("GET", `/plan-entries?from=${from}&to=${to}&tz=${TZ}&user_id=${member.profile.id}`, vendor.token);
        check("a coach reads them, others can't", coach.status === 200 && stranger.status === 403, `status ${coach.status}/${stranger.status}`);

        const [mon, wed] = workouts;
        const moved = await call("PUT", `/plan-entries/${mon.id}`, member.token, {
          starts_at: `${monday}T16:00:00Z`, duration_minutes: 90, note: "after work",
        });
        check(
          "one planned workout is moved on its own",
          moved.status === 200 && moved.data.edited === true && moved.data.duration_minutes === 90 && moved.data.note === "after work" &&
            new Date(moved.data.ends_at).getTime() - new Date(moved.data.starts_at).getTime() === 90 * 60_000,
          short(moved.data),
        );
        const othersEdit = await call("PUT", `/plan-entries/${mon.id}`, trainer.token, { note: "x" });
        const badDuration = await call("PUT", `/plan-entries/${mon.id}`, member.token, { duration_minutes: 1 });
        const mealOnly = await call("PUT", `/plan-entries/${mon.id}`, member.token, { training_id: crypto.randomUUID() });
        check(
          "edit validation (others 403, duration, unknown training 404)",
          othersEdit.status === 403 && badDuration.status === 400 && mealOnly.status === 404,
          `status ${othersEdit.status}/${badDuration.status}/${mealOnly.status}`,
        );

        // Changing the time regenerates untouched future entries; the moved one stays.
        const retimed = await call("PUT", `/routine-assignments/${assignmentId}`, member.token, { workout_time: "07:15" });
        const afterRetime = ((await call("GET", `/plan-entries?from=${from}&to=${to}&tz=${TZ}`, member.token)).data as any[])
          .filter((e) => e.routine_assignment_id === assignmentId);
        check(
          "a new workout time moves untouched entries only",
          retimed.status === 200 && retimed.data.workout_time === "07:15" && afterRetime.length === 2 &&
            afterRetime.some((e) => e.id === mon.id && e.starts_at === moved.data.starts_at) &&
            afterRetime.some((e) => e.id !== mon.id && wallTime(e.starts_at) === "07:15"),
          short(afterRetime),
        );
        const wedNow = afterRetime.find((e) => e.id !== mon.id)!;
        check("the regenerated entry keeps its plan date", wedNow.plan_date === wed.plan_date, short(wedNow));

        const confirmed = await call("POST", `/plan-entries/${mon.id}/confirm`, member.token, {});
        if (confirmed.data?.training_session_id) sessions.push(confirmed.data.training_session_id);
        const session = await call("GET", `/training-sessions/${confirmed.data?.training_session_id}`, member.token);
        check(
          "confirming logs the workout as planned (even ahead of time)",
          confirmed.status === 201 && confirmed.data.status === "done" && session.status === 200 &&
            session.data.plan_entry_id === mon.id && session.data.training_id === trainingId &&
            session.data.set_logs.length === 1 && session.data.set_logs[0].drop_logs[0].weight_kg_actual == 50,
          short(session.data),
        );
        const skipped = await call("DELETE", `/plan-entries/${wedNow.id}`, member.token);
        const wedRow = await call("GET", `/plan-entries/${wedNow.id}`, member.token);
        check("deleting skips it", skipped.status === 204 && wedRow.data?.status === "skipped" && wedRow.data.exercises.length === 1, short(wedRow.data));
        const differently = await call("POST", "/training-sessions", member.token, {
          plan_entry_id: wedNow.id, started_at: `${wednesday}T17:00:00Z`, ended_at: `${wednesday}T18:00:00Z`,
          sets: [{ exercise_id: pubEx.id, drops: [{ rep_count_actual: 3, weight_kg_actual: 60 }] }],
        });
        if (differently.data?.id) sessions.push(differently.data.id);
        const wedDone = await call("GET", `/plan-entries/${wedNow.id}`, member.token);
        check(
          "logging differently with plan_entry_id also marks it done",
          differently.status === 201 && wedDone.data?.status === "done" && wedDone.data.sessions.length === 1,
          short(wedDone.data),
        );
        const foreign = await call("POST", "/training-sessions", trainer.token, { plan_entry_id: wedNow.id });
        if (foreign.data?.id) sessions.push(foreign.data.id);
        check("someone else can't log against my plan", foreign.status === 404, `status ${foreign.status}`);

        // ── Meals ──
        const food = ((await call("GET", "/food-items?page_size=1")).data as any[])[0];
        const daily = await call("POST", "/daily-meal-plans", member.token, {
          name: `${name} day plan`,
          slots: [
            { slot_type: "breakfast", entries: [{ food_item_id: food.id, quantity: 100 }] },
            { slot_type: "dinner", entries: [{ food_item_id: food.id, quantity: 200 }] },
          ],
        });
        dailyId = daily.data?.id ?? null;
        const mealPlan = await call("POST", "/meal-plans", member.token, {
          name: `${name} meals`, num_weeks: 1, days: [{ daily_meal_plan_id: dailyId, week_number: 1, day_of_week: 3 }],
        });
        mealPlanId = mealPlan.data?.id ?? null;
        const mealEnroll = await call("POST", "/meal-plan-assignments", member.token, {
          meal_plan_id: mealPlanId, user_id: member.profile.id, start_date: monday, timezone: TZ,
        });
        mealAssignmentId = mealEnroll.data?.id ?? null;
        check("member enrolls in their own meal plan", mealEnroll.status === 201 && mealEnroll.data.timezone === TZ, short(mealEnroll.data));
        const meals = ((await call("GET", `/plan-entries?from=${from}&to=${to}&tz=${TZ}`, member.token)).data as any[])
          .filter((e) => e.meal_plan_assignment_id === mealAssignmentId);
        const breakfast = meals.find((e) => e.meal_slot === "breakfast");
        const dinner = meals.find((e) => e.meal_slot === "dinner");
        check(
          "the plan's Wednesday shows as planned meals at the slots' usual times",
          meals.length === 2 && !!breakfast && !!dinner && breakfast.plan_date === wednesday &&
            wallTime(breakfast.starts_at) === "08:00" && wallTime(dinner.starts_at) === "20:00" && breakfast.daily_meal_plan_id === dailyId,
          short(meals),
        );
        const mealDetail = await call("GET", `/plan-entries/${dinner?.id}`, member.token);
        check(
          "a planned meal lists its items with macros",
          mealDetail.status === 200 && mealDetail.data.items.length === 1 && mealDetail.data.items[0].amount === 200 &&
            mealDetail.data.items[0].food_item_id === food.id,
          short(mealDetail.data),
        );
        const ateIt = await call("POST", `/plan-entries/${breakfast?.id}/confirm`, member.token, {});
        const diary = await call("GET", `/food-logs?date=${wednesday}`, member.token);
        const fromPlan = ((diary.data ?? []) as any[]).filter((l) => l.plan_entry_id === breakfast?.id);
        check(
          "confirming a meal logs it in the diary, linked and timed",
          ateIt.status === 201 && ateIt.data.status === "done" && ateIt.data.logged_count === 1 && fromPlan.length === 1 &&
            new Date(fromPlan[0].eaten_at).getTime() === new Date(breakfast.starts_at).getTime(),
          short(fromPlan),
        );
        const adhoc = await call("POST", "/food-logs", member.token, {
          log_date: wednesday, slot_type: "dinner", food_item_id: food.id, amount: 150,
          plan_entry_id: dinner?.id, eaten_at: `${wednesday}T19:10:00Z`,
        });
        const dinnerDone = await call("GET", `/plan-entries/${dinner?.id}`, member.token);
        check(
          "logging a meal differently against the plan marks it done",
          adhoc.status === 201 && adhoc.data.eaten_at && dinnerDone.data?.status === "done" && dinnerDone.data.logs.length === 1,
          short(dinnerDone.data),
        );
        const wrongKind = await call("POST", "/food-logs", member.token, {
          log_date: wednesday, slot_type: "dinner", food_item_id: food.id, amount: 1, plan_entry_id: mon.id,
        });
        check("a workout entry can't take food logs", wrongKind.status === 400, `status ${wrongKind.status}`);
        for (const l of (await call("GET", `/food-logs?date=${wednesday}`, member.token)).data as any[]) {
          if (l.plan_entry_id === breakfast?.id || l.plan_entry_id === dinner?.id) {
            await call("DELETE", `/food-logs/${l.id}`, member.token);
          }
        }
      } finally {
        for (const id of sessions) await call("DELETE", `/training-sessions/${id}`, member.token);
        if (assignmentId) await call("DELETE", `/routine-assignments/${assignmentId}`, member.token);
        if (mealAssignmentId) await call("DELETE", `/meal-plan-assignments/${mealAssignmentId}`, member.token);
        if (routineId) await call("DELETE", `/routines/${routineId}`, member.token);
        if (trainingId) await call("DELETE", `/trainings/${trainingId}`, member.token);
        if (mealPlanId) await call("DELETE", `/meal-plans/${mealPlanId}`, member.token);
        if (dailyId) await call("DELETE", `/daily-meal-plans/${dailyId}`, member.token);
      }
    });

    await t.step("typed posts, mentions and photo tags", async () => {
      const posts: string[] = [];
      const sessions: string[] = [];
      let routineId: string | null = null;
      try {
        // ── Typed posts ──
        const start = new Date(Date.now() - 2 * 3600_000);
        const pubEx = ((await call("GET", "/exercises?page_size=1")).data as any[])[0];
        const past = await call("POST", "/training-sessions", member.token, {
          started_at: start.toISOString(), ended_at: new Date(start.getTime() + 45 * 60_000).toISOString(),
          sets: [{ exercise_id: pubEx.id, drops: [{ rep_count_actual: 5, weight_kg_actual: 100 }] }],
        });
        if (past.data?.id) sessions.push(past.data.id);
        const ahead = await call("POST", "/training-sessions", member.token, {
          started_at: new Date(Date.now() + 86_400_000).toISOString(),
        });
        if (ahead.data?.id) sessions.push(ahead.data.id);

        const shared = await call("POST", "/posts", member.token, { type: "workout", ref_id: past.data?.id });
        if (shared.data?.id) posts.push(shared.data.id);
        const a = shared.data?.attachment;
        check(
          "a logged workout is shared as a post without a caption",
          shared.status === 201 && shared.data.post_type === "workout" && shared.data.ref_id === past.data?.id &&
            a?.duration_minutes === 45 && a.set_count === 1 && a.volume_kg === 500 && a.exercises[0]?.id === pubEx.id &&
            a.exercises[0].best_weight_kg === 100,
          short(shared.data),
        );
        const early = await call("POST", "/posts", member.token, { type: "workout", ref_id: ahead.data?.id });
        if (early.data?.id) posts.push(early.data.id);
        check(
          "a workout logged in the future can't be shared yet",
          early.status === 400 && early.data?.code === "future_activity",
          short(early.data),
        );
        const notMine = await call("POST", "/posts", trainer.token, { type: "workout", ref_id: past.data?.id });
        if (notMine.data?.id) posts.push(notMine.data.id);
        const noRef = await call("POST", "/posts", member.token, { type: "routine" });
        const badType = await call("POST", "/posts", member.token, { type: "story", content: "x" });
        check(
          "type validation (someone else's workout 404, missing ref 400, unknown type 400)",
          notMine.status === 404 && noRef.status === 400 && badType.status === 400,
          `status ${notMine.status}/${noRef.status}/${badType.status}`,
        );

        const routine = await call("POST", "/routines", member.token, { name: `${name} secret`, schedule_type: "wildcard" });
        routineId = routine.data?.id ?? null;
        const privateShare = await call("POST", "/posts", trainer.token, { type: "routine", ref_id: routineId });
        if (privateShare.data?.id) posts.push(privateShare.data.id);
        const ownShare = await call("POST", "/posts", member.token, { type: "routine", ref_id: routineId, content: "my plan" });
        if (ownShare.data?.id) posts.push(ownShare.data.id);
        check(
          "only visible library items can be shared",
          privateShare.status === 404 && ownShare.status === 201 && ownShare.data.attachment.title === `${name} secret` &&
            ownShare.data.attachment.schedule_type === "wildcard",
          `status ${privateShare.status}/${ownShare.status}`,
        );
        const blankEdit = await call("PUT", `/posts/${shared.data?.id}`, member.token, { content: "" });
        check("a typed post may have an empty caption", blankEdit.status === 200, `status ${blankEdit.status}`);

        // ── Mentions ──
        const search = await call("GET", "/posts/mention-search?q=elena", member.token);
        const elena = (search.data as any[])?.find((s) => s.kind === "user" && s.id === trainer.profile.id);
        const gyms = await call("GET", "/posts/mention-search?q=ironclad&kinds=business", member.token);
        check(
          "@ search finds people and gyms",
          search.status === 200 && !!elena && elena.username && (gyms.data as any[]).some((g) => g.kind === "business"),
          short(search.data),
        );
        const gym = (gyms.data as any[])[0];
        const mention = await call("POST", "/posts", member.token, {
          content: `Leg day with @${trainer.profile.username} at @[${gym.label}](business:${gym.id}) ${name}`,
          visibility: "followers",
        });
        if (mention.data?.id) posts.push(mention.data.id);
        check(
          "a typed @handle becomes a mention, picked mentions stay",
          mention.status === 201 && mention.data.content.includes(`(user:${trainer.profile.id})`) &&
            mention.data.content.includes(`(business:${gym.id})`),
          short(mention.data?.content),
        );
        const tagged = await call("GET", `/posts?tagged_user_id=${trainer.profile.id}`, trainer.token);
        const seen = await call("GET", `/posts/${mention.data?.id}`, trainer.token);
        check(
          "the mentioned person sees the followers-only post and finds it under Tagged",
          seen.status === 200 && (tagged.data as any[]).some((p) => p.id === mention.data?.id),
          `status ${seen.status}`,
        );
        const notes = await notificationsOf(trainer.token);
        check(
          "the mentioned person is notified",
          notes.some((n) => n.type === "mention" && n.metadata?.post_id === mention.data?.id && !n.body.includes("](user:")),
          short(notes.slice(0, 2)),
        );
        const comment = await call("POST", `/posts/${shared.data?.id}/comments`, trainer.token, {
          body: `Nice @${member.profile.username}`,
        });
        const memberNotes = await notificationsOf(member.token);
        check(
          "a mention in a comment is stored as markup and doesn't double-notify the post's author",
          comment.status === 201 && comment.data.body.includes(`(user:${member.profile.id})`) &&
            memberNotes.filter((n) => n.metadata?.comment_id === comment.data?.id).length === 1,
          short(comment.data?.body),
        );

        // ── Photo tags ──
        const slot = await call("POST", "/posts/uploads", member.token, { mime_type: "image/png", size_bytes: PNG.length });
        await uploadTo(slot.data, PNG, "image/png");
        const badPin = await call("POST", "/posts", member.token, {
          media: [{ path: slot.data?.path, tags: [{ user_id: trainer.profile.id, x: 1.5, y: 0.2 }] }],
        });
        check("pins need x, y within the photo", badPin.status === 400, `status ${badPin.status}`);
        const photo = await call("POST", "/posts", member.token, {
          content: name, media: [{ path: slot.data?.path, width: 1, height: 1, tags: [{ user_id: trainer.profile.id, x: 0.25, y: 0.75 }] }],
        });
        if (photo.data?.id) posts.push(photo.data.id);
        const pin = photo.data?.images?.[0]?.tags?.[0];
        check(
          "a person is pinned on the photo",
          photo.status === 201 && pin?.user_id === trainer.profile.id && pin.x === 0.25 && pin.y === 0.75 && pin.username,
          short(photo.data?.images),
        );
        const trainerNotes = await notificationsOf(trainer.token);
        check("the pinned person is notified", trainerNotes.some((n) => n.type === "photo_tag" && n.metadata?.post_id === photo.data?.id), "");
        const imageId = photo.data?.images?.[0]?.id;
        const repin = await call("PUT", `/posts/${photo.data?.id}`, member.token, {
          photo_tags: [{ post_image_id: imageId, tags: [{ user_id: trainer.profile.id, x: 0.5, y: 0.5 }] }],
        });
        const foreignImage = await call("PUT", `/posts/${photo.data?.id}`, member.token, {
          photo_tags: [{ post_image_id: crypto.randomUUID(), tags: [] }],
        });
        check(
          "the author moves the pin; only this post's photos",
          repin.status === 200 && repin.data.images[0].tags[0].x === 0.5 && foreignImage.status === 400,
          `status ${repin.status}/${foreignImage.status}`,
        );
        const untag = await call("DELETE", `/posts/${photo.data?.id}/tags/me`, trainer.token);
        const afterUntag = await call("GET", `/posts/${photo.data?.id}`, member.token);
        check(
          "the tagged person removes themself",
          untag.status === 204 && afterUntag.data.images[0].tags.length === 0,
          short(afterUntag.data?.images),
        );
      } finally {
        for (const id of posts) await call("DELETE", `/posts/${id}`, member.token);
        for (const id of sessions) await call("DELETE", `/training-sessions/${id}`, member.token);
        if (routineId) await call("DELETE", `/routines/${routineId}`, member.token);
        const ours = (n: any) => posts.includes(n.metadata?.post_id);
        await deleteNotifications(trainer.token, ours);
        await deleteNotifications(member.token, ours);
      }
    });

    assertAll();
  },
});
