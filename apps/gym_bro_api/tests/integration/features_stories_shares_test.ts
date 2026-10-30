// deno-lint-ignore-file no-explicit-any
// Stories (posting, the tray, views, likes + notifications, viewers, replies
// and emoji reactions in DMs, expiry, archive), sharing things in chat with
// per-viewer visibility ("private" / "unavailable" / "expired"), stories
// sharing things, and archiving posts.
//
// Seeded graph relied on (checked up front): Liam (public) ↔ Elena follow
// each other; Liam ↔ Sofia (private) follow each other; Elena doesn't follow
// Sofia; Ravi follows none of them. Everything created is deleted in
// `finally` (stories, posts, routines, sessions, notifications; chat
// messages are unsent).
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

const uniq = () => `it-${crypto.randomUUID().slice(0, 8)}`;

Deno.test({
  name: "features: stories, sharing in chat, archive",
  ...suite,
  async fn(t) {
    const { check, assertAll } = checker();
    const { member, trainer, vendor } = await seededUsers();
    const priv = await signin("sofia.rossi@example.com");
    const name = uniq();
    const id = { member: member.profile.id, trainer: trainer.profile.id, priv: priv.profile.id, vendor: vendor.profile.id };

    const following = async (who: { token: string }, target: string) =>
      (await call("GET", `/social/users/${target}`, who.token)).data?.relationship?.following;
    const pre = await Promise.all([
      following(trainer, id.member),
      following(member, id.priv),
      following(trainer, id.priv),
      following(vendor, id.priv),
      following(vendor, id.member),
    ]);
    check(
      "seeded follow graph is as this suite expects",
      pre[0] === "accepted" && pre[1] === "accepted" && pre[2] === "none" && pre[3] === "none" && pre[4] === "none",
      short(pre),
    );

    const stories: string[] = [];
    const storyOwner = new Map<string, string>();
    const posts: { id: string; token: string }[] = [];
    const messages: { id: string; token: string }[] = [];
    const sessions: string[] = [];
    let routineId: string | null = null;

    const newStory = async (who: { token: string }, body: Record<string, unknown>) => {
      const r = await call("POST", "/stories", who.token, body);
      if (r.data?.id) {
        stories.push(r.data.id);
        storyOwner.set(r.data.id, who.token);
      }
      return r;
    };
    const photoStory = async (who: { token: string }, caption: string) => {
      const slot = await call("POST", "/stories/uploads", who.token, { mime_type: "image/png", size_bytes: PNG.length });
      await uploadTo(slot.data, PNG, "image/png");
      return await newStory(who, { media: { path: slot.data?.path, width: 1, height: 1 }, caption });
    };
    const newPost = async (who: { token: string }, body: Record<string, unknown>) => {
      const r = await call("POST", "/posts", who.token, body);
      if (r.data?.id) posts.push({ id: r.data.id, token: who.token });
      return r;
    };
    const getMessage = (who: { token: string }, messageId: string) => call("GET", `/chat/messages/${messageId}`, who.token);
    const shareTo = async (who: { token: string }, body: Record<string, unknown>) => {
      const r = await call("POST", "/chat/share", who.token, body);
      for (const x of r.data?.results ?? []) if (x.message_id) messages.push({ id: x.message_id, token: who.token });
      return r;
    };

    try {
      await t.step("posting stories and the tray", async () => {
        const photo = await photoStory(member, `${name} photo`);
        check(
          "a photo story is posted, live, with a signed URL and the author's counts",
          photo.status === 201 && photo.data.media_type === "image" && photo.data.media_url?.startsWith("/storage/v1/") &&
            photo.data.is_live && photo.data.is_mine && photo.data.view_count === 0 && photo.data.seen,
          short(photo.data),
        );
        const text = await newStory(member, { caption: `${name} text`, background: "#ff5500" });
        check("a text story on a colour", text.status === 201 && text.data.background === "#ff5500", short(text.data));

        const empty = await call("POST", "/stories", member.token, {});
        const badColour = await call("POST", "/stories", member.token, { caption: "x", background: "red" });
        const person = await call("POST", "/stories", member.token, { share: { kind: "user", ref_id: id.trainer } });
        const business = await call("POST", "/stories", member.token, { share: { kind: "business", ref_id: id.trainer } });
        const video = await call("POST", "/stories/uploads", member.token, { mime_type: "application/pdf", size_bytes: 10 });
        check(
          "validation: empty 400, bad colour 400, people/businesses can't be shared to a story 400, photos/videos only",
          empty.status === 400 && badColour.status === 400 && person.status === 400 && business.status === 400 &&
            video.status === 400,
          `status ${empty.status}/${badColour.status}/${person.status}/${business.status}/${video.status}`,
        );

        const tray = await call("GET", "/stories/feed", trainer.token);
        const entry = (tray.data as any[])?.find((e) => e.user.id === id.member);
        check(
          "a follower sees the author in the tray with unseen stories",
          tray.status === 200 && entry?.story_count >= 2 && entry.has_unseen,
          short(entry),
        );
        const mine = await call("GET", "/stories/feed", member.token);
        check("my own stories come first in my tray", mine.data?.[0]?.is_me === true, short(mine.data?.[0]));
        const profile = await call("GET", `/social/users/${id.member}`, trainer.token);
        check(
          "their profile shows the story ring",
          profile.data?.story_count >= 2 && profile.data.has_unseen_story === true,
          short([profile.data?.story_count, profile.data?.has_unseen_story]),
        );

        const list = await call("GET", `/stories?user_id=${id.member}`, trainer.token);
        const ours = (list.data as any[])?.filter((s) => stories.includes(s.id)) ?? [];
        check(
          "the follower gets them oldest first, unseen, without the author's counts",
          ours.length === 2 && ours[0].id === photo.data.id && !ours[0].seen && ours[0].view_count === null,
          short(ours.map((s) => [s.id, s.seen, s.view_count])),
        );

        for (const s of ours) await call("POST", `/stories/${s.id}/view`, trainer.token);
        const after = await call("GET", "/stories/feed", trainer.token);
        const authorView = await call("GET", `/stories/${photo.data.id}`, member.token);
        check(
          "watching them clears the ring and counts a view",
          (after.data as any[]).find((e) => e.user.id === id.member)?.has_unseen === false &&
            authorView.data?.view_count === 1 &&
            (await call("GET", `/social/users/${id.member}`, trainer.token)).data?.has_unseen_story === false,
          short(authorView.data?.view_count),
        );
      });

      await t.step("likes, notifications and viewers", async () => {
        const story = stories[0];
        const like = await call("POST", `/stories/${story}/like`, trainer.token);
        const fire = await call("PUT", `/stories/${story}/reaction`, trainer.token, { reaction: "fire" });
        const bad = await call("PUT", `/stories/${story}/reaction`, trainer.token, { reaction: "meh" });
        check(
          "a follower likes it, then switches to 🔥; unknown reactions 400",
          like.status === 200 && like.data.liked && fire.data?.my_reaction === "fire" && bad.status === 400,
          `${short(like.data)} ${short(fire.data)}`,
        );
        const notes = (await notificationsOf(member.token)).filter((n) => n.metadata?.story_id === story);
        check(
          "the author is notified once (the first like), not when it's switched",
          notes.length === 1 && notes[0].type === "story_reaction" && notes[0].title.includes("liked your story"),
          short(notes),
        );
        const viewers = await call("GET", `/stories/${story}/viewers`, member.token);
        const notAuthor = await call("GET", `/stories/${story}/viewers`, trainer.token);
        check(
          "the author sees who watched it and their reaction; nobody else does",
          viewers.status === 200 && viewers.data?.[0]?.user?.id === id.trainer && viewers.data[0].reaction === "fire" &&
            notAuthor.status === 403,
          short(viewers.data),
        );
        const unlike = await call("DELETE", `/stories/${story}/like`, trainer.token);
        check("unliking", unlike.status === 200 && unlike.data.liked === false, short(unlike.data));
      });

      await t.step("replies and emoji reactions go to the author's DMs", async () => {
        const story = stories[0];
        const react = await call("POST", "/chat/story-replies", trainer.token, { story_id: story, reaction: "fire" });
        if (react.data?.id) messages.push({ id: react.data.id, token: trainer.token });
        check(
          "a quick reaction sends \"🔥\" with the story attached",
          react.status === 201 && react.data.body === "🔥" && react.data.story_reply?.mode === "reaction" &&
            react.data.story_reply.reaction === "fire" && react.data.story_reply.owner_id === id.member &&
            react.data.story_reply.story?.available === true,
          short(react.data),
        );
        const reply = await call("POST", "/chat/story-replies", trainer.token, { story_id: story, body: "Strong!" });
        if (reply.data?.id) messages.push({ id: reply.data.id, token: trainer.token });
        const seen = await getMessage(member, reply.data?.id);
        check(
          "a text reply; the author sees it with their story's preview",
          reply.status === 201 && seen.status === 200 && seen.data.story_reply?.mode === "reply" &&
            seen.data.body === "Strong!" && seen.data.story_reply.story?.preview?.id === story &&
            seen.data.conversation_id === react.data?.conversation_id,
          short(seen.data?.story_reply),
        );
        const inbox = await call("GET", "/chat/conversations", member.token);
        const conv = (inbox.data as any[]).find((c) => c.id === reply.data?.conversation_id);
        check("the inbox row says it's a story reply", conv?.last_message?.story_mode === "reply", short(conv?.last_message));

        const own = await call("POST", "/chat/story-replies", member.token, { story_id: story, body: "me" });
        const empty = await call("POST", "/chat/story-replies", trainer.token, { story_id: story });
        const unknown = await call("POST", "/chat/story-replies", trainer.token, { story_id: crypto.randomUUID(), body: "x" });
        check(
          "can't reply to my own story (400), with nothing (400), or to a missing story (404)",
          own.status === 400 && empty.status === 400 && unknown.status === 404,
          `status ${own.status}/${empty.status}/${unknown.status}`,
        );
      });

      await t.step("a private account's stories", async () => {
        const s = await photoStory(priv, `${name} private`);
        const follower = await call("GET", `/stories?user_id=${id.priv}`, member.token);
        const stranger = await call("GET", `/stories?user_id=${id.priv}`, vendor.token);
        const direct = await call("GET", `/stories/${s.data?.id}`, vendor.token);
        const view = await call("POST", `/stories/${s.data?.id}/view`, vendor.token);
        const like = await call("POST", `/stories/${s.data?.id}/like`, vendor.token);
        const reply = await call("POST", "/chat/story-replies", vendor.token, { story_id: s.data?.id, body: "hi" });
        check(
          "followers see them; anyone else gets nothing (list empty, 404 on view/like/reply)",
          (follower.data as any[]).some((x) => x.id === s.data?.id) && (stranger.data as any[]).length === 0 &&
            direct.status === 404 && view.status === 404 && like.status === 404 && reply.status === 404,
          `status ${direct.status}/${view.status}/${like.status}/${reply.status}`,
        );
        const tray = await call("GET", "/stories/feed", vendor.token);
        check("…nor in their tray", !(tray.data as any[]).some((e) => e.user.id === id.priv), "");
      });

      await t.step("sharing in chat, with visibility checked per viewer", async () => {
        const pub = await newPost(member, { content: `${name} public post` });
        const sent = await shareTo(member, { share: { kind: "post", ref_id: pub.data?.id }, user_ids: [id.trainer], body: "look" });
        const msgId = sent.data?.results?.[0]?.message_id;
        const asTrainer = await getMessage(trainer, msgId);
        check(
          "a post is sent to a person; they see its preview",
          sent.status === 201 && sent.data.sent === 1 && asTrainer.data?.share?.available === true &&
            asTrainer.data.share.preview.caption === `${name} public post` && asTrainer.data.body === "look" &&
            asTrainer.data.share.preview.author?.id === id.member,
          short(asTrainer.data?.share),
        );
        const thread = await call("GET", `/chat/conversations/${sent.data?.results?.[0]?.conversation_id}/messages?limit=5`, trainer.token);
        const inThread = (thread.data as any[]).find((m) => m.id === msgId);
        check("message lists resolve shares too", inThread?.share?.available === true, short(inThread?.share));
        const inbox = await call("GET", "/chat/conversations", trainer.token);
        check(
          "the inbox row says what was shared",
          (inbox.data as any[]).some((c) => c.last_message?.id === msgId && c.last_message.share_kind === "post"),
          "",
        );

        // A private account's post, sent to someone who doesn't follow them.
        const secret = await newPost(priv, { content: `${name} private post` });
        const toStranger = await shareTo(priv, { share: { kind: "post", ref_id: secret.data?.id }, user_ids: [id.vendor] });
        const strangerMsg = toStranger.data?.results?.[0]?.message_id;
        const asStranger = await getMessage(vendor, strangerMsg);
        const asAuthor = await getMessage(priv, strangerMsg);
        check(
          "the recipient who can't see it gets \"private\" and no preview; the sender still sees it",
          toStranger.status === 201 && asStranger.data?.share?.available === false &&
            asStranger.data.share.reason === "private" && asStranger.data.share.preview === undefined &&
            asAuthor.data?.share?.available === true,
          short(asStranger.data?.share),
        );
        const reshare = await shareTo(vendor, { share: { kind: "post", ref_id: secret.data?.id }, user_ids: [id.trainer] });
        check(
          "you can't share what you can't see (404)",
          reshare.status === 404 && reshare.data?.code === "share_not_found",
          short(reshare.data),
        );

        // Archiving makes it unavailable to others, and back again.
        await call("PUT", `/posts/${pub.data?.id}/archive`, member.token);
        const archived = await getMessage(trainer, msgId);
        const authorSide = await getMessage(member, msgId);
        await call("DELETE", `/posts/${pub.data?.id}/archive`, member.token);
        const restored = await getMessage(trainer, msgId);
        check(
          "an archived post is \"unavailable\" to others (not to its author) until it's shown again",
          archived.data?.share?.available === false && archived.data.share.reason === "unavailable" &&
            authorSide.data?.share?.available === true && restored.data?.share?.available === true,
          `${short(archived.data?.share)} ${short(restored.data?.share)}`,
        );

        // Accounts, library items, a logged workout.
        const profile = await shareTo(member, { share: { kind: "user", ref_id: id.priv }, user_ids: [id.trainer] });
        const profileMsg = await getMessage(trainer, profile.data?.results?.[0]?.message_id);
        check(
          "a private account's profile card is shareable (just the card)",
          profileMsg.data?.share?.available === true && profileMsg.data.share.preview.is_private === true &&
            profileMsg.data.share.preview.username,
          short(profileMsg.data?.share),
        );
        const routine = await call("POST", "/routines", member.token, { name: `${name} secret`, schedule_type: "wildcard" });
        routineId = routine.data?.id ?? null;
        const routineShare = await shareTo(member, { share: { kind: "routine", ref_id: routineId }, user_ids: [id.trainer] });
        const routineMsg = await getMessage(trainer, routineShare.data?.results?.[0]?.message_id);
        const routineMine = await getMessage(member, routineShare.data?.results?.[0]?.message_id);
        check(
          "a private routine shows as \"private\" to the recipient, as a card to its author",
          routineMsg.data?.share?.available === false && routineMsg.data.share.reason === "private" &&
            routineMine.data?.share?.preview?.title === `${name} secret`,
          short(routineMsg.data?.share),
        );
        const pubEx = ((await call("GET", "/exercises?page_size=1")).data as any[])[0];
        const exShare = await shareTo(member, { share: { kind: "exercise", ref_id: pubEx.id }, user_ids: [id.trainer] });
        const exMsg = await getMessage(trainer, exShare.data?.results?.[0]?.message_id);
        check("a public exercise", exMsg.data?.share?.preview?.title === pubEx.name, short(exMsg.data?.share));

        const start = new Date(Date.now() - 2 * 3600_000);
        const past = await call("POST", "/training-sessions", member.token, {
          started_at: start.toISOString(), ended_at: new Date(start.getTime() + 30 * 60_000).toISOString(),
          sets: [{ exercise_id: pubEx.id, drops: [{ rep_count_actual: 5, weight_kg_actual: 60 }] }],
        });
        if (past.data?.id) sessions.push(past.data.id);
        const workout = await shareTo(member, { share: { kind: "workout", ref_id: past.data?.id }, user_ids: [id.trainer] });
        const workoutMsg = await getMessage(trainer, workout.data?.results?.[0]?.message_id);
        const notMine = await shareTo(trainer, { share: { kind: "workout", ref_id: past.data?.id }, user_ids: [id.member] });
        check(
          "my logged workout is sent as a snapshot; someone else's can't be shared",
          workoutMsg.data?.share?.available === true && workoutMsg.data.share.preview.duration_minutes === 30 &&
            workoutMsg.data.share.preview.volume_kg === 300 && notMine.status === 404,
          `${short(workoutMsg.data?.share)} ${notMine.status}`,
        );

        // A story in chat; validation.
        const storyShare = await shareTo(trainer, { share: { kind: "story", ref_id: stories[0] }, user_ids: [id.vendor] });
        const storyMsg = await getMessage(vendor, storyShare.data?.results?.[0]?.message_id);
        check(
          "a public account's story can be sent on",
          storyMsg.data?.share?.available === true && storyMsg.data.share.preview.id === stories[0],
          short(storyMsg.data?.share),
        );
        const badKind = await call("POST", "/chat/share", member.token, { share: { kind: "spaceship", ref_id: pubEx.id }, user_ids: [id.trainer] });
        const missing = await call("POST", "/chat/share", member.token, { share: { kind: "post", ref_id: crypto.randomUUID() }, user_ids: [id.trainer] });
        const nobody = await call("POST", "/chat/share", member.token, { share: { kind: "exercise", ref_id: pubEx.id } });
        const direct = await call("POST", `/chat/conversations/${sent.data?.results?.[0]?.conversation_id}/messages`, member.token, {
          share: { kind: "exercise", ref_id: pubEx.id },
        });
        if (direct.data?.id) messages.push({ id: direct.data.id, token: member.token });
        check(
          "unknown kind 400, missing thing 404, no recipients 400; a share can also go straight into a chat",
          badKind.status === 400 && missing.status === 404 && nobody.status === 400 && direct.status === 201 &&
            direct.data.share?.available === true,
          `status ${badKind.status}/${missing.status}/${nobody.status}/${direct.status}`,
        );
      });

      await t.step("stories sharing things", async () => {
        const followersOnly = await newPost(member, { content: `${name} followers only`, visibility: "followers" });
        const s = await newStory(member, { share: { kind: "post", ref_id: followersOnly.data?.id }, caption: "new post!" });
        const asFollower = await call("GET", `/stories/${s.data?.id}`, trainer.token);
        const asStranger = await call("GET", `/stories/${s.data?.id}`, vendor.token);
        check(
          "a story sharing a followers-only post: followers see the post, others see the story but \"private\"",
          s.status === 201 && asFollower.data?.share?.available === true && asStranger.status === 200 &&
            asStranger.data.share?.available === false && asStranger.data.share.reason === "private",
          `${short(asFollower.data?.share)} ${short(asStranger.data?.share)}`,
        );
      });

      await t.step("expiry and the story archive", async () => {
        const story = stories[0];
        const replyMsg = messages.find((m) => m.token === trainer.token)?.id;
        const now = new Date();
        const monthStart = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1)).toISOString();
        const archive = await call("GET", `/stories/archive?from=${encodeURIComponent(monthStart)}`, member.token);
        const future = await call("GET", `/stories/archive?from=${encodeURIComponent(new Date(Date.now() + 86_400_000).toISOString())}`, member.token);
        const badRange = await call("GET", "/stories/archive?from=yesterday", member.token);
        check(
          "the archive lists my stories by date; bad dates 400",
          (archive.data as any[]).some((s) => s.id === story) && (future.data as any[]).length === 0 && badRange.status === 400,
          `status ${badRange.status}`,
        );

        if (!(await dbAvailable())) {
          console.warn("No database access — skipping the expiry checks.");
          return;
        }
        await sql("UPDATE story SET created_at = NOW() - INTERVAL '25 hours', expires_at = NOW() - INTERVAL '1 hour' WHERE id = $1", [story]);
        const gone = await call("GET", `/stories/${story}`, trainer.token);
        const authorSees = await call("GET", `/stories/${story}`, member.token);
        const list = await call("GET", `/stories?user_id=${id.member}`, trainer.token);
        const reply = await call("POST", "/chat/story-replies", trainer.token, { story_id: story, body: "late" });
        check(
          "after 24 hours it's gone for others, still there (not live) for its author",
          gone.status === 404 && authorSees.status === 200 && authorSees.data.is_live === false &&
            !(list.data as any[]).some((s) => s.id === story) && reply.status === 404,
          `status ${gone.status}/${authorSees.status}/${reply.status}`,
        );
        const oldReply = await getMessage(trainer, replyMsg!);
        const ownerSide = await getMessage(member, replyMsg!);
        check(
          "an old reply now shows the story as expired to the replier; its author still sees it",
          oldReply.data?.story_reply?.story?.available === false && oldReply.data.story_reply.story.reason === "expired" &&
            ownerSide.data?.story_reply?.story?.available === true,
          short(oldReply.data?.story_reply),
        );
        const stillArchived = await call("GET", "/stories/archive", member.token);
        check("expired stories stay in the archive", (stillArchived.data as any[]).some((s) => s.id === story), "");

        const del = await call("DELETE", `/stories/${story}`, member.token);
        stories.splice(stories.indexOf(story), 1);
        const afterDelete = await getMessage(member, replyMsg!);
        check(
          "deleting it leaves the reply saying the story is unavailable",
          del.status === 204 && afterDelete.data?.story_reply?.mode === "reaction" &&
            afterDelete.data.story_reply.story.available === false && afterDelete.data.story_reply.story.reason === "unavailable",
          short(afterDelete.data?.story_reply),
        );
      });

      await t.step("archiving posts", async () => {
        const p = await newPost(member, { content: `${name} to archive` });
        const other = await call("PUT", `/posts/${p.data?.id}/archive`, trainer.token);
        const put = await call("PUT", `/posts/${p.data?.id}/archive`, member.token);
        const profileMine = await call("GET", `/posts?author_id=${id.member}&page_size=50`, member.token);
        const profileTheirs = await call("GET", `/posts?author_id=${id.member}&page_size=50`, trainer.token);
        const direct = await call("GET", `/posts/${p.data?.id}`, trainer.token);
        const own = await call("GET", `/posts/${p.data?.id}`, member.token);
        const feed = await call("GET", "/posts/feed?page_size=50", trainer.token);
        const list = await call("GET", "/posts/archive", member.token);
        check(
          "only the author archives; it leaves the profile (for everyone) and the feed, and is in my archive",
          other.status === 403 && put.status === 200 && put.data.archived_at &&
            !(profileMine.data as any[]).some((x) => x.id === p.data?.id) &&
            !(profileTheirs.data as any[]).some((x) => x.id === p.data?.id) &&
            direct.status === 404 && own.status === 200 &&
            !(feed.data as any[]).some((x) => x.id === p.data?.id) &&
            (list.data as any[]).some((x) => x.id === p.data?.id),
          `status ${other.status}/${put.status}/${direct.status}/${own.status}`,
        );
        const range = await call("GET", `/posts/archive?to=${encodeURIComponent(new Date(Date.now() - 86_400_000).toISOString())}`, member.token);
        check("the archive takes a date range", !(range.data as any[]).some((x) => x.id === p.data?.id), "");
        const unarchive = await call("DELETE", `/posts/${p.data?.id}/archive`, member.token);
        const back = await call("GET", `/posts/${p.data?.id}`, trainer.token);
        check(
          "showing it again",
          unarchive.status === 200 && unarchive.data.archived_at === null && back.status === 200,
          `status ${unarchive.status}/${back.status}`,
        );
      });
    } finally {
      for (const s of stories) await call("DELETE", `/stories/${s}`, storyOwner.get(s));
      for (const m of messages) await call("DELETE", `/chat/messages/${m.id}`, m.token);
      for (const p of posts) await call("DELETE", `/posts/${p.id}`, p.token);
      for (const s of sessions) await call("DELETE", `/training-sessions/${s}`, member.token);
      if (routineId) await call("DELETE", `/routines/${routineId}`, member.token);
      await deleteNotifications(member.token, (n) => n.type === "story_reaction");
    }

    assertAll();
  },
});
