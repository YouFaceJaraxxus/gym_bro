// deno-lint-ignore-file no-explicit-any
// People (profiles, privacy, follows, friends, blocks, discovery), chat
// (direct + group, uploads, reactions, realtime authorization) and personal
// posts (visibility, private media, reactions, threaded comments, feed).
// Relationships between seeded users are snapshotted and restored; created
// rows are deleted in `finally`.

// Pinned: deno.json has no lockfile, and a newer realtime client than the
// local stack's realtime server joins private channels but never gets broadcasts.
import { createClient, type RealtimeChannel } from "jsr:@supabase/supabase-js@2.100.1";
import { ANON, API, call, checker, deleteNotifications, notificationsOf, short, signin, suite } from "./_client.ts";
import { sql } from "./_db.ts";

// A 1×1 PNG.
const PNG = Uint8Array.from(
  atob("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="),
  (c) => c.charCodeAt(0),
);

/** Uploads bytes through a slot from an /uploads endpoint. */
async function uploadTo(slot: any, bytes: Uint8Array<ArrayBuffer>, type: string): Promise<number> {
  const res = await fetch(`${API}${slot.upload_url}`, {
    method: "PUT",
    headers: { "Content-Type": type, "x-upsert": "false" },
    body: bytes,
  });
  await res.body?.cancel();
  return res.status;
}

async function fetchStatus(relativeUrl: string): Promise<number> {
  const res = await fetch(`${API}${relativeUrl}`);
  await res.body?.cancel();
  return res.status;
}

type PairSnapshot = { follows: any[]; friendships: any[]; blocks: any[] };

/** Follow / friendship / block rows between two users, to put back after a test. */
async function snapshotPair(a: string, b: string): Promise<PairSnapshot> {
  const pair = [a, b];
  return {
    follows: (await sql(`SELECT * FROM follow WHERE follower_id = ANY($1) AND followee_id = ANY($1)`, [pair])) ?? [],
    friendships: (await sql(`SELECT * FROM friendship WHERE requester_id = ANY($1) AND addressee_id = ANY($1)`, [pair])) ?? [],
    blocks: (await sql(`SELECT * FROM user_block WHERE blocker_id = ANY($1) AND blocked_id = ANY($1)`, [pair])) ?? [],
  };
}

async function restorePair(a: string, b: string, s: PairSnapshot) {
  const pair = [a, b];
  await sql(`DELETE FROM follow WHERE follower_id = ANY($1) AND followee_id = ANY($1)`, [pair]);
  await sql(`DELETE FROM friendship WHERE requester_id = ANY($1) AND addressee_id = ANY($1)`, [pair]);
  await sql(`DELETE FROM user_block WHERE blocker_id = ANY($1) AND blocked_id = ANY($1)`, [pair]);
  for (const f of s.follows) {
    await sql(`INSERT INTO follow VALUES ($1,$2,$3,$4,$5)`, [f.follower_id, f.followee_id, f.status, f.created_at, f.accepted_at]);
  }
  for (const f of s.friendships) {
    await sql(`INSERT INTO friendship VALUES ($1,$2,$3,$4,$5)`, [f.requester_id, f.addressee_id, f.status, f.created_at, f.accepted_at]);
  }
  for (const r of s.blocks) await sql(`INSERT INTO user_block VALUES ($1,$2,$3)`, [r.blocker_id, r.blocked_id, r.created_at]);
}

/** Subscribes to a private realtime channel; resolves with the final status. */
function subscribe(token: string, topic: string, events: string[], onEvent: (event: string, payload: any) => void) {
  const client = createClient(API, ANON, { auth: { persistSession: false, autoRefreshToken: false } });
  client.realtime.setAuth(token);
  let channel: RealtimeChannel = client.channel(topic, { config: { private: true, broadcast: { self: false } } });
  for (const e of events) channel = channel.on("broadcast", { event: e }, (m) => onEvent(e, m.payload));
  const status = new Promise<string>((resolve) => {
    channel.subscribe((s) => {
      if (s === "SUBSCRIBED" || s === "CHANNEL_ERROR" || s === "TIMED_OUT") resolve(s);
    });
    setTimeout(() => resolve("TIMED_OUT"), 8000);
  });
  return { channel, status, close: async () => await client.removeAllChannels() };
}

const waitFor = async (pred: () => boolean, ms = 6000) => {
  const until = Date.now() + ms;
  while (!pred() && Date.now() < until) await new Promise((r) => setTimeout(r, 100));
  return pred();
};

Deno.test({
  name: "features: people, chat and personal posts",
  ...suite,
  async fn(t) {
    const { check, assertAll } = checker();
    const [liam, kenji, daniel, zoe, natalia, amelia] = await Promise.all([
      signin("liam.oconnor@example.com"),
      signin("kenji.tanaka@example.com"),
      signin("daniel.kim@example.com"),
      signin("zoe.harrington@example.com"),
      signin("natalia.petrova@example.com"),
      signin("amelia.chang@example.com"),
    ]);
    const stamp = Date.now();

    await t.step("profiles, privacy and follows", async () => {
      const before = await call("GET", "/social/me", liam.token);
      const snap = await snapshotPair(liam.profile.id, zoe.profile.id);
      try {
        const edit = await call("PUT", "/social/me", liam.token, { bio: `Testing ${stamp}`, interests: ["Powerlifting", "running"] });
        check("edit bio and interests", edit.status === 200 && edit.data.bio === `Testing ${stamp}` && edit.data.interests.join() === "powerlifting,running", short(edit.data));
        const long = await call("PUT", "/social/me", liam.token, { bio: "x".repeat(301) });
        check("bio over 300 chars is 400", long.status === 400, `status ${long.status}`);
        const badWho = await call("PUT", "/social/me", liam.token, { who_can_message: "nobody" });
        check("unknown who_can_message is 400", badWho.status === 400, `status ${badWho.status}`);

        // Zoe is private. Without an accepted follow Liam sees her profile but not her posts.
        await call("DELETE", `/social/users/${zoe.profile.id}/follow`, liam.token);
        const profile = await call("GET", `/social/users/${zoe.profile.id}`, liam.token);
        check("private profile is findable", profile.status === 200 && profile.data.is_private === true && profile.data.can_view_content === false && profile.data.bio, short(profile.data));
        const hidden = await call("GET", `/posts?author_id=${zoe.profile.id}`, liam.token);
        check("private account's posts are 403", hidden.status === 403 && hidden.data.code === "private_account", short(hidden.data));
        const hiddenFollowers = await call("GET", `/social/users/${zoe.profile.id}/followers`, liam.token);
        check("private account's follower list is 403", hiddenFollowers.status === 403, `status ${hiddenFollowers.status}`);

        const follow = await call("POST", `/social/users/${zoe.profile.id}/follow`, liam.token);
        check("following a private account makes a request", follow.status === 200 && follow.data.relationship.following === "pending", short(follow.data));
        const requests = await call("GET", "/social/follow-requests", zoe.token);
        check("request shows for the private account", (requests.data as any[]).some((r) => r.id === liam.profile.id), short(requests.data));
        const notice = (await notificationsOf(zoe.token)).find((n) => n.type === "follow_request" && n.metadata?.user_id === liam.profile.id);
        check("follow_request notification", !!notice, short(notice));
        const accept = await call("POST", `/social/follow-requests/${liam.profile.id}/accept`, zoe.token);
        check("private account accepts", accept.status === 200 && accept.data.relationship.followed_by === "accepted", short(accept.data));
        const visible = await call("GET", `/posts?author_id=${zoe.profile.id}`, liam.token);
        const withMedia = (visible.data as any[])?.find((p) => p.images?.length);
        check("accepted follower sees the posts", visible.status === 200 && Array.isArray(visible.data), `status ${visible.status}`);
        if (withMedia) {
          const url = withMedia.images[0].url as string;
          check("media URL is a signed private URL", url.startsWith("/storage/v1/object/sign/user-media/"), url);
          check("signed URL downloads", (await fetchStatus(url)) === 200, url);
          const publicUrl = url.replace("/object/sign/", "/object/public/").replace(/\?.*$/, "");
          check("unsigned public URL is refused", (await fetchStatus(publicUrl)) >= 400, publicUrl);
        }
        await deleteNotifications(zoe.token, (n) => n.metadata?.user_id === liam.profile.id && n.type === "follow_request");
        await deleteNotifications(liam.token, (n) => n.metadata?.user_id === zoe.profile.id && n.type === "follow_accepted");
      } finally {
        await restorePair(liam.profile.id, zoe.profile.id, snap);
        await call("PUT", "/social/me", liam.token, { bio: before.data.bio, interests: before.data.interests });
      }
      assertAll();
    });

    await t.step("friends and blocks", async () => {
      const snapN = await snapshotPair(liam.profile.id, natalia.profile.id);
      const snapD = await snapshotPair(liam.profile.id, daniel.profile.id);
      try {
        // Natalia sent Liam a request in the seed; make sure one is pending.
        await sql(`DELETE FROM friendship WHERE requester_id = ANY($1) AND addressee_id = ANY($1)`, [[liam.profile.id, natalia.profile.id]]);
        await call("POST", `/social/users/${liam.profile.id}/friend`, natalia.token);
        const incoming = await call("GET", "/social/friend-requests", liam.token);
        check("incoming friend request listed", (incoming.data as any[]).some((r) => r.id === natalia.profile.id), short(incoming.data));
        const accept = await call("POST", `/social/users/${natalia.profile.id}/friend`, liam.token);
        check(
          "sending back accepts; friends follow each other",
          accept.data?.relationship?.friendship === "friends" && accept.data.relationship.following === "accepted" &&
            accept.data.relationship.followed_by === "accepted",
          short(accept.data),
        );
        const friends = await call("GET", `/social/users/${liam.profile.id}/friends`, natalia.token);
        check("friend appears in the list", (friends.data as any[]).some((u) => u.id === natalia.profile.id || u.id === liam.profile.id), `status ${friends.status}`);
        await deleteNotifications(liam.token, (n) => n.type === "friend_request" && n.metadata?.user_id === natalia.profile.id);
        await deleteNotifications(natalia.token, (n) => n.type === "friend_accepted" && n.metadata?.user_id === liam.profile.id);

        const block = await call("POST", `/social/users/${daniel.profile.id}/block`, liam.token);
        check("block", block.status === 200 && block.data.relationship.blocked === true && block.data.relationship.following === "none", short(block.data));
        const asDaniel = await call("GET", `/social/users/${liam.profile.id}`, daniel.token);
        check("blocked user can't see the blocker's profile", asDaniel.status === 404, `status ${asDaniel.status}`);
        const search = await call("GET", "/social/search?q=liam", daniel.token);
        check("blocker is hidden from search", !(search.data as any[]).some((u) => u.id === liam.profile.id), short(search.data));
        const dm = await call("POST", "/chat/conversations", daniel.token, { user_ids: [liam.profile.id] });
        check("blocked user can't start a chat", dm.status === 400, `status ${dm.status}`);
        const followBack = await call("POST", `/social/users/${liam.profile.id}/follow`, daniel.token);
        check("blocked user can't follow", followBack.status === 404, `status ${followBack.status}`);
        const blocks = await call("GET", "/social/blocks", liam.token);
        check("block list", (blocks.data as any[]).some((u) => u.id === daniel.profile.id), short(blocks.data));
        const unblock = await call("DELETE", `/social/users/${daniel.profile.id}/block`, liam.token);
        check("unblock", unblock.status === 200 && unblock.data.relationship.blocked === false, short(unblock.data));
      } finally {
        await restorePair(liam.profile.id, natalia.profile.id, snapN);
        await restorePair(liam.profile.id, daniel.profile.id, snapD);
      }
      assertAll();
    });

    await t.step("discovery", async () => {
      try {
        const search = await call("GET", "/social/search?q=kenji", liam.token);
        check("search finds by name", search.data?.[0]?.username === "kenjitanaka", short(search.data?.[0]));
        const suggestions = await call("GET", "/social/suggestions?page_size=50", liam.token);
        const following = (await sql<{ id: string }>(`SELECT followee_id AS id FROM follow WHERE follower_id = $1`, [liam.profile.id])) ?? [];
        check(
          "suggestions skip people I follow and carry reasons",
          suggestions.status === 200 && (suggestions.data as any[]).length > 0 &&
            (suggestions.data as any[]).every((s) => !following.some((f) => f.id === s.id) && Array.isArray(s.reasons)),
          short(suggestions.data?.[0]),
        );
        const sorted = (suggestions.data as any[]).every((s, i, a) => i === 0 || a[i - 1].score >= s.score);
        check("suggestions are ranked by score", sorted);
        await call("DELETE", "/social/me/location", liam.token);
        const noLoc = await call("GET", "/social/nearby", liam.token);
        check("nearby needs a location", noLoc.status === 409 && noLoc.data.code === "location_required", short(noLoc.data));
        const set = await call("PUT", "/social/me/location", liam.token, { lat: 40.68261, lng: -73.92981 });
        check("set location", set.status === 200, `status ${set.status}`);
        const stored = await sql<{ location_lat: number }>(`SELECT location_lat FROM users WHERE id = $1`, [liam.profile.id]);
        if (stored) check("location is stored rounded", stored[0].location_lat === 40.68, String(stored[0].location_lat));
        const nearby = await call("GET", "/social/nearby?radius_km=30", liam.token);
        check(
          "nearby lists people with rounded distance, never coordinates",
          nearby.status === 200 && (nearby.data as any[]).every((u) => Number.isInteger(u.distance_km) && !("location_lat" in u)),
          short(nearby.data?.[0]),
        );
        const badLoc = await call("PUT", "/social/me/location", liam.token, { lat: 123, lng: 0 });
        check("invalid coordinates are 400", badLoc.status === 400, `status ${badLoc.status}`);
      } finally {
        await call("DELETE", "/social/me/location", liam.token);
      }
      assertAll();
    });

    await t.step("chat: direct, uploads, reactions, realtime", async () => {
      const cleanup: (() => Promise<unknown>)[] = [];
      try {
        const open1 = await call("POST", "/chat/conversations", liam.token, { user_ids: [kenji.profile.id] });
        const open2 = await call("POST", "/chat/conversations", liam.token, { user_ids: [kenji.profile.id] });
        check("direct chat is get-or-create", open1.status === 200 && open1.data.id === open2.data.id && open1.data.kind === "direct", short(open1.data));
        const convId = open1.data.id as string;
        cleanup.push(() => sql(`DELETE FROM message WHERE conversation_id = $1 AND client_id LIKE 'it-%'`, [convId]));

        const realtime = await call("GET", "/chat/realtime", kenji.token);
        check("realtime config", realtime.status === 200 && !!realtime.data.anon_key && realtime.data.user_topic === `user:${kenji.profile.id}`, short(realtime.data));

        // Kenji listens on the conversation and his inbox; typing goes over chat-live.
        const got: { event: string; payload: any }[] = [];
        const chat = subscribe(kenji.token, `chat:${convId}`, ["message", "message_updated"], (event, payload) => got.push({ event, payload }));
        const inbox = subscribe(kenji.token, `user:${kenji.profile.id}`, ["inbox"], (event, payload) => got.push({ event, payload }));
        const typingSeen: any[] = [];
        const liveK = subscribe(kenji.token, `chat-live:${convId}`, ["typing"], (_e, p) => typingSeen.push(p));
        const liveL = subscribe(liam.token, `chat-live:${convId}`, [], () => {});
        cleanup.push(chat.close, inbox.close, liveK.close, liveL.close);
        check("participant joins chat:<id>", (await chat.status) === "SUBSCRIBED");
        check("user joins own user:<id>", (await inbox.status) === "SUBSCRIBED");
        check("participants join chat-live:<id>", (await liveK.status) === "SUBSCRIBED" && (await liveL.status) === "SUBSCRIBED");

        const someoneElse = subscribe(kenji.token, `user:${liam.profile.id}`, [], () => {});
        cleanup.push(someoneElse.close);
        check("can't join someone else's user topic", (await someoneElse.status) !== "SUBSCRIBED");
        const strangerChat = subscribe(zoe.token, `chat:${convId}`, [], () => {});
        cleanup.push(strangerChat.close);
        check("non-participant can't join chat:<id>", (await strangerChat.status) !== "SUBSCRIBED");

        await liveL.channel.send({ type: "broadcast", event: "typing", payload: { user_id: liam.profile.id, typing: true } });
        check("typing indicator reaches the other participant", await waitFor(() => typingSeen.some((p) => p.user_id === liam.profile.id)));

        const sent = await call("POST", `/chat/conversations/${convId}/messages`, liam.token, { body: `hello ${stamp}`, client_id: `it-${stamp}` });
        check("send message", sent.status === 201 && sent.data.body === `hello ${stamp}` && sent.data.sender.id === liam.profile.id, short(sent.data));
        const retry = await call("POST", `/chat/conversations/${convId}/messages`, liam.token, { body: `hello ${stamp}`, client_id: `it-${stamp}` });
        check("retry with the same client_id doesn't duplicate", retry.data?.id === sent.data.id, short(retry.data));
        check("message arrives over realtime", await waitFor(() => got.some((g) => g.event === "message" && g.payload.id === sent.data.id)));
        check("inbox event arrives", await waitFor(() => got.some((g) => g.event === "inbox" && g.payload.message_id === sent.data.id)));

        const outsider = await call("GET", `/chat/conversations/${convId}/messages`, zoe.token);
        check("non-participant can't read messages", outsider.status === 404, `status ${outsider.status}`);
        const page = await call("GET", `/chat/conversations/${convId}/messages?limit=5`, kenji.token);
        check("messages newest first", page.status === 200 && page.data[0].id === sent.data.id, short(page.data?.[0]));
        const after = await call("GET", `/chat/conversations/${convId}/messages?after_id=${page.data[1]?.id}`, kenji.token);
        check("after_id catches up", after.status === 200 && after.data.at(-1)?.id === sent.data.id, short(after.data));

        const react = await call("PUT", `/chat/messages/${sent.data.id}/reaction`, kenji.token, { reaction: "fire" });
        check("react to a message", react.status === 200 && react.data.reactions.some((r: any) => r.user_id === kenji.profile.id && r.reaction === "fire"), short(react.data));
        const badReact = await call("PUT", `/chat/messages/${sent.data.id}/reaction`, kenji.token, { reaction: "poop" });
        check("unknown reaction is 400", badReact.status === 400, `status ${badReact.status}`);
        check("reaction update arrives over realtime", await waitFor(() => got.some((g) => g.event === "message_updated" && g.payload.id === sent.data.id)));
        const editOther = await call("PUT", `/chat/messages/${sent.data.id}`, kenji.token, { body: "hacked" });
        check("can't edit someone else's message", editOther.status === 403, `status ${editOther.status}`);
        const edit = await call("PUT", `/chat/messages/${sent.data.id}`, liam.token, { body: "hello (edited)" });
        check("edit own message", edit.status === 200 && edit.data.body === "hello (edited)" && !!edit.data.edited_at, short(edit.data));

        // Attachment: reserve → upload straight to storage → attach.
        const slot = await call("POST", `/chat/conversations/${convId}/uploads`, liam.token, { mime_type: "image/png", size_bytes: PNG.length, file_name: "dot.png" });
        check("upload slot", slot.status === 201 && slot.data.path.startsWith(`${convId}/`) && slot.data.upload_url.startsWith("/storage/v1/"), short(slot.data));
        const tooBig = await call("POST", `/chat/conversations/${convId}/uploads`, liam.token, { mime_type: "video/mp4", size_bytes: 60 * 1024 * 1024 });
        check("over 50 MB is refused", tooBig.status === 413, `status ${tooBig.status}`);
        const strangerSlot = await call("POST", `/chat/conversations/${convId}/uploads`, zoe.token, { mime_type: "image/png", size_bytes: 10 });
        check("non-participant can't upload", strangerSlot.status === 404, `status ${strangerSlot.status}`);
        const early = await call("POST", `/chat/conversations/${convId}/messages`, liam.token, { attachments: [{ path: slot.data.path }], client_id: `it-early-${stamp}` });
        check("attaching before the upload finished is 400", early.status === 400, short(early.data));
        check("upload to storage", (await uploadTo(slot.data, PNG, "image/png")) === 200);
        const kenjiSteals = await call("POST", `/chat/conversations/${convId}/messages`, kenji.token, { attachments: [{ path: slot.data.path }] });
        check("someone else can't attach my upload", kenjiSteals.status === 400, `status ${kenjiSteals.status}`);
        const media = await call("POST", `/chat/conversations/${convId}/messages`, liam.token, {
          body: "pic",
          attachments: [{ path: slot.data.path, file_name: "dot.png", size_bytes: PNG.length, width: 1, height: 1 }],
          reply_to_id: sent.data.id,
          client_id: `it-media-${stamp}`,
        });
        const att = media.data?.attachments?.[0];
        check(
          "media message with a reply",
          media.status === 201 && att?.media_type === "image" && att.url.startsWith("/storage/v1/object/sign/chat-media/") &&
            media.data.reply_to?.id === sent.data.id,
          short(media.data),
        );
        check("participant downloads the attachment", (await fetchStatus(att.url)) === 200);
        const reuse = await call("POST", `/chat/conversations/${convId}/messages`, liam.token, { attachments: [{ path: slot.data.path }] });
        check("an upload can only be used once", reuse.status === 400, `status ${reuse.status}`);
        const gallery = await call("GET", `/chat/conversations/${convId}/media?type=media`, kenji.token);
        check("shared media gallery", (gallery.data as any[]).some((m) => m.message_id === media.data.id), `status ${gallery.status}`);
        const unsend = await call("DELETE", `/chat/messages/${media.data.id}`, liam.token);
        check("unsend", unsend.status === 200 && unsend.data.deleted_at && unsend.data.attachments.length === 0, short(unsend.data));
        check("unsent attachment is deleted from storage", (await fetchStatus(att.url)) >= 400);

        const read = await call("POST", `/chat/conversations/${convId}/read`, kenji.token);
        const detail = await call("GET", `/chat/conversations/${convId}`, liam.token);
        const kenjiRow = detail.data.members.find((m: any) => m.id === kenji.profile.id);
        check("read receipt visible to the other side", read.status === 200 && kenjiRow?.last_read_at === read.data.last_read_at, short(kenjiRow));
        const mute = await call("PUT", `/chat/conversations/${convId}/settings`, kenji.token, { muted: true });
        check("mute", mute.status === 200 && mute.data.muted === true, short(mute.data));
        await call("PUT", `/chat/conversations/${convId}/settings`, kenji.token, { muted: false });
      } finally {
        for (const c of cleanup.reverse()) await c();
      }
      assertAll();
    });

    await t.step("chat: message requests and groups", async () => {
      const convIds: string[] = [];
      try {
        // Amelia only takes messages from friends: Liam's DM is a request.
        const dm = await call("POST", "/chat/conversations", liam.token, { user_ids: [amelia.profile.id] });
        convIds.push(dm.data.id);
        await call("POST", `/chat/conversations/${dm.data.id}/messages`, liam.token, { body: "hi amelia" });
        const inbox = await call("GET", "/chat/conversations", amelia.token);
        const requests = await call("GET", "/chat/conversations?box=requests", amelia.token);
        check(
          "DM from a non-friend lands in requests",
          !(inbox.data as any[]).some((c) => c.id === dm.data.id) && (requests.data as any[]).some((c) => c.id === dm.data.id && c.my_status === "request"),
          short(requests.data),
        );
        const accept = await call("POST", `/chat/conversations/${dm.data.id}/accept`, amelia.token);
        check("accepting moves it to the inbox", accept.status === 200 && accept.data.my_status === "active", short(accept.data));

        const group = await call("POST", "/chat/conversations", liam.token, { user_ids: [kenji.profile.id, daniel.profile.id], title: `Test crew ${stamp}` });
        convIds.push(group.data.id);
        check("create a group", group.status === 201 && group.data.kind === "group" && group.data.my_role === "owner" && group.data.members.length === 3, short(group.data));
        const first = await call("GET", `/chat/conversations/${group.data.id}/messages`, kenji.token);
        check("group starts with a system message", first.data?.[0]?.kind === "system" && first.data[0].metadata.event === "created", short(first.data?.[0]));
        const memberAdds = await call("POST", `/chat/conversations/${group.data.id}/participants`, kenji.token, { user_ids: [natalia.profile.id] });
        check("plain members can't add people", memberAdds.status === 403, `status ${memberAdds.status}`);
        const promote = await call("PUT", `/chat/conversations/${group.data.id}/participants/${kenji.profile.id}`, liam.token, { role: "admin" });
        check("owner promotes an admin", promote.status === 200 && promote.data.members.find((m: any) => m.id === kenji.profile.id)?.role === "admin", short(promote.data?.members));
        const adminAdds = await call("POST", `/chat/conversations/${group.data.id}/participants`, kenji.token, { user_ids: [natalia.profile.id] });
        check("admin adds someone", adminAdds.status === 200 && adminAdds.data.members.length === 4, short(adminAdds.data?.members));
        const rename = await call("PUT", `/chat/conversations/${group.data.id}`, kenji.token, { title: "Renamed crew" });
        check("admin renames the group", rename.status === 200 && rename.data.title === "Renamed crew", short(rename.data));
        const removeOwner = await call("DELETE", `/chat/conversations/${group.data.id}/participants/${liam.profile.id}`, kenji.token);
        check("admins can't remove the owner", removeOwner.status === 403, `status ${removeOwner.status}`);
        const remove = await call("DELETE", `/chat/conversations/${group.data.id}/participants/${daniel.profile.id}`, kenji.token);
        const danielLooks = await call("GET", `/chat/conversations/${group.data.id}`, daniel.token);
        check("removed member loses access", remove.status === 204 && danielLooks.status === 404, `status ${remove.status}/${danielLooks.status}`);
        const ownerLeaves = await call("DELETE", `/chat/conversations/${group.data.id}/participants/${liam.profile.id}`, liam.token);
        const after = await call("GET", `/chat/conversations/${group.data.id}`, kenji.token);
        check("owner leaving hands ownership to an admin", ownerLeaves.status === 204 && after.data.my_role === "owner", short(after.data?.my_role));
        const msgs = await call("GET", `/chat/conversations/${group.data.id}/messages`, kenji.token);
        check("leave/remove/rename show as system messages", (msgs.data as any[]).filter((m) => m.kind === "system").length >= 4, String((msgs.data as any[]).length));
        await deleteNotifications(kenji.token, (n) => n.type === "group_added" && n.metadata?.conversation_id === group.data.id);
        await deleteNotifications(daniel.token, (n) => n.type === "group_added" && n.metadata?.conversation_id === group.data.id);
        await deleteNotifications(natalia.token, (n) => n.type === "group_added" && n.metadata?.conversation_id === group.data.id);
      } finally {
        for (const id of convIds) await sql(`DELETE FROM conversation WHERE id = $1`, [id]);
      }
      assertAll();
    });

    await t.step("personal posts: visibility, reactions, threads, feed", async () => {
      let postId: string | null = null;
      let publicPostId: string | null = null;
      // Someone who doesn't follow Liam.
      const outsiderRow = await sql<{ email: string }>(
        `SELECT u.email FROM users u WHERE u.id <> $1 AND u.auth_id IS NOT NULL
           AND NOT EXISTS (SELECT 1 FROM follow f WHERE f.follower_id = u.id AND f.followee_id = $1)
           AND NOT is_blocked_between(u.id, $1) ORDER BY u.email LIMIT 1`,
        [liam.profile.id],
      );
      const outsider = outsiderRow?.[0] ? await signin(outsiderRow[0].email) : null;
      try {
        const slot = await call("POST", "/posts/uploads", liam.token, { mime_type: "image/png", size_bytes: PNG.length });
        check("post upload slot", slot.status === 201 && slot.data.path.startsWith(`${liam.profile.id}/`), short(slot.data));
        const pdf = await call("POST", "/posts/uploads", liam.token, { mime_type: "application/pdf", size_bytes: 10 });
        check("posts only take photos and videos", pdf.status === 400, `status ${pdf.status}`);
        await uploadTo(slot.data, PNG, "image/png");
        const post = await call("POST", "/posts", liam.token, {
          content: `Followers only ${stamp}`,
          visibility: "followers",
          media: [{ path: slot.data.path, width: 1, height: 1 }],
        });
        postId = post.data?.id ?? null;
        check(
          "personal post with private media",
          post.status === 201 && post.data.kind === "personal" && post.data.business_id === null &&
            post.data.images[0]?.url?.startsWith("/storage/v1/object/sign/user-media/"),
          short(post.data),
        );
        const pub = await call("POST", "/posts", liam.token, { content: `Public ${stamp}`, visibility: "public" });
        publicPostId = pub.data?.id ?? null;
        const badVis = await call("POST", "/posts", liam.token, { content: "x", visibility: "secret" });
        check("unknown visibility is 400", badVis.status === 400, `status ${badVis.status}`);

        const asFollower = await call("GET", `/posts/${postId}`, kenji.token);
        check("follower sees a followers-only post", asFollower.status === 200, `status ${asFollower.status}`);
        const anon = await call("GET", `/posts/${postId}`);
        check("anonymous can't see a followers-only post", anon.status === 404, `status ${anon.status}`);
        const anonPublic = await call("GET", `/posts/${publicPostId}`);
        check("anonymous sees a public post of a public account", anonPublic.status === 200, `status ${anonPublic.status}`);
        if (outsider) {
          const asOutsider = await call("GET", `/posts/${postId}`, outsider.token);
          check("non-follower can't see a followers-only post", asOutsider.status === 404, `status ${asOutsider.status}`);
          const grid = await call("GET", `/posts?author_id=${liam.profile.id}`, outsider.token);
          check("non-follower's view of the profile grid skips it", grid.status === 200 && !(grid.data as any[]).some((p) => p.id === postId) && (grid.data as any[]).some((p) => p.id === publicPostId), `n=${grid.data?.length}`);
        }

        const feed = await call("GET", "/posts/feed?page_size=50", kenji.token);
        check("a follower's feed has the new post", (feed.data as any[]).some((p) => p.id === postId), `n=${feed.data?.length}`);
        const explore = await call("GET", "/posts/feed?mode=explore&page_size=50", kenji.token);
        check("explore leaves out people I follow", !(explore.data as any[]).some((p) => p.author_id === liam.profile.id), `n=${explore.data?.length}`);

        // Reactions: one per person, switching doesn't re-notify.
        const fire = await call("PUT", `/posts/${postId}/reaction`, kenji.token, { reaction: "fire" });
        check("react", fire.status === 200 && fire.data.reactions.counts.fire === 1 && fire.data.my_reaction === "fire", short(fire.data));
        const love = await call("PUT", `/posts/${postId}/reaction`, kenji.token, { reaction: "love" });
        check("switch reaction", love.data.reactions.counts.love === 1 && !love.data.reactions.counts.fire && love.data.reactions.total === 1, short(love.data));
        const reactNotes = (await notificationsOf(liam.token)).filter((n) => n.type === "post_reaction" && n.metadata?.post_id === postId);
        check("one notification for a reaction (not per switch)", reactNotes.length === 1, String(reactNotes.length));
        const legacy = await call("POST", `/posts/${postId}/like`, daniel.token);
        check("legacy like is a 'like' reaction", legacy.data?.my_reaction === "like" && legacy.data.like_count === 2, short(legacy.data));
        const who = await call("GET", `/posts/${postId}/reactions?reaction=love`, liam.token);
        check("who reacted, filtered", who.status === 200 && who.data.length === 1 && who.data[0].id === kenji.profile.id, short(who.data));
        const bad = await call("PUT", `/posts/${postId}/reaction`, kenji.token, { reaction: "meh" });
        check("unknown reaction is 400", bad.status === 400, `status ${bad.status}`);

        // A thread ten levels deep.
        const ids: string[] = [];
        for (let depth = 0; depth < 10; depth++) {
          const author = depth % 2 === 0 ? kenji : liam;
          const c = await call("POST", `/posts/${postId}/comments`, author.token, { body: `level ${depth}`, parent_id: ids.at(-1) });
          ids.push(c.data?.id);
          if (c.status !== 201 || c.data.depth !== depth) check(`reply at depth ${depth}`, false, short(c.data));
        }
        check("ten levels of replies", ids.every(Boolean));
        const tooDeep = await call("POST", `/posts/${postId}/comments`, kenji.token, { body: "level 10", parent_id: ids.at(-1) });
        check("an 11th level is refused", tooDeep.status === 400, short(tooDeep.data));
        const replyNote = (await notificationsOf(kenji.token)).find((n) => n.type === "comment_reply" && n.metadata?.parent_id === ids[0]);
        check("comment_reply notification to the parent's author", !!replyNote, short(replyNote));
        const tree = await call("GET", `/posts/${postId}/comments`, daniel.token);
        const rows = tree.data as any[];
        check(
          "thread comes back flat with depth and reply counts",
          rows.length === 10 && rows.find((r) => r.id === ids[0])?.reply_count === 1 && rows.find((r) => r.id === ids[9])?.can_reply === false,
          `n=${rows?.length}`,
        );
        const creact = await call("PUT", `/posts/comments/${ids[3]}/reaction`, daniel.token, { reaction: "haha" });
        check("react to a comment", creact.status === 200 && creact.data.reactions.counts.haha === 1 && creact.data.my_reaction === "haha", short(creact.data));
        const midDelete = await call("DELETE", `/posts/comments/${ids[4]}`, kenji.token);
        const afterMid = (await call("GET", `/posts/${postId}/comments`, daniel.token)).data as any[];
        const placeholder = afterMid.find((r) => r.id === ids[4]);
        check(
          "deleting a comment with replies leaves a placeholder",
          midDelete.status === 204 && placeholder?.deleted === true && placeholder.body === null && afterMid.length === 10,
          short(placeholder),
        );
        const replyToDeleted = await call("POST", `/posts/${postId}/comments`, liam.token, { body: "x", parent_id: ids[4] });
        check("can't reply to a deleted comment", replyToDeleted.status === 400, `status ${replyToDeleted.status}`);
        const leafDelete = await call("DELETE", `/posts/comments/${ids[9]}`, liam.token);
        const afterLeaf = (await call("GET", `/posts/${postId}/comments?sort=new`, daniel.token)).data as any[];
        check("deleting a leaf removes it", leafDelete.status === 204 && afterLeaf.length === 9, `n=${afterLeaf.length}`);
        const authorModerates = await call("DELETE", `/posts/comments/${ids[2]}`, liam.token);
        check("post author can delete others' comments on their post", authorModerates.status === 204, `status ${authorModerates.status}`);
        const badSort = await call("GET", `/posts/${postId}/comments?sort=hot`, daniel.token);
        check("unknown sort is 400", badSort.status === 400, `status ${badSort.status}`);

        const vis = await call("PUT", `/posts/${postId}`, liam.token, { visibility: "public" });
        check("change a post's visibility", vis.status === 200 && vis.data.visibility === "public", short(vis.data));
        const mediaUrl = post.data.images[0].url as string;
        const del = await call("DELETE", `/posts/${postId}`, liam.token);
        postId = null;
        check("deleting the post deletes its files", del.status === 204 && (await fetchStatus(mediaUrl)) >= 400);
      } finally {
        if (postId) await call("DELETE", `/posts/${postId}`, liam.token);
        if (publicPostId) await call("DELETE", `/posts/${publicPostId}`, liam.token);
        await deleteNotifications(liam.token, (n) => ["post_reaction", "post_comment", "comment_reply"].includes(n.type) && String(n.body ?? "").includes("level"));
        await deleteNotifications(liam.token, (n) => n.type === "post_reaction" && n.metadata?.user_id === kenji.profile.id && n.created_at > new Date(stamp).toISOString());
        await deleteNotifications(liam.token, (n) => n.type === "post_reaction" && n.metadata?.user_id === daniel.profile.id && n.created_at > new Date(stamp).toISOString());
        await deleteNotifications(kenji.token, (n) => n.type === "comment_reply" && String(n.body ?? "").startsWith("level"));
      }
      assertAll();
    });
  },
});
