import { sql } from "npm:kysely@^0.27";
import { db } from "../_shared/config.ts";
import { json, jsonError, requireCaller, staffsAnyBusiness } from "../_shared/auth.ts";

// ── Handler ───────────────────────────────────────────────────────────────────

Deno.serve(async (req: Request) => {
  const { caller, response } = await requireCaller(req);
  if (!caller) return response;

  if (req.method !== "GET") return jsonError("Method not allowed", 405);

  // Results carry emails: only for people who own or staff a gym or shop
  // (to pick someone to add), and super users.
  if (!(await staffsAnyBusiness(caller))) {
    return jsonError("Only gym and shop staff can search users", 403);
  }

  const url = new URL(req.url);
  const q = (url.searchParams.get("q") ?? "").trim();
  const page = Math.max(0, parseInt(url.searchParams.get("page") ?? "0") || 0);
  const pageSize = Math.min(
    50,
    Math.max(1, parseInt(url.searchParams.get("page_size") ?? "10") || 10),
  );

  // %q% for contains match; q% for starts-with ranking
  const like = `%${q}%`;
  const starts = `${q}%`;

  // Correlated subqueries aggregate gym memberships and team roles into JSON arrays.
  // When q is empty, ILIKE '%%' matches all rows → browse mode (ordered by name).
  const result = await sql`
    SELECT
      u.id,
      u.username,
      u.email,
      u.name,
      u.last_name,
      u.is_trainer,
      COALESCE(
        (SELECT json_agg(json_build_object('id', m.id, 'gym_id', m.gym_id))
         FROM member m WHERE m.user_id = u.id),
        '[]'::json
      ) AS member_entries,
      COALESCE(
        (SELECT json_agg(json_build_object('business_id', bm.business_id, 'role', bm.role, 'status', bm.status))
         FROM business_member bm WHERE bm.user_id = u.id),
        '[]'::json
      ) AS team_entries
    FROM users u
    WHERE
      u.username ILIKE ${like}
      OR u.name ILIKE ${like}
      OR u.last_name ILIKE ${like}
      OR (u.name || ' ' || u.last_name) ILIKE ${like}
    ORDER BY
      CASE
        WHEN ${q} = ''                                      THEN 0
        WHEN LOWER(u.username) = LOWER(${q})               THEN 0
        WHEN LOWER(u.name || ' ' || u.last_name) = LOWER(${q}) THEN 1
        WHEN u.username ILIKE ${starts}                    THEN 2
        WHEN u.name ILIKE ${starts}                        THEN 3
        WHEN u.last_name ILIKE ${starts}                   THEN 4
        ELSE 5
      END,
      u.name,
      u.last_name
    LIMIT ${pageSize}
    OFFSET ${page * pageSize}
  `.execute(db);

  return json(result.rows);
});
