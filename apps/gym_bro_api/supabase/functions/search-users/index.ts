import { sql } from "npm:kysely@^0.27";
import { db, supabaseAdmin } from "../_shared/config.ts";

// ── Auth ──────────────────────────────────────────────────────────────────────

async function requireAuth(req: Request) {
  const token = req.headers.get("Authorization")?.replace(/^Bearer\s+/i, "");
  if (!token) return { user: null, error: "Missing Authorization header" };
  const { data: { user }, error } = await supabaseAdmin.auth.getUser(token);
  return { user: error ? null : user, error: error?.message ?? null };
}

// ── Handler ───────────────────────────────────────────────────────────────────

Deno.serve(async (req: Request) => {
  const { user, error: authError } = await requireAuth(req);
  if (!user) return jsonError(authError ?? "Unauthorized", 401);

  if (req.method !== "GET") return jsonError("Method not allowed", 405);

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

  // Correlated subqueries aggregate each role table into a JSON array.
  // When q is empty, ILIKE '%%' matches all rows → browse mode (ordered by name).
  const result = await sql`
    SELECT
      u.id,
      u.username,
      u.email,
      u.name,
      u.last_name,
      u.role,
      COALESCE(
        (SELECT json_agg(json_build_object('id', m.id, 'gym_id', m.gym_id))
         FROM member m WHERE m.user_id = u.id),
        '[]'::json
      ) AS member_entries,
      COALESCE(
        (SELECT json_agg(json_build_object('id', e.id, 'gym_id', e.gym_id))
         FROM employee e WHERE e.user_id = u.id),
        '[]'::json
      ) AS employee_entries,
      COALESCE(
        (SELECT json_agg(json_build_object('id', et.id, 'gym_id', et.gym_id))
         FROM employee_trainer et WHERE et.user_id = u.id),
        '[]'::json
      ) AS employee_trainer_entries,
      COALESCE(
        (SELECT json_agg(json_build_object('id', t.id, 'gym_id', t.gym_id))
         FROM trainer t WHERE t.user_id = u.id),
        '[]'::json
      ) AS trainer_entries,
      COALESCE(
        (SELECT json_agg(json_build_object('id', go.id, 'gym_id', go.gym_id))
         FROM gym_owner go WHERE go.user_id = u.id),
        '[]'::json
      ) AS gym_owner_entries,
      COALESCE(
        (SELECT json_agg(json_build_object('id', so.id, 'shop_id', so.shop_id))
         FROM shop_owner so WHERE so.user_id = u.id),
        '[]'::json
      ) AS shop_owner_entries,
      COALESCE(
        (SELECT json_agg(json_build_object('id', sv.id, 'shop_id', sv.shop_id))
         FROM shop_vendor sv WHERE sv.user_id = u.id),
        '[]'::json
      ) AS shop_vendor_entries
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

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function jsonError(message: string, status: number): Response {
  return json({ error: message }, status);
}
