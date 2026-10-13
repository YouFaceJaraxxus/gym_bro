import { db } from "../_shared/config.ts";
import { json, jsonError, requireCaller } from "../_shared/auth.ts";
import type { DeviceTokenTable } from "../../types/schema/public.ts";

// Push notification device tokens (FCM registration tokens). The app
// registers its token after sign-in and whenever FCM rotates it, and removes
// it on logout. _shared/notify.ts sends pushes to these.

type Platform = DeviceTokenTable["platform"];
const PLATFORMS: readonly Platform[] = ["android", "ios", "web", "macos"];

const COLUMNS = ["id", "token", "platform", "created_at", "last_seen_at"] as const;

Deno.serve(async (req: Request) => {
  const { pathname } = new URL(req.url);
  if (pathname !== "/devices" && pathname !== "/devices/") return jsonError("Not found", 404);

  const { caller, response } = await requireCaller(req);
  if (!caller) return response;

  // ── POST /devices ─────────────────────────────────────────────────────────────
  // {token, platform}. Registers the token for the caller. A token belongs to
  // one device, so if another account registered it before (someone else
  // signed in on this phone) it moves to the caller.
  if (req.method === "POST") {
    const body = await req.json().catch(() => null);
    const token = typeof body?.token === "string" ? body.token.trim() : "";
    const platform = body?.platform as Platform;
    if (!token) return jsonError("token is required", 400);
    if (token.length > 4096) return jsonError("token is too long", 400);
    if (!PLATFORMS.includes(platform)) {
      return jsonError(`platform must be one of: ${PLATFORMS.join(", ")}`, 400);
    }

    const now = new Date().toISOString();
    const device = await db
      .insertInto("device_token")
      .values({ user_id: caller.id, token, platform, last_seen_at: now })
      .onConflict((oc) =>
        oc.column("token").doUpdateSet({ user_id: caller.id, platform, last_seen_at: now })
      )
      .returning(COLUMNS)
      .executeTakeFirstOrThrow();

    return json(device);
  }

  // ── DELETE /devices ───────────────────────────────────────────────────────────
  // {token}. Unregisters one of the caller's own tokens (on logout).
  if (req.method === "DELETE") {
    const body = await req.json().catch(() => null);
    const token = typeof body?.token === "string" ? body.token.trim() : "";
    if (!token) return jsonError("token is required", 400);

    await db
      .deleteFrom("device_token")
      .where("token", "=", token)
      .where("user_id", "=", caller.id)
      .execute();

    return new Response(null, { status: 204 });
  }

  return jsonError("Not found", 404);
});
