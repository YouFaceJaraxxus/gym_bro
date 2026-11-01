// deno-lint-ignore-file no-explicit-any
// The super-user database console (/admin/tables): catalog, browsing,
// insert/update, delete impact, plain and forced deletes, and the audit log.
// Works on a throwaway business with one member and one follower; seeded
// rows are only read.
import { call, checker, seededUsers, short, suite } from "./_client.ts";
import { sql } from "./_db.ts";

const pkParam = (pk: Record<string, unknown>) => encodeURIComponent(JSON.stringify(pk));

Deno.test({
  name: "features: super-user database console",
  ...suite,
  async fn(t) {
    const { check, assertAll } = checker();
    const { member, owner, superU } = await seededUsers();
    const S = superU.token;
    let businessId: string | null = null;

    try {
      await t.step("1. only super users, catalog and browsing", async () => {
        for (const [who, s] of [["member", member], ["owner", owner]] as const) {
          const r = await call("GET", "/admin/tables", s.token);
          check(`${who} can't open the console`, r.status === 403, `status ${r.status}`);
        }
        const tables = await call("GET", "/admin/tables", S);
        const users = (tables.data as any[])?.find((x) => x.name === "users");
        check(
          "tables come with columns, keys, references and counts",
          tables.status === 200 && users?.primary_key?.[0] === "id" && users.row_count > 0 &&
            users.columns.some((c: any) => c.name === "is_super_user" && c.type === "boolean") &&
            users.referenced_by.length > 0,
          short(users),
        );
        const bm = (tables.data as any[]).find((x) => x.name === "business_member");
        const role = bm?.columns.find((c: any) => c.name === "role");
        check("enum columns list their values", role?.kind === "enum" && role.enum_values?.includes("trainer"), short(role));
        const audit = (tables.data as any[]).find((x) => x.name === "admin_audit_log");
        check("the audit log is read-only", audit?.read_only === true);

        const search = await call("GET", `/admin/tables/users?q=${encodeURIComponent(member.profile.username)}`, S);
        check("free-text search finds a user", search.status === 200 && search.data.rows.some((r: any) => r.id === member.profile.id), short(search.data));
        const byId = await call("GET", `/admin/tables/users?q=${member.profile.id}`, S);
        check("a pasted id matches uuid columns", byId.data?.total === 1, short(byId.data));
        const where = await call(
          "GET",
          `/admin/tables/business_member?where=${pkParam({ user_id: owner.profile.id })}`,
          S,
        );
        check("exact filters", where.status === 200 && where.data.rows.every((r: any) => r.user_id === owner.profile.id), short(where.data));
        const badCol = await call("GET", `/admin/tables/users?where=${pkParam({ nope: 1 })}`, S);
        check("unknown filter columns are refused", badCol.status === 400, `status ${badCol.status}`);
        const unknown = await call("GET", "/admin/tables/no_such_table", S);
        check("unknown tables are 404", unknown.status === 404, `status ${unknown.status}`);
        const auditWrite = await call("POST", "/admin/tables/admin_audit_log", S, { values: { action: "x" } });
        check("read-only tables refuse writes", auditWrite.status === 403, `status ${auditWrite.status}`);
      });
      assertAll();

      await t.step("2. insert, read, update", async () => {
        const created = await call("POST", "/admin/tables/business", S, {
          values: {
            name: "it-admin console gym",
            location: "Nowhere",
            working_hours_from: "08:00",
            working_hours_to: "20:00",
            working_weekdays: [1, 2, 3],
            has_gym: true,
          },
        });
        businessId = created.data?.id ?? null;
        check(
          "insert fills defaults",
          created.status === 201 && created.data.status === "pending" && created.data.has_shop === false,
          short(created.data),
        );
        const pk = pkParam({ id: businessId });
        const upd = await call("PATCH", `/admin/tables/business/row?pk=${pk}`, S, {
          values: { status: "approved", bio: "verified as real" },
        });
        check("update sets columns", upd.status === 200 && upd.data.status === "approved" && upd.data.bio === "verified as real", short(upd.data));
        const badEnum = await call("PATCH", `/admin/tables/business/row?pk=${pk}`, S, { values: { status: "nonsense" } });
        check("bad enum values are 400", badEnum.status === 400, short(badEnum.data));
        const badCheck = await call("PATCH", `/admin/tables/business/row?pk=${pk}`, S, {
          values: { has_gym: false, has_shop: false },
        });
        check("check constraints are enforced", badCheck.status === 400, short(badCheck.data));
        const notNull = await call("PATCH", `/admin/tables/business/row?pk=${pk}`, S, { values: { name: null } });
        check("not-null columns are enforced", notNull.status === 400, short(notNull.data));

        const m = await call("POST", "/admin/tables/member", S, { values: { user_id: member.profile.id, gym_id: businessId } });
        const f = await call("POST", "/admin/tables/business_follow", S, {
          values: { user_id: member.profile.id, business_id: businessId },
        });
        check("related rows insert", m.status === 201 && f.status === 201, `${m.status} ${f.status}`);
        const dup = await call("POST", "/admin/tables/member", S, { values: { user_id: member.profile.id, gym_id: businessId } });
        check("unique violations are 409", dup.status === 409, `status ${dup.status}`);

        const row = await call("GET", `/admin/tables/business/row?pk=${pk}`, S);
        const refs = Object.fromEntries((row.data?.referenced_by ?? []).filter((r: any) => r.count).map((r: any) => [r.table, r.count]));
        check("a row shows what points at it", refs.member === 1 && refs.business_follow === 1, short(refs));
      });
      assertAll();

      await t.step("3. delete impact, guards, forced delete, audit", async () => {
        const pk = pkParam({ id: businessId });
        const impact = await call("GET", `/admin/tables/business/row/impact?pk=${pk}`, S);
        check(
          "impact lists cascades and blockers",
          impact.data?.deleted?.some((e: any) => e.table === "business_follow" && e.count === 1) &&
            impact.data?.blocking?.some((e: any) => e.table === "member" && e.action === "restrict" && e.count === 1),
          short(impact.data),
        );

        const stale = await call("DELETE", `/admin/tables/business/row?pk=${pk}`, S, { expected: 1 });
        check("a confirmation for the wrong count is refused", stale.status === 409 && stale.data.code === "impact_changed", short(stale.data));
        const blocked = await call("DELETE", `/admin/tables/business/row?pk=${pk}`, S, { expected: 2 });
        check("a plain delete with blockers is refused", blocked.status === 409 && blocked.data.code === "blocked", short(blocked.data));
        const forced = await call("DELETE", `/admin/tables/business/row?pk=${pk}`, S, {
          force: true,
          expected: impact.data.forced_rows + 1,
        });
        check("a forced delete takes the blockers too", forced.status === 204, `status ${forced.status} ${short(forced.data)}`);
        const left = (await sql<{ n: number }>(
          `SELECT (SELECT count(*) FROM business WHERE id = $1) + (SELECT count(*) FROM member WHERE gym_id = $1)
             + (SELECT count(*) FROM business_follow WHERE business_id = $1) AS n`,
          [businessId],
        )) ?? [];
        check("nothing is left behind", Number(left[0]?.n) === 0, short(left));
        const logged = (await sql<{ action: string }>(
          `SELECT action FROM admin_audit_log WHERE actor_id = $1 AND metadata->'pk'->>'id' = $2 ORDER BY created_at`,
          [superU.profile.id, businessId],
        )) ?? [];
        check("updates and deletes are audited", logged.some((l) => l.action === "db_update") && logged.some((l) => l.action === "db_force_delete"), short(logged));
        if (Number(left[0]?.n ?? 0) === 0) businessId = null;
      });
      assertAll();
    } finally {
      if (businessId) {
        await sql(`DELETE FROM member WHERE gym_id = $1`, [businessId]);
        await sql(`DELETE FROM business WHERE id = $1`, [businessId]);
      }
      await sql(
        `DELETE FROM admin_audit_log WHERE actor_id = $1 AND action LIKE 'db_%' AND metadata->>'table' IN ('business', 'member', 'business_follow')
           AND (metadata->'row'->>'name' = 'it-admin console gym' OR metadata->'before'->>'name' = 'it-admin console gym'
             OR metadata->'row'->>'gym_id' IS NOT NULL OR metadata->'row'->>'business_id' IS NOT NULL)
           AND created_at > NOW() - INTERVAL '1 hour'`,
        [superU.profile.id],
      );
    }
  },
});
