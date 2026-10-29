// deno-lint-ignore-file no-explicit-any
// Drafts: CRUD on the caller's own drafts, privacy (nobody else can read,
// change or delete one), validation, media held by a draft (only your own
// unclaimed uploads, not another draft's), media swept when dropped from a
// draft or when the draft is deleted, and publishing a post with a draft's
// upload. Drafts and posts are deleted through the API in `finally`.
import { call, checker, fetchStatus, PNG, short, signin, suite, uploadTo } from "./_client.ts";
import { sql } from "./_db.ts";

Deno.test({
  name: "features: drafts",
  ...suite,
  async fn(t) {
    const { check, assertAll } = checker();
    const [ethan, maya] = await Promise.all([
      signin("ethan.brooks@example.com"),
      signin("maya.flores@example.com"),
    ]);
    const tag = `it-${crypto.randomUUID().slice(0, 8)}`;
    const draftIds: string[] = [];
    const postIds: string[] = [];

    const upload = async (token: string) => {
      const slot = await call("POST", "/posts/uploads", token, { mime_type: "image/png", size_bytes: PNG.length });
      await uploadTo(slot.data, PNG, "image/png");
      return slot.data.path as string;
    };

    try {
      await t.step("1. create, list, read, update, delete", async () => {
        const created = await call("POST", "/drafts", ethan.token, {
          kind: "exercise",
          title: `Squat ${tag}`,
          thumbnail_url: "https://example.com/squat.jpg",
          data: { name: `Squat ${tag}`, primary_muscles: ["quads_all"] },
        });
        if (created.data?.id) draftIds.push(created.data.id);
        check(
          "creates a draft",
          created.status === 201 && created.data.kind === "exercise" && created.data.data.name === `Squat ${tag}` &&
            created.data.thumbnail_url === "https://example.com/squat.jpg" && created.data.media.length === 0,
          short(created.data),
        );
        const id = created.data?.id;

        const list = await call("GET", "/drafts?kind=exercise", ethan.token);
        const listed = (list.data as any[])?.find((d) => d.id === id);
        check("lists it by kind, without data", list.status === 200 && listed?.title === `Squat ${tag}` && !("data" in listed), short(listed));
        const otherKind = await call("GET", "/drafts?kind=training", ethan.token);
        check("…not under another kind", !(otherKind.data as any[])?.some((d) => d.id === id));

        const updated = await call("PUT", `/drafts/${id}`, ethan.token, { title: `Front squat ${tag}`, data: { name: "Front squat" } });
        check(
          "updates replace title and data",
          updated.status === 200 && updated.data.title === `Front squat ${tag}` && updated.data.data.name === "Front squat" &&
            updated.data.thumbnail_url === null && updated.data.updated_at >= created.data.updated_at,
          short(updated.data),
        );

        const mayaRead = await call("GET", `/drafts/${id}`, maya.token);
        const mayaEdit = await call("PUT", `/drafts/${id}`, maya.token, { data: {} });
        const mayaDelete = await call("DELETE", `/drafts/${id}`, maya.token);
        const mayaList = await call("GET", "/drafts?kind=exercise", maya.token);
        check(
          "drafts are private (404 to others, absent from their list)",
          mayaRead.status === 404 && mayaEdit.status === 404 && mayaDelete.status === 404 &&
            !(mayaList.data as any[])?.some((d) => d.id === id),
          `status ${mayaRead.status}/${mayaEdit.status}/${mayaDelete.status}`,
        );
        const anon = await call("GET", "/drafts", undefined);
        check("anonymous is 401", anon.status === 401, `status ${anon.status}`);

        const del = await call("DELETE", `/drafts/${id}`, ethan.token);
        const gone = await call("GET", `/drafts/${id}`, ethan.token);
        check("deletes it", del.status === 204 && gone.status === 404, `status ${del.status}/${gone.status}`);
        assertAll();
      });

      await t.step("2. validation", async () => {
        const badKind = await call("POST", "/drafts", ethan.token, { kind: "invoice", data: {} });
        const badData = await call("POST", "/drafts", ethan.token, { kind: "post", data: [1, 2] });
        const badScope = await call("POST", "/drafts", ethan.token, { kind: "business_post", scope_id: "nope", data: {} });
        const badThumb = await call("POST", "/drafts", ethan.token, { kind: "post", thumbnail_url: "javascript:alert(1)", data: {} });
        const longTitle = await call("POST", "/drafts", ethan.token, { kind: "post", title: "x".repeat(201), data: {} });
        const huge = await call("POST", "/drafts", ethan.token, { kind: "post", data: { blob: "x".repeat(200_001) } });
        const ghost = await call("GET", `/drafts/${crypto.randomUUID()}`, ethan.token);
        const listBad = await call("GET", "/drafts?kind=invoice", ethan.token);
        for (const r of [badKind, badData, badScope, badThumb, longTitle, huge]) if (r.status === 201) draftIds.push(r.data.id);
        check(
          "rejects bad kind, data, scope, thumbnail, title and size; unknown id is 404",
          [badKind, badData, badScope, badThumb, longTitle, huge, listBad].every((r) => r.status === 400) && ghost.status === 404,
          [badKind, badData, badScope, badThumb, longTitle, huge, listBad, ghost].map((r) => r.status).join("/"),
        );
        assertAll();
      });

      await t.step("3. media held by a draft", async () => {
        const mayaPath = await upload(maya.token);
        const stolen = await call("POST", "/drafts", ethan.token, { kind: "post", data: {}, media: [{ path: mayaPath }] });
        if (stolen.status === 201) draftIds.push(stolen.data.id);
        check("someone else's upload can't go on your draft", stolen.status === 400, `status ${stolen.status}`);

        const [a, b] = [await upload(ethan.token), await upload(ethan.token)];
        const draft = await call("POST", "/drafts", ethan.token, {
          kind: "post",
          title: `Beach ${tag}`,
          data: { caption: `Beach ${tag}`, visibility: "public" },
          media: [
            { path: a, width: 1, height: 1, edit: { filter: "vivid", adjust: { brightness: 0.2 } } },
            { path: b, width: 1, height: 1 },
          ],
        });
        if (draft.data?.id) draftIds.push(draft.data.id);
        const id = draft.data?.id;
        check(
          "media is stored with its edit state and signed URLs",
          draft.status === 201 && draft.data.media.length === 2 && draft.data.media[0].mime_type === "image/png" &&
            draft.data.media[0].edit?.filter === "vivid" && typeof draft.data.media[0].url === "string" &&
            draft.data.thumbnail_url === draft.data.media[0].url,
          short(draft.data),
        );
        check("signed media URL works", draft.data?.media?.[0]?.url && (await fetchStatus(draft.data.media[0].url)) === 200);
        const held = await sql<{ n: number }>(
          "SELECT count(*)::int AS n FROM media_upload WHERE draft_id = $1 AND claimed_at IS NULL",
          [id],
        );
        check("its upload slots are held by the draft", held === null || held[0].n === 2, short(held));

        const second = await call("POST", "/drafts", ethan.token, { kind: "post", data: {}, media: [{ path: a }] });
        if (second.status === 201) draftIds.push(second.data.id);
        check("an upload can't be on two drafts", second.status === 400, `status ${second.status}`);

        // Dropping b from the draft deletes its file.
        const bUrl = draft.data?.media?.[1]?.url;
        const dropped = await call("PUT", `/drafts/${id}`, ethan.token, {
          title: `Beach ${tag}`,
          data: { caption: `Beach ${tag}` },
          media: [{ path: a, edit: { filter: "vivid" } }],
        });
        check("update drops a photo", dropped.status === 200 && dropped.data.media.length === 1, short(dropped.data));
        check("…and its file is gone", !bUrl || (await fetchStatus(bUrl)) !== 200);

        // Publishing: the post claims the draft's upload, then the draft is deleted.
        const post = await call("POST", "/posts", ethan.token, { content: `Beach ${tag}`, media: [{ path: a, width: 1, height: 1 }] });
        if (post.data?.id) postIds.push(post.data.id);
        check("a post can use the draft's upload", post.status === 201 && post.data.images.length === 1, short(post.data));
        const del = await call("DELETE", `/drafts/${id}`, ethan.token);
        const postAfter = await call("GET", `/posts/${post.data?.id}`, ethan.token);
        check(
          "deleting the draft keeps the published post's media",
          del.status === 204 && postAfter.status === 200 && (await fetchStatus(postAfter.data.images[0].url)) === 200,
          `status ${del.status}/${postAfter.status}`,
        );

        // Deleting an unpublished draft deletes its uploads.
        const c = await upload(ethan.token);
        const temp = await call("POST", "/drafts", ethan.token, { kind: "post", data: {}, media: [{ path: c }] });
        const cUrl = temp.data?.media?.[0]?.url;
        const tempDel = await call("DELETE", `/drafts/${temp.data?.id}`, ethan.token);
        check(
          "deleting a draft deletes its unpublished media",
          temp.status === 201 && tempDel.status === 204 && !!cUrl && (await fetchStatus(cUrl)) !== 200,
          `status ${temp.status}/${tempDel.status}`,
        );
        assertAll();
      });
    } finally {
      for (const id of draftIds) await call("DELETE", `/drafts/${id}`, ethan.token);
      for (const id of postIds) await call("DELETE", `/posts/${id}`, ethan.token);
    }
  },
});
