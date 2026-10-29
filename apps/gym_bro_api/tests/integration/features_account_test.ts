// deno-lint-ignore-file no-explicit-any
// Settings, push device registration, scheduled jobs, super-user
// impersonation, and the user directory (lookups, profile reads/edits).
// Seeded users' emails and passwords are never changed; settings and the one
// edited display name are restored and test device tokens / audit rows removed.
// (Sign-up, invites, sessions and account deletion: auth_flows_test.ts.)
import { ANON, call, checker, FN, seededUsers, short, suite } from "./_client.ts";
import { sql } from "./_db.ts";

Deno.test({
  name: "features: settings, devices, jobs, impersonation, user directory",
  ...suite,
  async fn(t) {
    const { check, assertAll } = checker();
    const { member, owner, trainer, employee, superU, vendor } = await seededUsers();
    const stamp = Date.now();

    await t.step("10. settings, devices, jobs, impersonation", async () => {
      // ── Settings ──
      const original = await call("GET", "/users/me/settings", member.token);
      check(
        "member reads settings",
        original.status === 200 && typeof original.data.push_enabled === "boolean" && Array.isArray(original.data.muted_types) &&
          ["kg", "lb"].includes(original.data.weight_unit),
        short(original.data),
      );
      try {
        const put = await call("PUT", "/users/me/settings", member.token, {
          weight_unit: "lb", muted_types: ["news", "news", "events"], theme_mode: "dark", locale: "pt-BR", push_enabled: false,
        });
        check(
          "member updates settings (muted types de-duplicated)",
          put.status === 200 && put.data.weight_unit === "lb" && put.data.theme_mode === "dark" && put.data.locale === "pt-BR" &&
            put.data.push_enabled === false && put.data.muted_types.length === 2 && !!put.data.updated_at,
          short(put.data),
        );
        const partial = await call("PUT", "/users/me/settings", member.token, { theme_mode: "light" });
        check("partial update keeps other fields", partial.status === 200 && partial.data.theme_mode === "light" && partial.data.weight_unit === "lb", short(partial.data));
        const other = await call("GET", "/users/me/settings", trainer.token);
        check("settings are per user", other.status === 200 && !(other.data.theme_mode === "light" && other.data.weight_unit === "lb"), short(other.data));

        for (
          const [name, body] of [
            ["unknown key", { favourite_colour: "red" }],
            ["bad weight_unit", { weight_unit: "stone" }],
            ["bad theme_mode", { theme_mode: "neon" }],
            ["bad muted type", { muted_types: ["bogus"] }],
            ["muted_types not an array", { muted_types: "news" }],
            ["push_enabled not boolean", { push_enabled: "yes" }],
            ["bad locale", { locale: "English (US)" }],
            ["empty body", {}],
          ] as const
        ) {
          const r = await call("PUT", "/users/me/settings", member.token, body);
          check(`settings reject ${name}`, r.status === 400, `status ${r.status} ${short(r.data)}`);
        }
        const arr = await call("PUT", "/users/me/settings", member.token, [1, 2]);
        check("settings reject an array body", arr.status === 400, `status ${arr.status}`);
        const anon = await call("GET", "/users/me/settings");
        check("settings need a signed-in user", anon.status === 401, `status ${anon.status}`);
      } finally {
        if (original.data?.updated_at === null) {
          // The member had defaults only: drop the row we created.
          await sql(`DELETE FROM user_settings WHERE user_id = $1`, [member.profile.id]);
        } else if (original.status === 200) {
          const { push_enabled, muted_types, weight_unit, theme_mode, locale } = original.data;
          await call("PUT", "/users/me/settings", member.token, { push_enabled, muted_types, weight_unit, theme_mode, locale });
        }
      }

      // ── Devices ──
      const token = `test-fcm-token-${stamp}`;
      try {
        const reg = await call("POST", "/devices", member.token, { token, platform: "ios" });
        check("member registers a device", reg.status === 200 && reg.data.token === token && reg.data.platform === "ios", short(reg.data));
        const again = await call("POST", "/devices", member.token, { token, platform: "android" });
        check("re-registering updates the same row", again.status === 200 && again.data.id === reg.data.id && again.data.platform === "android", short(again.data));
        const badPlatform = await call("POST", "/devices", member.token, { token, platform: "symbian" });
        check("unknown platform is 400", badPlatform.status === 400, `status ${badPlatform.status}`);
        const noToken = await call("POST", "/devices", member.token, { platform: "ios" });
        check("missing token is 400", noToken.status === 400, `status ${noToken.status}`);

        // Another account signing in on the same phone takes the token over.
        const moved = await call("POST", "/devices", trainer.token, { token, platform: "ios" });
        check("token moves to the account that registers it last", moved.status === 200 && moved.data.id === reg.data.id, short(moved.data));
        const memberUnreg = await call("DELETE", "/devices", member.token, { token });
        check("unregister is 204 even for a token you no longer own", memberUnreg.status === 204, `status ${memberUnreg.status}`);
        const owner = await sql<{ user_id: string }>(`SELECT user_id FROM device_token WHERE token = $1`, [token]);
        if (owner) check("someone else can't unregister the token", owner[0]?.user_id === trainer.profile.id, short(owner));
        const unreg = await call("DELETE", "/devices", trainer.token, { token });
        check("owner unregisters the device", unreg.status === 204, `status ${unreg.status}`);
        const gone = await sql(`SELECT 1 FROM device_token WHERE token = $1`, [token]);
        if (gone) check("token row is gone", gone.length === 0, `n=${gone.length}`);
        const noBody = await call("DELETE", "/devices", member.token, {});
        check("unregister without a token is 400", noBody.status === 400, `status ${noBody.status}`);
        const anonReg = await call("POST", "/devices", undefined, { token, platform: "ios" });
        check("registering needs a signed-in user", anonReg.status === 401, `status ${anonReg.status}`);
      } finally {
        await sql(`DELETE FROM device_token WHERE token = $1`, [token]);
      }

      // ── Scheduled jobs ──
      const jobs = await fetch(`${FN}/jobs/run`, { method: "POST", headers: { apikey: ANON, "x-cron-secret": "guess" } });
      const jobsBody = await jobs.json().catch(() => null);
      check("/jobs/run without CRON_SECRET is 503 not_configured", jobs.status === 503 && jobsBody?.code === "not_configured", `status ${jobs.status} ${short(jobsBody)}`);
      const jobsGet = await call("GET", "/jobs/run");
      check("GET /jobs/run is 404", jobsGet.status === 404, `status ${jobsGet.status}`);

      // ── Impersonation ──
      const startedAt = new Date(Date.now() - 5_000).toISOString();
      try {
        const imp = await call("POST", "/users/impersonate", superU.token, { user_id: member.profile.id });
        check(
          "super user impersonates a member",
          imp.status === 200 && typeof imp.data.access_token === "string" && imp.data.profile?.id === member.profile.id,
          short({ ...imp.data, access_token: imp.data?.access_token ? "…" : undefined, refresh_token: undefined }),
        );
        if (imp.status === 200) {
          const me = await call("GET", "/users/me", imp.data.access_token);
          check("impersonated session acts as the member", me.status === 200 && (me.data.id ?? me.data.profile?.id) === member.profile.id, short(me.data));
          const out = await call("POST", "/users/logout", imp.data.access_token);
          check("impersonated session logs out", out.status === 204, `status ${out.status}`);
          const stillMember = await call("GET", "/users/me/settings", member.token);
          check("the member's own session survives", stillMember.status === 200, `status ${stillMember.status}`);
        }
        const audit = await sql<{ n: number }>(
          `SELECT COUNT(*)::int AS n FROM admin_audit_log WHERE actor_id = $1 AND target_user_id = $2 AND action = 'impersonate' AND created_at >= $3`,
          [superU.profile.id, member.profile.id, startedAt],
        );
        if (audit) check("impersonation is audit-logged", audit[0]?.n === 1, short(audit));

        const memberImp = await call("POST", "/users/impersonate", member.token, { user_id: trainer.profile.id });
        check("member can't impersonate", memberImp.status === 403 && !memberImp.data.access_token, `status ${memberImp.status}`);
        const superImp = await call("POST", "/users/impersonate", superU.token, { user_id: superU.profile.id });
        check("super user can't impersonate a super user", superImp.status === 403 && !superImp.data.access_token, `status ${superImp.status}`);
        const unknown = await call("POST", "/users/impersonate", superU.token, { user_id: crypto.randomUUID() });
        check("impersonating an unknown user is 404", unknown.status === 404, `status ${unknown.status}`);
        const malformed = await call("POST", "/users/impersonate", superU.token, { user_id: "nope" });
        check("impersonating a malformed id is 404", malformed.status === 404, `status ${malformed.status}`);
        const missing = await call("POST", "/users/impersonate", superU.token, {});
        check("impersonate without user_id is 400", missing.status === 400, `status ${missing.status}`);
      } finally {
        await sql(
          `DELETE FROM admin_audit_log WHERE actor_id = $1 AND action = 'impersonate' AND created_at >= $2`,
          [superU.profile.id, startedAt],
        );
      }
      assertAll();
    });

    await t.step("11. user directory: lookups, profile reads and edits, unknown routes", async () => {
      const all = await call("GET", "/users", superU.token);
      check(
        "super user lists every user (full columns)",
        all.status === 200 && (all.data as any[]).some((u) => u.id === member.profile.id && u.email === member.profile.email && "auth_id" in u),
        `status ${all.status} n=${(all.data as any[])?.length}`,
      );
      const upper = await call("GET", `/users?email=${encodeURIComponent(member.profile.email.toUpperCase())}`, employee.token);
      const hit = (upper.data as any[])?.[0];
      check(
        "staff email lookup ignores case and returns public columns + email",
        upper.status === 200 && (upper.data as any[]).length === 1 && hit.id === member.profile.id && hit.email === member.profile.email && !("auth_id" in hit),
        `status ${upper.status} ${short(upper.data)}`,
      );
      const superLookup = await call("GET", `/users?email=${encodeURIComponent(member.profile.email)}`, superU.token);
      check("super user lookup includes auth_id", superLookup.status === 200 && !!superLookup.data?.[0]?.auth_id, short(superLookup.data));
      const vendorLookup = await call("GET", `/users?email=${encodeURIComponent(member.profile.email)}`, vendor.token);
      check("shop vendors (shop staff) may look users up by email", vendorLookup.status === 200 && vendorLookup.data?.[0]?.id === member.profile.id, `status ${vendorLookup.status}`);
      const none = await call("GET", `/users?email=it-nobody-${stamp}@example.com`, owner.token);
      check("lookup of an unknown email is []", none.status === 200 && (none.data as any[]).length === 0, short(none.data));

      const staffRead = await call("GET", `/users/${member.profile.id}`, employee.token);
      check("gym staff reading their member gets the email", staffRead.status === 200 && staffRead.data.email === member.profile.email, short(staffRead.data));
      const coachRead = await call("GET", `/users/${member.profile.id}`, trainer.token);
      check("a trainer (not front-desk staff) gets the public profile only", coachRead.status === 200 && !("email" in coachRead.data), short(coachRead.data));
      const unknown = await call("GET", `/users/${crypto.randomUUID()}`, member.token);
      check("unknown user id is 404", unknown.status === 404, `status ${unknown.status}`);
      const malformed = await call("GET", "/users/not-a-uuid", member.token);
      check("malformed user id is 404", malformed.status === 404, `status ${malformed.status}`);

      const empty = await call("PUT", `/users/${member.profile.id}`, member.token, {});
      check("profile PUT with an empty body is 400", empty.status === 400, `status ${empty.status}`);
      const onlyIgnored = await call("PUT", `/users/${member.profile.id}`, member.token, { id: member.profile.id, created_at: "x" });
      check("profile PUT with only read-only keys is 400 nothing to update", onlyIgnored.status === 400, `status ${onlyIgnored.status}`);
      const ownEmail = await call("PUT", `/users/${member.profile.id}`, member.token, { email: `it-${stamp}@example.com` });
      check("users can't change their own email through PUT", ownEmail.status === 403, `status ${ownEmail.status}`);
      const takenName = await call("PUT", `/users/${member.profile.id}`, member.token, { username: owner.profile.username });
      check("taking someone else's username is 409", takenName.status === 409, `status ${takenName.status}`);
      const badRole = await call("PUT", `/users/${member.profile.id}`, superU.token, { role: "wizard" });
      check("super user setting an unknown role is 400", badRole.status === 400, `status ${badRole.status}`);
      const ghost = await call("PUT", `/users/${crypto.randomUUID()}`, superU.token, { name: "x" });
      check("super user editing an unknown user is 404", ghost.status === 404, `status ${ghost.status}`);
      try {
        const edit = await call("PUT", `/users/${member.profile.id}`, superU.token, { name: `It${stamp}` });
        check("super user edits someone's display name", edit.status === 200 && edit.data.name === `It${stamp}` && edit.data.email === member.profile.email, short(edit.data));
        const seen = await call("GET", `/users/${member.profile.id}`, trainer.token);
        check("the edit is visible to others", seen.data?.name === `It${stamp}`, short(seen.data));
      } finally {
        const restore = await call("PUT", `/users/${member.profile.id}`, superU.token, { name: member.profile.name });
        check("display name restored", restore.status === 200 && restore.data.name === member.profile.name, `status ${restore.status}`);
      }

      const patch = await call("PATCH", "/users/me", member.token, {});
      check("unknown /users route is 404", patch.status === 404, `status ${patch.status}`);
      const anonMe = await call("GET", "/users/me");
      check("GET /users/me needs a session", anonMe.status === 401, `status ${anonMe.status}`);
      const jobsOther = await call("POST", "/jobs/other");
      check("unknown /jobs route is 404", jobsOther.status === 404, `status ${jobsOther.status}`);
      assertAll();
    });
  },
});
