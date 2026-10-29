import { type Kysely, sql } from "npm:kysely@^0.27";
import { db, supabaseAnonKey } from "../_shared/config.ts";
import { type Caller, forbidden, json, jsonError, requireCaller } from "../_shared/auth.ts";
import { notify, pushOnly } from "../_shared/notify.ts";
import { broadcast, broadcastToUsers, chatTopic, userTopic } from "../_shared/realtime.ts";
import {
  createUploadSlot,
  MAX_UPLOAD_BYTES,
  mediaTypeOf,
  normalizeMime,
  removeObjects,
  signPaths,
  verifyUploads,
} from "../_shared/media.ts";
import {
  directMessageStatus,
  displayName,
  isBlockedBetween,
  isReaction,
  REACTION_EMOJI,
  touchActivity,
  unreadMessageSql,
  type UserSummary,
  userSummaries,
} from "../_shared/social.ts";
import type { Database, ParticipantRole, ParticipantStatus, WhoCanMessage } from "../../types/schema/public.ts";

// Direct and group chat.
//
//   GET    /chat/realtime                                   anon key + my inbox topic
//   GET    /chat/conversations?box=inbox|requests|archived  list, newest activity first
//   POST   /chat/conversations {user_ids, title?, group?}   one user → direct (get or create); else group
//   GET    /chat/conversations/:id                          detail + participants (read receipts)
//   PUT    /chat/conversations/:id {title, description, avatar_url}   group admins
//   DELETE /chat/conversations/:id                          group owner: delete for everyone
//   PUT    /chat/conversations/:id/settings {muted, muted_until, archived}
//   POST   /chat/conversations/:id/accept                   accept a message request
//   POST   /chat/conversations/:id/clear                    hide history for me
//   POST   /chat/conversations/:id/read                     mark read up to now
//   POST   /chat/conversations/:id/participants {user_ids}  group admins add people
//   PUT    /chat/conversations/:id/participants/:userId {role}   owner sets admin/member
//   DELETE /chat/conversations/:id/participants/:userId     remove (admins) / leave (self) / decline request
//   GET    /chat/conversations/:id/messages?before_id=|after_id=&limit=
//   POST   /chat/conversations/:id/messages {body?, attachments?, reply_to_id?, client_id?}
//   POST   /chat/conversations/:id/uploads {mime_type, file_name?, size_bytes}  signed upload URL
//   GET    /chat/conversations/:id/media                    shared photos/videos/files
//   PUT    /chat/messages/:id {body}                        edit own text
//   DELETE /chat/messages/:id                               unsend own (group admins: anyone's)
//   PUT    /chat/messages/:id/reaction {reaction}, DELETE   one reaction per person
//
// Realtime (see _shared/realtime.ts): chat:<id> gets message, message_updated,
// read, conversation_updated; user:<id> gets inbox, conversation_added,
// conversation_removed. Typing and presence are client-to-client on chat-live:<id>.

const BODY_MAX = 4000;
const TITLE_MAX = 100;
const GROUP_MAX = 64;
const ATTACHMENTS_MAX = 10;
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const BUCKET = "chat-media" as const;

type Route =
  | { kind: "realtime" }
  | { kind: "conversations" }
  | { kind: "conversation"; id: string }
  | { kind: "conv_action"; id: string; action: "settings" | "accept" | "clear" | "read" | "uploads" | "media" }
  | { kind: "participants"; id: string }
  | { kind: "participant"; id: string; userId: string }
  | { kind: "messages"; id: string }
  | { kind: "message"; messageId: string }
  | { kind: "reaction"; messageId: string }
  | { kind: "unknown" };

function parsePath(pathname: string): Route {
  const p = pathname.replace(/\/+$/, "");
  if (p === "/chat/realtime") return { kind: "realtime" };
  if (p === "/chat/conversations") return { kind: "conversations" };
  let m = p.match(/^\/chat\/messages\/([^/]+)\/reaction$/);
  if (m) return { kind: "reaction", messageId: m[1] };
  m = p.match(/^\/chat\/messages\/([^/]+)$/);
  if (m) return { kind: "message", messageId: m[1] };
  m = p.match(/^\/chat\/conversations\/([^/]+)\/participants\/([^/]+)$/);
  if (m) return { kind: "participant", id: m[1], userId: m[2] };
  m = p.match(/^\/chat\/conversations\/([^/]+)\/participants$/);
  if (m) return { kind: "participants", id: m[1] };
  m = p.match(/^\/chat\/conversations\/([^/]+)\/messages$/);
  if (m) return { kind: "messages", id: m[1] };
  m = p.match(/^\/chat\/conversations\/([^/]+)\/(settings|accept|clear|read|uploads|media)$/);
  if (m) return { kind: "conv_action", id: m[1], action: m[2] as "settings" };
  m = p.match(/^\/chat\/conversations\/([^/]+)$/);
  if (m) return { kind: "conversation", id: m[1] };
  return { kind: "unknown" };
}

// ── Access ────────────────────────────────────────────────────────────────────

type Membership = {
  conversation_id: string;
  kind: "direct" | "group";
  role: ParticipantRole;
  status: ParticipantStatus;
  joined_at: string;
  cleared_at: string | null;
};

async function membership(conversationId: string, userId: string): Promise<Membership | null> {
  if (!UUID_RE.test(conversationId)) return null;
  const row = await db.selectFrom("conversation_participant as p")
    .innerJoin("conversation as c", "c.id", "p.conversation_id")
    .select(["p.conversation_id", "c.kind", "p.role", "p.status", "p.joined_at", "p.cleared_at"])
    .where("p.conversation_id", "=", conversationId)
    .where("p.user_id", "=", userId)
    .executeTakeFirst();
  return row ?? null;
}

const notFound = () => jsonError("Conversation not found", 404);
const isAdmin = (m: Membership) => m.role === "owner" || m.role === "admin";

/** Messages a participant can see start here (groups: when they joined; cleared history hidden). */
function visibleFrom(m: Membership): string {
  const joined = m.kind === "group" ? m.joined_at : "-infinity";
  if (!m.cleared_at) return joined;
  return m.kind === "group" && new Date(m.joined_at) > new Date(m.cleared_at) ? m.joined_at : m.cleared_at;
}

async function participantIds(conversationId: string, executor: Kysely<Database> = db): Promise<string[]> {
  const rows = await executor.selectFrom("conversation_participant").select("user_id")
    .where("conversation_id", "=", conversationId).execute();
  return rows.map((r) => r.user_id);
}

// ── Serialization ─────────────────────────────────────────────────────────────

const MESSAGE_COLS = [
  "id",
  "conversation_id",
  "sender_id",
  "kind",
  "body",
  "reply_to_id",
  "client_id",
  "metadata",
  "created_at",
  "edited_at",
  "deleted_at",
] as const;

type MessageRow = {
  id: string;
  conversation_id: string;
  sender_id: string | null;
  kind: "text" | "media" | "system";
  body: string | null;
  reply_to_id: string | null;
  client_id: string | null;
  metadata: Record<string, unknown>;
  created_at: string;
  edited_at: string | null;
  deleted_at: string | null;
};

/** Attachments (with signed URLs), reactions, sender and reply previews. */
async function decorateMessages(rows: MessageRow[]) {
  if (!rows.length) return [];
  const ids = rows.map((r) => r.id);
  const replyIds = [...new Set(rows.map((r) => r.reply_to_id).filter((x): x is string => !!x))];
  const [attachments, reactions, replies] = await Promise.all([
    db.selectFrom("message_attachment")
      .select(["id", "message_id", "storage_path", "mime_type", "size_bytes", "file_name", "width", "height", "duration_ms", "position"])
      .where("message_id", "in", ids)
      .orderBy("position")
      .execute(),
    db.selectFrom("message_reaction").select(["message_id", "user_id", "reaction"]).where("message_id", "in", ids)
      .orderBy("created_at").execute(),
    replyIds.length
      ? db.selectFrom("message").select(["id", "sender_id", "kind", "body", "deleted_at"]).where("id", "in", replyIds)
        .execute()
      : Promise.resolve([]),
  ]);
  const replyAttachmentKinds = replyIds.length
    ? await db.selectFrom("message_attachment").select(["message_id", "mime_type"]).where("message_id", "in", replyIds)
      .orderBy("position").execute()
    : [];
  const signed = await signPaths(BUCKET, attachments.map((a) => a.storage_path));
  const people = await userSummaries([...rows.map((r) => r.sender_id), ...replies.map((r) => r.sender_id)]);

  const attByMessage = new Map<string, unknown[]>();
  for (const a of attachments) {
    const list = attByMessage.get(a.message_id) ?? attByMessage.set(a.message_id, []).get(a.message_id)!;
    list.push({
      id: a.id,
      url: signed.get(a.storage_path) ?? null,
      mime_type: a.mime_type,
      media_type: mediaTypeOf(a.mime_type),
      size_bytes: Number(a.size_bytes),
      file_name: a.file_name,
      width: a.width,
      height: a.height,
      duration_ms: a.duration_ms,
    });
  }
  const reactByMessage = new Map<string, { user_id: string; reaction: string }[]>();
  for (const r of reactions) {
    (reactByMessage.get(r.message_id) ?? reactByMessage.set(r.message_id, []).get(r.message_id)!)
      .push({ user_id: r.user_id, reaction: r.reaction });
  }
  const replyById = new Map(replies.map((r) => [r.id, r]));
  const replyMedia = new Map<string, string>();
  for (const a of replyAttachmentKinds) if (!replyMedia.has(a.message_id)) replyMedia.set(a.message_id, mediaTypeOf(a.mime_type));

  return rows.map((r) => {
    const deleted = !!r.deleted_at;
    const reply = r.reply_to_id ? replyById.get(r.reply_to_id) : undefined;
    return {
      ...r,
      body: deleted ? null : r.body,
      sender: r.sender_id ? people[r.sender_id] ?? null : null,
      attachments: deleted ? [] : attByMessage.get(r.id) ?? [],
      reactions: deleted ? [] : reactByMessage.get(r.id) ?? [],
      reply_to: reply
        ? {
          id: reply.id,
          sender_id: reply.sender_id,
          sender_name: reply.sender_id && people[reply.sender_id] ? displayName(people[reply.sender_id]) : null,
          body: reply.deleted_at ? null : reply.body?.slice(0, 200) ?? null,
          media_type: reply.deleted_at ? null : replyMedia.get(reply.id) ?? null,
          deleted: !!reply.deleted_at,
        }
        : null,
    };
  });
}

async function loadMessage(id: string) {
  const row = await db.selectFrom("message").select(MESSAGE_COLS).where("id", "=", id).executeTakeFirst();
  if (!row) return null;
  const [decorated] = await decorateMessages([row]);
  return decorated;
}

/** Short inbox preview of a message ("📷 Photo", "Ana: hey"). */
function previewText(m: { kind: string; body: string | null; deleted_at: string | null }, mediaType?: string | null) {
  if (m.deleted_at) return null;
  if (m.body) return m.body.slice(0, 140);
  return mediaType ?? (m.kind === "media" ? "file" : null);
}

type ConversationListRow = {
  id: string;
  kind: "direct" | "group";
  title: string | null;
  description: string | null;
  avatar_url: string | null;
  created_by: string | null;
  created_at: string;
  last_message_at: string;
  role: ParticipantRole;
  status: ParticipantStatus;
  muted_until: string | null;
  archived_at: string | null;
  last_read_at: string | null;
  unread_count: number;
  participant_count: number;
  last_message: MessageRow | null;
  last_media_type: string | null;
};

async function listConversations(
  caller: Caller,
  opts: { box?: "inbox" | "requests" | "archived"; ids?: string[]; limit?: number; offset?: number },
) {
  const box = opts.box ?? "inbox";
  const { rows } = await sql<ConversationListRow>`
    SELECT c.id, c.kind, c.title, c.description, c.avatar_url, c.created_by, c.created_at, c.last_message_at,
           p.role, p.status, p.muted_until, p.archived_at, p.last_read_at,
           (SELECT count(*)::int FROM message m
             WHERE m.conversation_id = c.id AND ${unreadMessageSql(caller.id)}) AS unread_count,
           (SELECT count(*)::int FROM conversation_participant x WHERE x.conversation_id = c.id) AS participant_count,
           lm.msg AS last_message,
           lm.media_type AS last_media_type
    FROM conversation_participant p
    JOIN conversation c ON c.id = p.conversation_id
    LEFT JOIN LATERAL (
      SELECT to_jsonb(m) - 'client_id' AS msg,
             (SELECT CASE WHEN a.mime_type LIKE 'image/%' THEN 'image' WHEN a.mime_type LIKE 'video/%' THEN 'video'
                          WHEN a.mime_type LIKE 'audio/%' THEN 'audio' ELSE 'file' END
              FROM message_attachment a WHERE a.message_id = m.id ORDER BY a.position LIMIT 1) AS media_type
      FROM message m
      WHERE m.conversation_id = c.id
        AND m.created_at > COALESCE(p.cleared_at, '-infinity')
        AND (c.kind = 'direct' OR m.created_at >= p.joined_at)
      ORDER BY m.created_at DESC, m.id DESC
      LIMIT 1
    ) lm ON TRUE
    WHERE p.user_id = ${caller.id}
      AND (${opts.ids ?? null}::uuid[] IS NOT NULL AND c.id = ANY(${opts.ids ?? null}::uuid[])
        OR ${opts.ids ?? null}::uuid[] IS NULL AND (
          (${box} = 'requests' AND p.status = 'request')
          OR (${box} = 'archived' AND p.status = 'active' AND p.archived_at IS NOT NULL)
          OR (${box} = 'inbox' AND p.status = 'active' AND p.archived_at IS NULL
              -- an empty direct chat I didn't start isn't shown yet
              -- (nor one I started and then left)
              AND (c.kind = 'group' OR lm.msg IS NOT NULL OR (c.created_by = ${caller.id} AND p.cleared_at IS NULL)))))
    ORDER BY c.last_message_at DESC, c.id
    LIMIT ${opts.limit ?? 30} OFFSET ${opts.offset ?? 0}
  `.execute(db);
  if (!rows.length) return [];

  // Up to 5 other participants per conversation for titles and avatars.
  const { rows: members } = await sql<{ conversation_id: string; user_id: string }>`
    SELECT conversation_id, user_id FROM (
      SELECT conversation_id, user_id,
             row_number() OVER (PARTITION BY conversation_id ORDER BY joined_at, user_id) AS rn
      FROM conversation_participant
      WHERE conversation_id = ANY(${rows.map((r) => r.id)}::uuid[]) AND user_id <> ${caller.id}
    ) x WHERE rn <= 5
  `.execute(db);
  const people = await userSummaries([
    ...members.map((m) => m.user_id),
    ...rows.map((r) => (r.last_message?.sender_id as string | null) ?? null),
  ]);
  const presence = await db.selectFrom("users").select(["id", "last_active_at", "show_activity_status"])
    .where("id", "in", [...new Set(members.map((m) => m.user_id)), caller.id]).execute();
  const activeById = new Map(presence.map((p) => [p.id, p.show_activity_status ? p.last_active_at : null]));
  const byConv = new Map<string, UserSummary[]>();
  for (const m of members) {
    if (people[m.user_id]) (byConv.get(m.conversation_id) ?? byConv.set(m.conversation_id, []).get(m.conversation_id)!).push(people[m.user_id]);
  }

  const now = Date.now();
  return rows.map((r) => {
    const others = byConv.get(r.id) ?? [];
    const lm = r.last_message;
    return {
      id: r.id,
      kind: r.kind,
      title: r.title,
      description: r.description,
      avatar_url: r.avatar_url,
      created_by: r.created_by,
      created_at: r.created_at,
      last_message_at: r.last_message_at,
      my_role: r.role,
      my_status: r.status,
      muted: !!r.muted_until && new Date(r.muted_until).getTime() > now,
      muted_until: r.muted_until,
      archived: !!r.archived_at,
      last_read_at: r.last_read_at,
      unread_count: r.unread_count,
      participant_count: r.participant_count,
      participants: others,
      other_user: r.kind === "direct" ? others[0] ?? null : null,
      other_last_active_at: r.kind === "direct" && others[0] ? activeById.get(others[0].id) ?? null : null,
      last_message: lm
        ? {
          id: lm.id,
          sender_id: lm.sender_id,
          sender_name: lm.sender_id && people[lm.sender_id as string] ? people[lm.sender_id as string].name : null,
          kind: lm.kind,
          preview: previewText(lm, r.last_media_type),
          metadata: lm.metadata,
          created_at: lm.created_at,
          deleted: !!lm.deleted_at,
        }
        : null,
    };
  });
}

async function conversationDetail(caller: Caller, id: string) {
  const [summary] = await listConversations(caller, { ids: [id] });
  if (!summary) return null;
  const parts = await db.selectFrom("conversation_participant as p")
    .innerJoin("users as u", "u.id", "p.user_id")
    .select([
      "u.id",
      "u.username",
      "u.name",
      "u.last_name",
      "u.avatar_url",
      "u.show_activity_status",
      "u.last_active_at",
      "p.role",
      "p.status",
      "p.joined_at",
      "p.last_read_at",
    ])
    .where("p.conversation_id", "=", id)
    .orderBy(sql`CASE p.role WHEN 'owner' THEN 0 WHEN 'admin' THEN 1 ELSE 2 END`)
    .orderBy("u.name")
    .execute();
  return {
    ...summary,
    members: parts.map(({ show_activity_status, last_active_at, ...p }) => ({
      ...p,
      last_active_at: show_activity_status ? last_active_at : null,
    })),
  };
}

// ── System messages ───────────────────────────────────────────────────────────

async function systemMessage(
  trx: Kysely<Database>,
  conversationId: string,
  actorId: string,
  metadata: Record<string, unknown>,
) {
  const msg = await trx.insertInto("message")
    .values({ conversation_id: conversationId, sender_id: actorId, kind: "system", metadata })
    .returning(MESSAGE_COLS)
    .executeTakeFirstOrThrow();
  await trx.updateTable("conversation").set({ last_message_at: msg.created_at }).where("id", "=", conversationId)
    .execute();
  return msg;
}

async function announce(conversationId: string, messages: MessageRow[]) {
  for (const m of await decorateMessages(messages)) await broadcast(chatTopic(conversationId), "message", m);
}

// ── Adding people ─────────────────────────────────────────────────────────────

/**
 * Validates people to add: they exist, aren't blocked either way, and get
 * status 'active' if they let `adder` message them, else 'request'.
 */
async function resolveInvitees(adder: Caller, userIds: string[]) {
  const unique = [...new Set(userIds)].filter((id) => id !== adder.id);
  if (unique.some((id) => !UUID_RE.test(id))) return { error: "user_ids must be user ids" };
  const users = unique.length
    ? await db.selectFrom("users").select(["id", "who_can_message"]).where("id", "in", unique).execute()
    : [];
  if (users.length !== unique.length) return { error: "Some users don't exist" };
  const out: { id: string; status: ParticipantStatus }[] = [];
  for (const u of users) {
    const status = await directMessageStatus(adder.id, u as { id: string; who_can_message: WhoCanMessage });
    if (!status) return { error: "You can't add someone who blocked you or whom you blocked" };
    out.push({ id: u.id, status });
  }
  return { invitees: out };
}

// ── Handler ───────────────────────────────────────────────────────────────────

async function handler(req: Request): Promise<Response> {
  const url = new URL(req.url);
  const route = parsePath(url.pathname);
  if (route.kind === "unknown") return jsonError("Not found", 404);

  const { caller, response } = await requireCaller(req);
  if (!caller) return response;
  await touchActivity(caller.id);

  // ── GET /chat/realtime ───────────────────────────────────────────────────────
  // The anon key is public by design; the app passes it as `apikey` and the
  // user's access token for channel authorization.
  if (req.method === "GET" && route.kind === "realtime") {
    return json({ anon_key: supabaseAnonKey, user_topic: userTopic(caller.id) });
  }

  // ── GET /chat/conversations ──────────────────────────────────────────────────
  if (req.method === "GET" && route.kind === "conversations") {
    const boxParam = url.searchParams.get("box") ?? "inbox";
    if (!["inbox", "requests", "archived"].includes(boxParam)) return jsonError("box must be inbox, requests or archived", 400);
    const page = Math.max(0, parseInt(url.searchParams.get("page") ?? "0") || 0);
    const pageSize = Math.min(100, Math.max(1, parseInt(url.searchParams.get("page_size") ?? "") || 30));
    return json(await listConversations(caller, {
      box: boxParam as "inbox",
      limit: pageSize,
      offset: page * pageSize,
    }));
  }

  // ── POST /chat/conversations ─────────────────────────────────────────────────
  if (req.method === "POST" && route.kind === "conversations") {
    const body = await req.json().catch(() => null);
    const userIds: unknown = body?.user_ids;
    if (!Array.isArray(userIds) || userIds.length === 0 || userIds.some((x) => typeof x !== "string")) {
      return jsonError("user_ids must be a non-empty list", 400);
    }
    const title = typeof body?.title === "string" ? body.title.trim() : "";
    if (title.length > TITLE_MAX) return jsonError(`title is limited to ${TITLE_MAX} characters`, 400);
    const others = [...new Set(userIds as string[])].filter((id) => id !== caller.id);
    if (others.length === 0) return jsonError("Add at least one other person", 400);
    const wantsGroup = body?.group === true || others.length > 1 || !!title;

    const resolved = await resolveInvitees(caller, others);
    if ("error" in resolved) return jsonError(resolved.error!, 400);
    const invitees = resolved.invitees!;

    // Direct: one conversation per pair, reused.
    if (!wantsGroup) {
      const other = invitees[0];
      const key = [caller.id, other.id].sort().join(":");
      const id = await db.transaction().execute(async (trx) => {
        const existing = await trx.selectFrom("conversation").select("id").where("direct_key", "=", key)
          .executeTakeFirst();
        const convId = existing?.id ?? (await trx.insertInto("conversation")
          .values({ kind: "direct", direct_key: key, created_by: caller.id })
          .onConflict((oc) => oc.column("direct_key").doUpdateSet({ updated_at: sql`conversation.updated_at` }))
          .returning("id")
          .executeTakeFirstOrThrow()).id;
        // Re-add whoever left/declined: me active, them per their settings.
        await trx.insertInto("conversation_participant")
          .values([
            { conversation_id: convId, user_id: caller.id, status: "active", role: "member" },
            { conversation_id: convId, user_id: other.id, status: other.status, role: "member", added_by: caller.id },
          ])
          .onConflict((oc) => oc.columns(["conversation_id", "user_id"]).doNothing())
          .execute();
        // Opening a chat I had archived brings it back.
        await trx.updateTable("conversation_participant").set({ archived_at: null })
          .where("conversation_id", "=", convId).where("user_id", "=", caller.id).execute();
        return convId;
      });
      return json(await conversationDetail(caller, id), 200);
    }

    if (invitees.length + 1 > GROUP_MAX) return jsonError(`Groups are limited to ${GROUP_MAX} people`, 400);
    const id = await db.transaction().execute(async (trx) => {
      const conv = await trx.insertInto("conversation")
        .values({ kind: "group", title: title || null, created_by: caller.id })
        .returning("id")
        .executeTakeFirstOrThrow();
      await trx.insertInto("conversation_participant").values([
        { conversation_id: conv.id, user_id: caller.id, role: "owner", status: "active" },
        ...invitees.map((i) => ({
          conversation_id: conv.id,
          user_id: i.id,
          role: "member" as const,
          status: i.status,
          added_by: caller.id,
        })),
      ]).execute();
      await systemMessage(trx, conv.id, caller.id, { event: "created", title: title || null });
      await broadcastToUsers([caller.id, ...invitees.map((i) => i.id)], "conversation_added", { conversation_id: conv.id }, trx);
      return conv.id;
    });
    await notify(invitees.filter((i) => i.status === "active").map((i) => i.id), {
      type: "group_added",
      title: `${displayName(caller)} added you to ${title || "a group"}`,
      body: "",
      metadata: { conversation_id: id },
    });
    return json(await conversationDetail(caller, id), 201);
  }

  // Everything below is about one conversation or message.

  // ── Message-level routes ─────────────────────────────────────────────────────
  if (route.kind === "message" || route.kind === "reaction") {
    if (!UUID_RE.test(route.messageId)) return jsonError("Message not found", 404);
    const msg = await db.selectFrom("message").select(MESSAGE_COLS).where("id", "=", route.messageId)
      .executeTakeFirst();
    if (!msg) return jsonError("Message not found", 404);
    const me = await membership(msg.conversation_id, caller.id);
    if (!me || new Date(msg.created_at) <= new Date(visibleFrom(me))) return jsonError("Message not found", 404);
    if (msg.deleted_at) return jsonError("Message was unsent", 410);
    if (msg.kind === "system") return jsonError("System messages can't be changed", 400);

    if (route.kind === "message" && req.method === "PUT") {
      if (msg.sender_id !== caller.id) return forbidden("You can only edit your own messages");
      const body = await req.json().catch(() => null);
      const text = typeof body?.body === "string" ? body.body.trim() : "";
      if (!text && msg.kind === "text") return jsonError("body is required", 400);
      if (text.length > BODY_MAX) return jsonError(`Messages are limited to ${BODY_MAX} characters`, 400);
      await db.updateTable("message").set({ body: text || null, edited_at: new Date().toISOString() })
        .where("id", "=", msg.id).execute();
    } else if (route.kind === "message" && req.method === "DELETE") {
      if (msg.sender_id !== caller.id && !(me.kind === "group" && isAdmin(me))) {
        return forbidden("You can only unsend your own messages");
      }
      const paths = await db.selectFrom("message_attachment").select("storage_path").where("message_id", "=", msg.id)
        .execute();
      await db.transaction().execute(async (trx) => {
        await trx.updateTable("message").set({ deleted_at: new Date().toISOString(), body: null })
          .where("id", "=", msg.id).execute();
        await trx.deleteFrom("message_attachment").where("message_id", "=", msg.id).execute();
        await trx.deleteFrom("message_reaction").where("message_id", "=", msg.id).execute();
      });
      await removeObjects(BUCKET, paths.map((p) => p.storage_path));
    } else if (route.kind === "reaction" && req.method === "PUT") {
      const body = await req.json().catch(() => null);
      if (!isReaction(body?.reaction)) return jsonError("Unknown reaction", 400);
      await db.insertInto("message_reaction")
        .values({ message_id: msg.id, user_id: caller.id, reaction: body.reaction })
        .onConflict((oc) => oc.columns(["message_id", "user_id"]).doUpdateSet({ reaction: body.reaction }))
        .execute();
      if (msg.sender_id && msg.sender_id !== caller.id) {
        pushOnly([msg.sender_id], {
          type: "chat_message",
          title: displayName(caller),
          body: `Reacted ${REACTION_EMOJI[body.reaction as keyof typeof REACTION_EMOJI]} to your message`,
          metadata: { conversation_id: msg.conversation_id, message_id: msg.id },
        });
      }
    } else if (route.kind === "reaction" && req.method === "DELETE") {
      await db.deleteFrom("message_reaction").where("message_id", "=", msg.id).where("user_id", "=", caller.id)
        .execute();
    } else {
      return jsonError("Method not allowed", 405);
    }

    const updated = await loadMessage(msg.id);
    await broadcast(chatTopic(msg.conversation_id), "message_updated", updated);
    return json(updated);
  }

  if (route.kind === "realtime" || route.kind === "conversations") return jsonError("Method not allowed", 405);
  const convId = route.id;
  const me = await membership(convId, caller.id);
  if (!me) return notFound();

  // ── GET /chat/conversations/:id ──────────────────────────────────────────────
  if (req.method === "GET" && route.kind === "conversation") {
    return json(await conversationDetail(caller, convId));
  }

  // ── PUT /chat/conversations/:id — group admins ───────────────────────────────
  if (req.method === "PUT" && route.kind === "conversation") {
    if (me.kind !== "group") return jsonError("Only group chats have a title", 400);
    if (!isAdmin(me)) return forbidden("Only group admins can edit the group");
    const body = await req.json().catch(() => null);
    const update: { title?: string | null; description?: string | null; avatar_url?: string | null } = {};
    if (body && "title" in body) {
      const t = typeof body.title === "string" ? body.title.trim() : "";
      if (t.length > TITLE_MAX) return jsonError(`title is limited to ${TITLE_MAX} characters`, 400);
      update.title = t || null;
    }
    if (body && "description" in body) {
      const d = typeof body.description === "string" ? body.description.trim() : "";
      if (d.length > 500) return jsonError("description is limited to 500 characters", 400);
      update.description = d || null;
    }
    if (body && "avatar_url" in body) {
      if (body.avatar_url !== null && typeof body.avatar_url !== "string") return jsonError("avatar_url must be a string", 400);
      update.avatar_url = body.avatar_url;
    }
    if (Object.keys(update).length === 0) return jsonError("Nothing to update", 400);
    const sys = await db.transaction().execute(async (trx) => {
      await trx.updateTable("conversation").set({ ...update, updated_at: new Date().toISOString() })
        .where("id", "=", convId).execute();
      if ("title" in update) return await systemMessage(trx, convId, caller.id, { event: "renamed", title: update.title });
      if ("avatar_url" in update) return await systemMessage(trx, convId, caller.id, { event: "photo_changed" });
      return null;
    });
    if (sys) await announce(convId, [sys]);
    const detail = await conversationDetail(caller, convId);
    await broadcast(chatTopic(convId), "conversation_updated", { conversation_id: convId });
    return json(detail);
  }

  // ── DELETE /chat/conversations/:id — group owner deletes for everyone ────────
  if (req.method === "DELETE" && route.kind === "conversation") {
    if (me.kind !== "group" || me.role !== "owner") return forbidden("Only the group owner can delete the group");
    await deleteConversation(convId);
    return new Response(null, { status: 204 });
  }

  // ── PUT /chat/conversations/:id/settings ─────────────────────────────────────
  if (req.method === "PUT" && route.kind === "conv_action" && route.action === "settings") {
    const body = await req.json().catch(() => null);
    const update: { muted_until?: string | null; archived_at?: string | null } = {};
    if (body && "muted" in body) {
      if (typeof body.muted !== "boolean") return jsonError("muted must be a boolean", 400);
      // "Muted" with no end is stored as far in the future.
      update.muted_until = body.muted ? "9999-12-31T00:00:00Z" : null;
    }
    if (body && "muted_until" in body) {
      if (body.muted_until !== null && Number.isNaN(Date.parse(body.muted_until))) {
        return jsonError("muted_until must be an ISO date or null", 400);
      }
      update.muted_until = body.muted_until;
    }
    if (body && "archived" in body) {
      if (typeof body.archived !== "boolean") return jsonError("archived must be a boolean", 400);
      update.archived_at = body.archived ? new Date().toISOString() : null;
    }
    if (Object.keys(update).length === 0) return jsonError("Nothing to update", 400);
    await db.updateTable("conversation_participant").set(update)
      .where("conversation_id", "=", convId).where("user_id", "=", caller.id).execute();
    const [summary] = await listConversations(caller, { ids: [convId] });
    return json(summary);
  }

  // ── POST /chat/conversations/:id/accept ──────────────────────────────────────
  if (req.method === "POST" && route.kind === "conv_action" && route.action === "accept") {
    if (me.status !== "request") return json(await conversationDetail(caller, convId));
    await db.updateTable("conversation_participant").set({ status: "active" })
      .where("conversation_id", "=", convId).where("user_id", "=", caller.id).execute();
    await broadcast(chatTopic(convId), "conversation_updated", { conversation_id: convId });
    return json(await conversationDetail(caller, convId));
  }

  // ── POST /chat/conversations/:id/clear ───────────────────────────────────────
  if (req.method === "POST" && route.kind === "conv_action" && route.action === "clear") {
    const now = new Date().toISOString();
    await db.updateTable("conversation_participant").set({ cleared_at: now, last_read_at: now })
      .where("conversation_id", "=", convId).where("user_id", "=", caller.id).execute();
    return new Response(null, { status: 204 });
  }

  // ── POST /chat/conversations/:id/read ────────────────────────────────────────
  // Read receipts aren't sent while it's still a message request.
  if (req.method === "POST" && route.kind === "conv_action" && route.action === "read") {
    const row = await db.updateTable("conversation_participant").set({ last_read_at: new Date().toISOString() })
      .where("conversation_id", "=", convId).where("user_id", "=", caller.id)
      .returning("last_read_at").executeTakeFirstOrThrow();
    if (me.status === "active") {
      await broadcast(chatTopic(convId), "read", { user_id: caller.id, last_read_at: row.last_read_at });
    }
    await broadcastToUsers([caller.id], "inbox", { conversation_id: convId, read: true });
    return json({ last_read_at: row.last_read_at });
  }

  // ── POST /chat/conversations/:id/uploads ─────────────────────────────────────
  if (req.method === "POST" && route.kind === "conv_action" && route.action === "uploads") {
    const body = await req.json().catch(() => null);
    const mime = normalizeMime(body?.mime_type);
    if (!mime) return jsonError("mime_type is required", 400);
    const size = Number(body?.size_bytes);
    if (!Number.isFinite(size) || size <= 0) return jsonError("size_bytes is required", 400);
    if (size > MAX_UPLOAD_BYTES) return jsonError(`Files are limited to ${MAX_UPLOAD_BYTES / 1024 / 1024} MB`, 413);
    const fileName = typeof body?.file_name === "string" ? body.file_name.slice(0, 200) : null;
    const slot = await createUploadSlot({
      bucket: BUCKET,
      prefix: convId,
      uploaderId: caller.id,
      mime,
      fileName,
      conversationId: convId,
    });
    return json(slot, 201);
  }

  // ── GET /chat/conversations/:id/media ────────────────────────────────────────
  if (req.method === "GET" && route.kind === "conv_action" && route.action === "media") {
    const page = Math.max(0, parseInt(url.searchParams.get("page") ?? "0") || 0);
    const type = url.searchParams.get("type"); // media (image/video) | file | audio
    const rows = await db.selectFrom("message_attachment as a")
      .innerJoin("message as m", "m.id", "a.message_id")
      .select([
        "a.id",
        "a.storage_path",
        "a.mime_type",
        "a.size_bytes",
        "a.file_name",
        "a.width",
        "a.height",
        "a.duration_ms",
        "m.id as message_id",
        "m.sender_id",
        "m.created_at",
      ])
      .where("m.conversation_id", "=", convId)
      .where("m.deleted_at", "is", null)
      .where("m.created_at", ">", visibleFrom(me))
      .$if(type === "media", (q) =>
        q.where((eb) => eb.or([eb("a.mime_type", "like", "image/%"), eb("a.mime_type", "like", "video/%")])))
      .$if(type === "audio", (q) => q.where("a.mime_type", "like", "audio/%"))
      .$if(type === "file", (q) =>
        q.where("a.mime_type", "not like", "image/%").where("a.mime_type", "not like", "video/%")
          .where("a.mime_type", "not like", "audio/%"))
      .orderBy("m.created_at", "desc")
      .limit(60)
      .offset(page * 60)
      .execute();
    const signed = await signPaths(BUCKET, rows.map((r) => r.storage_path));
    return json(rows.map(({ storage_path, ...r }) => ({
      ...r,
      size_bytes: Number(r.size_bytes),
      media_type: mediaTypeOf(r.mime_type),
      url: signed.get(storage_path) ?? null,
    })));
  }

  // ── POST /chat/conversations/:id/participants — group admins ────────────────
  if (req.method === "POST" && route.kind === "participants") {
    if (me.kind !== "group") return jsonError("You can't add people to a direct chat — start a group", 400);
    if (!isAdmin(me)) return forbidden("Only group admins can add people");
    const body = await req.json().catch(() => null);
    if (!Array.isArray(body?.user_ids) || body.user_ids.length === 0) return jsonError("user_ids is required", 400);
    const existing = new Set(await participantIds(convId));
    const resolved = await resolveInvitees(caller, (body.user_ids as string[]).filter((id) => !existing.has(id)));
    if ("error" in resolved) return jsonError(resolved.error!, 400);
    const invitees = resolved.invitees!;
    if (invitees.length === 0) return json(await conversationDetail(caller, convId));
    if (existing.size + invitees.length > GROUP_MAX) return jsonError(`Groups are limited to ${GROUP_MAX} people`, 400);

    const sys = await db.transaction().execute(async (trx) => {
      await trx.insertInto("conversation_participant").values(invitees.map((i) => ({
        conversation_id: convId,
        user_id: i.id,
        status: i.status,
        added_by: caller.id,
      }))).onConflict((oc) => oc.columns(["conversation_id", "user_id"]).doNothing()).execute();
      await broadcastToUsers(invitees.map((i) => i.id), "conversation_added", { conversation_id: convId }, trx);
      return await systemMessage(trx, convId, caller.id, { event: "added", user_ids: invitees.map((i) => i.id) });
    });
    await announce(convId, [sys]);
    await broadcast(chatTopic(convId), "conversation_updated", { conversation_id: convId });
    const conv = await db.selectFrom("conversation").select("title").where("id", "=", convId).executeTakeFirst();
    await notify(invitees.filter((i) => i.status === "active").map((i) => i.id), {
      type: "group_added",
      title: `${displayName(caller)} added you to ${conv?.title || "a group"}`,
      body: "",
      metadata: { conversation_id: convId },
    });
    return json(await conversationDetail(caller, convId));
  }

  // ── PUT /chat/conversations/:id/participants/:userId {role} — owner ─────────
  if (req.method === "PUT" && route.kind === "participant") {
    if (me.kind !== "group" || me.role !== "owner") return forbidden("Only the group owner can change roles");
    const body = await req.json().catch(() => null);
    const role = body?.role;
    if (role !== "admin" && role !== "member" && role !== "owner") return jsonError("role must be owner, admin or member", 400);
    if (route.userId === caller.id) return jsonError("Hand ownership to someone else instead", 400);
    const target = await membership(convId, route.userId);
    if (!target) return jsonError("Not a participant", 404);
    await db.transaction().execute(async (trx) => {
      if (role === "owner") {
        // Transfer: the old owner becomes an admin.
        await trx.updateTable("conversation_participant").set({ role: "admin" })
          .where("conversation_id", "=", convId).where("user_id", "=", caller.id).execute();
      }
      await trx.updateTable("conversation_participant").set({ role })
        .where("conversation_id", "=", convId).where("user_id", "=", route.userId).execute();
      const sys = await systemMessage(trx, convId, caller.id, { event: "role_changed", user_id: route.userId, role });
      await broadcast(chatTopic(convId), "conversation_updated", { conversation_id: convId }, trx);
      return sys;
    }).then((sys) => announce(convId, [sys]));
    return json(await conversationDetail(caller, convId));
  }

  // ── DELETE /chat/conversations/:id/participants/:userId ──────────────────────
  // Self: leave the group / decline a request / delete a direct chat for me.
  // Others: group admins remove members; only the owner removes admins.
  if (req.method === "DELETE" && route.kind === "participant") {
    const self = route.userId === caller.id;
    const target = self ? me : await membership(convId, route.userId);
    if (!target) return jsonError("Not a participant", 404);
    if (!self) {
      if (me.kind !== "group" || !isAdmin(me)) return forbidden("Only group admins can remove people");
      if (target.role === "owner" || (target.role === "admin" && me.role !== "owner")) {
        return forbidden("Only the owner can remove admins");
      }
    }
    if (me.kind === "direct") {
      // Leaving a direct chat hides it for me (it comes back on a new message).
      const now = new Date().toISOString();
      if (me.status === "request") {
        await db.deleteFrom("conversation_participant").where("conversation_id", "=", convId)
          .where("user_id", "=", caller.id).execute();
      } else {
        await db.updateTable("conversation_participant").set({ cleared_at: now, last_read_at: now, archived_at: null })
          .where("conversation_id", "=", convId).where("user_id", "=", caller.id).execute();
      }
      await broadcastToUsers([caller.id], "conversation_removed", { conversation_id: convId });
      return new Response(null, { status: 204 });
    }

    await db.transaction().execute(async (trx) => {
      await trx.deleteFrom("conversation_participant").where("conversation_id", "=", convId)
        .where("user_id", "=", route.userId).execute();
      const remaining = await trx.selectFrom("conversation_participant").select(["user_id", "role", "status"])
        .where("conversation_id", "=", convId).orderBy("joined_at").execute();
      if (target.role === "owner" && remaining.length) {
        // Hand ownership to the longest-standing admin, else member.
        const heir = remaining.find((r) => r.role === "admin" && r.status === "active") ??
          remaining.find((r) => r.status === "active") ?? remaining[0];
        await trx.updateTable("conversation_participant").set({ role: "owner" })
          .where("conversation_id", "=", convId).where("user_id", "=", heir.user_id).execute();
      }
      if (target.status === "active" && remaining.length) {
        const sys = await systemMessage(trx, convId, caller.id, self
          ? { event: "left" }
          : { event: "removed", user_id: route.userId });
        await broadcast(chatTopic(convId), "message", (await decorateMessages([sys]))[0], trx);
      }
      await broadcastToUsers([route.userId], "conversation_removed", { conversation_id: convId }, trx);
      await broadcast(chatTopic(convId), "conversation_updated", { conversation_id: convId }, trx);
    });
    const left = await participantIds(convId);
    if (left.length === 0) await deleteConversation(convId);
    return new Response(null, { status: 204 });
  }

  // ── GET /chat/conversations/:id/messages ─────────────────────────────────────
  // Newest first. before_id pages back; after_id catches up after a reconnect
  // (oldest first, so the app can append in order).
  if (req.method === "GET" && route.kind === "messages") {
    const limit = Math.min(100, Math.max(1, parseInt(url.searchParams.get("limit") ?? "") || 40));
    const beforeId = url.searchParams.get("before_id");
    const afterId = url.searchParams.get("after_id");
    const cursorId = beforeId ?? afterId;
    let cursor: { id: string } | undefined;
    if (cursorId) {
      if (!UUID_RE.test(cursorId)) return jsonError("Invalid cursor", 400);
      cursor = await db.selectFrom("message").select("id").where("id", "=", cursorId)
        .where("conversation_id", "=", convId).executeTakeFirst();
      if (!cursor) return jsonError("Cursor message not found", 404);
    }
    // Compare against the cursor row in SQL: its created_at has microseconds a JS Date would drop.
    const cursorRow = cursor && sql`(SELECT cm.created_at, cm.id FROM message cm WHERE cm.id = ${cursor.id}::uuid)`;
    const from = visibleFrom(me);
    let q = db.selectFrom("message").select(MESSAGE_COLS).where("conversation_id", "=", convId)
      .where("created_at", ">", from);
    if (cursor && beforeId) {
      q = q.where(sql<boolean>`(created_at, id) < ${cursorRow}`)
        .orderBy("created_at", "desc").orderBy("id", "desc");
    } else if (cursor && afterId) {
      q = q.where(sql<boolean>`(created_at, id) > ${cursorRow}`)
        .orderBy("created_at", "asc").orderBy("id", "asc");
    } else {
      q = q.orderBy("created_at", "desc").orderBy("id", "desc");
    }
    const rows = await q.limit(limit).execute();
    return json(await decorateMessages(rows));
  }

  // ── POST /chat/conversations/:id/messages ────────────────────────────────────
  if (req.method === "POST" && route.kind === "messages") {
    const body = await req.json().catch(() => null);
    const text = typeof body?.body === "string" ? body.body.trim() : "";
    if (text.length > BODY_MAX) return jsonError(`Messages are limited to ${BODY_MAX} characters`, 400);
    const clientId = typeof body?.client_id === "string" ? body.client_id.slice(0, 64) : null;
    const replyToId = typeof body?.reply_to_id === "string" ? body.reply_to_id : null;
    const attachments: {
      path: string;
      file_name?: string;
      size_bytes?: number;
      width?: number;
      height?: number;
      duration_ms?: number;
    }[] = Array.isArray(body?.attachments) ? body.attachments : [];
    if (attachments.length > ATTACHMENTS_MAX) return jsonError(`Up to ${ATTACHMENTS_MAX} attachments per message`, 400);
    if (attachments.some((a) => typeof a?.path !== "string")) return jsonError("Each attachment needs a path", 400);
    if (!text && attachments.length === 0) return jsonError("A message needs text or an attachment", 400);

    // Idempotent retry: same client_id → the message already sent.
    if (clientId) {
      const dup = await db.selectFrom("message").select(MESSAGE_COLS).where("conversation_id", "=", convId)
        .where("sender_id", "=", caller.id).where("client_id", "=", clientId).executeTakeFirst();
      if (dup) return json((await decorateMessages([dup]))[0]);
    }

    // Direct chats: blocked either way → no sending; a recipient who left or
    // declined is re-added (as a request if they don't let me message them).
    let directOther: { id: string; who_can_message: WhoCanMessage } | undefined;
    if (me.kind === "direct") {
      const key = await db.selectFrom("conversation").select("direct_key").where("id", "=", convId)
        .executeTakeFirstOrThrow();
      const otherId = key.direct_key!.split(":").find((id) => id !== caller.id)!;
      if (await isBlockedBetween(caller.id, otherId)) return forbidden("You can't message this person");
      directOther = await db.selectFrom("users").select(["id", "who_can_message"]).where("id", "=", otherId)
        .executeTakeFirst();
      if (!directOther) return forbidden("This account no longer exists");
    }
    if (me.status === "request") {
      // Replying to a request accepts it.
      await db.updateTable("conversation_participant").set({ status: "active" })
        .where("conversation_id", "=", convId).where("user_id", "=", caller.id).execute();
    }

    if (replyToId) {
      const target = await db.selectFrom("message").select("id").where("id", "=", replyToId)
        .where("conversation_id", "=", convId).executeTakeFirst();
      if (!target) return jsonError("reply_to_id is not in this conversation", 400);
    }

    const verified = await verifyUploads({
      bucket: BUCKET,
      paths: attachments.map((a) => a.path),
      uploaderId: caller.id,
      conversationId: convId,
    });
    if ("error" in verified) return jsonError(verified.error, 400);

    const int = (v: unknown) => (Number.isFinite(Number(v)) && Number(v) >= 0 ? Math.round(Number(v)) : null);
    const msg = await db.transaction().execute(async (trx) => {
      if (directOther) {
        const status = await directMessageStatus(caller.id, directOther);
        await trx.insertInto("conversation_participant")
          .values({ conversation_id: convId, user_id: directOther.id, status: status ?? "request", added_by: caller.id })
          .onConflict((oc) => oc.columns(["conversation_id", "user_id"]).doNothing())
          .execute();
      }
      const inserted = await trx.insertInto("message").values({
        conversation_id: convId,
        sender_id: caller.id,
        kind: attachments.length ? "media" : "text",
        body: text || null,
        reply_to_id: replyToId,
        client_id: clientId,
      }).returning(MESSAGE_COLS).executeTakeFirstOrThrow();
      if (attachments.length) {
        await trx.insertInto("message_attachment").values(attachments.map((a, i) => ({
          message_id: inserted.id,
          storage_path: a.path,
          mime_type: verified.mimeByPath.get(a.path)!,
          size_bytes: int(a.size_bytes) ?? 0,
          file_name: typeof a.file_name === "string" ? a.file_name.slice(0, 200) : null,
          width: int(a.width),
          height: int(a.height),
          duration_ms: int(a.duration_ms),
          position: i,
        }))).execute();
        await trx.updateTable("media_upload").set({ claimed_at: inserted.created_at })
          .where("bucket", "=", BUCKET).where("storage_path", "in", attachments.map((a) => a.path)).execute();
      }
      await trx.updateTable("conversation").set({ last_message_at: inserted.created_at }).where("id", "=", convId)
        .execute();
      // Sending marks the chat read for me, and un-archives it for everyone.
      await trx.updateTable("conversation_participant").set({ last_read_at: inserted.created_at })
        .where("conversation_id", "=", convId).where("user_id", "=", caller.id).execute();
      await trx.updateTable("conversation_participant").set({ archived_at: null })
        .where("conversation_id", "=", convId).where("archived_at", "is not", null).execute();
      return inserted;
    });

    const [decorated] = await decorateMessages([msg]);
    await broadcast(chatTopic(convId), "message", decorated);

    const recipients = await db.selectFrom("conversation_participant")
      .select(["user_id", "status", "muted_until"])
      .where("conversation_id", "=", convId)
      .execute();
    const otherIds = recipients.map((r) => r.user_id).filter((id) => id !== caller.id);
    const mediaType = decorated.attachments.length ? (decorated.attachments[0] as { media_type: string }).media_type : null;
    await broadcastToUsers([caller.id, ...otherIds], "inbox", {
      conversation_id: convId,
      message_id: msg.id,
      sender_id: caller.id,
      preview: previewText(msg, mediaType),
      created_at: msg.created_at,
    });

    const now = Date.now();
    const pushTo = recipients.filter((r) =>
      r.user_id !== caller.id && r.status === "active" && !(r.muted_until && new Date(r.muted_until).getTime() > now)
    ).map((r) => r.user_id);
    if (pushTo.length) {
      const conv = me.kind === "group"
        ? await db.selectFrom("conversation").select("title").where("id", "=", convId).executeTakeFirst()
        : null;
      const who = displayName(caller);
      const preview = text ? text.slice(0, 140) : `Sent ${mediaType === "image" ? "a photo" : mediaType === "video" ? "a video" : mediaType === "audio" ? "a voice message" : "a file"}`;
      pushOnly(pushTo, {
        type: "chat_message",
        title: conv ? conv.title || "Group chat" : who,
        body: conv ? `${caller.name}: ${preview}` : preview,
        metadata: { conversation_id: convId, message_id: msg.id },
      });
    }
    return json(decorated, 201);
  }

  return jsonError("Not found", 404);
}

async function deleteConversation(id: string) {
  const paths = await db.selectFrom("message_attachment as a").innerJoin("message as m", "m.id", "a.message_id")
    .select("a.storage_path").where("m.conversation_id", "=", id).execute();
  const pending = await db.selectFrom("media_upload").select("storage_path")
    .where("bucket", "=", BUCKET).where("conversation_id", "=", id).where("claimed_at", "is", null).execute();
  const members = await participantIds(id);
  await db.deleteFrom("conversation").where("id", "=", id).execute();
  await broadcastToUsers(members, "conversation_removed", { conversation_id: id });
  await removeObjects(BUCKET, [...paths, ...pending].map((p) => p.storage_path));
}

Deno.serve(async (req: Request) => {
  try {
    return await handler(req);
  } catch (e) {
    const err = e as { code?: string; message?: string };
    if (err?.code === "22P02") return jsonError("Invalid id", 400);
    if (err?.code === "23505") return jsonError("Already exists", 409);
    throw e;
  }
});
