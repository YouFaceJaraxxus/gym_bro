// deno-lint-ignore-file no-explicit-any
// Chat beyond the basics in features_people_chat_test.ts: conversation
// validation, who may message whom (private accounts, the followers-only
// toggle, approved followers), declining and re-opening
// message requests, leaving a direct chat, blocks inside an existing chat,
// group roles (owner / admin / member, transfer, delete), moderation,
// replies, edits and unsends, reaction switching, paging, read receipts,
// file attachments and the media listing (only for participants), and
// mute / archive / clear / unread counts. Conversations are deleted (groups
// through the API, direct chats in the database); follow/block rows are
// snapshotted and restored, and the notifications they caused are removed.
import { call, checker, fetchStatus, short, signin, suite, uploadTo } from "./_client.ts";
import { deleteNotificationsSince, deleteNotificationsWhere, restorePair, snapshotPair, sql } from "./_db.ts";

const NOTES = new TextEncoder().encode("squat 5x5, bench 3x8\n");

// Seeded people no other suite acts as. All public and taking messages from
// anyone, except Ingrid: private, and only takes messages from her approved
// followers (allow_non_follower_messages off; Victor's follow request to her
// is pending).
Deno.test({
  name: "features: chat requests, groups, moderation and settings",
  ...suite,
  async fn(t) {
    const { check, assertAll } = checker();
    const [victor, noah, gabriel, olivia, ingrid] = await Promise.all([
      signin("victor.huang@example.com"),
      signin("noah.sullivan@example.com"),
      signin("gabriel.santos@example.com"),
      signin("olivia.mercer@example.com"),
      signin("ingrid.larsen@example.com"),
    ]);
    const V = victor.profile.id as string;
    const N = noah.profile.id as string;
    const B = gabriel.profile.id as string;
    const O = olivia.profile.id as string;
    const G = ingrid.profile.id as string;
    const tag = `it-${crypto.randomUUID().slice(0, 8)}`;
    const since = new Date(Date.now() - 60_000).toISOString();
    const inBox = async (token: string, id: string, box = "inbox") =>
      ((await call("GET", `/chat/conversations?box=${box}&page_size=100`, token)).data as any[])?.find((c) => c.id === id);

    await t.step("1. direct chats: validation, message requests, leaving, blocks", async () => {
      const convIds: string[] = [];
      const snap = await snapshotPair(G, N);
      try {
        const invalid: [string, unknown][] = [
          ["no user_ids", {}],
          ["empty user_ids", { user_ids: [] }],
          ["non-string ids", { user_ids: [1] }],
          ["only myself", { user_ids: [V] }],
          ["a malformed id", { user_ids: ["nope"] }],
          ["an unknown user", { user_ids: [crypto.randomUUID()] }],
          ["a title over 100 chars", { user_ids: [N, B], title: "x".repeat(101) }],
        ];
        for (const [name, body] of invalid) {
          const r = await call("POST", "/chat/conversations", victor.token, body);
          if (r.data?.id) convIds.push(r.data.id);
          check(`new conversation with ${name} is 400`, r.status === 400, `status ${r.status}`);
        }
        const anon = await call("GET", "/chat/conversations");
        check("chat needs a signed-in user", anon.status === 401, `status ${anon.status}`);

        // Ingrid only takes messages from approved followers: Victor can't write.
        const closed = await call("GET", `/social/users/${G}`, victor.token);
        check("her profile says Victor can't message her", closed.data?.message_status === null, short(closed.data?.message_status));
        const refused = await call("POST", "/chat/conversations", victor.token, { user_ids: [G] });
        if (refused.data?.id) convIds.push(refused.data.id);
        check("…so starting a chat is refused", refused.status === 400, `status ${refused.status}`);

        // With the toggle on, she's private: Victor's DM is a message request.
        const open = await call("PUT", "/social/me", ingrid.token, { allow_non_follower_messages: true });
        check("she takes messages from non-followers again", open.status === 200, `status ${open.status}`);
        const badgesBefore = (await call("GET", "/social/badges", ingrid.token)).data;
        const profile = await call("GET", `/social/users/${G}`, victor.token);
        check("her profile says a DM would be a request", profile.data?.message_status === "request", short(profile.data?.message_status));
        const dm = await call("POST", "/chat/conversations", victor.token, { user_ids: [G] });
        convIds.push(dm.data?.id);
        const sent = await call("POST", `/chat/conversations/${dm.data?.id}/messages`, victor.token, { body: `hi ingrid ${tag}` });
        check("send to someone who doesn't follow me", sent.status === 201, `status ${sent.status}`);
        const request = await inBox(ingrid.token, dm.data?.id, "requests");
        check(
          "it lands in her requests with a preview",
          request?.my_status === "request" && request.unread_count === 1 && request.last_message?.preview === `hi ingrid ${tag}` &&
            request.other_user?.id === V && !(await inBox(ingrid.token, dm.data?.id)),
          short(request),
        );
        const badges = (await call("GET", "/social/badges", ingrid.token)).data;
        check("message_requests badge counts it", badges?.message_requests === badgesBefore.message_requests + 1, `${badgesBefore.message_requests} → ${badges?.message_requests}`);

        const decline = await call("DELETE", `/chat/conversations/${dm.data?.id}/participants/${G}`, ingrid.token);
        const gone = await call("GET", `/chat/conversations/${dm.data?.id}`, ingrid.token);
        check(
          "declining removes the request",
          decline.status === 204 && gone.status === 404 && !(await inBox(ingrid.token, dm.data?.id, "requests")),
          `status ${decline.status}/${gone.status}`,
        );
        await call("POST", `/chat/conversations/${dm.data?.id}/messages`, victor.token, { body: "sorry, one more" });
        check("a new message re-opens it as a request", (await inBox(ingrid.token, dm.data?.id, "requests"))?.my_status === "request");
        const reply = await call("POST", `/chat/conversations/${dm.data?.id}/messages`, ingrid.token, { body: "ok, hi" });
        const accepted = await inBox(ingrid.token, dm.data?.id);
        check("replying accepts the request", reply.status === 201 && accepted?.my_status === "active", short(accepted?.my_status));
        const victorSide = await call("GET", `/chat/conversations/${dm.data?.id}`, victor.token);
        check(
          "the sender sees her as active",
          victorSide.data?.members?.find((m: any) => m.id === G)?.status === "active",
          short(victorSide.data?.members),
        );

        // Once she approves Noah's follow request, his DM goes straight to her inbox.
        const follow = await call("POST", `/social/users/${G}/follow`, noah.token);
        const approve = await call("POST", `/social/follow-requests/${N}/accept`, ingrid.token);
        check(
          "Noah's follow request is approved",
          follow.data?.relationship?.following === "pending" && approve.data?.relationship?.followed_by === "accepted",
          short(approve.data),
        );
        const noahProfile = await call("GET", `/social/users/${G}`, noah.token);
        check("…so Noah's DM wouldn't be a request", noahProfile.data?.message_status === "active", short(noahProfile.data?.message_status));
        const dm2 = await call("POST", "/chat/conversations", noah.token, { user_ids: [G] });
        convIds.push(dm2.data?.id);
        await call("POST", `/chat/conversations/${dm2.data?.id}/messages`, noah.token, { body: `hey ${tag}` });
        check("approved followers land in her inbox", (await inBox(ingrid.token, dm2.data?.id))?.my_status === "active");

        // Direct chats have no title, members or delete-for-everyone.
        const rename = await call("PUT", `/chat/conversations/${dm2.data?.id}`, noah.token, { title: "x" });
        const add = await call("POST", `/chat/conversations/${dm2.data?.id}/participants`, noah.token, { user_ids: [B] });
        const del = await call("DELETE", `/chat/conversations/${dm2.data?.id}`, noah.token);
        const kick = await call("DELETE", `/chat/conversations/${dm2.data?.id}/participants/${G}`, noah.token);
        check(
          "direct chats can't be renamed (400), extended (400), deleted (403) or have people removed (403)",
          rename.status === 400 && add.status === 400 && del.status === 403 && kick.status === 403,
          `status ${rename.status}/${add.status}/${del.status}/${kick.status}`,
        );

        // Leaving a direct chat hides its history for me until a new message.
        const leave = await call("DELETE", `/chat/conversations/${dm2.data?.id}/participants/${N}`, noah.token);
        const hiddenHistory = await call("GET", `/chat/conversations/${dm2.data?.id}/messages`, noah.token);
        const herHistory = await call("GET", `/chat/conversations/${dm2.data?.id}/messages`, ingrid.token);
        check(
          "leave: history hidden for me only",
          leave.status === 204 && hiddenHistory.data?.length === 0 && herHistory.data?.length === 1,
          `status ${leave.status} mine=${hiddenHistory.data?.length} hers=${herHistory.data?.length}`,
        );
        const stillListed = await inBox(noah.token, dm2.data?.id);
        check("leave: gone from my inbox (even though I started it)", !stillListed, short(stillListed));
        const back = await call("POST", `/chat/conversations/${dm2.data?.id}/messages`, ingrid.token, { body: "you there?" });
        const noahRow = await inBox(noah.token, dm2.data?.id);
        check(
          "a new message brings it back with only the new history",
          back.status === 201 && noahRow?.last_message?.preview === "you there?" && noahRow.unread_count === 1,
          short(noahRow),
        );

        // A block stops an existing chat both ways.
        const block = await call("POST", `/social/users/${G}/block`, noah.token);
        const fromBlocked = await call("POST", `/chat/conversations/${dm2.data?.id}/messages`, ingrid.token, { body: "hello?" });
        const fromBlocker = await call("POST", `/chat/conversations/${dm2.data?.id}/messages`, noah.token, { body: "bye" });
        check(
          "no messages either way across a block",
          block.status === 200 && fromBlocked.status === 403 && fromBlocker.status === 403,
          `status ${fromBlocked.status}/${fromBlocker.status}`,
        );
        await call("DELETE", `/social/users/${G}/block`, noah.token);
        const unblocked = await call("POST", `/chat/conversations/${dm2.data?.id}/messages`, ingrid.token, { body: "back again" });
        check("unblocking lets messages through again", unblocked.status === 201, `status ${unblocked.status}`);
      } finally {
        await call("PUT", "/social/me", ingrid.token, { allow_non_follower_messages: false });
        await restorePair(G, N, snap);
        await deleteNotificationsSince([N, G], since, "user_id", [G, N]);
        for (const id of convIds.filter(Boolean)) await sql(`DELETE FROM conversation WHERE id = $1`, [id]);
      }
      assertAll();
    });

    await t.step("2. groups: roles, moderation, replies, reactions, paging, files", async () => {
      const convIds: string[] = [];
      const created: string[] = [];
      try {
        const group = await call("POST", "/chat/conversations", victor.token, { user_ids: [N, B, O], title: `Crew ${tag}` });
        const id = group.data?.id as string;
        convIds.push(id);
        created.push(id);
        check("Victor creates a group", group.status === 201 && group.data.my_role === "owner" && group.data.members.length === 4, short(group.data));

        const pair = await call("POST", "/chat/conversations", victor.token, { user_ids: [N], group: true });
        if (pair.data?.id) {
          convIds.push(pair.data.id);
          created.push(pair.data.id);
        }
        check("group: true makes a group even with one other person", pair.status === 201 && pair.data.kind === "group" && pair.data.title === null, short(pair.data));
        const notOwnerDelete = await call("DELETE", `/chat/conversations/${pair.data?.id}`, noah.token);
        const ownerDelete = await call("DELETE", `/chat/conversations/${pair.data?.id}`, victor.token);
        const afterDelete = await call("GET", `/chat/conversations/${pair.data?.id}`, noah.token);
        check(
          "only the owner deletes a group, for everyone",
          notOwnerDelete.status === 403 && ownerDelete.status === 204 && afterDelete.status === 404,
          `status ${notOwnerDelete.status}/${ownerDelete.status}/${afterDelete.status}`,
        );

        // ── Roles ──
        const memberRename = await call("PUT", `/chat/conversations/${id}`, noah.token, { title: "mine" });
        const memberRole = await call("PUT", `/chat/conversations/${id}/participants/${B}`, noah.token, { role: "admin" });
        const memberKick = await call("DELETE", `/chat/conversations/${id}/participants/${B}`, noah.token);
        check(
          "a plain member can't rename, change roles or remove people",
          memberRename.status === 403 && memberRole.status === 403 && memberKick.status === 403,
          `status ${memberRename.status}/${memberRole.status}/${memberKick.status}`,
        );
        await call("PUT", `/chat/conversations/${id}/participants/${B}`, victor.token, { role: "admin" });
        const two = await call("PUT", `/chat/conversations/${id}/participants/${O}`, victor.token, { role: "admin" });
        check("owner promotes two admins", two.data?.members?.filter((m: any) => m.role === "admin").length === 2, short(two.data?.members));
        const adminRole = await call("PUT", `/chat/conversations/${id}/participants/${N}`, gabriel.token, { role: "admin" });
        const adminKicksAdmin = await call("DELETE", `/chat/conversations/${id}/participants/${O}`, gabriel.token);
        check(
          "only the owner changes roles or removes admins",
          adminRole.status === 403 && adminKicksAdmin.status === 403,
          `status ${adminRole.status}/${adminKicksAdmin.status}`,
        );
        const badRole = await call("PUT", `/chat/conversations/${id}/participants/${O}`, victor.token, { role: "boss" });
        const selfRole = await call("PUT", `/chat/conversations/${id}/participants/${V}`, victor.token, { role: "member" });
        const outsiderRole = await call("PUT", `/chat/conversations/${id}/participants/${G}`, victor.token, { role: "admin" });
        check(
          "role validation (unknown role 400, myself 400, non-participant 404)",
          badRole.status === 400 && selfRole.status === 400 && outsiderRole.status === 404,
          `status ${badRole.status}/${selfRole.status}/${outsiderRole.status}`,
        );
        const demote = await call("PUT", `/chat/conversations/${id}/participants/${O}`, victor.token, { role: "member" });
        check("owner demotes an admin", demote.data?.members?.find((m: any) => m.id === O)?.role === "member", short(demote.data?.members));

        const describe = await call("PUT", `/chat/conversations/${id}`, gabriel.token, { description: "  Leg day crew  ", avatar_url: "https://example.com/g.png" });
        check(
          "an admin sets description and photo",
          describe.status === 200 && describe.data.description === "Leg day crew" && describe.data.avatar_url === "https://example.com/g.png",
          short(describe.data),
        );
        const nothing = await call("PUT", `/chat/conversations/${id}`, gabriel.token, {});
        const longDesc = await call("PUT", `/chat/conversations/${id}`, gabriel.token, { description: "x".repeat(501) });
        const badAvatar = await call("PUT", `/chat/conversations/${id}`, gabriel.token, { avatar_url: 5 });
        const longTitle = await call("PUT", `/chat/conversations/${id}`, gabriel.token, { title: "x".repeat(101) });
        check(
          "group edit validation",
          nothing.status === 400 && longDesc.status === 400 && badAvatar.status === 400 && longTitle.status === 400,
          `status ${nothing.status}/${longDesc.status}/${badAvatar.status}/${longTitle.status}`,
        );

        // ── Messages: replies, unsend, edits, reactions ──
        const m1 = await call("POST", `/chat/conversations/${id}/messages`, noah.token, { body: "noah here" });
        const m2 = await call("POST", `/chat/conversations/${id}/messages`, olivia.token, { body: "hi noah", reply_to_id: m1.data?.id });
        check(
          "reply quotes the original",
          m2.status === 201 && m2.data.reply_to?.id === m1.data?.id && m2.data.reply_to.body === "noah here" && m2.data.reply_to.sender_id === N,
          short(m2.data?.reply_to),
        );
        const foreignReply = await call("POST", `/chat/conversations/${id}/messages`, olivia.token, { body: "x", reply_to_id: crypto.randomUUID() });
        check("reply_to outside the conversation is 400", foreignReply.status === 400, `status ${foreignReply.status}`);
        const invalid: [string, unknown][] = [
          ["no text or attachment", { body: "  " }],
          ["text over 4000 chars", { body: "x".repeat(4001) }],
          ["more than 10 attachments", { attachments: Array.from({ length: 11 }, () => ({ path: "x" })) }],
          ["an attachment without a path", { attachments: [{}] }],
        ];
        for (const [name, body] of invalid) {
          const r = await call("POST", `/chat/conversations/${id}/messages`, olivia.token, body);
          check(`message with ${name} is 400`, r.status === 400, `status ${r.status}`);
        }
        const outsiderSend = await call("POST", `/chat/conversations/${id}/messages`, ingrid.token, { body: "let me in" });
        check("a non-participant can't post", outsiderSend.status === 404, `status ${outsiderSend.status}`);

        const memberUnsend = await call("DELETE", `/chat/messages/${m2.data?.id}`, noah.token);
        check("a member can't unsend someone else's message", memberUnsend.status === 403, `status ${memberUnsend.status}`);
        const adminUnsend = await call("DELETE", `/chat/messages/${m1.data?.id}`, gabriel.token);
        check("an admin unsends anyone's message", adminUnsend.status === 200 && !!adminUnsend.data.deleted_at && adminUnsend.data.body === null, short(adminUnsend.data));
        const editUnsent = await call("PUT", `/chat/messages/${m1.data?.id}`, noah.token, { body: "edit" });
        const reactUnsent = await call("PUT", `/chat/messages/${m1.data?.id}/reaction`, olivia.token, { reaction: "sad" });
        check("an unsent message is 410", editUnsent.status === 410 && reactUnsent.status === 410, `status ${editUnsent.status}/${reactUnsent.status}`);
        const page = (await call("GET", `/chat/conversations/${id}/messages`, olivia.token)).data as any[];
        const quoted = page.find((m) => m.id === m2.data?.id);
        check("the reply now quotes a deleted message", quoted?.reply_to?.deleted === true && quoted.reply_to.body === null, short(quoted?.reply_to));
        const system = page.find((m) => m.kind === "system");
        const editSystem = await call("PUT", `/chat/messages/${system?.id}`, victor.token, { body: "x" });
        const reactSystem = await call("PUT", `/chat/messages/${system?.id}/reaction`, victor.token, { reaction: "like" });
        check("system messages can't be edited or reacted to", editSystem.status === 400 && reactSystem.status === 400, `status ${editSystem.status}/${reactSystem.status}`);
        const emptyEdit = await call("PUT", `/chat/messages/${m2.data?.id}`, olivia.token, { body: " " });
        const longEdit = await call("PUT", `/chat/messages/${m2.data?.id}`, olivia.token, { body: "x".repeat(4001) });
        check("edit validation", emptyEdit.status === 400 && longEdit.status === 400, `status ${emptyEdit.status}/${longEdit.status}`);

        const strong = await call("PUT", `/chat/messages/${m2.data?.id}/reaction`, noah.token, { reaction: "strong" });
        const clap = await call("PUT", `/chat/messages/${m2.data?.id}/reaction`, noah.token, { reaction: "clap" });
        const mine = (clap.data?.reactions as any[])?.filter((r) => r.user_id === N);
        check(
          "switching a reaction keeps one per person",
          strong.status === 200 && mine?.length === 1 && mine[0].reaction === "clap",
          short(clap.data?.reactions),
        );
        const unreact = await call("DELETE", `/chat/messages/${m2.data?.id}/reaction`, noah.token);
        check("remove a reaction", unreact.status === 200 && !(unreact.data.reactions as any[]).some((r) => r.user_id === N), short(unreact.data?.reactions));
        const wrongVerb = await call("POST", `/chat/messages/${m2.data?.id}/reaction`, noah.token, { reaction: "like" });
        check("POST on a reaction is 405", wrongVerb.status === 405, `status ${wrongVerb.status}`);
        const outsiderReact = await call("PUT", `/chat/messages/${m2.data?.id}/reaction`, ingrid.token, { reaction: "like" });
        const ghost = await call("PUT", `/chat/messages/${crypto.randomUUID()}`, olivia.token, { body: "x" });
        const badId = await call("DELETE", "/chat/messages/nope", olivia.token);
        check(
          "unknown message or non-participant is 404",
          outsiderReact.status === 404 && ghost.status === 404 && badId.status === 404,
          `status ${outsiderReact.status}/${ghost.status}/${badId.status}`,
        );

        // ── Paging ──
        const more: string[] = [];
        for (const n of [3, 4, 5]) {
          more.push((await call("POST", `/chat/conversations/${id}/messages`, victor.token, { body: `m${n}`, client_id: `${tag}-${n}` })).data?.id);
        }
        const newest = await call("GET", `/chat/conversations/${id}/messages?limit=2`, gabriel.token);
        const older = await call("GET", `/chat/conversations/${id}/messages?limit=2&before_id=${more[1]}`, gabriel.token);
        const newer = await call("GET", `/chat/conversations/${id}/messages?after_id=${more[0]}`, gabriel.token);
        check(
          "limit, and before_id pages back (newest first)",
          newest.data?.map((m: any) => m.id).join() === [more[2], more[1]].join() && older.data?.[0]?.id === more[0] &&
            older.data[1]?.id === m2.data?.id,
          `${newest.data?.map((m: any) => m.body)} / ${older.data?.map((m: any) => m.body)}`,
        );
        // The cursor message itself isn't repeated (created_at has microseconds).
        check(
          "after_id returns only newer messages, oldest first",
          newer.data?.map((m: any) => m.id).join() === [more[1], more[2]].join(),
          `${newer.data?.map((m: any) => m.body)}`,
        );
        const badCursor = await call("GET", `/chat/conversations/${id}/messages?before_id=nope`, gabriel.token);
        const ghostCursor = await call("GET", `/chat/conversations/${id}/messages?after_id=${crypto.randomUUID()}`, gabriel.token);
        check("a malformed cursor is 400, an unknown one 404", badCursor.status === 400 && ghostCursor.status === 404, `status ${badCursor.status}/${ghostCursor.status}`);

        // ── Read receipts ──
        const read = await call("POST", `/chat/conversations/${id}/read`, olivia.token);
        const detail = await call("GET", `/chat/conversations/${id}`, victor.token);
        const oliviaRow = await inBox(olivia.token, id);
        check(
          "read receipt shows to others; my unread count drops to 0",
          detail.data?.members?.find((m: any) => m.id === O)?.last_read_at === read.data?.last_read_at && oliviaRow?.unread_count === 0,
          short(oliviaRow?.unread_count),
        );

        // ── A file attachment and the media listing ──
        const slot = await call("POST", `/chat/conversations/${id}/uploads`, olivia.token, { mime_type: "text/plain", size_bytes: NOTES.length, file_name: "notes.txt" });
        const noMime = await call("POST", `/chat/conversations/${id}/uploads`, olivia.token, { size_bytes: 10 });
        const noSize = await call("POST", `/chat/conversations/${id}/uploads`, olivia.token, { mime_type: "text/plain" });
        check("upload slot validation (mime, size)", noMime.status === 400 && noSize.status === 400, `status ${noMime.status}/${noSize.status}`);
        check("upload a text file", slot.status === 201 && slot.data.path.endsWith(".txt") && (await uploadTo(slot.data, NOTES, "text/plain")) === 200, short(slot.data));
        const file = await call("POST", `/chat/conversations/${id}/messages`, olivia.token, {
          attachments: [{ path: slot.data?.path, file_name: "notes.txt", size_bytes: NOTES.length }],
        });
        const att = file.data?.attachments?.[0];
        check(
          "send a file",
          file.status === 201 && file.data.kind === "media" && att?.media_type === "file" && att.file_name === "notes.txt" &&
            att.url?.startsWith("/storage/v1/object/sign/chat-media/"),
          short(file.data),
        );
        const files = await call("GET", `/chat/conversations/${id}/media?type=file`, noah.token);
        const media = await call("GET", `/chat/conversations/${id}/media?type=media`, noah.token);
        const audio = await call("GET", `/chat/conversations/${id}/media?type=audio`, noah.token);
        const listed = (files.data as any[])?.find((f) => f.message_id === file.data?.id);
        check(
          "media listing filters by type and signs URLs for participants",
          listed?.media_type === "file" && !(media.data as any[]).some((f) => f.message_id === file.data?.id) &&
            !(audio.data as any[]).some((f) => f.message_id === file.data?.id) && (await fetchStatus(listed.url)) === 200,
          short(listed),
        );
        const inboxRow = await inBox(noah.token, id);
        check("inbox preview for a file", inboxRow?.last_message?.preview === "file", short(inboxRow?.last_message));

        // ── Ownership, removal, delete ──
        const transfer = await call("PUT", `/chat/conversations/${id}/participants/${B}`, victor.token, { role: "owner" });
        const roles = Object.fromEntries((transfer.data?.members as any[] ?? []).map((m) => [m.id, m.role]));
        check("hand ownership over; the old owner becomes an admin", roles[B] === "owner" && roles[V] === "admin", short(roles));
        const exOwnerDelete = await call("DELETE", `/chat/conversations/${id}`, victor.token);
        check("the old owner can't delete the group any more", exOwnerDelete.status === 403, `status ${exOwnerDelete.status}`);
        const kick = await call("DELETE", `/chat/conversations/${id}/participants/${N}`, gabriel.token);
        const kickedMessages = await call("GET", `/chat/conversations/${id}/messages`, noah.token);
        const kickedMedia = await call("GET", `/chat/conversations/${id}/media`, noah.token);
        const kickedUpload = await call("POST", `/chat/conversations/${id}/uploads`, noah.token, { mime_type: "image/png", size_bytes: 10 });
        check(
          "a removed member gets no messages, media URLs or upload slots",
          kick.status === 204 && kickedMessages.status === 404 && kickedMedia.status === 404 && kickedUpload.status === 404,
          `status ${kick.status}/${kickedMessages.status}/${kickedMedia.status}/${kickedUpload.status}`,
        );
        const outsiderMedia = await call("GET", `/chat/conversations/${id}/media`, ingrid.token);
        check("…nor does anyone outside the group", outsiderMedia.status === 404, `status ${outsiderMedia.status}`);
        const leave = await call("DELETE", `/chat/conversations/${id}/participants/${O}`, olivia.token);
        const remaining = await call("GET", `/chat/conversations/${id}`, gabriel.token);
        check("a member leaves", leave.status === 204 && remaining.data?.members?.length === 2, `status ${leave.status} n=${remaining.data?.members?.length}`);
        const del = await call("DELETE", `/chat/conversations/${id}`, gabriel.token);
        const after = await call("GET", `/chat/conversations/${id}`, victor.token);
        check("the new owner deletes the group (and its files)", del.status === 204 && after.status === 404 && (await fetchStatus(listed?.url ?? "/x")) >= 400, `status ${del.status}/${after.status}`);
        if (del.status === 204) convIds.splice(convIds.indexOf(id), 1);
      } finally {
        await deleteNotificationsWhere("conversation_id", created.filter(Boolean));
        for (const id of convIds.filter(Boolean)) await sql(`DELETE FROM conversation WHERE id = $1`, [id]);
      }
      assertAll();
    });

    await t.step("3. mute, archive, clear and unread counts", async () => {
      let convId: string | null = null;
      try {
        const dm = await call("POST", "/chat/conversations", gabriel.token, { user_ids: [O] });
        convId = dm.data?.id ?? null;
        const id = convId!;
        await call("POST", `/chat/conversations/${id}/messages`, gabriel.token, { body: "one" });
        check("unread count", (await inBox(olivia.token, id))?.unread_count === 1);
        await call("POST", `/chat/conversations/${id}/read`, olivia.token);
        check("reading clears it", (await inBox(olivia.token, id))?.unread_count === 0);
        const b0 = (await call("GET", "/social/badges", olivia.token)).data?.unread_conversations as number;
        await call("POST", `/chat/conversations/${id}/messages`, gabriel.token, { body: "two" });
        const b1 = (await call("GET", "/social/badges", olivia.token)).data?.unread_conversations;
        check("the unread_conversations badge counts the chat", b1 === b0 + 1, `${b0} → ${b1}`);
        await call("POST", `/chat/conversations/${id}/read`, olivia.token);
        const oops = await call("POST", `/chat/conversations/${id}/messages`, gabriel.token, { body: "oops" });
        await call("DELETE", `/chat/messages/${oops.data?.id}`, gabriel.token);
        const row = await inBox(olivia.token, id);
        check("an unsent message isn't unread", row?.unread_count === 0 && row.last_message?.deleted === true && row.last_message.preview === null, short(row));
        const b2 = (await call("GET", "/social/badges", olivia.token)).data?.unread_conversations;
        check("…nor does it light the unread badge", b2 === b0, `${b0} → ${b2}`);

        // ── Mute ──
        const mute = await call("PUT", `/chat/conversations/${id}/settings`, olivia.token, { muted: true });
        const until = new Date(Date.now() + 3_600_000).toISOString();
        const muteFor = await call("PUT", `/chat/conversations/${id}/settings`, olivia.token, { muted_until: until });
        const expired = await call("PUT", `/chat/conversations/${id}/settings`, olivia.token, { muted_until: "2020-01-01T00:00:00Z" });
        const unmute = await call("PUT", `/chat/conversations/${id}/settings`, olivia.token, { muted: false });
        check(
          "mute forever, for an hour, already expired, unmute",
          mute.data?.muted === true && muteFor.data?.muted === true && new Date(muteFor.data.muted_until).getTime() === new Date(until).getTime() &&
            expired.data?.muted === false && unmute.data?.muted === false && unmute.data.muted_until === null,
          `${mute.data?.muted}/${muteFor.data?.muted}/${expired.data?.muted}/${unmute.data?.muted}`,
        );
        const invalid: [string, unknown][] = [
          ["muted not a boolean", { muted: "yes" }],
          ["muted_until not a date", { muted_until: "soon" }],
          ["archived not a boolean", { archived: 1 }],
          ["nothing", {}],
        ];
        for (const [name, body] of invalid) {
          const r = await call("PUT", `/chat/conversations/${id}/settings`, olivia.token, body);
          check(`settings with ${name} is 400`, r.status === 400, `status ${r.status}`);
        }
        const outsider = await call("PUT", `/chat/conversations/${id}/settings`, victor.token, { muted: true });
        check("a non-participant's settings are 404", outsider.status === 404, `status ${outsider.status}`);

        // ── Archive ──
        const archive = await call("PUT", `/chat/conversations/${id}/settings`, olivia.token, { archived: true });
        check(
          "archive moves it out of the inbox",
          archive.data?.archived === true && !(await inBox(olivia.token, id)) && !!(await inBox(olivia.token, id, "archived")),
          short(archive.data?.archived),
        );
        await call("POST", `/chat/conversations/${id}/messages`, gabriel.token, { body: "unarchive me" });
        check(
          "a new message brings it back",
          (await inBox(olivia.token, id))?.archived === false && !(await inBox(olivia.token, id, "archived")),
        );
        await call("PUT", `/chat/conversations/${id}/settings`, olivia.token, { archived: true });
        const reopen = await call("POST", "/chat/conversations", olivia.token, { user_ids: [B] });
        check("opening the chat again un-archives it for me", reopen.data?.id === id && reopen.data.archived === false, short(reopen.data?.archived));
        const badBox = await call("GET", "/chat/conversations?box=spam", olivia.token);
        check("unknown box is 400", badBox.status === 400, `status ${badBox.status}`);

        // ── Clear ──
        const clear = await call("POST", `/chat/conversations/${id}/clear`, olivia.token);
        const mine = await call("GET", `/chat/conversations/${id}/messages`, olivia.token);
        const his = await call("GET", `/chat/conversations/${id}/messages`, gabriel.token);
        check(
          "clear hides the history for me only",
          clear.status === 204 && mine.data?.length === 0 && his.data?.length >= 4,
          `status ${clear.status} mine=${mine.data?.length} his=${his.data?.length}`,
        );
        const cleared = await inBox(olivia.token, id);
        check("a cleared chat I didn't start leaves my inbox until the next message", !cleared, short(cleared));
        await call("POST", `/chat/conversations/${id}/messages`, gabriel.token, { body: "after clear" });
        const fresh = await call("GET", `/chat/conversations/${id}/messages`, olivia.token);
        check("then only the new message shows", fresh.data?.length === 1 && fresh.data[0].body === "after clear", `n=${fresh.data?.length}`);
      } finally {
        if (convId) await sql(`DELETE FROM conversation WHERE id = $1`, [convId]);
      }
      assertAll();
    });
  },
});
