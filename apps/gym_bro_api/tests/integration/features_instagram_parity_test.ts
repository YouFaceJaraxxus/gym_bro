// deno-lint-ignore-file no-explicit-any
// Instagram parity: hashtags, per-post settings (hidden like counts, comments
// off, location), pinned posts, saved posts and collections, liked posts,
// Reels, muting, website links, close friends (stories and notes), story
// polls, mentions and highlights, inbox notes, pinned chats, forwarding.
//
// Seeded graph relied on (checked up front): Liam (public) ↔ Elena follow
// each other; Liam ↔ Sofia (private) follow each other; Elena doesn't follow
// Sofia; Ravi follows none of them. Everything created is deleted in
// `finally`; mutes, close friends, notes and the website are reset.
import {
  call,
  checker,
  deleteNotifications,
  notificationsOf,
  PNG,
  seededUsers,
  short,
  signin,
  suite,
  uploadTo,
} from "./_client.ts";
import { dbAvailable, sql } from "./_db.ts";

const uniq = () => `it${crypto.randomUUID().slice(0, 8)}`;

Deno.test({
  name: "features: instagram parity",
  ...suite,
  async fn(t) {
    const { check, assertAll } = checker();
    const { member, trainer, vendor } = await seededUsers();
    const priv = await signin("sofia.rossi@example.com");
    const tag = uniq();
    const id = { member: member.profile.id, trainer: trainer.profile.id, priv: priv.profile.id, vendor: vendor.profile.id };

    const following = async (who: { token: string }, target: string) =>
      (await call("GET", `/social/users/${target}`, who.token)).data?.relationship?.following;
    const pre = await Promise.all([
      following(trainer, id.member),
      following(member, id.trainer),
      following(member, id.priv),
      following(trainer, id.priv),
      following(vendor, id.member),
    ]);
    check(
      "seeded follow graph is as this suite expects",
      pre[0] === "accepted" && pre[1] === "accepted" && pre[2] === "accepted" && pre[3] === "none" && pre[4] === "none",
      short(pre),
    );

    const posts: { id: string; token: string }[] = [];
    const stories: { id: string; token: string }[] = [];
    const messages: { id: string; token: string }[] = [];
    const collections: string[] = [];
    const highlights: string[] = [];
    let website: string | null = null;

    const newPost = async (who: { token: string }, body: Record<string, unknown>) => {
      const r = await call("POST", "/posts", who.token, body);
      if (r.data?.id) posts.push({ id: r.data.id, token: who.token });
      return r;
    };
    const newStory = async (who: { token: string }, body: Record<string, unknown>) => {
      const r = await call("POST", "/stories", who.token, body);
      if (r.data?.id) stories.push({ id: r.data.id, token: who.token });
      return r;
    };
    const send = async (who: { token: string }, conversationId: string, body: Record<string, unknown>) => {
      const r = await call("POST", `/chat/conversations/${conversationId}/messages`, who.token, body);
      if (r.data?.id) messages.push({ id: r.data.id, token: who.token });
      return r;
    };
    const ids = (r: { data: any }) => ((r.data ?? []) as any[]).map((p) => p.id);

    try {
      website = (await call("GET", "/social/me", member.token)).data?.website ?? null;

      await t.step("hashtags", async () => {
        const a = await newPost(member, { content: `Leg day #${tag} #LegDay_${tag} and #10 reps` });
        const b = await newPost(priv, { content: `Private #${tag}` });
        check("posts with hashtags are created", a.status === 201 && b.status === 201, `${a.status}/${b.status}`);

        const search = await call("GET", `/posts/hashtags?q=%23${tag.slice(0, 6)}`, trainer.token);
        const found = (search.data as any[])?.find((h) => h.tag === tag);
        check(
          "tag search finds the lowercased tag with its count, and #10 isn't a tag",
          search.status === 200 && found?.post_count === 2 &&
            (await call("GET", `/posts/hashtags?q=LegDay_${tag.slice(0, 4)}`, trainer.token)).data
              ?.some((h: any) => h.tag === `legday_${tag}`) &&
            !(await call("GET", "/posts/hashtags/10", trainer.token)).data?.post_count,
          short(search.data),
        );
        const page = await call("GET", `/posts/hashtags/${tag.toUpperCase()}`, trainer.token);
        check("the tag page header", page.status === 200 && page.data.tag === tag && page.data.post_count === 2, short(page.data));

        const asTrainer = await call("GET", `/posts?hashtag=${tag}&sort=recent`, trainer.token);
        const asMember = await call("GET", `/posts?hashtag=${encodeURIComponent(`#${tag}`)}`, member.token);
        check(
          "tag posts respect visibility: Elena doesn't see Sofia's private post, Liam (her follower) does",
          ids(asTrainer).includes(a.data.id) && !ids(asTrainer).includes(b.data.id) &&
            ids(asMember).includes(a.data.id) && ids(asMember).includes(b.data.id),
          `${short(ids(asTrainer))} / ${short(ids(asMember))}`,
        );

        const edited = await call("PUT", `/posts/${a.data.id}`, member.token, { content: "No tags now" });
        const after = await call("GET", `/posts/hashtags/${tag}`, trainer.token);
        check("editing the caption re-syncs its tags", edited.status === 200 && after.data?.post_count === 1, short(after.data));
      });

      await t.step("per-post settings: hidden like counts, comments off, location", async () => {
        const p = await newPost(member, {
          content: `${tag} settings`,
          hide_like_count: true,
          comments_disabled: true,
          location_name: "  Ironclad Fitness ",
        });
        check(
          "settings are stored",
          p.status === 201 && p.data.hide_like_count === true && p.data.comments_disabled === true &&
            p.data.location_name === "Ironclad Fitness",
          short(p.data),
        );
        const reacted = await call("PUT", `/posts/${p.data.id}/reaction`, trainer.token, { reaction: "fire" });
        const theirs = await call("GET", `/posts/${p.data.id}`, trainer.token);
        const mine = await call("GET", `/posts/${p.data.id}`, member.token);
        check(
          "others don't see the count (but see which reactions); the author does",
          reacted.data?.reactions?.total === 0 && theirs.data.reactions.total === 0 &&
            theirs.data.reactions.top.includes("fire") && theirs.data.my_reaction === "fire" &&
            mine.data.reactions.total === 1 && mine.data.like_count === 1,
          `${short(theirs.data.reactions)} / ${short(mine.data.reactions)}`,
        );
        const comment = await call("POST", `/posts/${p.data.id}/comments`, trainer.token, { body: "nice" });
        const own = await call("POST", `/posts/${p.data.id}/comments`, member.token, { body: "mine" });
        check(
          "commenting is off for everyone",
          comment.status === 403 && comment.data.code === "comments_disabled" && own.status === 403,
          `${comment.status}/${own.status}`,
        );
        const on = await call("PUT", `/posts/${p.data.id}`, member.token, { comments_disabled: false, location_name: null });
        const later = await call("POST", `/posts/${p.data.id}/comments`, trainer.token, { body: "nice" });
        check(
          "turning comments back on works; location cleared",
          on.status === 200 && on.data.location_name === null && later.status === 201,
          `${on.status}/${later.status}`,
        );
        const bad = await call("PUT", `/posts/${p.data.id}`, member.token, { hide_like_count: "yes" });
        const long = await call("POST", "/posts", member.token, { content: "x", location_name: "x".repeat(101) });
        check("validation", bad.status === 400 && long.status === 400, `${bad.status}/${long.status}`);
        await call("DELETE", `/posts/${p.data.id}/reaction`, trainer.token);
      });

      await t.step("pinned posts", async () => {
        const made = [];
        for (let i = 0; i < 4; i++) made.push((await newPost(member, { content: `${tag} pin ${i}` })).data.id);
        for (const p of made.slice(0, 3)) await call("PUT", `/posts/${p}/pin`, member.token);
        const fourth = await call("PUT", `/posts/${made[3]}/pin`, member.token);
        const again = await call("PUT", `/posts/${made[0]}/pin`, member.token);
        check(
          "up to three; pinning a pinned post again is fine",
          fourth.status === 409 && fourth.data.code === "pin_limit" && again.status === 200 && again.data.pinned,
          `${fourth.status}/${again.status}`,
        );
        const notMine = await call("PUT", `/posts/${made[3]}/pin`, trainer.token);
        check("only the author pins", notMine.status === 403, String(notMine.status));
        const grid = await call("GET", `/posts?author_id=${id.member}&page_size=5`, trainer.token);
        check(
          "pinned posts lead the profile, most recently pinned first",
          short(ids(grid).slice(0, 3)) === short([made[2], made[1], made[0]]),
          short(ids(grid)),
        );
        const archived = await call("PUT", `/posts/${made[2]}/archive`, member.token);
        const unpinned = await call("DELETE", `/posts/${made[1]}/pin`, member.token);
        check(
          "archiving unpins; unpinning works",
          archived.data?.pinned === false && unpinned.data?.pinned === false,
          `${archived.data?.pinned}/${unpinned.data?.pinned}`,
        );
        await call("DELETE", `/posts/${made[0]}/pin`, member.token);
      });

      await t.step("saved posts and collections", async () => {
        const mine = (await newPost(member, { content: `${tag} save me` })).data.id;
        const hers = (await newPost(priv, { content: `${tag} private save` })).data.id;

        const saved = await call("PUT", `/posts/${mine}/save`, trainer.token);
        const decorated = await call("GET", `/posts/${mine}`, trainer.token);
        const cantSee = await call("PUT", `/posts/${hers}/save`, trainer.token);
        check(
          "saving a visible post; a post I can't see is 404",
          saved.data?.saved === true && decorated.data.saved_by_me === true && cantSee.status === 404,
          `${short(saved.data)} / ${cantSee.status}`,
        );

        const col = await call("POST", "/posts/collections", member.token, { name: `${tag} Gains`, post_ids: [hers] });
        if (col.data?.id) collections.push(col.data.id);
        const dup = await call("POST", "/posts/collections", member.token, { name: `${tag} gains` });
        check(
          "a collection is created with a post (saving it); names are unique per person, case-insensitively",
          col.status === 201 && col.data.post_count === 1 && col.data.covers.length === 0 && dup.status === 409,
          `${short(col.data)} / ${dup.status}`,
        );
        const filed = await call("PUT", `/posts/collections/${col.data.id}/posts/${mine}`, member.token);
        const overview = await call("GET", `/posts/collections?post_id=${mine}`, member.token);
        const c = overview.data.collections.find((x: any) => x.id === col.data.id);
        check(
          "filing a post saves it; the overview counts both and marks the collection holding it",
          filed.status === 200 && overview.data.saved.post_count >= 2 && overview.data.post_saved === true &&
            c?.post_count === 2 && c.contains_post === true,
          short(overview.data),
        );
        const list = await call("GET", `/posts/saved?collection_id=${col.data.id}`, member.token);
        check("a collection lists its posts, newest first", short(ids(list)) === short([mine, hers]), short(ids(list)));
        const others = await call("GET", `/posts/saved?collection_id=${col.data.id}`, trainer.token);
        check("someone else's collection is 404", others.status === 404, String(others.status));

        const renamed = await call("PUT", `/posts/collections/${col.data.id}`, member.token, { name: `${tag} Cut` });
        const out = await call("DELETE", `/posts/collections/${col.data.id}/posts/${mine}`, member.token);
        const stillSaved = await call("GET", "/posts/saved", member.token);
        check(
          "rename; taking a post out of a collection keeps it saved",
          renamed.data?.name === `${tag} Cut` && out.status === 204 && ids(stillSaved).includes(mine),
          `${short(renamed.data)} / ${out.status}`,
        );
        await call("PUT", `/posts/${mine}/save`, member.token, { collection_id: col.data.id });
        const unsave = await call("DELETE", `/posts/${mine}/save`, member.token);
        const after = await call("GET", `/posts/collections?post_id=${mine}`, member.token);
        check(
          "unsaving removes it from every collection",
          unsave.data?.saved === false && after.data.post_saved === false &&
            after.data.collections.find((x: any) => x.id === col.data.id)?.contains_post === false,
          short(after.data),
        );
        const del = await call("DELETE", `/posts/collections/${col.data.id}`, member.token);
        const herStillSaved = await call("GET", "/posts/saved", member.token);
        check(
          "deleting a collection keeps its posts saved",
          del.status === 204 && ids(herStillSaved).includes(hers),
          String(del.status),
        );
        await call("DELETE", `/posts/${mine}/save`, trainer.token);
        await call("DELETE", `/posts/${hers}/save`, member.token);
      });

      await t.step("liked posts, reels and muting posts", async () => {
        const p = (await newPost(member, { content: `${tag} like me` })).data.id;
        await call("PUT", `/posts/${p}/reaction`, trainer.token, { reaction: "like" });
        const liked = await call("GET", "/posts/liked", trainer.token);
        check("posts I reacted to, most recent first", liked.data?.[0]?.id === p, short(ids(liked).slice(0, 3)));
        await call("DELETE", `/posts/${p}/reaction`, trainer.token);

        const slot = await call("POST", "/posts/uploads", member.token, { mime_type: "video/mp4", size_bytes: PNG.length });
        await uploadTo(slot.data, PNG, "video/mp4");
        const video = await newPost(member, { content: `${tag} reel`, media: [{ path: slot.data.path, duration_ms: 3000 }] });
        const photoSlot = await call("POST", "/posts/uploads", member.token, { mime_type: "image/png", size_bytes: PNG.length });
        await uploadTo(photoSlot.data, PNG, "image/png");
        const photo = await newPost(member, { content: `${tag} photo`, media: [{ path: photoSlot.data.path }] });
        const reels = await call("GET", "/posts/feed?mode=reels&page_size=50", trainer.token);
        check(
          "reels: posts opening with a video, not photos",
          video.status === 201 && ids(reels).includes(video.data.id) && !ids(reels).includes(photo.data.id),
          short(ids(reels).slice(0, 5)),
        );

        const home = async () => ids(await call("GET", "/posts/feed?page_size=50", trainer.token));
        const before = await home();
        const mute = await call("PUT", `/social/users/${id.member}/mute`, trainer.token, { posts: true, stories: false });
        const muted = await home();
        const profile = await call("GET", `/social/users/${id.member}`, trainer.token);
        const grid = await call("GET", `/posts?author_id=${id.member}&page_size=50`, trainer.token);
        check(
          "muting someone's posts drops them from my feed but not their profile; they're marked muted for me",
          before.includes(p) && mute.status === 200 && !muted.includes(p) && profile.data.muted?.posts === true &&
            ids(grid).includes(p),
          `${before.includes(p)}/${muted.includes(p)}/${short(profile.data.muted)}`,
        );
        const mutes = await call("GET", "/social/mutes", trainer.token);
        check(
          "the mutes list",
          (mutes.data as any[]).some((u) => u.id === id.member && u.muted.posts && !u.muted.stories),
          short(mutes.data),
        );
        await call("DELETE", `/social/users/${id.member}/mute`, trainer.token);
        const unmuted = await home();
        const self = await call("PUT", `/social/users/${id.trainer}/mute`, trainer.token, { posts: true, stories: true });
        check("unmuting; can't mute yourself", unmuted.includes(p) && self.status === 400, String(self.status));
      });

      await t.step("website on the profile", async () => {
        const set = await call("PUT", "/social/me", member.token, { website: "ironclad.example.com/liam" });
        const bad = await call("PUT", "/social/me", member.token, { website: "not a site" });
        const js = await call("PUT", "/social/me", member.token, { website: "javascript:alert(1)" });
        const seen = await call("GET", `/social/users/${id.member}`, vendor.token);
        check(
          "a website gets https:// and shows to others; junk is refused",
          set.data?.website === "https://ironclad.example.com/liam" && bad.status === 400 && js.status === 400 &&
            seen.data.website === "https://ironclad.example.com/liam",
          `${short(set.data?.website)} ${bad.status}/${js.status}`,
        );
      });

      await t.step("close friends and close-friends stories", async () => {
        const story = await newStory(member, { caption: `${tag} cf`, audience: "close_friends" });
        const open = await newStory(member, { caption: `${tag} open` });
        const before = await call("GET", `/stories?user_id=${id.member}`, trainer.token);
        check(
          "a close-friends story is hidden from followers who aren't close friends",
          story.status === 201 && story.data.close_friends === true && ids(before).includes(open.data.id) &&
            !ids(before).includes(story.data.id),
          short(ids(before)),
        );
        const add = await call("PUT", `/social/close-friends/${id.trainer}`, member.token);
        const list = await call("GET", "/social/close-friends", member.token);
        const after = await call("GET", `/stories?user_id=${id.member}`, trainer.token);
        const tray = await call("GET", "/stories/feed", trainer.token);
        const profile = await call("GET", `/social/users/${id.trainer}`, member.token);
        check(
          "once added they see it, the tray marks it green, and the profile says so (to me)",
          add.data?.is_close_friend === true && ids(list).includes(id.trainer) && ids(after).includes(story.data.id) &&
            (tray.data as any[]).find((e) => e.user.id === id.member)?.close_friends === true &&
            profile.data.is_close_friend === true,
          short(ids(after)),
        );
        const stranger = await call("GET", `/stories/${story.data.id}`, vendor.token);
        check("others still can't open it", stranger.status === 404, String(stranger.status));

        await call("PUT", `/social/users/${id.member}/mute`, trainer.token, { posts: false, stories: true });
        const mutedTray = await call("GET", "/stories/feed", trainer.token);
        check(
          "muting someone's stories takes them out of my tray",
          !(mutedTray.data as any[]).some((e) => e.user.id === id.member),
          short((mutedTray.data as any[]).map((e) => e.user.username)),
        );
        await call("DELETE", `/social/users/${id.member}/mute`, trainer.token);
      });

      await t.step("story polls and mentions", async () => {
        const bad = await call("POST", "/stories", member.token, { poll: { question: "?", options: ["only one"] } });
        const poll = await newStory(member, {
          caption: `Which? @${trainer.profile.username}`,
          poll: { question: "Squat or deadlift?", options: ["Squat", "Deadlift"] },
        });
        check(
          "a poll story; a poll needs 2–4 options; @username becomes a mention",
          bad.status === 400 && poll.status === 201 && poll.data.poll.question === "Squat or deadlift?" &&
            poll.data.poll.counts?.join() === "0,0" && poll.data.caption.includes(`(user:${id.trainer})`),
          short(poll.data),
        );
        const fresh = await call("GET", `/stories/${poll.data.id}`, trainer.token);
        check(
          "results are hidden until I vote",
          fresh.data.poll.counts === null && fresh.data.poll.my_vote === null,
          short(fresh.data.poll),
        );
        const vote = await call("PUT", `/stories/${poll.data.id}/vote`, trainer.token, { option: 1 });
        const outOfRange = await call("PUT", `/stories/${poll.data.id}/vote`, trainer.token, { option: 2 });
        const own = await call("PUT", `/stories/${poll.data.id}/vote`, member.token, { option: 0 });
        check(
          "voting shows results; bad options and voting in my own poll are refused",
          vote.data?.poll?.my_vote === 1 && vote.data.poll.counts.join() === "0,1" && outOfRange.status === 400 &&
            own.status === 400,
          `${short(vote.data?.poll)} ${outOfRange.status}/${own.status}`,
        );
        const viewers = await call("GET", `/stories/${poll.data.id}/viewers`, member.token);
        check(
          "the author sees who voted for what",
          (viewers.data as any[]).find((v) => v.user.id === id.trainer)?.poll_vote === 1,
          short(viewers.data),
        );
        const notes = await notificationsOf(trainer.token);
        check(
          "the mentioned person is told",
          notes.some((n) => n.type === "story_mention" && n.metadata?.story_id === poll.data.id),
          short(notes.slice(0, 2)),
        );
      });

      await t.step("highlights", async () => {
        const a = await newStory(member, { caption: `${tag} h1` });
        const b = await newStory(member, { caption: `${tag} h2`, background: "#112233" });
        const cf = await newStory(member, { caption: `${tag} h-cf`, audience: "close_friends" });
        const theirs = await newStory(trainer, { caption: `${tag} not yours` });
        const foreign = await call("POST", "/stories/highlights", member.token, { title: "x", story_ids: [theirs.data.id] });
        const h = await call("POST", "/stories/highlights", member.token, {
          title: `${tag} Gym`.slice(0, 30),
          story_ids: [a.data.id, b.data.id, cf.data.id],
          cover_story_id: b.data.id,
        });
        if (h.data?.id) highlights.push(h.data.id);
        check(
          "a highlight of my own stories, with a cover",
          foreign.status === 400 && h.status === 201 && h.data.story_count === 3 && h.data.cover.story_id === b.data.id &&
            h.data.cover.background === "#112233",
          short(h.data),
        );
        if (await dbAvailable()) {
          await sql(
            "UPDATE story SET created_at = created_at - INTERVAL '25 hours', expires_at = NOW() - INTERVAL '1 hour' WHERE id = ANY($1)",
            [[a.data.id, b.data.id, cf.data.id]],
          );
        }
        const asStranger = await call("GET", `/stories/highlights?user_id=${id.member}`, vendor.token);
        const detail = await call("GET", `/stories/highlights/${h.data.id}`, vendor.token);
        const asCloseFriend = await call("GET", `/stories/highlights/${h.data.id}`, trainer.token);
        check(
          "expired stories stay in the highlight for everyone who can see the profile; close-friends ones only for them",
          asStranger.data.find((x: any) => x.id === h.data.id)?.story_count === 2 &&
            short(ids({ data: detail.data.stories })) === short([a.data.id, b.data.id]) &&
            detail.data.stories.every((s: any) => s.is_live === false) &&
            ids({ data: asCloseFriend.data.stories }).includes(cf.data.id),
          `${short(ids({ data: detail.data?.stories }))} / ${short(ids({ data: asCloseFriend.data?.stories }))}`,
        );
        const edit = await call("PUT", `/stories/highlights/${h.data.id}`, member.token, {
          title: "Renamed",
          remove_story_ids: [b.data.id],
        });
        const notOwner = await call("PUT", `/stories/highlights/${h.data.id}`, trainer.token, { title: "Mine" });
        const empty = await call("PUT", `/stories/highlights/${h.data.id}`, member.token, { story_ids: [] });
        check(
          "rename + remove (the cover falls back); only the owner edits; can't empty it",
          edit.data?.title === "Renamed" && edit.data.story_count === 2 && edit.data.cover_story_id === null &&
            notOwner.status === 403 && empty.status === 400,
          `${short(edit.data)} ${notOwner.status}/${empty.status}`,
        );
        const blocked = await call("POST", `/social/users/${id.vendor}/block`, member.token);
        const hidden = await call("GET", `/stories/highlights/${h.data.id}`, vendor.token);
        await call("DELETE", `/social/users/${id.vendor}/block`, member.token);
        check("blocked people can't see highlights", blocked.status === 200 && hidden.status === 404, String(hidden.status));
      });

      await t.step("notes", async () => {
        const long = await call("PUT", "/chat/notes", member.token, { body: "x".repeat(61) });
        const put = await call("PUT", "/chat/notes", member.token, { body: `${tag} leg day 🦵` });
        check("a note (≤ 60 characters)", long.status === 400 && put.data?.mine?.body === `${tag} leg day 🦵`, short(put.data));
        const mutual = await call("GET", "/chat/notes", trainer.token);
        const stranger = await call("GET", "/chat/notes", vendor.token);
        check(
          "people who follow each other with me see it; others don't",
          mutual.data.notes.some((n: any) => n.user.id === id.member) &&
            !stranger.data.notes.some((n: any) => n.user.id === id.member),
          short(mutual.data.notes),
        );
        await call("DELETE", `/social/close-friends/${id.trainer}`, member.token);
        await call("PUT", "/chat/notes", member.token, { body: `${tag} cf only`, audience: "close_friends" });
        const notClose = await call("GET", "/chat/notes", trainer.token);
        await call("PUT", `/social/close-friends/${id.vendor}`, member.token);
        const close = await call("GET", "/chat/notes", vendor.token);
        check(
          "a close-friends note: only close friends, even if they don't follow each other",
          !notClose.data.notes.some((n: any) => n.user.id === id.member) &&
            close.data.notes.some((n: any) => n.user.id === id.member),
          `${short(notClose.data.notes)} / ${short(close.data.notes)}`,
        );
        const reply = await call("POST", `/chat/notes/${id.member}/replies`, vendor.token, { body: "same" });
        if (reply.data?.id) messages.push({ id: reply.data.id, token: vendor.token });
        const cantReply = await call("POST", `/chat/notes/${id.member}/replies`, trainer.token, { body: "hm" });
        check(
          "a reply lands in their DMs with the note attached; you can't reply to a note you can't see",
          reply.status === 201 && reply.data.metadata?.note_reply?.body === `${tag} cf only` && cantReply.status === 404,
          `${short(reply.data?.metadata)} ${cantReply.status}`,
        );
        const del = await call("DELETE", "/chat/notes", member.token);
        check("deleting my note", del.data?.mine === null, short(del.data));
      });

      await t.step("pinned chats and forwarding", async () => {
        const groups = [];
        for (let i = 0; i < 4; i++) {
          const g = await call("POST", "/chat/conversations", member.token, {
            user_ids: [id.trainer],
            title: `${tag} g${i}`,
          });
          groups.push(g.data.id);
        }
        try {
          for (const g of groups.slice(0, 3)) await call("PUT", `/chat/conversations/${g}/settings`, member.token, { pinned: true });
          const fourth = await call("PUT", `/chat/conversations/${groups[3]}/settings`, member.token, { pinned: true });
          const inbox = await call("GET", "/chat/conversations", member.token);
          check(
            "up to three pinned chats, leading the inbox",
            fourth.status === 409 && fourth.data.code === "pin_limit" &&
              short(ids(inbox).slice(0, 3)) === short([groups[2], groups[1], groups[0]]) && inbox.data[0].pinned === true,
            short(ids(inbox).slice(0, 4)),
          );
          const unpin = await call("PUT", `/chat/conversations/${groups[2]}/settings`, member.token, { pinned: false });
          check("unpinning", unpin.data?.pinned === false, short(unpin.data));

          const text = await send(member, groups[0], { body: `${tag} forward me` });
          const slot = await call("POST", `/chat/conversations/${groups[0]}/uploads`, member.token, {
            mime_type: "audio/mp4",
            file_name: "voice.m4a",
            size_bytes: PNG.length,
          });
          await uploadTo(slot.data, PNG, "audio/mp4");
          const voice = await send(member, groups[0], {
            attachments: [{ path: slot.data.path, size_bytes: PNG.length, duration_ms: 1500, file_name: "voice.m4a" }],
          });
          const fwd = await call("POST", `/chat/messages/${text.data.id}/forward`, trainer.token, {
            conversation_ids: [groups[1]],
            user_ids: [id.member],
          });
          for (const r of fwd.data?.results ?? []) if (r.message_id) messages.push({ id: r.message_id, token: trainer.token });
          const copy = await call("GET", `/chat/messages/${fwd.data?.results?.[0]?.message_id}`, trainer.token);
          check(
            "forwarding text to a chat and a person, marked forwarded",
            fwd.status === 201 && fwd.data.sent === 2 && copy.data.body === `${tag} forward me` &&
              copy.data.metadata?.forwarded === true && copy.data.sender_id === id.trainer,
            short(fwd.data),
          );
          const fwdVoice = await call("POST", `/chat/messages/${voice.data.id}/forward`, member.token, {
            conversation_ids: [groups[1]],
          });
          const voiceId = fwdVoice.data?.results?.[0]?.message_id;
          if (voiceId) messages.push({ id: voiceId, token: member.token });
          const voiceCopy = await call("GET", `/chat/messages/${voiceId}`, member.token);
          const att = voiceCopy.data?.attachments?.[0];
          check(
            "forwarding a voice message copies the file into the other chat",
            fwdVoice.status === 201 && att?.media_type === "audio" && att.duration_ms === 1500 &&
              att.url?.startsWith("/storage/v1/") && !att.url.includes(groups[0]),
            short(att),
          );
          const outsider = await call("POST", `/chat/messages/${text.data.id}/forward`, vendor.token, { user_ids: [id.member] });
          check("you can only forward what you can see", outsider.status === 404, String(outsider.status));
        } finally {
          for (const g of groups) {
            await call("DELETE", `/chat/conversations/${g}`, member.token);
          }
        }
      });
      assertAll();
    } finally {
      for (const s of stories) await call("DELETE", `/stories/${s.id}`, s.token);
      for (const m of messages) await call("DELETE", `/chat/messages/${m.id}`, m.token);
      for (const p of posts) await call("DELETE", `/posts/${p.id}`, p.token);
      for (const c of collections) await call("DELETE", `/posts/collections/${c}`, member.token);
      for (const h of highlights) await call("DELETE", `/stories/highlights/${h}`, member.token);
      await call("DELETE", "/chat/notes", member.token);
      await call("DELETE", `/social/close-friends/${id.trainer}`, member.token);
      await call("DELETE", `/social/close-friends/${id.vendor}`, member.token);
      await call("DELETE", `/social/users/${id.member}/mute`, trainer.token);
      await call("PUT", "/social/me", member.token, { website });
      await deleteNotifications(trainer.token, (n) => n.type === "story_mention" || n.type === "mention");
      await deleteNotifications(member.token, (n) => n.type === "post_reaction" || n.type === "post_comment");
    }
  },
});
