import { db, supabaseAdmin } from "../_shared/config.ts";
import type { MembershipInvoiceInsert } from "../../types/schema/public.ts";

// ── Auth ──────────────────────────────────────────────────────────────────────

async function requireAuth(req: Request) {
  const token = req.headers.get("Authorization")?.replace(/^Bearer\s+/i, "");
  if (!token) return { user: null, error: "Missing Authorization header" };
  const { data: { user }, error } = await supabaseAdmin.auth.getUser(token);
  return { user: error ? null : user, error: error?.message ?? null };
}

// ── Path parsing ──────────────────────────────────────────────────────────────

function parseId(pathname: string): string | null {
  const match = pathname.match(/^\/membership-invoices\/([^/]+)$/);
  return match ? match[1] : null;
}

// ── Handler ───────────────────────────────────────────────────────────────────

Deno.serve(async (req: Request) => {
  const { user, error: authError } = await requireAuth(req);
  if (!user) return jsonError(authError ?? "Unauthorized", 401);

  const url = new URL(req.url);
  const id = parseId(url.pathname);

  // ── POST /membership-invoices ─────────────────────────────────────────────────
  if (req.method === "POST" && !id) {
    const body = await req.json().catch(() => null);
    const { membership_id, membership_type_id, amount } = body ?? {};
    if (!membership_id || !membership_type_id || amount == null) {
      return jsonError("Missing required fields: membership_id, membership_type_id, amount", 400);
    }
    const insert: MembershipInvoiceInsert = { membership_id, membership_type_id, amount };
    const row = await db
      .insertInto("membership_invoice")
      .values(insert)
      .returningAll()
      .executeTakeFirstOrThrow();
    return json(row, 201);
  }

  // ── GET /membership-invoices — optional ?membership_id= filter ────────────────
  if (req.method === "GET" && !id) {
    const membershipId = url.searchParams.get("membership_id");
    let query = db.selectFrom("membership_invoice").selectAll();
    if (membershipId) query = query.where("membership_id", "=", membershipId);
    return json(await query.execute());
  }

  // ── GET /membership-invoices/:id ──────────────────────────────────────────────
  if (req.method === "GET" && id) {
    const row = await db
      .selectFrom("membership_invoice")
      .selectAll()
      .where("id", "=", id)
      .executeTakeFirst();
    if (!row) return jsonError("Invoice not found", 404);
    return json(row);
  }

  // ── DELETE /membership-invoices/:id ───────────────────────────────────────────
  // Invoices are immutable records — no PUT.
  if (req.method === "DELETE" && id) {
    const result = await db
      .deleteFrom("membership_invoice")
      .where("id", "=", id)
      .executeTakeFirst();
    if (!result.numDeletedRows) return jsonError("Invoice not found", 404);
    return new Response(null, { status: 204 });
  }

  return jsonError("Not found", 404);
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
