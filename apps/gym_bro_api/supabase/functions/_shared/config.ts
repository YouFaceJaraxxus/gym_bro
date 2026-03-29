import { Kysely, PostgresDialect } from "npm:kysely@^0.27";
import pg from "npm:pg@^8";
import { Database } from "../../types/schema/public.ts";

const { Pool } = pg;

const postgresUrl = Deno.env.get("POSTGRES_URL");
if (!postgresUrl) throw new Error("POSTGRES_URL must be set");

const isLocal = postgresUrl.includes("127.0.0.1") ||
  postgresUrl.includes("localhost") ||
  postgresUrl.includes("host.docker.internal");

export const db = new Kysely<Database>({
  dialect: new PostgresDialect({
    pool: new Pool({
      connectionString: postgresUrl,
      ssl: isLocal ? false : { rejectUnauthorized: false },
    }),
  }),
});
