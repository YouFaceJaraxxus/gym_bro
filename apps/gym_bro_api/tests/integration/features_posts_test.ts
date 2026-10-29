// deno-lint-ignore-file no-explicit-any
// Posts: gym announcements (staff only, news to members, members-only
// comments), personal post validation/edit/delete rights, every reaction
// type on posts and comments, comment validation and sorting, and who can
// see what — private accounts and blocks. Posts are deleted through the API
// in `finally`; follow/friend/block rows are snapshotted and restored, and
// the notifications the posts caused are removed.
import { call, checker, fetchStatus, notificationsOf, PNG, short, signin, suite, uploadTo } from "./_client.ts";
import { deleteNotificationsWhere, restorePair, snapshotPair, sql } from "./_db.ts";

const REACTIONS = ["like", "love", "haha", "wow", "sad", "angry", "fire", "strong", "clap", "celebrate"];
const SUMMIT = "Summit Strength Collective";

// Seeded people no other suite acts as: Becky trains at Summit, where Ethan
// and Maya are members (and friends who follow each other). Sofia is a
// private account at another gym; Grace follows her, Ethan doesn't.
Deno.test({
  name: "features: posts, announcements, reactions and visibility",
  ...suite,
  async fn(t) {
    const { check, assertAll } = checker();
    const [becky, ethan, maya, sofia, grace] = await Promise.all([
      signin("becky.morrison@example.com"),
      signin("ethan.brooks@example.com"),
      signin("maya.flores@example.com"),
      signin("sofia.rossi@example.com"),
      signin("grace.okafor@example.com"),
    ]);
    const E = ethan.profile.id as string;
    const M = maya.profile.id as string;
    const tag = `it-${crypto.randomUUID().slice(0, 8)}`;
    // A finished upload of Maya's that step 4 posts (step 2 tries to steal it).
    let mayaUpload: any = null;

    await t.step("1. gym announcements", async () => {
      let postId: string | null = null;
      try {
        const gyms = (await call("GET", "/social/me", becky.token)).data?.gyms as any[];
        const summit = (Array.isArray(gyms) ? gyms : []).find((b) => b.name === SUMMIT);
        check("trainer's profile lists their gym", !!summit, short(gyms));
        assertAll();

        const post = await call("POST", "/posts", becky.token, {
          business_id: summit.id,
          content: `Summit news ${tag}`,
          images: [{ url: "https://example.com/a.jpg" }],
        });
        postId = post.data?.id ?? null;
        check(
          "trainer posts an announcement",
          post.status === 201 && post.data.kind === "business" && post.data.business?.name === SUMMIT &&
            post.data.images[0]?.url === "https://example.com/a.jpg" && post.data.can_edit === true,
          short(post.data),
        );
        const news = (await notificationsOf(ethan.token)).find((n) => n.type === "news" && n.metadata?.post_id === postId);
        check("gym members get a 'news' notification", news?.metadata?.business_id === summit.id, short(news));
        const authorNews = (await notificationsOf(becky.token)).find((n) => n.type === "news" && n.metadata?.post_id === postId);
        check("…but not the author", !authorNews);

        const memberPost = await call("POST", "/posts", ethan.token, { business_id: summit.id, content: "not staff" });
        if (memberPost.status === 201) await call("DELETE", `/posts/${memberPost.data.id}`, ethan.token);
        check("a member can't post as the gym", memberPost.status === 403, `status ${memberPost.status}`);
        const noContent = await call("POST", "/posts", becky.token, { business_id: summit.id });
        check("an announcement needs content", noContent.status === 400, `status ${noContent.status}`);
        const ghost = await call("POST", "/posts", becky.token, { business_id: crypto.randomUUID(), content: "x" });
        check("unknown business is 404", ghost.status === 404, `status ${ghost.status}`);

        const listed = await call("GET", `/posts?business_id=${summit.id}`);
        check("anyone can read the gym's posts", (listed.data as any[])?.some((p) => p.id === postId), `status ${listed.status}`);
        const noFilter = await call("GET", "/posts", ethan.token);
        check("listing needs business_id or author_id", noFilter.status === 400, `status ${noFilter.status}`);

        const edit = await call("PUT", `/posts/${postId}`, becky.token, {
          content: `Summit news ${tag} (updated)`,
          images: [{ url: "https://example.com/b.jpg" }, { url: "https://example.com/c.jpg" }],
        });
        check(
          "author edits text and replaces images",
          edit.status === 200 && edit.data.content.endsWith("(updated)") && edit.data.images.map((i: any) => i.url).join() ===
              "https://example.com/b.jpg,https://example.com/c.jpg",
          short(edit.data),
        );
        const vis = await call("PUT", `/posts/${postId}`, becky.token, { visibility: "followers" });
        check("announcements have no visibility setting", vis.status === 400, `status ${vis.status}`);
        const memberEdit = await call("PUT", `/posts/${postId}`, ethan.token, { content: "hacked" });
        const memberDelete = await call("DELETE", `/posts/${postId}`, ethan.token);
        check("members can't edit or delete it", memberEdit.status === 403 && memberDelete.status === 403, `status ${memberEdit.status}/${memberDelete.status}`);

        const memberComment = await call("POST", `/posts/${postId}/comments`, ethan.token, { body: "See you there" });
        check("a member comments", memberComment.status === 201, `status ${memberComment.status}`);
        const staffComment = await call("POST", `/posts/${postId}/comments`, becky.token, { body: "Bring chalk" });
        check("staff comment", staffComment.status === 201, `status ${staffComment.status}`);
        const outsider = await call("POST", `/posts/${postId}/comments`, sofia.token, { body: "hi" });
        check("someone from another gym can't comment", outsider.status === 403, `status ${outsider.status}`);
        const outsiderReacts = await call("PUT", `/posts/${postId}/reaction`, sofia.token, { reaction: "clap" });
        check("…but can react (the post is public)", outsiderReacts.status === 200 && outsiderReacts.data.my_reaction === "clap", short(outsiderReacts.data));
        const notice = (await notificationsOf(becky.token)).find((n) => n.type === "post_comment" && n.metadata?.comment_id === memberComment.data?.id);
        check("author gets post_comment with the gym's name", notice?.metadata?.business_name === SUMMIT, short(notice));
      } finally {
        if (postId) {
          const del = await call("DELETE", `/posts/${postId}`, becky.token);
          check("author deletes the announcement", del.status === 204, `status ${del.status}`);
          await deleteNotificationsWhere("post_id", [postId]);
        }
      }
      assertAll();
    });

    await t.step("2. personal posts: validation, edit and delete rights", async () => {
      const postIds: string[] = [];
      const strayUploads: string[] = [];
      try {
        const invalid: [string, unknown][] = [
          ["caption over 2200 chars", { content: "x".repeat(2201) }],
          ["no caption and no media", { content: "   " }],
          ["more than 10 media", { content: "x", media: Array.from({ length: 11 }, () => ({ path: "x" })) }],
          ["media without a path", { content: "x", media: [{}] }],
          ["a path that was never reserved", { content: "x", media: [{ path: `${E}/${crypto.randomUUID()}.png` }] }],
        ];
        for (const [name, body] of invalid) {
          const r = await call("POST", "/posts", ethan.token, body);
          if (r.status === 201) postIds.push(r.data.id);
          check(`post with ${name} is 400`, r.status === 400, `status ${r.status}`);
        }

        const noMime = await call("POST", "/posts/uploads", ethan.token, { size_bytes: 10 });
        const noSize = await call("POST", "/posts/uploads", ethan.token, { mime_type: "image/png" });
        const tooBig = await call("POST", "/posts/uploads", ethan.token, { mime_type: "video/mp4", size_bytes: 51 * 1024 * 1024 });
        const anonSlot = await call("POST", "/posts/uploads", undefined, { mime_type: "image/png", size_bytes: 10 });
        check(
          "upload slot validation (mime 400, size 400, over 50 MB 413, anonymous 401)",
          noMime.status === 400 && noSize.status === 400 && tooBig.status === 413 && anonSlot.status === 401,
          `status ${noMime.status}/${noSize.status}/${tooBig.status}/${anonSlot.status}`,
        );

        const pending = await call("POST", "/posts/uploads", ethan.token, { mime_type: "image/png", size_bytes: PNG.length });
        strayUploads.push(pending.data?.path);
        const early = await call("POST", "/posts", ethan.token, { content: "x", media: [{ path: pending.data?.path }] });
        if (early.status === 201) postIds.push(early.data.id);
        check("posting before the upload finished is 400", early.status === 400, short(early.data));

        const slot = await call("POST", "/posts/uploads", maya.token, { mime_type: "image/png", size_bytes: PNG.length });
        mayaUpload = slot.data;
        check("Maya uploads a photo", slot.status === 201 && (await uploadTo(slot.data, PNG, "image/png")) === 200, short(slot.data));
        const steal = await call("POST", "/posts", ethan.token, { content: "mine now", media: [{ path: slot.data?.path }] });
        if (steal.status === 201) postIds.push(steal.data.id);
        check("someone else's upload can't be posted", steal.status === 400, `status ${steal.status}`);

        const post = await call("POST", "/posts", ethan.token, { content: `Text post ${tag}` });
        if (post.data?.id) postIds.push(post.data.id);
        check("visibility defaults to public", post.status === 201 && post.data.visibility === "public" && post.data.images.length === 0, short(post.data));
        const id = post.data?.id;
        const edit = await call("PUT", `/posts/${id}`, ethan.token, { content: `Edited ${tag}` });
        check("author edits the caption", edit.status === 200 && edit.data.content === `Edited ${tag}` && edit.data.updated_at >= post.data.updated_at, short(edit.data));
        const long = await call("PUT", `/posts/${id}`, ethan.token, { content: "x".repeat(2201) });
        const badVis = await call("PUT", `/posts/${id}`, ethan.token, { visibility: "friends" });
        check("edit validation (caption length, visibility)", long.status === 400 && badVis.status === 400, `status ${long.status}/${badVis.status}`);
        // An edit keeps POST's rule: a post needs a caption or media.
        const blank = await call("PUT", `/posts/${id}`, ethan.token, { content: "   " });
        check("blanking a text-only post's caption is 400", blank.status === 400, `status ${blank.status} content=${short(blank.data?.content)}`);
        const otherEdit = await call("PUT", `/posts/${id}`, maya.token, { content: "hacked" });
        const otherDelete = await call("DELETE", `/posts/${id}`, maya.token);
        check("others can't edit or delete it", otherEdit.status === 403 && otherDelete.status === 403, `status ${otherEdit.status}/${otherDelete.status}`);
        const ghostEdit = await call("PUT", `/posts/${crypto.randomUUID()}`, ethan.token, { content: "x" });
        const ghostDelete = await call("DELETE", `/posts/${crypto.randomUUID()}`, ethan.token);
        check("unknown post is 404", ghostEdit.status === 404 && ghostDelete.status === 404, `status ${ghostEdit.status}/${ghostDelete.status}`);
        const anonDelete = await call("DELETE", `/posts/${id}`);
        check("anonymous can't delete", anonDelete.status === 401, `status ${anonDelete.status}`);

        const grid = await call("GET", `/posts?author_id=${E}&media=only`, maya.token);
        const all = await call("GET", `/posts?author_id=${E}`, maya.token);
        check(
          "media=only leaves out text posts",
          !(grid.data as any[]).some((p) => p.id === id) && (all.data as any[]).some((p) => p.id === id),
          `n=${grid.data?.length}/${all.data?.length}`,
        );
        const ghostAuthor = await call("GET", `/posts?author_id=${crypto.randomUUID()}`, maya.token);
        const badAuthor = await call("GET", "/posts?author_id=nope", maya.token);
        check("unknown author is 404", ghostAuthor.status === 404 && badAuthor.status === 404, `status ${ghostAuthor.status}/${badAuthor.status}`);

        const del = await call("DELETE", `/posts/${id}`, ethan.token);
        const gone = await call("GET", `/posts/${id}`, maya.token);
        check("author deletes the post", del.status === 204 && gone.status === 404, `status ${del.status}/${gone.status}`);
        postIds.splice(postIds.indexOf(id), 1);
      } finally {
        for (const id of postIds) await call("DELETE", `/posts/${id}`, ethan.token);
        await sql(`DELETE FROM media_upload WHERE storage_path = ANY($1::text[])`, [strayUploads.filter(Boolean)]);
      }
      assertAll();
    });

    await t.step("3. every reaction on posts and comments; comment validation and sorting", async () => {
      const postIds: string[] = [];
      try {
        const post = await call("POST", "/posts", ethan.token, { content: `React to me ${tag}` });
        const other = await call("POST", "/posts", ethan.token, { content: `Another ${tag}` });
        const id = post.data?.id as string;
        postIds.push(id, other.data?.id);

        // Maya goes through all ten reactions: one per person, last one wins.
        for (const reaction of REACTIONS) {
          const r = await call("PUT", `/posts/${id}/reaction`, maya.token, { reaction });
          if (
            r.status !== 200 || r.data.my_reaction !== reaction || r.data.reactions.counts[reaction] !== 1 || r.data.reactions.total !== 1
          ) {
            check(`post reaction '${reaction}'`, false, short(r.data));
          }
        }
        const fire = await call("PUT", `/posts/${id}/reaction`, sofia.token, { reaction: "fire" });
        check(
          "all ten reaction types work on posts; reactions from two people add up",
          fire.data?.reactions?.total === 2 && fire.data.reactions.counts.celebrate === 1 && fire.data.reactions.counts.fire === 1 &&
            fire.data.reactions.top.length === 2,
          short(fire.data),
        );
        const notes = (await notificationsOf(ethan.token)).filter((n) => n.type === "post_reaction" && n.metadata?.post_id === id);
        check("one notification per person, however often they switch", notes.length === 2, String(notes.length));
        const who = await call("GET", `/posts/${id}/reactions`, ethan.token);
        check(
          "who reacted",
          who.status === 200 && who.data.length === 2 && who.data.find((u: any) => u.id === M)?.reaction === "celebrate",
          short(who.data),
        );
        const badFilter = await call("GET", `/posts/${id}/reactions?reaction=meh`, ethan.token);
        check("unknown reaction filter is 400", badFilter.status === 400, `status ${badFilter.status}`);
        const remove = await call("DELETE", `/posts/${id}/reaction`, maya.token);
        check(
          "remove my reaction",
          remove.status === 200 && remove.data.my_reaction === null && remove.data.reactions.total === 1 && !remove.data.reactions.counts.celebrate,
          short(remove.data),
        );
        const removeAgain = await call("DELETE", `/posts/${id}/reaction`, maya.token);
        check("removing again is a no-op", removeAgain.status === 200 && removeAgain.data.reactions.total === 1, short(removeAgain.data));
        const noBody = await call("PUT", `/posts/${id}/reaction`, maya.token);
        const ghost = await call("PUT", `/posts/${crypto.randomUUID()}/reaction`, maya.token, { reaction: "like" });
        const anon = await call("PUT", `/posts/${id}/reaction`, undefined, { reaction: "like" });
        check(
          "reaction needs a body (400), a known post (404) and a user (401)",
          noBody.status === 400 && ghost.status === 404 && anon.status === 401,
          `status ${noBody.status}/${ghost.status}/${anon.status}`,
        );

        // ── Comments ──
        const first = await call("POST", `/posts/${id}/comments`, maya.token, { body: "first" });
        const cid = first.data?.id as string;
        for (const reaction of REACTIONS) {
          const r = await call("PUT", `/posts/comments/${cid}/reaction`, ethan.token, { reaction });
          if (r.status !== 200 || r.data.my_reaction !== reaction || r.data.reactions.counts[reaction] !== 1 || r.data.reactions.total !== 1) {
            check(`comment reaction '${reaction}'`, false, short(r.data));
          }
        }
        const sofiaLikes = await call("PUT", `/posts/comments/${cid}/reaction`, sofia.token, { reaction: "like" });
        check(
          "all ten reaction types work on comments",
          sofiaLikes.data?.reactions?.total === 2 && sofiaLikes.data.reactions.counts.celebrate === 1 && sofiaLikes.data.my_reaction === "like",
          short(sofiaLikes.data),
        );
        const uncomment = await call("DELETE", `/posts/comments/${cid}/reaction`, ethan.token);
        check(
          "remove a comment reaction",
          uncomment.status === 200 && uncomment.data.my_reaction === null && uncomment.data.reactions.total === 1,
          short(uncomment.data),
        );
        const badReaction = await call("PUT", `/posts/comments/${cid}/reaction`, ethan.token, { reaction: "meh" });
        const ghostComment = await call("PUT", `/posts/comments/${crypto.randomUUID()}/reaction`, ethan.token, { reaction: "like" });
        check("comment reaction validation (400 / 404)", badReaction.status === 400 && ghostComment.status === 404, `status ${badReaction.status}/${ghostComment.status}`);

        const second = await call("POST", `/posts/${id}/comments`, sofia.token, { body: "second" });
        // sort picks which top-level comments make the page (the app orders the tree).
        const oldest = await call("GET", `/posts/${id}/comments?sort=old&page_size=1`, maya.token);
        const newest = await call("GET", `/posts/${id}/comments?sort=new&page_size=1`, maya.token);
        const page2 = await call("GET", `/posts/${id}/comments?sort=new&page_size=1&page=1`, maya.token);
        check(
          "sort=old / sort=new pages over top-level comments",
          oldest.data?.length === 1 && oldest.data[0].id === cid && newest.data?.length === 1 && newest.data[0].id === second.data?.id &&
            page2.data?.[0]?.id === cid,
          `${oldest.data?.map((c: any) => c.body)} / ${newest.data?.map((c: any) => c.body)} / ${page2.data?.map((c: any) => c.body)}`,
        );
        const top = await call("GET", `/posts/${id}/comments`, undefined);
        check("anonymous reads comments of a public post, without reply rights", top.status === 200 && top.data.every((c: any) => c.can_reply === false && c.can_delete === false), `status ${top.status}`);

        const otherComment = await call("POST", `/posts/${other.data?.id}/comments`, maya.token, { body: "elsewhere" });
        const crossParent = await call("POST", `/posts/${id}/comments`, maya.token, { body: "x", parent_id: otherComment.data?.id });
        const ghostParent = await call("POST", `/posts/${id}/comments`, maya.token, { body: "x", parent_id: crypto.randomUUID() });
        const badParent = await call("POST", `/posts/${id}/comments`, maya.token, { body: "x", parent_id: "nope" });
        check(
          "a parent from another post, or an unknown one, is 404",
          crossParent.status === 404 && ghostParent.status === 404 && badParent.status === 404,
          `status ${crossParent.status}/${ghostParent.status}/${badParent.status}`,
        );
        const longComment = await call("POST", `/posts/${id}/comments`, maya.token, { body: "x".repeat(2001) });
        const longEdit = await call("PUT", `/posts/comments/${cid}`, maya.token, { body: "x".repeat(2001) });
        const emptyEdit = await call("PUT", `/posts/comments/${cid}`, maya.token, { body: " " });
        const ghostEdit = await call("PUT", `/posts/comments/${crypto.randomUUID()}`, maya.token, { body: "x" });
        const ghostDelete = await call("DELETE", `/posts/comments/${crypto.randomUUID()}`, maya.token);
        const unknownPost = await call("POST", `/posts/${crypto.randomUUID()}/comments`, maya.token, { body: "x" });
        check(
          "comment validation (2000 chars, empty edit, unknown comment/post)",
          longComment.status === 400 && longEdit.status === 400 && emptyEdit.status === 400 && ghostEdit.status === 404 &&
            ghostDelete.status === 404 && unknownPost.status === 404,
          `status ${longComment.status}/${longEdit.status}/${emptyEdit.status}/${ghostEdit.status}/${ghostDelete.status}/${unknownPost.status}`,
        );
        const anonComment = await call("POST", `/posts/${id}/comments`, undefined, { body: "x" });
        check("anonymous can't comment", anonComment.status === 401, `status ${anonComment.status}`);
        const edited = await call("PUT", `/posts/comments/${cid}`, maya.token, { body: "first (edited)" });
        check("author edits a comment", edited.status === 200 && edited.data.body === "first (edited)" && edited.data.updated_at >= first.data.updated_at, short(edited.data));
        const postAuthorEdit = await call("PUT", `/posts/comments/${cid}`, ethan.token, { body: "nope" });
        check("the post author can't edit others' comments", postAuthorEdit.status === 403, `status ${postAuthorEdit.status}`);
        const reactDeleted = await call("DELETE", `/posts/comments/${second.data?.id}`, ethan.token);
        const afterDelete = await call("PUT", `/posts/comments/${second.data?.id}/reaction`, maya.token, { reaction: "like" });
        check(
          "the post author deletes others' comments; reacting to a deleted one is 404",
          reactDeleted.status === 204 && afterDelete.status === 404,
          `status ${reactDeleted.status}/${afterDelete.status}`,
        );
        const counted = await call("GET", `/posts/${id}`, maya.token);
        check("comment_count tracks live comments", counted.data?.comment_count === 1, short(counted.data));
      } finally {
        for (const id of postIds.filter(Boolean)) await call("DELETE", `/posts/${id}`, ethan.token);
        await deleteNotificationsWhere("post_id", postIds.filter(Boolean));
      }
      assertAll();
    });

    await t.step("4. private accounts and blocks decide who sees posts", async () => {
      const postIds: { id: string; token: string }[] = [];
      const created: string[] = [];
      const snap = await snapshotPair(E, M);
      try {
        // A 'public' post on a private account is still followers-only.
        const p1 = await call("POST", "/posts", sofia.token, { content: `Private account ${tag}`, visibility: "public" });
        if (p1.data?.id) {
          postIds.push({ id: p1.data.id, token: sofia.token });
          created.push(p1.data.id);
        }
        const id1 = p1.data?.id;
        const anon = await call("GET", `/posts/${id1}`);
        const stranger = await call("GET", `/posts/${id1}`, ethan.token);
        const follower = await call("GET", `/posts/${id1}`, grace.token);
        check(
          "private account's post: follower 200, others 404",
          anon.status === 404 && stranger.status === 404 && follower.status === 200,
          `status ${anon.status}/${stranger.status}/${follower.status}`,
        );
        const strangerGrid = await call("GET", `/posts?author_id=${sofia.profile.id}`, ethan.token);
        const anonGrid = await call("GET", `/posts?author_id=${sofia.profile.id}`);
        const followerGrid = await call("GET", `/posts?author_id=${sofia.profile.id}`, grace.token);
        check(
          "private account's grid: 403 private_account unless following",
          strangerGrid.status === 403 && strangerGrid.data.code === "private_account" && anonGrid.status === 403 &&
            (followerGrid.data as any[])?.some((p) => p.id === id1),
          `status ${strangerGrid.status}/${anonGrid.status}/${followerGrid.status}`,
        );
        const homeFeed = await call("GET", "/posts/feed?page_size=50", grace.token);
        const explore = await call("GET", "/posts/feed?mode=explore&page_size=50", ethan.token);
        check(
          "follower's feed has it; a stranger's explore doesn't",
          (homeFeed.data as any[])?.some((p) => p.id === id1) && !(explore.data as any[])?.some((p) => p.id === id1),
          `n=${homeFeed.data?.length}/${explore.data?.length}`,
        );
        const strangerReacts = await call("PUT", `/posts/${id1}/reaction`, ethan.token, { reaction: "like" });
        const strangerComments = await call("POST", `/posts/${id1}/comments`, ethan.token, { body: "hi" });
        const strangerReads = await call("GET", `/posts/${id1}/comments`, ethan.token);
        const strangerWho = await call("GET", `/posts/${id1}/reactions`, ethan.token);
        check(
          "a stranger can't react, comment or read its comments/reactions",
          strangerReacts.status === 404 && strangerComments.status === 404 && strangerReads.status === 404 && strangerWho.status === 404,
          `status ${strangerReacts.status}/${strangerComments.status}/${strangerReads.status}/${strangerWho.status}`,
        );
        const anonFeed = await call("GET", "/posts/feed");
        check("feed needs a signed-in user", anonFeed.status === 401, `status ${anonFeed.status}`);

        // ── Blocks: Maya (public) blocks Ethan ──
        check("Maya's photo upload is ready", !!mayaUpload?.path);
        assertAll();
        const p2 = await call("POST", "/posts", maya.token, {
          content: `Public with a photo ${tag}`,
          visibility: "public",
          media: [{ path: mayaUpload.path, width: 1, height: 1 }],
        });
        if (p2.data?.id) {
          postIds.push({ id: p2.data.id, token: maya.token });
          created.push(p2.data.id);
        }
        const id2 = p2.data?.id;
        const seen = await call("GET", `/posts/${id2}`, ethan.token);
        const url = seen.data?.images?.[0]?.url as string;
        check("Ethan sees the post with a signed photo URL", seen.status === 200 && url?.startsWith("/storage/v1/object/sign/user-media/") && (await fetchStatus(url)) === 200, short(seen.data));
        const ethanComment = await call("POST", `/posts/${id2}/comments`, ethan.token, { body: `before the block ${tag}` });

        const block = await call("POST", `/social/users/${E}/block`, maya.token);
        check("Maya blocks Ethan", block.status === 200 && block.data.relationship.blocked === true, short(block.data));
        const after = await call("GET", `/posts/${id2}`, ethan.token);
        const grid = await call("GET", `/posts?author_id=${M}`, ethan.token);
        const profile = await call("GET", `/social/users/${M}`, ethan.token);
        check(
          "blocked: the post (and its photo URL), grid and profile are gone",
          after.status === 404 && grid.status === 403 && profile.status === 404,
          `status ${after.status}/${grid.status}/${profile.status}`,
        );
        const react = await call("PUT", `/posts/${id2}/reaction`, ethan.token, { reaction: "like" });
        const comment = await call("POST", `/posts/${id2}/comments`, ethan.token, { body: "still here" });
        check("blocked: can't react or comment", react.status === 404 && comment.status === 404, `status ${react.status}/${comment.status}`);
        const feed = await call("GET", "/posts/feed?page_size=50", ethan.token);
        const exploreAfter = await call("GET", "/posts/feed?mode=explore&page_size=50", ethan.token);
        check(
          "blocked: not in feed or explore",
          ![...(feed.data as any[]), ...(exploreAfter.data as any[])].some((p) => p.author_id === M),
          `n=${feed.data?.length}/${exploreAfter.data?.length}`,
        );
        const dm = await call("POST", "/chat/conversations", ethan.token, { user_ids: [M] });
        check("blocked: can't message the blocker", dm.status === 400, `status ${dm.status}`);
        const threads = await call("GET", `/posts/${id2}/comments`, maya.token);
        const hidden = (threads.data as any[])?.find((c) => c.id === ethanComment.data?.id);
        check(
          "the blocker sees the blocked person's comment hidden",
          hidden?.hidden === true && hidden.body === null && hidden.author === null,
          short(hidden),
        );

        await call("DELETE", `/social/users/${E}/block`, maya.token);
        const back = await call("GET", `/posts/${id2}`, ethan.token);
        check("after unblocking the public post is visible again", back.status === 200, `status ${back.status}`);
        const del = await call("DELETE", `/posts/${id2}`, maya.token);
        postIds.pop();
        check("deleting the post removes its photo", del.status === 204 && (await fetchStatus(url)) >= 400, `status ${del.status}`);
      } finally {
        for (const p of postIds) await call("DELETE", `/posts/${p.id}`, p.token);
        await restorePair(E, M, snap);
        await deleteNotificationsWhere("post_id", created);
        // Upload bookkeeping outlives the post (no endpoint removes it).
        if (mayaUpload?.path) await sql(`DELETE FROM media_upload WHERE storage_path = $1`, [mayaUpload.path]);
      }
      assertAll();
    });
  },
});
