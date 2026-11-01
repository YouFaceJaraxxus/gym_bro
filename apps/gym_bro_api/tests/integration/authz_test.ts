// deno-lint-ignore-file no-explicit-any
// Authorization checks (ported from the authz smoke script). Read-only except
// for no-op writes that restore the original values.
import { ANON, API, call, checker, PW, short, signin, suite } from "./_client.ts";

Deno.test({
  name: "authorization",
  ...suite,
  async fn(t) {
    const { check, assertAll } = checker();

    const member = await signin("liam.oconnor@example.com");
    const owner = await signin("marcus.bennett@example.com");
    const trainer = await signin("elena.vasquez@example.com");

    const ownerBiz = await call("GET", "/businesses", owner.token);
    const gym = (ownerBiz.data as any[]).find((b) => b.has_gym);
    check("owner lists own businesses", ownerBiz.status === 200 && !!gym, `status ${ownerBiz.status}`);
    assertAll();

    await t.step("1. account takeover via signup", async () => {
      const takeover = await call("POST", "/users/signup", undefined, {
        email: "marcus.bennett@example.com", password: "hacked123", username: "x", name: "x", last_name: "x",
      });
      check("signup with an existing email is refused", takeover.status === 409 && !takeover.data.access_token, `status ${takeover.status} code ${takeover.data?.code}`);
      const stillWorks = await call("POST", "/users/signin", undefined, { email: "marcus.bennett@example.com", password: PW });
      check("victim's password unchanged", stillWorks.status === 200);
      assertAll();
    });

    await t.step("2. self-assigned super user", async () => {
      const stamp = Date.now();
      const selfRole = await call("POST", "/users/signup", undefined, {
        email: `smoke-${stamp}@example.com`, password: "secret123", username: `smoke${stamp}`, name: "S", last_name: "T",
        role: "super_user", is_super_user: true, is_trainer: true,
      });
      try {
        check(
          "signup ignores role / is_super_user / is_trainer",
          selfRole.status === 201 && selfRole.data.user?.is_super_user === false && selfRole.data.user?.is_trainer === false,
          `status ${selfRole.status} ${short(selfRole.data?.user)}`,
        );
      } finally {
        if (selfRole.data?.user?.id) {
          const superU = await signin("chloe.anderson@example.com");
          await call("DELETE", `/users/${selfRole.data.user.id}`, superU.token);
        }
      }
      const putOther = await call("PUT", `/users/${owner.profile.id}`, member.token, { name: "pwned" });
      check("member can't edit another user", putOther.status === 403, `status ${putOther.status}`);
      const putRole = await call("PUT", `/users/${member.profile.id}`, member.token, { is_super_user: true });
      check("member can't make themselves a super user", putRole.status === 403, `status ${putRole.status}`);
      const putTrainer = await call("PUT", `/users/${member.profile.id}`, member.token, { is_trainer: true });
      check("is_trainer isn't set through PUT /users/:id", putTrainer.status === 403, `status ${putTrainer.status}`);
      const putSelf = await call("PUT", `/users/${member.profile.id}`, member.token, { name: member.profile.name });
      check("member can edit own name", putSelf.status === 200, `status ${putSelf.status}`);
      const delOther = await call("DELETE", `/users/${owner.profile.id}`, member.token);
      check("member can't delete another user", delOther.status === 403, `status ${delOther.status}`);
      assertAll();
    });

    await t.step("3. direct REST access with the anon key", async () => {
      const rest = await fetch(`${API}/rest/v1/users?select=email&limit=1`, { headers: { apikey: ANON, Authorization: `Bearer ${ANON}` } });
      const restBody = await rest.text();
      check("REST /rest/v1/users is closed", rest.status >= 400 || restBody === "[]", `status ${rest.status} ${restBody.slice(0, 80)}`);
      const restMember = await fetch(`${API}/rest/v1/membership_invoice?select=*&limit=1`, { headers: { apikey: ANON, Authorization: `Bearer ${member.token}` } });
      const restMemberBody = await restMember.text();
      check("REST closed for signed-in users too", restMember.status >= 400 || restMemberBody === "[]", `status ${restMember.status} ${restMemberBody.slice(0, 80)}`);
      assertAll();
    });

    await t.step("4. ownership checks", async () => {
      const bizPut = await call("PUT", `/businesses/${gym.id}`, member.token, { name: "pwned gym" });
      check("member can't edit a gym", bizPut.status === 403, `status ${bizPut.status}`);
      for (const role of ["owner", "staff", "trainer"]) {
        const grant = await call("POST", `/businesses/${gym.id}/team`, member.token, { user_id: member.profile.id, role });
        check(`member can't add themselves to the team as ${role}`, grant.status === 403, `status ${grant.status}`);
      }
      const empAdd = await call("POST", `/businesses/${gym.id}/team`, trainer.token, { user_id: member.profile.id, role: "staff" });
      check("a trainer can't invite staff", empAdd.status === 403, `status ${empAdd.status}`);
      const selfAccept = await call("POST", `/businesses/${gym.id}/invites/owner/accept`, member.token);
      check("accepting an invite nobody sent is 404", selfAccept.status === 404, `status ${selfAccept.status}`);
      const review = await call("POST", `/businesses/${gym.id}/review`, owner.token, { status: "blocked", note: "x" });
      check("an owner can't review businesses", review.status === 403, `status ${review.status}`);
      const types = await call("GET", `/gym-membership-types?gym_id=${gym.id}`, owner.token);
      const typeId = (types.data as any[])?.[0]?.id;
      if (typeId) {
        const typePut = await call("PUT", `/gym-membership-types/${typeId}`, member.token, { monthly_cost: 0 });
        check("member can't change membership prices", typePut.status === 403, `status ${typePut.status}`);
      }
      const forged = await call("POST", "/notifications", member.token, {
        user_id: member.profile.id, type: "business_invite", title: "x", body: "x",
        metadata: { invite_status: "pending", business_id: gym.id, role: "owner" },
      });
      check("member can't create notifications", forged.status === 403, `status ${forged.status}`);
      const othersNotifs = await call("GET", `/notifications?user_id=${owner.profile.id}`, member.token);
      const leaked = JSON.stringify(othersNotifs.data).includes(owner.profile.id);
      check("member can't read the owner's notifications", !leaked, `status ${othersNotifs.status}`);
      assertAll();
    });

    await t.step("5. owner still works", async () => {
      const ownPut = await call("PUT", `/businesses/${gym.id}`, owner.token, { name: gym.name });
      check("owner can edit own gym", ownPut.status === 200, `status ${ownPut.status} ${JSON.stringify(ownPut.data).slice(0, 120)}`);
      const stats = await call("GET", "/businesses/stats", owner.token);
      check("owner stats endpoint", stats.status === 200 && typeof stats.data.members_total === "number", `status ${stats.status} ${JSON.stringify(stats.data).slice(0, 160)}`);
      const invoices = await call("GET", `/membership-invoices?gym_id=${gym.id}`, owner.token);
      check("owner lists gym invoices with status", invoices.status === 200 && (invoices.data as any[]).every((i) => "status" in i), `status ${invoices.status} n=${(invoices.data as any[])?.length}`);
      assertAll();
    });

    await t.step("6. previously broken features", async () => {
      const search = await call("GET", "/exercises?name=press", member.token);
      check("exercise name search", search.status === 200 && Array.isArray(search.data), `status ${search.status} n=${(search.data as any[])?.length}`);
      const muscle = await call("GET", "/exercises?muscle=chest_all", member.token);
      check("exercise muscle filter", muscle.status === 200 && Array.isArray(muscle.data), `status ${muscle.status} n=${(muscle.data as any[])?.length}`);
      const priv = await call("GET", "/exercises?is_public=false", member.token);
      check("private exercises are only the caller's", priv.status === 200 && (priv.data as any[]).every((e) => e.author_id === member.profile.id), `n=${(priv.data as any[])?.length}`);

      const mySessions = await call("GET", "/training-sessions", member.token);
      const sess = (mySessions.data as any[])?.[0];
      check("member lists own sessions", mySessions.status === 200 && !!sess, `status ${mySessions.status}`);
      if (sess) {
        const coachRead = await call("GET", `/training-sessions?user_id=${member.profile.id}`, trainer.token);
        check("trainer at member's gym can list their sessions", coachRead.status === 200, `status ${coachRead.status} ${JSON.stringify(coachRead.data).slice(0, 100)}`);
        const vendor = await signin("ravi.deshmukh@example.com");
        const strangerRead = await call("GET", `/training-sessions/${sess.id}`, vendor.token);
        check("unrelated vendor can't read the session", strangerRead.status === 403 || strangerRead.status === 404, `status ${strangerRead.status}`);
      }

      const assignAll = await call("GET", "/meal-plan-assignments", member.token);
      const foreign = (assignAll.data as any[] ?? []).filter((a) => a.user_id !== member.profile.id && a.assigned_by_id !== member.profile.id);
      check("meal plan assignments are scoped", assignAll.status === 200 && foreign.length === 0, `status ${assignAll.status} foreign=${foreign.length}`);

      const plans = await call("GET", "/meal-plans", member.token);
      check("meal plans list", plans.status === 200 && Array.isArray(plans.data), `status ${plans.status} n=${(plans.data as any[])?.length}`);
      assertAll();
    });

    await t.step("7. user directory privacy", async () => {
      const list = await call("GET", "/users", member.token);
      check("member can't list users", list.status === 403, `status ${list.status}`);
      const search = await call("GET", "/search-users?q=a", member.token);
      check("member can't search users", search.status === 403, `status ${search.status}`);
      const byEmailMember = await call("GET", `/users?email=${encodeURIComponent(owner.profile.email)}`, member.token);
      check("member can't look users up by email", byEmailMember.status === 403, `status ${byEmailMember.status}`);

      const byEmail = await call("GET", `/users?email=${encodeURIComponent(member.profile.email)}`, owner.token);
      check(
        "owner can look up a user by email",
        byEmail.status === 200 && (byEmail.data as any[]).length === 1 && byEmail.data[0].id === member.profile.id,
        `status ${byEmail.status} ${short(byEmail.data)}`,
      );
      const ownerSearch = await call("GET", "/search-users?q=a", owner.token);
      check("owner can search users", ownerSearch.status === 200 && Array.isArray(ownerSearch.data), `status ${ownerSearch.status}`);

      const other = await call("GET", `/users/${owner.profile.id}`, member.token);
      check(
        "member reading another user by id gets no email",
        other.status === 200 && other.data.id === owner.profile.id && !("email" in other.data) && !("auth_id" in other.data),
        `status ${other.status} ${short(other.data)}`,
      );
      const self = await call("GET", `/users/${member.profile.id}`, member.token);
      check("user reading themself gets their email", self.status === 200 && self.data.email === member.profile.email, `status ${self.status}`);

      const members = await call("GET", `/members?gym_id=${gym.id}`, member.token);
      const leaked = (members.data as any[] ?? []).filter((m) => m.user_id !== member.profile.id && "email" in m);
      check("member list hides other members' emails from members", members.status === 200 && leaked.length === 0, `status ${members.status} leaked=${leaked.length}`);
      const staffView = await call("GET", `/members?gym_id=${gym.id}`, owner.token);
      check(
        "owner's member list embeds names and emails",
        staffView.status === 200 && (staffView.data as any[]).every((m) => typeof m.name === "string" && typeof m.email === "string"),
        `status ${staffView.status} ${short((staffView.data as any[])?.[0])}`,
      );
      assertAll();
    });
  },
});
