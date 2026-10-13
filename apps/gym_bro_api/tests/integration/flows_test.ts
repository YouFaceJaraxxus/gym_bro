// deno-lint-ignore-file no-explicit-any
// Write flows (ported from the flows smoke script). Everything it creates or
// changes is restored/deleted, in `finally` blocks so a failing check never
// leaves test data behind.
import { call, checker, short, signin, suite } from "./_client.ts";

Deno.test({
  name: "write flows",
  ...suite,
  async fn(t) {
    const { check, assertAll } = checker();

    const owner = await signin("marcus.bennett@example.com");
    const member = await signin("liam.oconnor@example.com");
    const trainer = await signin("elena.vasquez@example.com");
    const superU = await signin("chloe.anderson@example.com");
    const gym = ((await call("GET", "/businesses", owner.token)).data as any[]).find((b) => b.type === "gym");

    await t.step("invoice status round trip", async () => {
      const invs = (await call("GET", `/membership-invoices?gym_id=${gym.id}`, owner.token)).data as any[];
      const inv = invs[0];
      try {
        const paid = await call("PUT", `/membership-invoices/${inv.id}`, owner.token, { status: "paid" });
        check("owner marks invoice paid", paid.status === 200 && paid.data.status === "paid" && !!paid.data.paid_at, short(paid.data));
        const memberPay = await call("PUT", `/membership-invoices/${inv.id}`, member.token, { status: "void" });
        check("member can't change invoice status", memberPay.status === 403, `status ${memberPay.status}`);
      } finally {
        const restore = await call("PUT", `/membership-invoices/${inv.id}`, owner.token, { status: inv.status });
        check("invoice status restored", restore.status === 200 && restore.data.status === inv.status);
      }
      const myInv = await call("GET", `/membership-invoices?user_id=${member.profile.id}`, member.token);
      check("member reads own invoices", myInv.status === 200 && (myInv.data as any[]).every((i) => i.user_id === member.profile.id), `n=${(myInv.data as any[])?.length}`);
      assertAll();
    });

    await t.step("employee role change round trip", async () => {
      const emps = (await call("GET", `/employees?gym_id=${gym.id}`, owner.token)).data as any[];
      if (emps.length) {
        const e = emps[0];
        try {
          const toEt = await call("PUT", "/employees/role", owner.token, { user_id: e.user_id, gym_id: gym.id, employee_type: "employee_trainer" });
          check("owner promotes employee to employee-trainer", toEt.status === 200 && toEt.data.employee_type === "employee_trainer", short(toEt.data));
        } finally {
          const back = await call("PUT", "/employees/role", owner.token, { user_id: e.user_id, gym_id: gym.id, employee_type: "employee" });
          check("and back to employee", back.status === 200 && back.data.employee_type === "employee", short(back.data));
        }
        const memberTry = await call("PUT", "/employees/role", member.token, { user_id: e.user_id, gym_id: gym.id, employee_type: "employee_trainer" });
        check("member can't change staff roles", memberTry.status === 403, `status ${memberTry.status}`);
      } else check("gym has employees to test with", false);
      assertAll();
    });

    await t.step("session: start, log a set, edit, delete, end, delete session", async () => {
      const ex = ((await call("GET", "/exercises?name=press", member.token)).data as any[])[0];
      const s = await call("POST", "/training-sessions", member.token, {});
      check("member starts a free session", s.status === 201 || s.status === 200, short(s.data));
      const sid = s.data.id;
      try {
        const set = await call("POST", `/training-sessions/${sid}/sets`, member.token, { exercise_id: ex.id, position: 0, drops: [{ drop_number: 1, rep_type_actual: "count", rep_count_actual: 8, weight_kg_actual: 60 }] });
        check("log a set with exercise_id", (set.status === 201 || set.status === 200) && set.data.exercise_id === ex.id, short(set.data));
        const edit = await call("PUT", `/training-sessions/sets/${set.data.id}`, member.token, { note: "felt easy", drops: [{ drop_number: 1, rep_type_actual: "count", rep_count_actual: 10, weight_kg_actual: 62.5 }] });
        check("edit the logged set", edit.status === 200 && edit.data.note === "felt easy" && edit.data.drop_logs?.[0]?.rep_count_actual === 10, short(edit.data));
        const trainerEdit = await call("PUT", `/training-sessions/sets/${set.data.id}`, trainer.token, { note: "x" });
        check("trainer can't edit the member's set", trainerEdit.status === 403, `status ${trainerEdit.status}`);
        const trainerRead = await call("GET", `/training-sessions/${sid}`, trainer.token);
        check("trainer can read the member's session", trainerRead.status === 200, `status ${trainerRead.status}`);
        const delSet = await call("DELETE", `/training-sessions/sets/${set.data.id}`, member.token);
        check("delete the logged set", delSet.status === 204, `status ${delSet.status}`);
        const end = await call("POST", `/training-sessions/${sid}/end`, member.token);
        check("end session", end.status === 200 && !!end.data.ended_at, short(end.data));
      } finally {
        if (sid) {
          const delSess = await call("DELETE", `/training-sessions/${sid}`, member.token);
          check("delete session (cleanup)", delSess.status === 204, `status ${delSess.status}`);
        }
      }
      assertAll();
    });

    await t.step("meal plan assignment by a trainer", async () => {
      const plans = (await call("GET", "/meal-plans", trainer.token)).data as any[];
      const plan = plans.find((p) => p.is_public) ?? plans[0];
      const asg = await call("POST", "/meal-plan-assignments", trainer.token, { meal_plan_id: plan.id, user_id: member.profile.id });
      check("trainer assigns a meal plan to their member", asg.status === 201, short(asg.data));
      try {
        const vendor = await signin("ravi.deshmukh@example.com");
        const vAsg = await call("POST", "/meal-plan-assignments", vendor.token, { meal_plan_id: plan.id, user_id: member.profile.id });
        check("unrelated vendor can't assign plans to the member", vAsg.status === 403, `status ${vAsg.status}`);
      } finally {
        const notifs = (await call("GET", "/notifications", member.token)).data;
        const list = (notifs.items ?? notifs.data ?? notifs.notifications ?? notifs) as any[];
        check("member got the assignment notification", Array.isArray(list) && list.some((n) => n.metadata?.assignment_id === asg.data.id), `shape ${Object.keys(notifs).join(",")}`);
        if (asg.data?.id) {
          const del = await call("DELETE", `/meal-plan-assignments/${asg.data.id}`, trainer.token);
          check("remove assignment (cleanup)", del.status === 204, `status ${del.status}`);
          for (const n of (Array.isArray(list) ? list : []).filter((n) => n.metadata?.assignment_id === asg.data.id)) {
            await call("DELETE", `/notifications/${n.id}`, member.token);
          }
        }
      }
      assertAll();
    });

    await t.step("throwaway account: create, change password, logout, delete", async () => {
      const stamp = Date.now();
      const email = `flow-${stamp}@example.com`;
      let deleted = false;
      const created = await call("POST", "/users/signup", superU.token, { email, password: "start123", username: `flow${stamp}`, name: "Flow", last_name: "Test", role: "trainer" });
      check("super user creates an account with a role", created.status === 201 && created.data.user.role === "trainer", short(created.data));
      try {
        const tmp = await signin(email, "start123");
        const badPw = await call("POST", "/users/change-password", tmp.token, { current_password: "wrong", new_password: "next1234" });
        check("change password rejects wrong current password", badPw.status === 400, `status ${badPw.status}`);
        const okPw = await call("POST", "/users/change-password", tmp.token, { current_password: "start123", new_password: "next1234" });
        check("change password", okPw.status === 200, short(okPw.data));
        const tmp2 = await signin(email, "next1234");
        const out = await call("POST", "/users/logout", tmp2.token);
        check("logout", out.status === 204, `status ${out.status}`);
        const refreshAfter = await call("POST", "/users/refresh", undefined, { refresh_token: tmp2.refresh });
        check("refresh token revoked after logout", refreshAfter.status >= 400, `status ${refreshAfter.status}`);
        const tmp3 = await signin(email, "next1234");
        const delMe = await call("DELETE", `/users/${tmp3.profile.id}`, tmp3.token);
        deleted = delMe.status === 204;
        check("user deletes own account", delMe.status === 204, `status ${delMe.status} ${short(delMe.data)}`);
        const gone = await call("POST", "/users/signin", undefined, { email, password: "next1234" });
        check("deleted account can't sign in", gone.status >= 400, `status ${gone.status}`);
      } finally {
        const id = created.data?.user?.id;
        if (!deleted && id) await call("DELETE", `/users/${id}`, superU.token);
      }
      const ownerDel = await call("DELETE", `/users/${owner.profile.id}`, superU.token);
      check("can't delete an account that owns a gym", ownerDel.status === 409, `status ${ownerDel.status}`);
      assertAll();
    });

    await t.step("throwaway business: owner creates then deletes", async () => {
      const stamp = Date.now();
      const biz = await call("POST", "/businesses", owner.token, { name: `Flow Gym ${stamp}`, location: "Test", type: "gym", working_hours_from: "06:00", working_hours_to: "22:00", working_weekdays: [1, 2, 3, 4, 5] });
      check("owner creates a gym", biz.status === 201, short(biz.data));
      const bizId = biz.data.id ?? biz.data.business?.id;
      let deleted = false;
      try {
        await call("POST", "/gym-membership-types", owner.token, { name: "Flow", monthly_cost: 10, gym_id: bizId });
        const memberDelBiz = await call("DELETE", `/businesses/${bizId}`, member.token);
        check("member can't delete the gym", memberDelBiz.status === 403, `status ${memberDelBiz.status}`);
        const delBiz = await call("DELETE", `/businesses/${bizId}`, owner.token);
        deleted = delBiz.status === 204;
        check("owner deletes the gym", delBiz.status === 204, `status ${delBiz.status} ${short(delBiz.data)}`);
      } finally {
        if (!deleted && bizId) await call("DELETE", `/businesses/${bizId}`, owner.token);
      }
      assertAll();
    });
  },
});
