// deno-lint-ignore-file no-explicit-any
// Body progress: tape measurements on body_measurement (validation, coach
// read access) and private progress photos (upload slot → storage → create,
// weight snapshot, signed URLs, owner-only access, delete removes the file).
// Every measurement and photo created here is deleted in `finally`.
import { call, checker, fetchStatus, PNG, seededUsers, short, suite, uploadTo } from "./_client.ts";

Deno.test({
  name: "features: body measurements & progress photos",
  ...suite,
  async fn(t) {
    const { check, assertAll } = checker();
    const { member, trainer, superU, vendor } = await seededUsers();

    await t.step("tape measurements", async () => {
      const ids: string[] = [];
      try {
        const date = "2020-02-03";
        const tapeOnly = await call("POST", "/body-measurements", member.token, { measured_on: date, waist_cm: 84.26, arm_cm: "36" });
        if (tapeOnly.data?.id) ids.push(tapeOnly.data.id);
        check(
          "a tape-only measurement is fine",
          tapeOnly.status === 201 && tapeOnly.data.waist_cm === 84.3 && tapeOnly.data.arm_cm === 36 &&
            tapeOnly.data.weight_kg === null && tapeOnly.data.neck_cm === null,
          short(tapeOnly.data),
        );
        const full = await call("POST", "/body-measurements", member.token, {
          measured_on: date,
          weight_kg: 80.5,
          chest_cm: 101,
          hips_cm: 98.5,
          thigh_cm: 58,
          neck_cm: 38,
        });
        if (full.data?.id) ids.push(full.data.id);
        check("weight + tape", full.status === 201 && full.data.chest_cm === 101 && full.data.hips_cm === 98.5, short(full.data));

        for (const [field, value] of [["waist_cm", 10], ["neck_cm", 120], ["arm_cm", "abc"], ["thigh_cm", -1]] as const) {
          const bad = await call("POST", "/body-measurements", member.token, { [field]: value });
          check(`${field}=${value} is out of range`, bad.status === 400, `status ${bad.status}`);
        }

        const upd = await call("PUT", `/body-measurements/${tapeOnly.data.id}`, member.token, { waist_cm: 83, arm_cm: null });
        check("update a tape value and clear another", upd.status === 200 && upd.data.waist_cm === 83 && upd.data.arm_cm === null, short(upd.data));
        const clearAll = await call("PUT", `/body-measurements/${tapeOnly.data.id}`, member.token, { waist_cm: null });
        check("can't clear the last value", clearAll.status === 400, `status ${clearAll.status}`);

        const list = await call("GET", `/body-measurements?from=${date}&to=${date}`, member.token);
        const listed = (list.data as any[]).find((m) => m.id === full.data.id);
        check("list carries the tape fields", list.status === 200 && listed?.thigh_cm === 58 && "waist_cm" in listed, short(listed));
        const coach = await call("GET", `/body-measurements?user_id=${member.profile.id}&from=${date}&to=${date}`, trainer.token);
        check("coach sees the member's tape measurements", coach.status === 200 && (coach.data as any[]).some((m) => m.neck_cm === 38), `status ${coach.status}`);
      } finally {
        for (const id of ids) await call("DELETE", `/body-measurements/${id}`, member.token);
      }
      assertAll();
    });

    await t.step("progress photos", async () => {
      const photoIds: string[] = [];
      let weighInId: string | null = null;
      try {
        const takenOn = "2020-03-10";
        const weighIn = await call("POST", "/body-measurements", member.token, { measured_on: "2020-03-08", weight_kg: 79.4 });
        weighInId = weighIn.data?.id ?? null;

        const notImage = await call("POST", "/progress-photos/uploads", member.token, { mime_type: "video/mp4", size_bytes: 100 });
        check("only images", notImage.status === 400, `status ${notImage.status}`);
        const tooBig = await call("POST", "/progress-photos/uploads", member.token, { mime_type: "image/jpeg", size_bytes: 30 * 1024 * 1024 });
        check("over 20 MB is refused", tooBig.status === 413, `status ${tooBig.status}`);

        const slot = await call("POST", "/progress-photos/uploads", member.token, { mime_type: "image/png", size_bytes: PNG.length, file_name: "front.png" });
        check("upload slot under my folder", slot.status === 201 && slot.data.path.startsWith(`${member.profile.id}/`), short(slot.data));
        const early = await call("POST", "/progress-photos", member.token, { path: slot.data.path });
        check("creating before the upload finished is 400", early.status === 400, short(early.data));
        check("upload to storage", (await uploadTo(slot.data, PNG, "image/png")) === 200);
        const steal = await call("POST", "/progress-photos", trainer.token, { path: slot.data.path });
        check("someone else can't use my upload", steal.status === 400, `status ${steal.status}`);
        const badPose = await call("POST", "/progress-photos", member.token, { path: slot.data.path, pose: "selfie" });
        check("unknown pose is 400", badPose.status === 400, `status ${badPose.status}`);

        const photo = await call("POST", "/progress-photos", member.token, { path: slot.data.path, pose: "side", taken_on: takenOn, note: " day 1 " });
        if (photo.data?.id) photoIds.push(photo.data.id);
        check(
          "create a photo (weight snapshot from the nearest weigh-in)",
          photo.status === 201 && photo.data.pose === "side" && photo.data.taken_on === takenOn && photo.data.weight_kg === 79.4 &&
            photo.data.note === "day 1" && !("path" in photo.data) &&
            photo.data.url?.startsWith("/storage/v1/object/sign/progress-photos/"),
          short(photo.data),
        );
        check("owner downloads it", (await fetchStatus(photo.data.url)) === 200);
        check("the bucket is private", (await fetchStatus(`/storage/v1/object/public/progress-photos/${slot.data.path}`)) >= 400);
        const reuse = await call("POST", "/progress-photos", member.token, { path: slot.data.path });
        check("an upload is used once", reuse.status === 400, `status ${reuse.status}`);

        const slot2 = await call("POST", "/progress-photos/uploads", member.token, { mime_type: "image/png", size_bytes: PNG.length });
        await uploadTo(slot2.data, PNG, "image/png");
        const second = await call("POST", "/progress-photos", member.token, { path: slot2.data.path, pose: "front", taken_on: "2020-01-01", weight_kg: null });
        if (second.data?.id) photoIds.push(second.data.id);
        check("explicit null weight, no snapshot", second.status === 201 && second.data.weight_kg === null && second.data.pose === "front", short(second.data));

        const list = await call("GET", "/progress-photos?from=2020-01-01&to=2020-12-31", member.token);
        const ids = (list.data as any[]).map((p) => p.id);
        check("list newest first", list.status === 200 && ids.indexOf(photo.data.id) < ids.indexOf(second.data.id) && ids.includes(second.data.id), short(ids));
        check("listed with signed URLs", (list.data as any[]).every((p) => typeof p.url === "string"));
        const sides = await call("GET", "/progress-photos?pose=side&from=2020-01-01&to=2020-12-31", member.token);
        check("filter by pose", sides.status === 200 && (sides.data as any[]).every((p) => p.pose === "side") && (sides.data as any[]).some((p) => p.id === photo.data.id), short(sides.data));
        check("bad pose filter is 400", (await call("GET", "/progress-photos?pose=x", member.token)).status === 400);

        const coach = await call("GET", `/progress-photos?user_id=${member.profile.id}`, trainer.token);
        check("trainer can't list the member's photos", coach.status === 403, `status ${coach.status}`);
        const sup = await call("GET", `/progress-photos?user_id=${member.profile.id}`, superU.token);
        check("nor can a super user", sup.status === 403, `status ${sup.status}`);
        const theirs = await call("GET", "/progress-photos?from=2020-01-01&to=2020-12-31", vendor.token);
        check("others' lists never include them", theirs.status === 200 && !(theirs.data as any[]).some((p) => p.id === photo.data.id));
        const otherEdit = await call("PUT", `/progress-photos/${photo.data.id}`, trainer.token, { note: "x" });
        check("someone else can't edit it", otherEdit.status === 404, `status ${otherEdit.status}`);
        const otherDel = await call("DELETE", `/progress-photos/${photo.data.id}`, superU.token);
        check("someone else can't delete it", otherDel.status === 404, `status ${otherDel.status}`);

        const edit = await call("PUT", `/progress-photos/${photo.data.id}`, member.token, { pose: "back", weight_kg: 79, note: "" });
        check("owner edits it", edit.status === 200 && edit.data.pose === "back" && edit.data.weight_kg === 79 && edit.data.note === null, short(edit.data));
        check("empty edit is 400", (await call("PUT", `/progress-photos/${photo.data.id}`, member.token, {})).status === 400);

        const del = await call("DELETE", `/progress-photos/${photo.data.id}`, member.token);
        check("owner deletes it", del.status === 204, `status ${del.status}`);
        photoIds.splice(photoIds.indexOf(photo.data.id), 1);
        check("the file is gone from storage", (await fetchStatus(photo.data.url)) >= 400);
        check("deleting again is 404", (await call("DELETE", `/progress-photos/${photo.data.id}`, member.token)).status === 404);
        check("non-uuid id is 404", (await call("DELETE", "/progress-photos/nope", member.token)).status === 404);
      } finally {
        for (const id of photoIds) await call("DELETE", `/progress-photos/${id}`, member.token);
        if (weighInId) await call("DELETE", `/body-measurements/${weighInId}`, member.token);
      }
      assertAll();
    });
  },
});
