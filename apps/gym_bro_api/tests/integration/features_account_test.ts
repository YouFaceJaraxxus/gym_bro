// Settings, push device registration, scheduled jobs and super-user
// impersonation. Seeded users' emails and passwords are never changed;
// settings are restored and test device tokens / audit rows removed.
import { ANON, call, checker, FN, seededUsers, short, suite } from "./_client.ts";
import { sql } from "./_db.ts";

Deno.test({
  name: "features: settings, devices, jobs, impersonation",
  ...suite,
  async fn(t) {
    const { check, assertAll } = checker();
    const { member, trainer, superU } = await seededUsers();
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
  },
});
