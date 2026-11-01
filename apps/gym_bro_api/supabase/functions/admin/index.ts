import { type RawBuilder, sql } from "npm:kysely@^0.27";
import { db, supabaseAdmin } from "../_shared/config.ts";
import { type Caller, forbidden, isSuperUser, json, jsonError, requireCaller } from "../_shared/auth.ts";
import { pgCode } from "../_shared/business.ts";

// Super-user database console: every table in `public`, read and written
// generically from the Postgres catalog. Deletes report what they'd take with
// them (cascades, columns set to null, rows that block it) and can take the
// blockers too, but only when the caller confirms the exact number of rows.
// Every write lands in admin_audit_log.
//
//   GET    /admin/tables                          tables with columns, keys and row counts
//   GET    /admin/tables/:t?q=&where=&limit=&offset=&order=&dir=   rows
//   GET    /admin/tables/:t/row?pk=               one row
//   POST   /admin/tables/:t {values}              insert
//   PATCH  /admin/tables/:t/row?pk= {values}      update
//   GET    /admin/tables/:t/row/impact?pk=        what deleting it affects
//   DELETE /admin/tables/:t/row?pk= {force, expected}
//
// `pk` and `where` are JSON objects of column → value, URL-encoded.

type FkAction = "cascade" | "set_null" | "set_default" | "restrict" | "no_action";

type Column = {
  name: string;
  type: string; // format_type, e.g. "uuid", "text[]", "timestamp with time zone"
  kind: "enum" | "base" | "array" | "other";
  enum_values: string[] | null;
  nullable: boolean;
  has_default: boolean;
  generated: boolean;
};

type ForeignKey = {
  name: string;
  table: string; // child (holds the columns)
  columns: string[];
  ref_table: string; // parent
  ref_columns: string[];
  on_delete: FkAction;
};

type Table = {
  name: string;
  columns: Column[];
  primary_key: string[];
  foreign_keys: ForeignKey[]; // this table → others
  referenced_by: ForeignKey[]; // others → this table
};

const FK_ACTIONS: Record<string, FkAction> = {
  c: "cascade",
  n: "set_null",
  d: "set_default",
  r: "restrict",
  a: "no_action",
};

/** Bookkeeping tables nobody should edit by hand. */
const READ_ONLY = new Set(["_schema_migrations", "admin_audit_log"]);

const MAX_DEPTH = 8;

// ── Catalog ───────────────────────────────────────────────────────────────────

async function loadCatalog(): Promise<Map<string, Table>> {
  const cols = await sql<{
    table: string;
    name: string;
    type: string;
    typtype: string;
    is_array: boolean;
    enum_values: string[] | null;
    nullable: boolean;
    has_default: boolean;
    generated: boolean;
  }>`
    SELECT c.relname AS table, a.attname AS name,
      format_type(a.atttypid, a.atttypmod) AS type,
      t.typtype::text AS typtype,
      t.typcategory = 'A' AS is_array,
      (SELECT array_agg(e.enumlabel::text ORDER BY e.enumsortorder) FROM pg_enum e
        WHERE e.enumtypid = CASE WHEN t.typcategory = 'A' THEN t.typelem ELSE t.oid END) AS enum_values,
      NOT a.attnotnull AS nullable,
      a.atthasdef OR a.attidentity <> '' AS has_default,
      a.attgenerated <> '' AS generated
    FROM pg_attribute a
    JOIN pg_class c ON c.oid = a.attrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
    JOIN pg_type t ON t.oid = a.atttypid
    WHERE n.nspname = 'public' AND c.relkind = 'r' AND a.attnum > 0 AND NOT a.attisdropped
    ORDER BY c.relname, a.attnum
  `.execute(db);

  const pks = await sql<{ table: string; columns: string[] }>`
    SELECT c.relname AS table,
      array_agg(a.attname::text ORDER BY array_position(i.indkey::int2[], a.attnum)) AS columns
    FROM pg_index i
    JOIN pg_class c ON c.oid = i.indrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
    JOIN pg_attribute a ON a.attrelid = c.oid AND a.attnum = ANY(i.indkey)
    WHERE n.nspname = 'public' AND i.indisprimary
    GROUP BY c.relname
  `.execute(db);

  const fks = await sql<{
    name: string;
    table: string;
    columns: string[];
    ref_table: string;
    ref_columns: string[];
    action: string;
  }>`
    SELECT con.conname AS name, c.relname AS table, p.relname AS ref_table,
      con.confdeltype::text AS action,
      (SELECT array_agg(a.attname::text ORDER BY k.ord) FROM unnest(con.conkey) WITH ORDINALITY k(attnum, ord)
        JOIN pg_attribute a ON a.attrelid = con.conrelid AND a.attnum = k.attnum) AS columns,
      (SELECT array_agg(a.attname::text ORDER BY k.ord) FROM unnest(con.confkey) WITH ORDINALITY k(attnum, ord)
        JOIN pg_attribute a ON a.attrelid = con.confrelid AND a.attnum = k.attnum) AS ref_columns
    FROM pg_constraint con
    JOIN pg_class c ON c.oid = con.conrelid
    JOIN pg_class p ON p.oid = con.confrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
    JOIN pg_namespace pn ON pn.oid = p.relnamespace
    WHERE con.contype = 'f' AND n.nspname = 'public' AND pn.nspname = 'public'
  `.execute(db);

  const tables = new Map<string, Table>();
  for (const c of cols.rows) {
    let t = tables.get(c.table);
    if (!t) {
      t = { name: c.table, columns: [], primary_key: [], foreign_keys: [], referenced_by: [] };
      tables.set(c.table, t);
    }
    t.columns.push({
      name: c.name,
      type: c.type,
      kind: c.enum_values ? "enum" : c.is_array ? "array" : c.typtype === "b" ? "base" : "other",
      enum_values: c.enum_values,
      nullable: c.nullable,
      has_default: c.has_default,
      generated: c.generated,
    });
  }
  for (const p of pks.rows) {
    const t = tables.get(p.table);
    if (t) t.primary_key = p.columns;
  }
  for (const f of fks.rows) {
    const fk: ForeignKey = {
      name: f.name,
      table: f.table,
      columns: f.columns,
      ref_table: f.ref_table,
      ref_columns: f.ref_columns,
      on_delete: FK_ACTIONS[f.action] ?? "no_action",
    };
    tables.get(f.table)?.foreign_keys.push(fk);
    tables.get(f.ref_table)?.referenced_by.push(fk);
  }
  return tables;
}

// ── Values ────────────────────────────────────────────────────────────────────

const isJson = (c: Column) => c.type === "json" || c.type === "jsonb";

/** A request value as a pg parameter (json columns travel as text). */
function toParam(c: Column, v: unknown): unknown {
  if (v === null || v === undefined) return null;
  if (isJson(c)) return typeof v === "string" ? v : JSON.stringify(v);
  return v;
}

/** `col = value AND …` for a JSON object of column → value, checked against the table. */
function matchSql(t: Table, alias: string, values: Record<string, unknown>): RawBuilder<boolean> | string {
  const parts: RawBuilder<unknown>[] = [];
  for (const [k, v] of Object.entries(values)) {
    const col = t.columns.find((c) => c.name === k);
    if (!col) return `Unknown column ${k}`;
    parts.push(
      v === null
        ? sql`${sql.ref(`${alias}.${k}`)} IS NULL`
        : sql`${sql.ref(`${alias}.${k}`)} = ${toParam(col, v)}::${sql.raw(castType(col))}`,
    );
  }
  if (parts.length === 0) return sql<boolean>`TRUE`;
  return sql<boolean>`(${sql.join(parts, sql` AND `)})`;
}

/** The column's type for a cast. format_type output is already valid SQL. */
function castType(c: Column): string {
  return c.type;
}

function parseJsonParam(raw: string | null): Record<string, unknown> | null {
  if (!raw) return null;
  try {
    const v = JSON.parse(raw);
    return v && typeof v === "object" && !Array.isArray(v) ? v as Record<string, unknown> : null;
  } catch {
    return null;
  }
}

/** The pk object, with every primary key column present. */
function pkOf(t: Table, url: URL): Record<string, unknown> | string {
  if (t.primary_key.length === 0) return `${t.name} has no primary key`;
  const pk = parseJsonParam(url.searchParams.get("pk"));
  if (!pk) return "pk must be a JSON object";
  const missing = t.primary_key.filter((k) => !(k in pk));
  if (missing.length) return `pk is missing ${missing.join(", ")}`;
  return Object.fromEntries(t.primary_key.map((k) => [k, pk[k]]));
}

// ── Delete impact ─────────────────────────────────────────────────────────────

type Effect = {
  table: string;
  via: string; // fk name
  columns: string[];
  action: FkAction;
  count: number;
  depth: number;
};

/** Rows of `fk.table` that point at the rows `parentRows` selects from `fk.ref_table`. */
function childRows(fk: ForeignKey, parentRows: RawBuilder<unknown>): RawBuilder<unknown> {
  const childCols = sql.join(fk.columns.map((c) => sql.ref(`ch.${c}`)));
  const parentCols = sql.join(fk.ref_columns.map((c) => sql.ref(`pa.${c}`)));
  return sql`SELECT ch.* FROM ${sql.table(fk.table)} ch
    WHERE (${childCols}) IN (SELECT ${parentCols} FROM (${parentRows}) pa)`;
}

/**
 * Walks every foreign key pointing at the rows: cascades (recursively),
 * set-null/default columns, and restrict/no-action blockers.
 */
async function impactOf(
  catalog: Map<string, Table>,
  table: string,
  rows: RawBuilder<unknown>,
  depth = 1,
  out: Effect[] = [],
): Promise<Effect[]> {
  if (depth > MAX_DEPTH) return out;
  for (const fk of catalog.get(table)?.referenced_by ?? []) {
    const children = childRows(fk, rows);
    const { rows: [{ n }] } = await sql<{ n: number }>`SELECT count(*)::int AS n FROM (${children}) x`.execute(db);
    if (n === 0) continue;
    out.push({ table: fk.table, via: fk.name, columns: fk.columns, action: fk.on_delete, count: n, depth });
    // Cascaded rows take their own dependents; so would forced deletes of blockers.
    if (fk.on_delete === "cascade" || fk.on_delete === "restrict" || fk.on_delete === "no_action") {
      await impactOf(catalog, fk.table, children, depth + 1, out);
    }
  }
  return out;
}

function summarize(effects: Effect[]) {
  const deleted = effects.filter((e) => e.action === "cascade");
  const nulled = effects.filter((e) => e.action === "set_null" || e.action === "set_default");
  const blocking = effects.filter((e) => e.action === "restrict" || e.action === "no_action");
  // Everything a forced delete removes: cascades and blockers with their trees.
  const forcedRows = deleted.reduce((s, e) => s + e.count, 0) + blocking.reduce((s, e) => s + e.count, 0);
  return { deleted, nulled, blocking, forced_rows: forcedRows };
}

/**
 * Deletes the rows and, first, everything that would stop it (children of
 * any kind except set-null/default), deepest first.
 */
async function forceDelete(
  trx: typeof db,
  catalog: Map<string, Table>,
  table: string,
  rows: RawBuilder<unknown>,
  depth = 1,
): Promise<number> {
  let removed = 0;
  if (depth <= MAX_DEPTH) {
    for (const fk of catalog.get(table)?.referenced_by ?? []) {
      if (fk.on_delete === "set_null" || fk.on_delete === "set_default") continue;
      // Self-references (comment threads) cascade on their own.
      if (fk.table === table && fk.on_delete === "cascade") continue;
      removed += await forceDelete(trx, catalog, fk.table, childRows(fk, rows), depth + 1);
    }
  }
  const t = catalog.get(table)!;
  const key = t.primary_key.length ? t.primary_key : t.columns.map((c) => c.name);
  const keyCols = sql.join(key.map((c) => sql.ref(`d.${c}`)));
  const subCols = sql.join(key.map((c) => sql.ref(`s.${c}`)));
  const res = await sql`DELETE FROM ${sql.table(table)} d
    WHERE (${keyCols}) IN (SELECT ${subCols} FROM (${rows}) s)`.execute(trx);
  return removed + Number(res.numAffectedRows ?? 0);
}

// ── Handler ───────────────────────────────────────────────────────────────────

async function audit(caller: Caller, action: string, metadata: Record<string, unknown>) {
  await db.insertInto("admin_audit_log").values({ actor_id: caller.id, action, metadata }).execute();
}

function errorFor(err: unknown): Response | null {
  const code = pgCode(err);
  const message = (err as { message?: string })?.message ?? "Database error";
  const detail = (err as { detail?: string })?.detail;
  const text = detail ? `${message} (${detail})` : message;
  if (code === "23505") return jsonError(text, 409, { code: "unique_violation" });
  if (code === "23503") return jsonError(text, 409, { code: "foreign_key_violation" });
  if (code === "23502" || code === "23514" || code === "22P02" || code === "22007" || code === "22008" ||
    code === "42804" || code === "22003" || code === "22023" || code === "42883") {
    return jsonError(text, 400, { code: "invalid_value" });
  }
  return null;
}

Deno.serve(async (req: Request) => {
  const { caller, response } = await requireCaller(req);
  if (response) return response;
  if (!isSuperUser(caller)) return forbidden("Only a super user can use the database console");

  const url = new URL(req.url);
  const parts = url.pathname.replace(/^\/+|\/+$/g, "").split("/");
  if (parts[0] !== "admin" || parts[1] !== "tables") return jsonError("Not found", 404);

  const catalog = await loadCatalog();

  // ── GET /admin/tables ────────────────────────────────────────────────────────
  if (parts.length === 2 && req.method === "GET") {
    const counts = await Promise.all(
      [...catalog.keys()].map(async (name) => {
        const { rows: [{ n }] } = await sql<{ n: number }>`SELECT count(*)::int AS n FROM ${sql.table(name)}`
          .execute(db);
        return [name, n] as const;
      }),
    );
    const countOf = new Map(counts);
    return json(
      [...catalog.values()]
        .sort((a, b) => a.name.localeCompare(b.name))
        .map((t) => ({ ...t, row_count: countOf.get(t.name) ?? 0, read_only: READ_ONLY.has(t.name) })),
    );
  }

  const t = catalog.get(parts[2] ?? "");
  if (!t) return jsonError("Unknown table", 404);
  const readOnly = READ_ONLY.has(t.name);
  const tail = parts.slice(3).join("/");

  try {
    // ── GET /admin/tables/:t — rows ────────────────────────────────────────────
    if (tail === "" && req.method === "GET") {
      const limit = Math.min(200, Math.max(1, Number(url.searchParams.get("limit")) || 50));
      const offset = Math.max(0, Number(url.searchParams.get("offset")) || 0);
      const q = (url.searchParams.get("q") ?? "").trim();
      const where = parseJsonParam(url.searchParams.get("where")) ?? {};
      const filter = matchSql(t, "r", where);
      if (typeof filter === "string") return jsonError(filter, 400);

      // Free text: any text-ish column contains it; a uuid also matches uuid columns.
      let search: RawBuilder<boolean> = sql`TRUE`;
      if (q) {
        const like = `%${q.replace(/[\\%_]/g, (c) => `\\${c}`)}%`;
        const isUuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(q);
        const ors = t.columns
          .filter((c) => /^(text|character varying|citext)/.test(c.type) || c.kind === "enum" || (isUuid && c.type === "uuid"))
          .map((c) => c.type === "uuid" ? sql`${sql.ref(`r.${c.name}`)} = ${q}::uuid` : sql`${sql.ref(`r.${c.name}`)}::text ILIKE ${like}`);
        search = ors.length ? sql`(${sql.join(ors, sql` OR `)})` : sql`FALSE`;
      }

      const orderCol = url.searchParams.get("order");
      const dir = url.searchParams.get("dir") === "asc" ? sql`ASC` : sql`DESC`;
      const fallback = ["created_at", "updated_at"].find((c) => t.columns.some((x) => x.name === c));
      const order = orderCol && t.columns.some((c) => c.name === orderCol)
        ? sql`ORDER BY ${sql.ref(`r.${orderCol}`)} ${dir} NULLS LAST`
        : fallback
        ? sql`ORDER BY ${sql.ref(`r.${fallback}`)} DESC NULLS LAST`
        : sql``;

      const [{ rows }, { rows: [{ n }] }] = await Promise.all([
        sql<{ row: Record<string, unknown> }>`SELECT to_jsonb(r) AS row FROM ${sql.table(t.name)} r
          WHERE ${filter} AND ${search} ${order} LIMIT ${limit} OFFSET ${offset}`.execute(db),
        sql<{ n: number }>`SELECT count(*)::int AS n FROM ${sql.table(t.name)} r WHERE ${filter} AND ${search}`
          .execute(db),
      ]);
      return json({ total: n, rows: rows.map((r) => r.row) });
    }

    // ── POST /admin/tables/:t — insert ─────────────────────────────────────────
    if (tail === "" && req.method === "POST") {
      if (readOnly) return forbidden(`${t.name} is read-only`);
      const values = (await req.json().catch(() => null))?.values;
      if (!values || typeof values !== "object" || Array.isArray(values)) return jsonError("values is required", 400);
      const entries = Object.entries(values as Record<string, unknown>);
      for (const [k] of entries) {
        const c = t.columns.find((x) => x.name === k);
        if (!c) return jsonError(`Unknown column ${k}`, 400);
        if (c.generated) return jsonError(`${k} is generated`, 400);
      }
      const colsSql = entries.length ? sql`(${sql.join(entries.map(([k]) => sql.ref(k)))})` : sql``;
      const valsSql = entries.length
        ? sql`VALUES (${
          sql.join(entries.map(([k, v]) => {
            const c = t.columns.find((x) => x.name === k)!;
            return sql`${toParam(c, v)}::${sql.raw(castType(c))}`;
          }))
        })`
        : sql`DEFAULT VALUES`;
      const { rows: [created] } = await sql<{ row: Record<string, unknown> }>`
        INSERT INTO ${sql.table(t.name)} AS r ${colsSql} ${valsSql} RETURNING to_jsonb(r) AS row
      `.execute(db);
      await audit(caller, "db_insert", { table: t.name, row: created.row });
      return json(created.row, 201);
    }

    if (tail !== "row" && tail !== "row/impact") return jsonError("Not found", 404);
    const pk = pkOf(t, url);
    if (typeof pk === "string") return jsonError(pk, 400);
    const match = matchSql(t, "r", pk);
    if (typeof match === "string") return jsonError(match, 400);
    const target = sql`SELECT r.* FROM ${sql.table(t.name)} r WHERE ${match}`;

    const { rows: [current] } = await sql<{ row: Record<string, unknown> }>`
      SELECT to_jsonb(r) AS row FROM ${sql.table(t.name)} r WHERE ${match}`.execute(db);
    if (!current) return jsonError("Row not found", 404);

    // ── GET /admin/tables/:t/row ───────────────────────────────────────────────
    if (tail === "row" && req.method === "GET") {
      // How many rows point at this one, per foreign key (for "Referenced by").
      const refs = await Promise.all(t.referenced_by.map(async (fk) => {
        const { rows: [{ n }] } = await sql<{ n: number }>`SELECT count(*)::int AS n FROM (${childRows(fk, target)}) x`
          .execute(db);
        return { ...fk, count: n };
      }));
      return json({ row: current.row, referenced_by: refs });
    }

    // ── GET /admin/tables/:t/row/impact ────────────────────────────────────────
    if (tail === "row/impact" && req.method === "GET") {
      return json(summarize(await impactOf(catalog, t.name, target)));
    }

    // ── PATCH /admin/tables/:t/row — update ────────────────────────────────────
    if (tail === "row" && req.method === "PATCH") {
      if (readOnly) return forbidden(`${t.name} is read-only`);
      const values = (await req.json().catch(() => null))?.values;
      if (!values || typeof values !== "object" || Array.isArray(values)) return jsonError("values is required", 400);
      const sets: RawBuilder<unknown>[] = [];
      for (const [k, v] of Object.entries(values as Record<string, unknown>)) {
        const c = t.columns.find((x) => x.name === k);
        if (!c) return jsonError(`Unknown column ${k}`, 400);
        if (c.generated) return jsonError(`${k} is generated`, 400);
        sets.push(sql`${sql.ref(k)} = ${toParam(c, v)}::${sql.raw(castType(c))}`);
      }
      if (sets.length === 0) return jsonError("Nothing to update", 400);
      const { rows: [updated] } = await sql<{ row: Record<string, unknown> }>`
        UPDATE ${sql.table(t.name)} AS r SET ${sql.join(sets)} WHERE ${match} RETURNING to_jsonb(r) AS row
      `.execute(db);
      await audit(caller, "db_update", { table: t.name, pk, before: current.row, after: updated.row });
      return json(updated.row);
    }

    // ── DELETE /admin/tables/:t/row {force, expected} ──────────────────────────
    // Without force: a plain delete (the database cascades; blockers → 409).
    // With force: blockers and their dependents go first. `expected` must
    // equal the impact's forced_rows (+1 for the row itself) so a stale
    // confirmation can't delete more than the admin saw.
    if (tail === "row" && req.method === "DELETE") {
      if (readOnly) return forbidden(`${t.name} is read-only`);
      const body = await req.json().catch(() => ({}));
      const force = body?.force === true;
      const impact = summarize(await impactOf(catalog, t.name, target));
      const total = (force ? impact.forced_rows : impact.deleted.reduce((s, e) => s + e.count, 0)) + 1;
      if (body?.expected !== total) {
        return jsonError("The rows this affects changed. Review the impact again.", 409, {
          code: "impact_changed",
          impact,
        });
      }
      if (!force && impact.blocking.length) {
        return jsonError("Other rows still need this one", 409, { code: "blocked", impact });
      }

      // A user's login goes with their profile.
      const authId = t.name === "users" ? (current.row.auth_id as string | null) : null;
      const removed = await db.transaction().execute(async (trx) => {
        if (force) return await forceDelete(trx, catalog, t.name, target);
        const res = await sql`DELETE FROM ${sql.table(t.name)} r WHERE ${match}`.execute(trx);
        return Number(res.numAffectedRows ?? 0);
      });
      if (authId) {
        const { error } = await supabaseAdmin.auth.admin.deleteUser(authId);
        if (error) console.error("admin: deleted profile but not auth user", authId, error.message);
      }
      await audit(caller, force ? "db_force_delete" : "db_delete", {
        table: t.name,
        pk,
        row: current.row,
        impact,
        removed,
      });
      return new Response(null, { status: 204 });
    }

    return jsonError("Not found", 404);
  } catch (err) {
    const handled = errorFor(err);
    if (handled) return handled;
    throw err;
  }
});
