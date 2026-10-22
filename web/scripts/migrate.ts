import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { closePool, pool } from "../src/lib/db";

export async function migrate(dir = join(__dirname, "..", "migrations")): Promise<string[]> {
  const client = await pool().connect();
  const applied: string[] = [];
  try {
    await client.query("select pg_advisory_lock(7351001)");
    await client.query("create table if not exists schema_migrations (name text primary key, applied_at timestamptz not null default now())");
    const done = new Set((await client.query("select name from schema_migrations")).rows.map((r) => r.name as string));
    for (const file of readdirSync(dir).filter((f) => f.endsWith(".sql")).sort()) {
      if (done.has(file)) continue;
      try {
        await client.query("begin");
        await client.query(readFileSync(join(dir, file), "utf8"));
        await client.query("insert into schema_migrations (name) values ($1)", [file]);
        await client.query("commit");
        applied.push(file);
      } catch (err) {
        await client.query("rollback");
        throw new Error(`migration ${file} failed: ${(err as Error).message}`);
      }
    }
  } finally {
    await client.query("select pg_advisory_unlock(7351001)").catch(() => undefined);
    client.release();
  }
  return applied;
}

if (require.main === module) {
  migrate()
    .then((applied) => {
      console.log(applied.length ? `applied: ${applied.join(", ")}` : "database is up to date");
    })
    .catch((err) => {
      console.error(err.message);
      process.exitCode = 1;
    })
    .finally(closePool);
}
