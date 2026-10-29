// deno-lint-ignore-file no-explicit-any
// End-to-end auth flows, driven through the API and the local Mailpit inbox
// the way the app does it: self sign-up (+ confirmation), password recovery
// via the emailed link, refresh/logout/change-password, email change, gym /
// shop invites activated with the 6-digit code (members, employees, vendors),
// staff invites to existing users accepted/declined through notifications,
// the notifications inbox, per-account data (settings, devices, uploads),
// impersonation, Google sign-in and account deletion.
//
// Every account it creates is a throwaway (it-…@example.com) and is deleted at
// the end through the API (super user), with a DB fallback for auth users left
// without a profile. Notifications other users got about those accounts,
// impersonation audit rows and uploaded objects are removed via SQL.
// Needs Mailpit (MAILPIT_URL, defaults to the local stack's on :54324).
import { ANON, API, call, checker, FN, seededUsers, short, suite } from "./_client.ts";
import { deleteNotificationsWhere, sql } from "./_db.ts";

const LOCAL = /^https?:\/\/(127\.0\.0\.1|localhost):54321$/.test(API);
const MAILPIT = Deno.env.get("MAILPIT_URL")?.replace(/\/$/, "") ?? (LOCAL ? "http://127.0.0.1:54324" : "");
const PEAK = "Peak Performance Supply Co.";

type Mail = { id: string; subject: string; text: string };

/** Emails Mailpit captured for `to`, newest first. */
async function inbox(to: string): Promise<Mail[]> {
  const res = await fetch(`${MAILPIT}/api/v1/search?query=${encodeURIComponent(`to:${to}`)}`);
  const list = await res.json();
  const out: Mail[] = [];
  for (const m of list.messages ?? []) {
    const full = await (await fetch(`${MAILPIT}/api/v1/message/${m.ID}`)).json();
    out.push({ id: m.ID, subject: full.Subject ?? "", text: full.Text ?? "" });
  }
  return out;
}

/** Waits until `to` has at least `count` emails (or `timeoutMs` passes); newest first. */
async function waitForMail(to: string, count = 1, timeoutMs = 8_000): Promise<Mail[]> {
  const until = Date.now() + timeoutMs;
  let mails = await inbox(to);
  while (mails.length < count && Date.now() < until) {
    await sleep(250);
    mails = await inbox(to);
  }
  return mails;
}

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));
/** The 6-digit code in an auth email ("Alternatively, enter the code: 123456"). */
const codeIn = (m?: Mail) => m?.text.match(/enter the code:\s*(\d{6})/)?.[1] ?? null;
/** The verify link in an auth email. */
const linkIn = (m?: Mail) => m?.text.match(/\(\s*(https?:\/\/\S+\/auth\/v1\/verify\?\S+)\s*\)/)?.[1] ?? null;

/**
 * Opens an auth email link like a browser would and returns the params of the
 * fragment it redirects to (what the app's deep link handler reads:
 * access_token, refresh_token, type — or error_code). Only local links.
 */
async function followLink(link: string | null): Promise<URLSearchParams | null> {
  if (!link || !link.startsWith(`${API}/auth/v1/verify?`)) return null;
  const res = await fetch(link, { redirect: "manual" });
  await res.body?.cancel();
  const location = res.headers.get("location");
  if (!location) return null;
  const url = new URL(location);
  return new URLSearchParams(url.hash ? url.hash.slice(1) : url.search.slice(1));
}

/** Uploads a file to /uploads as multipart form data. */
async function upload(token: string | undefined, fields: Record<string, string | Blob>): Promise<{ status: number; data: any }> {
  const form = new FormData();
  for (const [k, v] of Object.entries(fields)) form.append(k, v);
  const res = await fetch(`${FN}/uploads`, {
    method: "POST",
    headers: { apikey: ANON, Authorization: `Bearer ${token ?? ANON}` },
    body: form,
  });
  const text = await res.text();
  let data: any = text;
  try {
    data = JSON.parse(text);
  } catch { /* not JSON */ }
  return { status: res.status, data };
}

// A 1×1 PNG.
const PNG = Uint8Array.from(
  atob("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="),
  (c) => c.charCodeAt(0),
);

const signinRaw = (email: string, password: string) => call("POST", "/users/signin", undefined, { email, password });

Deno.test({
  name: "auth flows: signup, recovery, sessions, email change, invites, notifications, deletion",
  ...suite,
  ignore: suite.ignore || !MAILPIT,
  async fn(t) {
    const { check, assertAll } = checker();
    const { member, owner, trainer, employee, superU, vendor, gym } = await seededUsers();
    const shop = ((await call("GET", "/businesses", owner.token)).data as any[]).find((b) => b.type === "shop" && b.name === PEAK);
    const tag = crypto.randomUUID().slice(0, 8);

    // The self-signup account ("S") carried through most steps.
    const sEmail = `it-signup-${tag}@example.com`;
    const sNewEmail = `it-signup-new-${tag}@example.com`;
    const sProfile = { username: `it_signup_${tag}`, name: "Ivy", last_name: `Signup${tag}` };
    let sId: string | undefined;
    let sToken: string | undefined; // a live session for S
    let sPassword = "Start-123";
    // Invited accounts: member, employee, shop vendor.
    const mEmail = `it-invite-m-${tag}@example.com`;
    const eEmail = `it-invite-e-${tag}@example.com`;
    const vEmail = `it-invite-v-${tag}@example.com`;
    const ids: Record<string, string | undefined> = {};
    const createdIds = new Set<string>(); // every account created, for cleanup
    let mToken: string | undefined;
    const allEmails = [sEmail, sNewEmail, mEmail, eEmail, vEmail, `it-dupname-${tag}@example.com`, `it-badinv-${tag}@example.com`];
    const startedAt = new Date(Date.now() - 5_000).toISOString();
    const uploadedPaths: string[] = [];
    const deviceToken = `it-fcm-${tag}`;

    try {
      await t.step("1. self sign-up: validation, create, confirm, duplicates", async () => {
        const full = { email: sEmail, password: sPassword, ...sProfile };
        for (const field of ["email", "password", "username", "name", "last_name"] as const) {
          const { [field]: _omit, ...rest } = full;
          const r = await call("POST", "/users/signup", undefined, rest);
          check(`signup without ${field} is 400`, r.status === 400, `status ${r.status} ${short(r.data)}`);
        }
        const weak = await call("POST", "/users/signup", undefined, { ...full, password: "12345" });
        check("signup with a 5-char password is 400", weak.status === 400, `status ${weak.status}`);
        const badEmail = await call("POST", "/users/signup", undefined, { ...full, email: `not-an-email-${tag}` });
        check("signup with an invalid email is 400", badEmail.status === 400, `status ${badEmail.status} ${short(badEmail.data)}`);
        const badRole = await call("POST", "/users/signup", superU.token, { ...full, role: "wizard" });
        check("super user signup with an unknown role is 400", badRole.status === 400, `status ${badRole.status}`);

        const created = await call("POST", "/users/signup", undefined, full);
        sId = created.data?.user?.id;
        if (sId) createdIds.add(sId);
        const u = created.data?.user ?? {};
        check(
          "anonymous signup creates the account (201, profile echoes the fields, default role member, no session)",
          created.status === 201 && u.email === sEmail && u.username === sProfile.username && u.name === sProfile.name &&
            u.last_name === sProfile.last_name && u.role === "member" && !!u.auth_id && created.data.role_assignment === null &&
            !created.data.access_token,
          short(created.data),
        );

        // The app sends people to "check your email" after signing up.
        const mails = await waitForMail(sEmail, 1, 4_000);
        check("signup sends a confirmation email", mails.length >= 1, `mails=${mails.map((m) => m.subject).join(",")}`);
        if (mails.length >= 1) {
          const confirmed = await followLink(linkIn(mails[0]));
          check("confirmation link opens a session", !!confirmed?.get("access_token"), confirmed?.toString().slice(0, 120) ?? "no link");
        }
        const first = await signinRaw(sEmail, sPassword);
        check("the confirmed account can sign in", first.status === 200, `status ${first.status} ${short(first.data)}`);
        if (first.status === 200) sToken = first.data.access_token;

        const dupEmail = await call("POST", "/users/signup", undefined, { ...full, username: `${sProfile.username}_2` });
        check("signup with a taken email is 409 email_taken", dupEmail.status === 409 && dupEmail.data.code === "email_taken", `status ${dupEmail.status} ${short(dupEmail.data)}`);
        const dupCase = await call("POST", "/users/signup", undefined, { ...full, email: sEmail.toUpperCase(), username: `${sProfile.username}_3` });
        check("email match ignores case (409 email_taken)", dupCase.status === 409 && dupCase.data.code === "email_taken", `status ${dupCase.status} ${short(dupCase.data)}`);

        const dupNameEmail = `it-dupname-${tag}@example.com`;
        const dupName = await call("POST", "/users/signup", undefined, { ...full, email: dupNameEmail, username: member.profile.username });
        check("signup with a taken username is 409 username_taken", dupName.status === 409 && dupName.data.code === "username_taken", `status ${dupName.status} ${short(dupName.data)}`);
        const orphan = await sql(`SELECT 1 FROM auth.users WHERE email = $1`, [dupNameEmail]);
        if (orphan) check("the refused signup leaves no auth user behind", orphan.length === 0, `n=${orphan.length}`);
        assertAll();
      });

      await t.step("2. password recovery: forgot-password email → link → reset-password → sign in", async () => {
        const missing = await call("POST", "/users/forgot-password", undefined, {});
        check("forgot-password without email is 400", missing.status === 400, `status ${missing.status}`);
        const ghost = `it-ghost-${tag}@example.com`;
        const unknown = await call("POST", "/users/forgot-password", undefined, { email: ghost });
        check("forgot-password for an unknown email still answers 200", unknown.status === 200 && unknown.data.success === true, `status ${unknown.status}`);

        const before = (await inbox(sEmail)).length;
        const sent = await call("POST", "/users/forgot-password", undefined, { email: sEmail });
        check("forgot-password for the account is 200", sent.status === 200 && sent.data.success === true, short(sent.data));
        const mails = await waitForMail(sEmail, before + 1);
        const recovery = mails.find((m) => /reset/i.test(m.subject));
        check("a recovery email arrives with a link and a code", !!recovery && !!linkIn(recovery) && !!codeIn(recovery), `subjects=${mails.map((m) => m.subject).join(",")}`);
        check("nothing is sent to an unknown address", (await inbox(ghost)).length === 0);

        const params = await followLink(linkIn(recovery));
        const recoveryToken = params?.get("access_token") ?? undefined;
        check("the recovery link signs in with type=recovery", !!recoveryToken && params?.get("type") === "recovery", params?.toString().slice(0, 120) ?? "no redirect");
        const reused = await followLink(linkIn(recovery));
        check("the recovery link works only once", !!reused && !reused.get("access_token") && !!reused.get("error_code"), reused?.toString().slice(0, 120) ?? "no redirect");

        const anonReset = await call("POST", "/users/reset-password", undefined, { password: "Reset-456" });
        check("reset-password needs a session", anonReset.status === 401, `status ${anonReset.status}`);
        const noPw = await call("POST", "/users/reset-password", recoveryToken, {});
        check("reset-password without a password is 400", noPw.status === 400, `status ${noPw.status}`);
        const shortPw = await call("POST", "/users/reset-password", recoveryToken, { password: "12345" });
        check("reset-password with a short password is 400", shortPw.status === 400, `status ${shortPw.status}`);
        const reset = await call("POST", "/users/reset-password", recoveryToken, { password: "Reset-456" });
        check("reset-password with the recovery session is 200", reset.status === 200 && reset.data.success === true, `status ${reset.status} ${short(reset.data)}`);
        if (reset.status === 200) sPassword = "Reset-456";
        // The app keeps using the recovery session after the reset (reset_password_page → /home).
        const stillIn = await call("GET", "/users/me", recoveryToken);
        check("the recovery session still works after the reset", stillIn.status === 200, `status ${stillIn.status} ${short(stillIn.data)}`);

        const signedIn = await signinRaw(sEmail, sPassword);
        const p = signedIn.data?.profile ?? {};
        check(
          "sign in with the new password: profile matches what was signed up with",
          signedIn.status === 200 && !!signedIn.data.access_token && !!signedIn.data.refresh_token && p.id === sId && p.email === sEmail &&
            p.username === sProfile.username && p.name === sProfile.name && p.last_name === sProfile.last_name && p.role === "member",
          `status ${signedIn.status} ${short(p)}`,
        );
        if (signedIn.status === 200) sToken = signedIn.data.access_token;
        const oldPw = await signinRaw(sEmail, "Start-123");
        check("the signup password no longer works (wrong password is 400)", oldPw.status === 400 && !oldPw.data.access_token, `status ${oldPw.status} ${short(oldPw.data)}`);
        const noPwSignin = await call("POST", "/users/signin", undefined, { email: sEmail });
        check("signin without a password is 400", noPwSignin.status === 400, `status ${noPwSignin.status}`);
        assertAll();
      });

      await t.step("3. sessions: whoami, refresh rotation, logout revokes, change password", async () => {
        if (!sToken) throw new Error("no session for the signup account (step 2 failed)");
        const anonTest = await call("GET", "/users/test");
        check("GET /users/test without a session is 404", anonTest.status === 404, `status ${anonTest.status}`);
        const whoami = await call("GET", "/users/test", sToken);
        check("GET /users/test returns the profile", whoami.status === 200 && whoami.data.authenticated === true && whoami.data.profile?.id === sId, short(whoami.data));
        const me = await call("GET", "/users/me", sToken);
        check("GET /users/me returns the profile with email", me.status === 200 && me.data.id === sId && me.data.email === sEmail, short(me.data));

        // A fresh session to rotate and revoke.
        const login = await signinRaw(sEmail, sPassword);
        const refreshed = await call("POST", "/users/refresh", undefined, { refresh_token: login.data?.refresh_token });
        check(
          "refresh returns a new access + refresh token",
          refreshed.status === 200 && typeof refreshed.data.access_token === "string" && typeof refreshed.data.refresh_token === "string" &&
            refreshed.data.refresh_token !== login.data?.refresh_token && refreshed.data.user?.email === sEmail,
          `status ${refreshed.status}`,
        );
        const rotatedMe = await call("GET", "/users/me", refreshed.data?.access_token);
        check("the refreshed access token works", rotatedMe.status === 200 && rotatedMe.data.id === sId, `status ${rotatedMe.status}`);
        const noRefresh = await call("POST", "/users/refresh", undefined, {});
        check("refresh without a token is 400", noRefresh.status === 400, `status ${noRefresh.status}`);
        const junk = await call("POST", "/users/refresh", undefined, { refresh_token: "not-a-token" });
        check("refresh with a bogus token fails", junk.status >= 400 && junk.status < 500 && !junk.data.access_token, `status ${junk.status}`);

        const anonOut = await call("POST", "/users/logout");
        check("logout without a session is 401", anonOut.status === 401, `status ${anonOut.status}`);
        const out = await call("POST", "/users/logout", refreshed.data?.access_token);
        check("logout is 204", out.status === 204, `status ${out.status}`);
        const afterOut = await call("POST", "/users/refresh", undefined, { refresh_token: refreshed.data?.refresh_token });
        check("the session's refresh token is revoked", afterOut.status >= 400 && !afterOut.data.access_token, `status ${afterOut.status}`);
        const deadAccess = await call("GET", "/users/me", login.data?.access_token);
        check("the session's access tokens stop working", deadAccess.status === 401, `status ${deadAccess.status}`);
        const otherSession = await call("GET", "/users/me", sToken);
        check("other sessions of the account survive the logout", otherSession.status === 200, `status ${otherSession.status}`);

        for (
          const [name, body] of [
            ["missing fields", { new_password: "Change-789" }],
            ["a short new password", { current_password: sPassword, new_password: "12345" }],
          ] as const
        ) {
          const r = await call("POST", "/users/change-password", sToken, body);
          check(`change-password with ${name} is 400`, r.status === 400, `status ${r.status}`);
        }
        const wrong = await call("POST", "/users/change-password", sToken, { current_password: "nope-nope", new_password: "Change-789" });
        check("change-password with a wrong current password is 400", wrong.status === 400, `status ${wrong.status}`);
        const changed = await call("POST", "/users/change-password", sToken, { current_password: sPassword, new_password: "Change-789" });
        check("change-password is 200", changed.status === 200 && changed.data.success === true, `status ${changed.status}`);
        if (changed.status === 200) {
          // The settings screen keeps the session it changed the password with.
          const same = await call("GET", "/users/me", sToken);
          check("the session that changed the password keeps working", same.status === 200, `status ${same.status} ${short(same.data)}`);
          const old = await signinRaw(sEmail, sPassword);
          check("the old password stops working", old.status === 400, `status ${old.status}`);
          sPassword = "Change-789";
          const fresh = await signinRaw(sEmail, sPassword);
          check("the new password signs in", fresh.status === 200 && fresh.data.profile?.id === sId, `status ${fresh.status}`);
          if (fresh.status === 200) sToken = fresh.data.access_token;
        }
        assertAll();
      });

      await t.step("4. email change: validation, confirmation links, profile synced, sign in with the new email", async () => {
        if (!sToken) throw new Error("no session for the signup account");
        for (
          const [name, body, status] of [
            ["missing password", { new_email: sNewEmail }, 400],
            ["an invalid address", { new_email: "nope", password: sPassword }, 400],
            ["the current address", { new_email: sEmail.toUpperCase(), password: sPassword }, 400],
            ["a taken address", { new_email: member.profile.email, password: sPassword }, 409],
            ["a wrong password", { new_email: sNewEmail, password: "wrong-pass" }, 400],
          ] as const
        ) {
          const r = await call("POST", "/users/change-email", sToken, body);
          check(`change-email with ${name} is ${status}`, r.status === status, `status ${r.status} ${short(r.data)}`);
          if (name === "a taken address") check("taken address code is email_taken", r.data.code === "email_taken", short(r.data));
          if (name === "a wrong password") check("wrong password code is invalid_password", r.data.code === "invalid_password", short(r.data));
        }
        const anon = await call("POST", "/users/change-email", undefined, { new_email: sNewEmail, password: sPassword });
        check("change-email needs a session", anon.status === 401, `status ${anon.status}`);

        const oldBefore = (await inbox(sEmail)).length;
        const started = await call("POST", "/users/change-email", sToken, { new_email: sNewEmail.toUpperCase(), password: sPassword });
        check("change-email starts a pending change (address normalized)", started.status === 200 && started.data.pending_email === sNewEmail, `status ${started.status} ${short(started.data)}`);
        const pending = await call("GET", "/users/me", sToken);
        check("the profile keeps the old email until confirmed", pending.data?.email === sEmail, short(pending.data));

        const toNew = (await waitForMail(sNewEmail, 1)).find((m) => /email change/i.test(m.subject));
        check("a confirmation link is sent to the new address", !!linkIn(toNew), toNew?.subject ?? "no mail");
        // double_confirm_changes: the current address gets its own link too.
        const toOld = (await waitForMail(sEmail, oldBefore + 1)).find((m) => /email change/i.test(m.subject));
        check("a confirmation link is sent to the current address", !!linkIn(toOld), toOld?.subject ?? "no mail");
        for (const m of [toNew, toOld]) {
          const p = await followLink(linkIn(m));
          check("confirmation link redirects back to the app", p !== null);
        }

        const synced = await call("GET", "/users/me", sToken);
        check("GET /users/me picks up the confirmed email", synced.status === 200 && synced.data.email === sNewEmail, short(synced.data));
        const newLogin = await signinRaw(sNewEmail, sPassword);
        check("sign in with the new email", newLogin.status === 200 && newLogin.data.profile?.email === sNewEmail, `status ${newLogin.status} ${short(newLogin.data)}`);
        if (newLogin.status === 200) sToken = newLogin.data.access_token;
        const oldLogin = await signinRaw(sEmail, sPassword);
        check("the old email no longer signs in", oldLogin.status === 400, `status ${oldLogin.status}`);
        const lookup = await call("GET", `/users?email=${encodeURIComponent(sNewEmail)}`, owner.token);
        check("staff lookup by the new email finds the account", lookup.status === 200 && lookup.data?.[0]?.id === sId, short(lookup.data));
        assertAll();
      });

      await t.step("5. member invite: code email, invite_pending signup, resend-invite authz, verify-invite, sign in", async () => {
        const username = `it_invm_${tag}`;
        const inv = await call("POST", "/members", owner.token, { gym_id: gym.id, email: mEmail, name: "Mira", last_name: `Invite${tag}`, username });
        ids.m = inv.data?.user_id;
        if (ids.m) createdIds.add(ids.m);
        check("owner invites a new email as a member (201)", inv.status === 201 && inv.data.gym_id === gym.id && !!inv.data.user_id, `status ${inv.status} ${short(inv.data)}`);
        const takenName = await call("POST", "/members", owner.token, {
          gym_id: gym.id, email: `it-badinv-${tag}@example.com`, name: "X", last_name: "Y", username: member.profile.username,
        });
        check("inviting with a taken username is 409", takenName.status === 409, `status ${takenName.status}`);
        const noNames = await call("POST", "/members", owner.token, { gym_id: gym.id, email: `it-badinv-${tag}@example.com` });
        check("inviting a new email without names is 400", noNames.status === 400, `status ${noNames.status}`);

        let mails = await waitForMail(mEmail, 1);
        const firstCode = codeIn(mails[0]);
        check("the invite email carries a 6-digit code and a link", /invited/i.test(mails[0]?.subject ?? "") && !!firstCode && !!linkIn(mails[0]), mails[0]?.subject ?? "no mail");

        // Before activation: signing up with the invited email re-sends the invite.
        await sleep(1_100);
        const pending = await call("POST", "/users/signup", undefined, { email: mEmail, password: "Mine-123", username: `${username}_x`, name: "M", last_name: "I" });
        check("signup for an invited email is 409 invite_pending", pending.status === 409 && pending.data.code === "invite_pending", `status ${pending.status} ${short(pending.data)}`);
        mails = await waitForMail(mEmail, 2);
        check("…and a fresh invite email is sent", mails.length >= 2, `mails=${mails.length}`);

        // resend-invite: staff of a gym the person belongs to, or a super user.
        const anonResend = await call("POST", "/users/resend-invite", undefined, { email: mEmail });
        check("resend-invite needs a session", anonResend.status === 401, `status ${anonResend.status}`);
        for (const [who, s] of [["trainer", trainer], ["shop vendor", vendor], ["member", member]] as const) {
          const r = await call("POST", "/users/resend-invite", s.token, { email: mEmail });
          check(`a ${who} can't resend the gym's invite`, r.status === 403, `status ${r.status}`);
        }
        const noEmail = await call("POST", "/users/resend-invite", owner.token, {});
        check("resend-invite without email is 400", noEmail.status === 400, `status ${noEmail.status}`);
        const unknown = await call("POST", "/users/resend-invite", owner.token, { email: `it-nobody-${tag}@example.com` });
        check("resend-invite for an unknown email is 404", unknown.status === 404, `status ${unknown.status}`);
        await sleep(1_100);
        const byEmployee = await call("POST", "/users/resend-invite", employee.token, { email: mEmail });
        check("gym front-desk staff (employee) resends the invite", byEmployee.status === 200 && byEmployee.data.success === true, `status ${byEmployee.status} ${short(byEmployee.data)}`);
        mails = await waitForMail(mEmail, 3);
        check("resend-invite sends another email", mails.length >= 3, `mails=${mails.length}`);
        const memberRowResend = await call("POST", `/members/${inv.data?.id}/resend-invite`, trainer.token);
        check("a trainer can't resend through /members/:id/resend-invite", memberRowResend.status === 403, `status ${memberRowResend.status}`);

        const latest = codeIn(mails[0]);
        for (
          const [name, body] of [
            ["without a token", { email: mEmail, password: "Mine-123" }],
            ["without a password", { email: mEmail, token: latest }],
            ["with a short password", { email: mEmail, token: latest, password: "12345" }],
          ] as const
        ) {
          const r = await call("POST", "/users/verify-invite", undefined, body);
          check(`verify-invite ${name} is 400`, r.status === 400, `status ${r.status}`);
        }
        const wrongCode = latest === "000000" ? "111111" : "000000";
        const wrong = await call("POST", "/users/verify-invite", undefined, { email: mEmail, token: wrongCode, password: "Mine-123" });
        check("verify-invite with a wrong code is 403", wrong.status === 403 && !wrong.data.access_token, `status ${wrong.status} ${short(wrong.data)}`);
        if (firstCode && firstCode !== latest) {
          const stale = await call("POST", "/users/verify-invite", undefined, { email: mEmail, token: firstCode, password: "Mine-123" });
          check("the code from a superseded invite email is 403", stale.status === 403, `status ${stale.status}`);
        }

        const ok = await call("POST", "/users/verify-invite", undefined, { email: mEmail, token: latest, password: "Mine-123" });
        check(
          "verify-invite with the latest code returns a session + profile",
          ok.status === 200 && typeof ok.data.access_token === "string" && typeof ok.data.refresh_token === "string" &&
            ok.data.profile?.id === ids.m && ok.data.profile?.email === mEmail && ok.data.profile?.username === username,
          `status ${ok.status} ${short(ok.data?.profile ?? ok.data)}`,
        );
        const again = await call("POST", "/users/verify-invite", undefined, { email: mEmail, token: latest, password: "Mine-123" });
        check("the code can't be used twice", again.status === 403, `status ${again.status}`);
        // The app stores this session and goes straight to /home (verify_invite_page).
        const fromVerify = await call("GET", "/users/me", ok.data?.access_token);
        check("the session verify-invite returns works", fromVerify.status === 200, `status ${fromVerify.status} ${short(fromVerify.data)}`);
        const refreshVerify = await call("POST", "/users/refresh", undefined, { refresh_token: ok.data?.refresh_token });
        check("…and can be refreshed", refreshVerify.status === 200, `status ${refreshVerify.status} ${short(refreshVerify.data)}`);

        const login = await signinRaw(mEmail, "Mine-123");
        mToken = login.data?.access_token;
        check("the invited member signs in with the password they chose", login.status === 200 && login.data.profile?.id === ids.m, `status ${login.status} ${short(login.data)}`);
        const memberships = await call("GET", `/members?user_id=${ids.m}`, mToken);
        check("they see their membership at the gym", memberships.status === 200 && (memberships.data as any[]).some((r) => r.gym_id === gym.id), short(memberships.data));
        const welcome = (await call("GET", "/notifications", mToken)).data?.items ?? [];
        check("they got the member_join welcome notification", welcome.some((n: any) => n.type === "member_join" && n.metadata?.gym_id === gym.id), `n=${welcome.length}`);
        const ownerNote = (await call("GET", "/notifications?page_size=50", owner.token)).data?.items ?? [];
        check("the owner was told the member joined", ownerNote.some((n: any) => n.type === "member_join" && n.metadata?.user_id === ids.m), `n=${ownerNote.length}`);

        const afterSignup = await call("POST", "/users/signup", undefined, { email: mEmail, password: "Mine-123", username: `${username}_y`, name: "M", last_name: "I" });
        check("once activated, signup with that email is email_taken", afterSignup.status === 409 && afterSignup.data.code === "email_taken", `status ${afterSignup.status} ${short(afterSignup.data)}`);
        const resendActive = await call("POST", "/users/resend-invite", owner.token, { email: mEmail });
        check("resend-invite to an activated account is refused", resendActive.status === 400, `status ${resendActive.status} ${short(resendActive.data)}`);
        assertAll();
      });

      await t.step("6. employee and shop-vendor invites by email", async () => {
        const denied = await call("POST", "/employees", employee.token, {
          gym_id: gym.id, email: `it-badinv-${tag}@example.com`, name: "X", last_name: "Y", username: `it_badinv_${tag}`,
        });
        check("an employee can't invite staff", denied.status === 403, `status ${denied.status}`);

        // Employee
        const eUser = `it_inve_${tag}`;
        const inv = await call("POST", "/employees", owner.token, { gym_id: gym.id, email: eEmail, name: "Eli", last_name: `Invite${tag}`, username: eUser, employee_type: "employee" });
        ids.e = inv.data?.user_id;
        if (ids.e) createdIds.add(ids.e);
        check("owner invites a new email as an employee (201)", inv.status === 201 && !!ids.e, `status ${inv.status} ${short(inv.data)}`);
        const byTrainer = await call("POST", "/users/resend-invite", trainer.token, { email: eEmail });
        check("a trainer can't resend the employee invite", byTrainer.status === 403, `status ${byTrainer.status}`);
        const eMail = (await waitForMail(eEmail, 1))[0];
        const eCode = codeIn(eMail);
        check("the employee invite email carries a code", !!eCode, eMail?.subject ?? "no mail");
        const eOk = await call("POST", "/users/verify-invite", undefined, { email: eEmail, token: eCode, password: "Staff-123" });
        check(
          "verify-invite activates the employee (role employee)",
          eOk.status === 200 && eOk.data.profile?.id === ids.e && eOk.data.profile?.role === "employee",
          `status ${eOk.status} ${short(eOk.data?.profile ?? eOk.data)}`,
        );
        // (Read with the owner's session: verify-invite's own session is revoked, see step 5.)
        const eRows = await call("GET", `/employees?user_id=${ids.e}`, owner.token);
        check("the new employee is on the gym's staff", eRows.status === 200 && (eRows.data as any[]).some((r) => r.gym_id === gym.id), short(eRows.data));

        // Shop vendor
        const vUser = `it_invv_${tag}`;
        const vInv = await call("POST", "/shop-vendors", owner.token, { shop_id: shop?.id, email: vEmail, name: "Vic", last_name: `Invite${tag}`, username: vUser });
        ids.v = vInv.data?.user_id;
        if (ids.v) createdIds.add(ids.v);
        check("shop owner invites a new email as a vendor (201)", vInv.status === 201 && vInv.data.shop_id === shop?.id, `status ${vInv.status} ${short(vInv.data)}`);
        for (const [who, s] of [["fellow vendor", vendor], ["gym employee", employee]] as const) {
          const r = await call("POST", "/users/resend-invite", s.token, { email: vEmail });
          check(`a ${who} can't resend a shop invite`, r.status === 403, `status ${r.status}`);
        }
        await waitForMail(vEmail, 1);
        await sleep(1_100);
        const byOwner = await call("POST", "/users/resend-invite", owner.token, { email: vEmail });
        check("the shop owner resends the vendor invite", byOwner.status === 200, `status ${byOwner.status} ${short(byOwner.data)}`);
        const vMails = await waitForMail(vEmail, 2);
        const vOk = await call("POST", "/users/verify-invite", undefined, { email: vEmail, token: codeIn(vMails[0]), password: "Vend-123" });
        check(
          "verify-invite activates the vendor (role shop_vendor)",
          vOk.status === 200 && vOk.data.profile?.id === ids.v && vOk.data.profile?.role === "shop_vendor",
          `status ${vOk.status} ${short(vOk.data?.profile ?? vOk.data)}`,
        );
        const vRows = await call("GET", `/shop-vendors?user_id=${ids.v}`, owner.token);
        check("the new vendor is on the shop's vendor list", vRows.status === 200 && (vRows.data as any[]).some((r) => r.shop_id === shop?.id), short(vRows.data));
        assertAll();
      });

      await t.step("7. staff invites to an existing account: decline, accept, owner notified, search", async () => {
        if (!sToken || !sId) throw new Error("no session for the signup account");
        const invitesOf = async () =>
          ((await call("GET", "/notifications?page_size=50", sToken)).data?.items ?? []) as any[];

        const inv1 = await call("POST", "/employees", owner.token, { user_id: sId, gym_id: gym.id, employee_type: "employee" });
        check("owner invites an existing account as employee (pending notification)", inv1.status === 200 && inv1.data.invited === true, `status ${inv1.status} ${short(inv1.data)}`);
        const n1 = (await invitesOf()).find((n) => n.type === "employee_gym_invite" && n.metadata?.gym_id === gym.id && n.metadata?.invite_status === "pending");
        check("the account gets an employee_gym_invite", !!n1 && n1.metadata.employee_type === "employee" && n1.metadata.inviter_id === owner.profile.id, short(n1));

        const othersAccept = await call("POST", `/notifications/${n1?.id}/accept`, member.token);
        check("someone else can't accept the invite", othersAccept.status === 403, `status ${othersAccept.status}`);
        const othersDecline = await call("POST", `/notifications/${n1?.id}/decline`, member.token);
        check("someone else can't decline the invite", othersDecline.status === 403, `status ${othersDecline.status}`);
        const declined = await call("POST", `/notifications/${n1?.id}/decline`, sToken);
        check("decline marks the invite declined and read", declined.status === 200 && declined.data.metadata?.invite_status === "declined" && declined.data.is_read === true, short(declined.data));
        const lateAccept = await call("POST", `/notifications/${n1?.id}/accept`, sToken);
        check("a declined invite can't be accepted (409)", lateAccept.status === 409, `status ${lateAccept.status}`);
        const notEmployee = await call("GET", `/employees?user_id=${sId}`, owner.token);
        check("declining adds no employee row", notEmployee.status === 200 && (notEmployee.data as any[]).length === 0, short(notEmployee.data));
        const missingAccept = await call("POST", `/notifications/${crypto.randomUUID()}/accept`, sToken);
        check("accepting an unknown notification is 404", missingAccept.status === 404, `status ${missingAccept.status}`);

        await call("POST", "/employees", owner.token, { user_id: sId, gym_id: gym.id, employee_type: "employee" });
        const n2 = (await invitesOf()).find((n) => n.type === "employee_gym_invite" && n.metadata?.invite_status === "pending");
        const accepted = await call("POST", `/notifications/${n2?.id}/accept`, sToken);
        check("accepting the second invite marks it accepted", accepted.status === 200 && accepted.data.metadata?.invite_status === "accepted", `status ${accepted.status} ${short(accepted.data)}`);
        const staff = await call("GET", `/employees?gym_id=${gym.id}`, owner.token);
        check("the account is now an employee of the gym", (staff.data as any[]).some((r) => r.user_id === sId), `n=${(staff.data as any[])?.length}`);
        const meRole = await call("GET", "/users/me", sToken);
        check("their role becomes employee", meRole.data?.role === "employee", short(meRole.data));
        const twice = await call("POST", `/notifications/${n2?.id}/accept`, sToken);
        check("an accepted invite can't be accepted again (409)", twice.status === 409, `status ${twice.status}`);
        const reinvite = await call("POST", "/employees", owner.token, { user_id: sId, gym_id: gym.id, employee_type: "employee" });
        check("inviting an existing employee again is 409", reinvite.status === 409, `status ${reinvite.status}`);
        const ownerNotes = (await call("GET", "/notifications?page_size=50", owner.token)).data?.items ?? [];
        check("the owner gets employee_join", ownerNotes.some((n: any) => n.type === "employee_join" && n.metadata?.user_id === sId), `n=${ownerNotes.length}`);

        const vInv = await call("POST", "/shop-vendors", owner.token, { user_id: sId, shop_id: shop?.id });
        check("shop owner invites the account as a vendor", vInv.status === 200 && vInv.data.invited === true, `status ${vInv.status} ${short(vInv.data)}`);
        const vn = (await invitesOf()).find((n) => n.type === "vendor_shop_invite" && n.metadata?.shop_id === shop?.id && n.metadata?.invite_status === "pending");
        const vAccepted = await call("POST", `/notifications/${vn?.id}/accept`, sToken);
        check("accepting the vendor invite", vAccepted.status === 200 && vAccepted.data.metadata?.invite_status === "accepted", `status ${vAccepted.status} ${short(vAccepted.data)}`);
        const vendors = await call("GET", `/shop-vendors?shop_id=${shop?.id}`, owner.token);
        check("the account is now a vendor of the shop", (vendors.data as any[]).some((r) => r.user_id === sId), `n=${(vendors.data as any[])?.length}`);
        const ownerNotes2 = (await call("GET", "/notifications?page_size=50", owner.token)).data?.items ?? [];
        check("the shop owner gets vendor_join", ownerNotes2.some((n: any) => n.type === "vendor_join" && n.metadata?.user_id === sId), `n=${ownerNotes2.length}`);

        // Staff directory search (results carry role rows).
        const found = await call("GET", `/search-users?q=${encodeURIComponent(sProfile.username)}`, owner.token);
        const hit = (found.data as any[])?.find((u) => u.id === sId);
        check(
          "owner finds the account by username, with its employee and vendor rows",
          found.status === 200 && !!hit && hit.email === sNewEmail && hit.employee_entries.some((e: any) => e.gym_id === gym.id) &&
            hit.shop_vendor_entries.some((e: any) => e.shop_id === shop?.id),
          short(hit ?? found.data),
        );
        const byLast = await call("GET", `/search-users?q=${encodeURIComponent(`ivy ${sProfile.last_name}`)}`, employee.token);
        check("staff search matches the full name, case-insensitively", byLast.status === 200 && (byLast.data as any[])[0]?.id === sId, short(byLast.data));
        const trainerSearch = await call("GET", `/search-users?q=${encodeURIComponent(sProfile.username)}`, trainer.token);
        check("a trainer can search too", trainerSearch.status === 200 && (trainerSearch.data as any[]).some((u) => u.id === sId), `status ${trainerSearch.status}`);
        const paged = await call("GET", "/search-users?q=&page_size=2", owner.token);
        const page2 = await call("GET", "/search-users?q=&page_size=2&page=1", owner.token);
        check(
          "browse mode pages (page_size, page)",
          paged.status === 200 && (paged.data as any[]).length === 2 && page2.status === 200 && (page2.data as any[]).length === 2 &&
            (page2.data as any[])[0].id !== (paged.data as any[])[0].id,
          `${(paged.data as any[])?.length}/${(page2.data as any[])?.length}`,
        );
        const big = await call("GET", "/search-users?q=&page_size=500", owner.token);
        check("page_size is capped at 50", big.status === 200 && (big.data as any[]).length <= 50, `n=${(big.data as any[])?.length}`);
        const none = await call("GET", `/search-users?q=zz-no-such-${tag}`, owner.token);
        check("no match returns []", none.status === 200 && (none.data as any[]).length === 0, short(none.data));
        const post = await call("POST", "/search-users", owner.token, {});
        check("POST /search-users is 405", post.status === 405, `status ${post.status}`);
        const anon = await call("GET", "/search-users?q=a");
        check("search needs a session", anon.status === 401, `status ${anon.status}`);
        assertAll();
      });

      await t.step("8. notifications: list, paging, unread counts, read/unread, mark-all-read, delete, isolation", async () => {
        if (!sToken || !sId) throw new Error("no session for the signup account");
        const list = async (q = "") => (await call("GET", `/notifications${q}`, sToken)).data;
        const base = await list();
        check("list shape is {items, unread_count}", Array.isArray(base?.items) && typeof base?.unread_count === "number", short(base));

        const made: any[] = [];
        for (let i = 0; i < 3; i++) {
          const r = await call("POST", "/notifications", superU.token, { user_id: sId, type: "news", title: `it news ${i} ${tag}`, body: "hello" });
          check(`super user creates notification ${i}`, r.status === 201 && r.data.user_id === sId && r.data.is_read === false, `status ${r.status}`);
          made.push(r.data);
          await sleep(5); // distinct created_at for ordering
        }
        const missing = await call("POST", "/notifications", superU.token, { user_id: sId, type: "news" });
        check("creating without a title is 400", missing.status === 400, `status ${missing.status}`);

        const after = await list();
        check("unread_count goes up by 3", after.unread_count === base.unread_count + 3, `${base.unread_count} → ${after.unread_count}`);
        check("newest first", after.items[0]?.id === made[2].id && after.items[1]?.id === made[1].id, after.items.slice(0, 3).map((n: any) => n.title).join(" | "));
        const p0 = await list("?page_size=1");
        const p1 = await list("?page_size=1&page=1");
        check("page_size/page page through the list", p0.items.length === 1 && p1.items.length === 1 && p0.items[0].id === made[2].id && p1.items[0].id === made[1].id, `${p0.items[0]?.title} / ${p1.items[0]?.title}`);
        const unreadOnly = await list("?unread_only=true&page_size=50");
        check("unread_only returns only unread", unreadOnly.items.length === after.unread_count && unreadOnly.items.every((n: any) => !n.is_read), `n=${unreadOnly.items.length}`);
        const superView = await call("GET", `/notifications?user_id=${sId}`, superU.token);
        check("a super user can read someone's notifications", superView.status === 200 && superView.data.items.some((n: any) => n.id === made[0].id), `status ${superView.status}`);
        const memberView = await call("GET", `/notifications?user_id=${sId}`, member.token);
        check("?user_id= is ignored for everyone else", memberView.status === 200 && !memberView.data.items.some((n: any) => n.user_id === sId), `status ${memberView.status}`);

        const one = await call("GET", `/notifications/${made[0].id}`, sToken);
        check("GET /notifications/:id returns your own", one.status === 200 && one.data.title === made[0].title, `status ${one.status}`);
        const othersOne = await call("GET", `/notifications/${made[0].id}`, member.token);
        check("someone else's notification is 404", othersOne.status === 404, `status ${othersOne.status}`);
        const unknown = await call("GET", `/notifications/${crypto.randomUUID()}`, sToken);
        check("unknown notification is 404", unknown.status === 404, `status ${unknown.status}`);
        const malformed = await call("GET", "/notifications/not-a-uuid", sToken);
        check("malformed notification id is 404", malformed.status === 404, `status ${malformed.status} ${short(malformed.data)}`);

        const read = await call("POST", `/notifications/${made[0].id}/read`, sToken);
        check("POST /:id/read marks it read", read.status === 200 && read.data.is_read === true, `status ${read.status}`);
        check("unread_count goes down", (await list()).unread_count === after.unread_count - 1);
        const othersRead = await call("POST", `/notifications/${made[1].id}/read`, member.token);
        check("someone else can't mark it read (404)", othersRead.status === 404, `status ${othersRead.status}`);
        const unread = await call("PATCH", `/notifications/${made[0].id}`, sToken, { is_read: false });
        check("PATCH is_read=false marks it unread again", unread.status === 200 && unread.data.is_read === false, `status ${unread.status}`);
        const badPatch = await call("PATCH", `/notifications/${made[0].id}`, sToken, { title: "x" });
        check("PATCH without a boolean is_read is 400", badPatch.status === 400, `status ${badPatch.status}`);
        const othersPatch = await call("PATCH", `/notifications/${made[0].id}`, member.token, { is_read: true });
        check("someone else's PATCH is 404", othersPatch.status === 404, `status ${othersPatch.status}`);

        const pseudo = await call("POST", "/notifications", superU.token, { user_id: sId, type: "news", title: `it pseudo ${tag}`, metadata: { invite_status: "pending" } });
        const notInvite = await call("POST", `/notifications/${pseudo.data?.id}/accept`, sToken);
        check("accepting a non-invite notification is 400", notInvite.status === 400, `status ${notInvite.status}`);
        const newsAccept = await call("POST", `/notifications/${made[1].id}/decline`, sToken);
        check("declining a plain notification is 409 (not pending)", newsAccept.status === 409, `status ${newsAccept.status}`);

        const all = await call("POST", "/notifications/mark-all-read", sToken);
        check("mark-all-read", all.status === 200 && all.data.ok === true, `status ${all.status}`);
        const cleared = await list("?page_size=50");
        check("unread_count is 0 after mark-all-read", cleared.unread_count === 0 && cleared.items.every((n: any) => n.is_read), `unread ${cleared.unread_count}`);

        const othersDel = await call("DELETE", `/notifications/${made[2].id}`, member.token);
        check("someone else can't delete it (404)", othersDel.status === 404, `status ${othersDel.status}`);
        const del = await call("DELETE", `/notifications/${made[2].id}`, sToken);
        check("delete your own notification (204)", del.status === 204, `status ${del.status}`);
        const gone = await call("GET", `/notifications/${made[2].id}`, sToken);
        check("deleted notification is gone", gone.status === 404, `status ${gone.status}`);
        const delAgain = await call("DELETE", `/notifications/${made[2].id}`, sToken);
        check("deleting it again is 404", delAgain.status === 404, `status ${delAgain.status}`);
        const anon = await call("GET", "/notifications");
        check("notifications need a session", anon.status === 401, `status ${anon.status}`);
        const badRoute = await call("PUT", "/notifications", sToken, {});
        check("unknown route is 404", badRoute.status === 404, `status ${badRoute.status}`);
        assertAll();
      });

      await t.step("9. per-account data: settings defaults, devices, uploads", async () => {
        if (!sToken || !sId) throw new Error("no session for the signup account");
        const defaults = await call("GET", "/users/me/settings", sToken);
        check(
          "a new account reads default settings",
          defaults.status === 200 && defaults.data.push_enabled === true && defaults.data.muted_types.length === 0 && defaults.data.weight_unit === "kg" &&
            defaults.data.theme_mode === "system" && defaults.data.locale === null && defaults.data.updated_at === null,
          short(defaults.data),
        );
        const memberBefore = await call("GET", "/users/me/settings", member.token);
        const put = await call("PUT", "/users/me/settings", sToken, { theme_mode: "dark", locale: "sr", user_id: member.profile.id });
        check("settings PUT ignores a user_id in the body", put.status === 200 && put.data.theme_mode === "dark" && put.data.locale === "sr", short(put.data));
        const memberAfter = await call("GET", "/users/me/settings", member.token);
        check("…and doesn't touch that user's settings", JSON.stringify(memberAfter.data) === JSON.stringify(memberBefore.data), short(memberAfter.data));
        const nullLocale = await call("PUT", "/users/me/settings", sToken, { locale: null });
        check("locale can be cleared with null", nullLocale.status === 200 && nullLocale.data.locale === null && nullLocale.data.theme_mode === "dark", short(nullLocale.data));

        for (const platform of ["web", "macos"] as const) {
          const r = await call("POST", "/devices", sToken, { token: `${deviceToken}-${platform}`, platform });
          check(`registers a ${platform} device`, r.status === 200 && r.data.platform === platform && !!r.data.last_seen_at, `status ${r.status}`);
        }
        const long = await call("POST", "/devices", sToken, { token: "x".repeat(4097), platform: "web" });
        check("a token over 4096 chars is 400", long.status === 400, `status ${long.status}`);
        const blank = await call("POST", "/devices", sToken, { token: "   ", platform: "web" });
        check("a blank token is 400", blank.status === 400, `status ${blank.status}`);
        const getDevices = await call("GET", "/devices", sToken);
        check("GET /devices is 404", getDevices.status === 404, `status ${getDevices.status}`);
        const subPath = await call("POST", "/devices/extra", sToken, { token: deviceToken, platform: "web" });
        check("unknown /devices path is 404", subPath.status === 404, `status ${subPath.status}`);
        const unregWeb = await call("DELETE", "/devices", sToken, { token: `  ${deviceToken}-web  ` });
        check("unregister trims the token (204)", unregWeb.status === 204, `status ${unregWeb.status}`);
        const left = await sql<{ token: string }>(`SELECT token FROM device_token WHERE user_id = $1`, [sId]);
        if (left) check("only the macos device is left", left.length === 1 && left[0].token === `${deviceToken}-macos`, short(left));

        // Image uploads (public buckets).
        const ok = await upload(sToken, { file: new File([PNG], "a.png", { type: "image/png" }), bucket: "avatars", folder: "it-tests" });
        if (ok.data?.path) uploadedPaths.push(`avatars/${ok.data.path}`);
        check(
          "upload a PNG avatar (201 with a public url)",
          ok.status === 201 && ok.data.bucket === "avatars" && /^it-tests\/[0-9a-f-]{36}\.png$/.test(ok.data.path) && String(ok.data.url).endsWith(`/avatars/${ok.data.path}`),
          `status ${ok.status} ${short(ok.data)}`,
        );
        if (ok.status === 201) {
          const res = await fetch(`${API}/storage/v1/object/public/avatars/${ok.data.path}`);
          const bytes = new Uint8Array(await res.arrayBuffer());
          check("the uploaded file is publicly readable", res.status === 200 && bytes.length === PNG.length, `status ${res.status}`);
        }
        const noFolder = await upload(sToken, { file: new File([PNG], "b.webp", { type: "image/webp" }), bucket: "media" });
        if (noFolder.data?.path) uploadedPaths.push(`media/${noFolder.data.path}`);
        check("upload to media without a folder", noFolder.status === 201 && /^[0-9a-f-]{36}\.webp$/.test(noFolder.data.path), `status ${noFolder.status} ${short(noFolder.data)}`);
        for (
          const [name, fields] of [
            ["a missing file", { bucket: "avatars" }],
            ["a private bucket", { file: new File([PNG], "a.png", { type: "image/png" }), bucket: "chat-media" }],
            ["a bad folder", { file: new File([PNG], "a.png", { type: "image/png" }), bucket: "media", folder: "../etc" }],
            ["an unsupported type", { file: new File(["hi"], "a.txt", { type: "text/plain" }), bucket: "media" }],
            ["an avatar over 5MB", { file: new File([new Uint8Array(5 * 1024 * 1024 + 1)], "big.png", { type: "image/png" }), bucket: "avatars" }],
          ] as const
        ) {
          const r = await upload(sToken, fields as Record<string, string | Blob>);
          if (r.data?.path) uploadedPaths.push(`${(fields as any).bucket}/${r.data.path}`);
          check(`upload with ${name} is 400`, r.status === 400, `status ${r.status} ${short(r.data)}`);
        }
        const json = await call("POST", "/uploads", sToken, { bucket: "media" });
        check("a JSON body is 400", json.status === 400, `status ${json.status}`);
        const anon = await upload(undefined, { file: new File([PNG], "a.png", { type: "image/png" }), bucket: "media" });
        check("uploads need a session", anon.status === 401, `status ${anon.status}`);
        const get = await call("GET", "/uploads", sToken);
        check("GET /uploads is 404", get.status === 404, `status ${get.status}`);
        assertAll();
      });

      await t.step("10. impersonation of a fresh account, Google sign-in", async () => {
        if (!sId) throw new Error("no signup account");
        const imp = await call("POST", "/users/impersonate", superU.token, { user_id: sId });
        check("super user impersonates the new account", imp.status === 200 && imp.data.profile?.id === sId && typeof imp.data.access_token === "string", `status ${imp.status} ${short(imp.data?.profile)}`);
        if (imp.status === 200) {
          const me = await call("GET", "/users/me", imp.data.access_token);
          check("the impersonated session acts as that account", me.status === 200 && me.data.id === sId, short(me.data));
          const out = await call("POST", "/users/logout", imp.data.access_token);
          check("the impersonated session logs out", out.status === 204, `status ${out.status}`);
          const own = await call("GET", "/users/me", sToken);
          check("the account's own session survives", own.status === 200, `status ${own.status}`);
        }
        for (const [who, s] of [["gym owner", owner], ["employee", employee]] as const) {
          const r = await call("POST", "/users/impersonate", s.token, { user_id: sId });
          check(`a ${who} can't impersonate`, r.status === 403 && !r.data.access_token, `status ${r.status}`);
        }
        const selfImp = await call("POST", "/users/impersonate", sToken, { user_id: member.profile.id });
        check("a regular account can't impersonate", selfImp.status === 403, `status ${selfImp.status}`);

        const noToken = await call("POST", "/users/google", undefined, {});
        check("Google sign-in without id_token is 400", noToken.status === 400, `status ${noToken.status}`);
        const bogus = await call("POST", "/users/google", undefined, { id_token: "bogus.id.token" });
        check("Google sign-in rejects a bogus id_token", bogus.status >= 400 && bogus.status < 500 && !bogus.data.access_token, `status ${bogus.status} ${short(bogus.data)}`);
        assertAll();
      });

      await t.step("11. account deletion: self, by a super user, and what goes with it", async () => {
        if (!sToken || !sId) throw new Error("no session for the signup account");
        const byOther = await call("DELETE", `/users/${sId}`, member.token);
        check("someone else can't delete the account", byOther.status === 403, `status ${byOther.status}`);
        const del = await call("DELETE", `/users/${sId}`, sToken);
        check("the account deletes itself (204)", del.status === 204, `status ${del.status} ${short(del.data)}`);
        if (del.status === 204) {
          const deletedId = sId;
          sId = undefined;
          const login = await signinRaw(sNewEmail, sPassword);
          check("a deleted account can't sign in", login.status === 400 && !login.data.access_token, `status ${login.status}`);
          const stale = await call("GET", "/users/me", sToken);
          check("its sessions stop working", stale.status === 401, `status ${stale.status}`);
          const again = await call("DELETE", `/users/${deletedId}`, superU.token);
          check("deleting it again is 404", again.status === 404, `status ${again.status}`);
          const emp = await call("GET", `/employees?user_id=${deletedId}`, owner.token);
          const ven = await call("GET", `/shop-vendors?user_id=${deletedId}`, owner.token);
          check("its employee and vendor rows are gone", (emp.data as any[])?.length === 0 && (ven.data as any[])?.length === 0, `${short(emp.data)} ${short(ven.data)}`);
          const rows = await sql<{ auth: number; devices: number; notes: number; settings: number }>(
            `SELECT (SELECT COUNT(*)::int FROM auth.users WHERE email = ANY($2)) AS auth,
                    (SELECT COUNT(*)::int FROM device_token WHERE user_id = $1) AS devices,
                    (SELECT COUNT(*)::int FROM notification WHERE user_id = $1) AS notes,
                    (SELECT COUNT(*)::int FROM user_settings WHERE user_id = $1) AS settings`,
            [deletedId, [sEmail, sNewEmail]],
          );
          if (rows) {
            const r = rows[0];
            check("auth user, devices, notifications and settings are gone", r.auth === 0 && r.devices === 0 && r.notes === 0 && r.settings === 0, short(r));
          }
        }

        // The invited member deletes themselves; the super user removes the others.
        const mDel = await call("DELETE", `/users/${ids.m}`, mToken);
        check("the invited member deletes their account", mDel.status === 204, `status ${mDel.status}`);
        if (mDel.status === 204) {
          const rows = await call("GET", `/members?user_id=${ids.m}`, owner.token);
          check("their membership row goes too", (rows.data as any[])?.length === 0, short(rows.data));
          ids.m = undefined;
        }
        for (const key of ["e", "v"] as const) {
          const r = await call("DELETE", `/users/${ids[key]}`, superU.token);
          check(`super user deletes invited account ${key}`, r.status === 204, `status ${r.status}`);
          if (r.status === 204) ids[key] = undefined;
        }
        const unknown = await call("DELETE", `/users/${crypto.randomUUID()}`, superU.token);
        check("deleting an unknown account is 404", unknown.status === 404, `status ${unknown.status}`);
        assertAll();
      });
    } finally {
      // Notifications other people got about the throwaway accounts, then the accounts.
      await deleteNotificationsWhere("user_id", [...createdIds]);
      const byEmail = await sql<{ id: string }>(`SELECT id FROM users WHERE lower(email) = ANY($1)`, [allEmails]);
      for (const id of new Set([sId, ids.m, ids.e, ids.v, ...(byEmail ?? []).map((r) => r.id)])) {
        if (id) await call("DELETE", `/users/${id}`, superU.token);
      }
      // Auth users left without a profile (or a profile the API couldn't delete).
      await sql(`DELETE FROM device_token WHERE token LIKE $1`, [`${deviceToken}%`]);
      await sql(`DELETE FROM auth.users WHERE lower(email) = ANY($1)`, [allEmails]);
      await sql(`DELETE FROM admin_audit_log WHERE action = 'impersonate' AND created_at >= $1 AND metadata->>'target_email' = ANY($2)`, [
        startedAt,
        allEmails,
      ]);
      const safe = uploadedPaths.filter((p) => /^(avatars|media)\/[\w-]+(\/[\w-]+)?\.(png|jpg|webp)$/.test(p));
      if (safe.length) {
        const list = safe.map((p) => {
          const [bucket, ...rest] = p.split("/");
          return `('${bucket}', '${rest.join("/")}')`;
        }).join(", ");
        await sql(
          `BEGIN; SET LOCAL storage.allow_delete_query = 'true';
           DELETE FROM storage.objects WHERE (bucket_id, name) IN (${list}); COMMIT;`,
        );
      }
    }
  },
});
