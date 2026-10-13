// deno-lint-ignore-file no-explicit-any
// Classes (booking, waitlist, attendance, series) and staff shifts. Classes
// have no hard-delete endpoint, so created rows are removed with SQL in
// `finally` (see _db.ts); everything else goes through the API.
import { call, checker, deleteNotifications, futureAt, notificationsOf, seededUsers, short, signin, suite } from "./_client.ts";
import { deleteNotificationsWhere, sql } from "./_db.ts";

Deno.test({
  name: "features: classes and shifts",
  ...suite,
  async fn(t) {
    const { check, assertAll } = checker();
    const { member, owner, trainer, employee, vendor, gym } = await seededUsers();
    const stamp = Date.now();

    // A second member of the same gym, for waitlist promotion.
    const roster = (await call("GET", `/members?gym_id=${gym.id}`, owner.token)).data as any[];
    const otherRow = roster.find((m) => m.user_id !== member.profile.id && typeof m.email === "string");
    check("gym has a second member", !!otherRow, `n=${roster.length}`);
    assertAll();
    const member2 = await signin(otherRow.email);

    await t.step("1. classes: create, book, waitlist, attendance, series cancel", async () => {
      const created: string[] = [];
      try {
        const base = {
          gym_id: gym.id,
          description: "integration test",
          location: "Studio T",
        };
        // Days ahead are randomised a little so reruns don't stack on one slot.
        const day = 3 + (stamp % 5);

        const single = await call("POST", "/classes", trainer.token, {
          ...base,
          title: `Test HIIT ${stamp}`,
          starts_at: futureAt(day, 18),
          ends_at: futureAt(day, 19),
          capacity: 10,
        });
        check("trainer creates a class", single.status === 201 && Array.isArray(single.data) && single.data.length === 1, short(single.data));
        const cls = single.data?.[0];
        if (cls?.id) created.push(cls.id);
        check("class defaults trainer_id to the creating trainer", cls?.trainer_id === trainer.profile.id && cls?.can_coach === true, short(cls));

        const series = await call("POST", "/classes", trainer.token, {
          ...base,
          title: `Test Yoga ${stamp}`,
          starts_at: futureAt(day, 7),
          ends_at: futureAt(day, 8),
          capacity: 5,
          repeat_weeks: 2,
        });
        const seriesRows = (series.data ?? []) as any[];
        created.push(...seriesRows.map((r) => r.id).filter(Boolean));
        check(
          "trainer creates a 2-week series",
          series.status === 201 && seriesRows.length === 2 && !!seriesRows[0].series_id &&
            seriesRows[0].series_id === seriesRows[1].series_id &&
            new Date(seriesRows[1].starts_at).getTime() - new Date(seriesRows[0].starts_at).getTime() === 7 * 86_400_000,
          short(series.data),
        );

        const badRepeat = await call("POST", "/classes", trainer.token, {
          ...base, title: "x", starts_at: futureAt(day, 9), ends_at: futureAt(day, 10), capacity: 5, repeat_weeks: 13,
        });
        check("repeat_weeks above 12 is rejected", badRepeat.status === 400, `status ${badRepeat.status}`);
        const badTimes = await call("POST", "/classes", trainer.token, {
          ...base, title: "x", starts_at: futureAt(day, 10), ends_at: futureAt(day, 9), capacity: 5,
        });
        check("ends_at before starts_at is rejected", badTimes.status === 400, `status ${badTimes.status}`);

        // ── Member permissions ──
        const memberCreate = await call("POST", "/classes", member.token, {
          ...base, title: "Member class", starts_at: futureAt(day, 12), ends_at: futureAt(day, 13), capacity: 5,
        });
        check("member can't create a class", memberCreate.status === 403, `status ${memberCreate.status}`);
        if (memberCreate.status === 201) created.push(...(memberCreate.data as any[]).map((r) => r.id));
        const memberEdit = await call("PUT", `/classes/${cls.id}`, member.token, { title: "pwned" });
        check("member can't edit a class", memberEdit.status === 403, `status ${memberEdit.status}`);
        const memberCancel = await call("DELETE", `/classes/${cls.id}`, member.token);
        check("member can't cancel a class", memberCancel.status === 403, `status ${memberCancel.status}`);
        const vendorRead = await call("GET", `/classes/${cls.id}`, vendor.token);
        check("unrelated vendor can't read the class", vendorRead.status === 403, `status ${vendorRead.status}`);
        const vendorBook = await call("POST", `/classes/${cls.id}/book`, vendor.token);
        check("non-member can't book", vendorBook.status === 403, `status ${vendorBook.status}`);

        // ── Booking ──
        const book = await call("POST", `/classes/${cls.id}/book`, member.token);
        check("member books the class", book.status === 201 && book.data.status === "booked", short(book.data));
        const again = await call("POST", `/classes/${cls.id}/book`, member.token);
        check("second booking is 409", again.status === 409, `status ${again.status}`);
        const listed = await call("GET", `/classes?gym_id=${gym.id}&mine=true&to=${futureAt(day + 1, 0)}`, member.token);
        check(
          "booked class appears in ?mine=true with my_booking_status",
          listed.status === 200 && (listed.data as any[]).some((c) => c.id === cls.id && c.my_booking_status === "booked" && c.booked_count === 1),
          `status ${listed.status}`,
        );

        const trainerEdit = await call("PUT", `/classes/${cls.id}`, trainer.token, { title: `Test HIIT ${stamp} (edited)`, capacity: 12 });
        check("trainer edits own class", trainerEdit.status === 200 && trainerEdit.data.capacity === 12, short(trainerEdit.data));

        const memberForOther = await call("POST", `/classes/${cls.id}/book`, member2.token, { user_id: member.profile.id });
        check("member can't book for someone else", memberForOther.status === 403, `status ${memberForOther.status}`);
        const staffBook = await call("POST", `/classes/${cls.id}/book`, trainer.token, { user_id: member2.profile.id });
        check("coach books a member in", staffBook.status === 201 && staffBook.data.user_id === member2.profile.id, short(staffBook.data));
        const staffBookNonMember = await call("POST", `/classes/${cls.id}/book`, trainer.token, { user_id: vendor.profile.id });
        check("coach can't book a non-member", staffBookNonMember.status === 400, `status ${staffBookNonMember.status}`);
        const moved = await call("PUT", `/classes/${cls.id}`, trainer.token, { starts_at: futureAt(day, 18, 30) });
        check(
          "moving the start keeps the duration",
          moved.status === 200 && new Date(moved.data.ends_at).getTime() - new Date(moved.data.starts_at).getTime() === 3_600_000,
          short(moved.data),
        );
        const movedNotice = (await notificationsOf(member2.token)).find((n) => n.metadata?.class_id === cls.id && /updated/i.test(n.title));
        check("booked members are told the class moved", !!movedNotice, short(movedNotice));
        const shrinkBelow = await call("PUT", `/classes/${cls.id}`, trainer.token, { capacity: 1 });
        check("capacity can't drop below the booked count", shrinkBelow.status === 400, `status ${shrinkBelow.status}`);

        // ── Capacity 1: waitlist and promotion ──
        const tiny = await call("POST", "/classes", trainer.token, {
          ...base, title: `Test PT ${stamp}`, starts_at: futureAt(day, 20), ends_at: futureAt(day, 21), capacity: 1,
        });
        const tinyCls = tiny.data?.[0];
        if (tinyCls?.id) created.push(tinyCls.id);
        check("trainer creates a capacity-1 class", tiny.status === 201 && tinyCls?.capacity === 1, short(tiny.data));

        const first = await call("POST", `/classes/${tinyCls.id}/book`, member.token);
        check("first member gets the seat", first.status === 201 && first.data.status === "booked", short(first.data));
        const second = await call("POST", `/classes/${tinyCls.id}/book`, member2.token);
        check(
          "second member is waitlisted at position 1",
          second.status === 201 && second.data.status === "waitlisted" && second.data.waitlist_position === 1,
          short(second.data),
        );

        const shrink = await call("PUT", `/classes/${tinyCls.id}`, trainer.token, { capacity: 1 });
        check("capacity can stay at the booked count", shrink.status === 200, `status ${shrink.status}`);

        // A coach can't seat a waitlisted member by "marking attendance" — that
        // would bypass capacity and the waitlist order.
        const jump = await call("PUT", `/classes/${tinyCls.id}/bookings/${second.data.id}`, trainer.token, { status: "attended" });
        check("coach can't mark a waitlisted booking attended", jump.status === 409, `status ${jump.status} ${short(jump.data)}`);

        const cancelOther = await call("POST", `/classes/${tinyCls.id}/cancel-booking`, member2.token, { user_id: member.profile.id });
        check("member can't cancel someone else's booking", cancelOther.status === 403, `status ${cancelOther.status}`);

        const cancel = await call("POST", `/classes/${tinyCls.id}/cancel-booking`, member.token);
        check("member cancels their booking", cancel.status === 200 && cancel.data.status === "cancelled", short(cancel.data));

        const detail = await call("GET", `/classes/${tinyCls.id}`, member2.token);
        check(
          "waitlisted member was promoted",
          detail.status === 200 && detail.data.my_booking_status === "booked" && detail.data.booked_count === 1 && detail.data.waitlist_count === 0,
          short(detail.data),
        );
        const promoted = (await notificationsOf(member2.token)).find((n) => n.metadata?.class_id === tinyCls.id);
        check("promoted member got a notification", !!promoted && promoted.type === "events" && /You're in/.test(promoted.title), short(promoted));

        // ── Attendance ──
        const coachView = await call("GET", `/classes/${tinyCls.id}`, trainer.token);
        const promotedBooking = (coachView.data?.bookings ?? []).find((b: any) => b.user_id === member2.profile.id);
        check("coach sees the bookings list", coachView.status === 200 && !!promotedBooking && coachView.data.can_coach === true, short(coachView.data?.bookings));
        const memberView = await call("GET", `/classes/${tinyCls.id}`, member2.token);
        check("member view has no bookings list", memberView.status === 200 && !("bookings" in memberView.data), short(memberView.data));
        const memberMark = await call("PUT", `/classes/${tinyCls.id}/bookings/${promotedBooking?.id}`, member2.token, { status: "attended" });
        check("member can't mark attendance", memberMark.status === 403, `status ${memberMark.status}`);
        const mark = await call("PUT", `/classes/${tinyCls.id}/bookings/${promotedBooking?.id}`, trainer.token, { status: "attended" });
        check("coach marks attendance", mark.status === 200 && mark.data.status === "attended", short(mark.data));
        const badMark = await call("PUT", `/classes/${tinyCls.id}/bookings/${promotedBooking?.id}`, trainer.token, { status: "cancelled" });
        check("attendance status is validated", badMark.status === 400, `status ${badMark.status}`);
        const cancelledMark = await call("PUT", `/classes/${tinyCls.id}/bookings/${cancel.data.id}`, trainer.token, { status: "booked" });
        check("coach can't revive a cancelled booking via attendance", cancelledMark.status === 409, `status ${cancelledMark.status}`);
        const ownerMark = await call("PUT", `/classes/${tinyCls.id}/bookings/${promotedBooking?.id}`, owner.token, { status: "no_show" });
        check("gym owner can mark attendance too", ownerMark.status === 200 && ownerMark.data.status === "no_show", short(ownerMark.data));

        // ── Cancelling ──
        const seriesBook = await call("POST", `/classes/${seriesRows[1].id}/book`, member.token);
        check("member books the second series class", seriesBook.status === 201, short(seriesBook.data));
        const seriesCancel = await call("DELETE", `/classes/${seriesRows[0].id}?series=true`, trainer.token);
        check(
          "trainer cancels the whole series",
          seriesCancel.status === 200 && seriesCancel.data.cancelled?.length === 2,
          short(seriesCancel.data),
        );
        const cancelledNotice = (await notificationsOf(member.token)).find((n) => n.metadata?.class_id === seriesRows[1].id);
        check("booked member was told about the cancellation", !!cancelledNotice && /cancelled/i.test(cancelledNotice.title), short(cancelledNotice));
        const bookCancelled = await call("POST", `/classes/${seriesRows[0].id}/book`, member.token);
        check("can't book a cancelled class", bookCancelled.status === 400, `status ${bookCancelled.status}`);
        const editCancelled = await call("PUT", `/classes/${seriesRows[0].id}`, trainer.token, { title: "x" });
        check("can't edit a cancelled class", editCancelled.status === 400, `status ${editCancelled.status}`);

        const single2 = await call("DELETE", `/classes/${cls.id}`, owner.token);
        check("owner cancels a trainer's class", single2.status === 200 && single2.data.cancelled?.[0] === cls.id, short(single2.data));
      } finally {
        await deleteNotifications(member.token, (n) => created.includes(n.metadata?.class_id));
        await deleteNotifications(member2.token, (n) => created.includes(n.metadata?.class_id));
        await deleteNotificationsWhere("class_id", created);
        await sql(`DELETE FROM gym_class WHERE id = ANY($1::uuid[])`, [created]);
      }
      assertAll();
    });

    await t.step("2. shifts: create, overlap, permissions, mine, notification, delete", async () => {
      let shiftId: string | null = null;
      const shiftIds: string[] = [];
      try {
        const day = 10 + (stamp % 7);
        const startsAt = futureAt(day, 9);
        const endsAt = futureAt(day, 17);
        const created = await call("POST", "/shifts", owner.token, {
          gym_id: gym.id, user_id: employee.profile.id, starts_at: startsAt, ends_at: endsAt, note: `test ${stamp}`,
        });
        shiftId = created.data?.id ?? null;
        if (shiftId) shiftIds.push(shiftId);
        check(
          "owner creates a shift for the employee",
          created.status === 201 && created.data.user_id === employee.profile.id && created.data.gym_name === gym.name,
          short(created.data),
        );

        const overlap = await call("POST", "/shifts", owner.token, {
          gym_id: gym.id, user_id: employee.profile.id, starts_at: futureAt(day, 12), ends_at: futureAt(day, 20),
        });
        check("overlapping shift is 409", overlap.status === 409, `status ${overlap.status}`);
        if (overlap.status === 201) {
          shiftIds.push(overlap.data.id);
          await call("DELETE", `/shifts/${overlap.data.id}`, owner.token);
        }

        const notStaff = await call("POST", "/shifts", owner.token, {
          gym_id: gym.id, user_id: member.profile.id, starts_at: futureAt(day, 9), ends_at: futureAt(day, 10),
        });
        check("can't schedule a non-staff member", notStaff.status === 400, `status ${notStaff.status}`);

        const memberCreate = await call("POST", "/shifts", member.token, {
          gym_id: gym.id, user_id: employee.profile.id, starts_at: futureAt(day, 18), ends_at: futureAt(day, 19),
        });
        check("member can't create shifts", memberCreate.status === 403, `status ${memberCreate.status}`);
        const employeeCreate = await call("POST", "/shifts", employee.token, {
          gym_id: gym.id, user_id: employee.profile.id, starts_at: futureAt(day, 18), ends_at: futureAt(day, 19),
        });
        check("employee can't create shifts", employeeCreate.status === 403, `status ${employeeCreate.status}`);
        const employeeEdit = await call("PUT", `/shifts/${shiftId}`, employee.token, { note: "x" });
        check("employee can't edit shifts", employeeEdit.status === 403, `status ${employeeEdit.status}`);

        const mine = await call("GET", `/shifts?mine=true&to=${futureAt(day + 1, 0)}`, employee.token);
        check("employee sees the shift in ?mine=true", mine.status === 200 && (mine.data as any[]).some((s) => s.id === shiftId), `status ${mine.status}`);
        const rota = await call("GET", `/shifts?gym_id=${gym.id}&to=${futureAt(day + 1, 0)}`, employee.token);
        check("employee reads the gym rota", rota.status === 200 && (rota.data as any[]).some((s) => s.id === shiftId), `status ${rota.status}`);
        const memberRota = await call("GET", `/shifts?gym_id=${gym.id}`, member.token);
        check("member can't read the gym rota", memberRota.status === 403, `status ${memberRota.status}`);
        const memberOne = await call("GET", `/shifts/${shiftId}`, member.token);
        check("member can't read a shift", memberOne.status === 403, `status ${memberOne.status}`);
        const staffList = await call("GET", `/shifts/staff?gym_id=${gym.id}`, owner.token);
        check(
          "owner lists schedulable staff",
          staffList.status === 200 && staffList.data.can_manage === true &&
            (staffList.data.staff as any[]).some((s) => s.user_id === employee.profile.id),
          short(staffList.data),
        );

        const notif = (await notificationsOf(employee.token)).find((n) => n.metadata?.shift_id === shiftId);
        check("employee got a shift_assigned notification", notif?.type === "shift_assigned", short(notif));

        const moved = await call("PUT", `/shifts/${shiftId}`, owner.token, { ends_at: futureAt(day, 18) });
        check("owner extends the shift", moved.status === 200 && new Date(moved.data.ends_at).toISOString() === futureAt(day, 18), short(moved.data));

        const memberDel = await call("DELETE", `/shifts/${shiftId}`, member.token);
        check("member can't delete shifts", memberDel.status === 403, `status ${memberDel.status}`);
        const del = await call("DELETE", `/shifts/${shiftId}`, owner.token);
        check("owner deletes the shift", del.status === 204, `status ${del.status}`);
        const gone = await call("GET", `/shifts/${shiftId}`, owner.token);
        check("deleted shift is gone", gone.status === 404, `status ${gone.status}`);
        const cancelNotice = (await notificationsOf(employee.token)).filter((n) => n.metadata?.shift_id === shiftId);
        if (del.status === 204) shiftId = null;
        check("employee was told the shift was cancelled", cancelNotice.some((n) => /cancelled/i.test(n.title)), `n=${cancelNotice.length}`);
      } finally {
        if (shiftId) await call("DELETE", `/shifts/${shiftId}`, owner.token);
        await deleteNotifications(employee.token, (n) => shiftIds.includes(n.metadata?.shift_id));
        await deleteNotificationsWhere("shift_id", shiftIds);
      }
      assertAll();
    });
  },
});
