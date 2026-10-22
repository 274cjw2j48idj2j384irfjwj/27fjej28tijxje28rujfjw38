// Development helper: makes (or reuses) a local user, gives it a session and prints the session cookie value.
// npx tsx scripts/dev-session.ts [--admin] [--grant] [--name=Dev]
import { closePool, one, query } from "../src/lib/db";
import { createSession } from "../src/lib/sessions";

async function main() {
  const args = process.argv.slice(2);
  const name = args.find((a) => a.startsWith("--name="))?.slice(7) || "dev";
  const admin = args.includes("--admin");
  const discordId = `8000000000000${admin ? "2" : "1"}${[...name].reduce((n, c) => (n * 31 + c.charCodeAt(0)) % 1000, 7).toString().padStart(3, "0")}`;
  const user = await one<{ id: string }>(
    `insert into users (discord_id, username, global_name, is_admin) values ($1,$2,$2,$3)
     on conflict (discord_id) do update set is_admin = excluded.is_admin returning id`,
    [discordId, name, admin],
  );
  if (args.includes("--grant")) {
    await query("delete from access_grants where user_id = $1", [user!.id]);
    await query("insert into access_grants (user_id, product_id, source, expires_at) values ($1,'gamesense','admin', now() + interval '40 days'), ($1,'primordial','admin', now() + interval '3 days')", [user!.id]);
  }
  console.log((await createSession(user!.id, "dev-session")).token);
}
main().catch((e) => { console.error(e); process.exitCode = 1; }).finally(closePool);
