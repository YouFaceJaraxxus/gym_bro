import { Kysely, PostgresDialect } from "kysely";
import pg from "pg";
import { Database } from "../../types/schema/public.ts";

const { Pool } = pg;

const postgresUrl = Deno.env.get("POSTGRES_URL");
if (!postgresUrl) throw new Error("POSTGRES_URL must be set");

export const IS_LOCAL = postgresUrl.includes("127.0.0.1") ||
  postgresUrl.includes("localhost");

export const ENV = IS_LOCAL ? "local" : "production";

console.log(`[config] targeting ${ENV} DB → ${postgresUrl.split("@")[1]}`);

export const db = new Kysely<Database>({
  dialect: new PostgresDialect({
    pool: new Pool({
      connectionString: postgresUrl,
      ssl: IS_LOCAL ? false : { rejectUnauthorized: false },
    }),
  }),
});
