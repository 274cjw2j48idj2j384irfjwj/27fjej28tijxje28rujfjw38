import { one } from "@/lib/db";
import { discordConfigured } from "@/lib/discord";
import { json } from "@/lib/http";

export const dynamic = "force-dynamic";

// Status page data: the web app, the database and whether the Discord integration is configured.
export async function GET() {
  let db = false;
  try {
    db = !!(await one("select 1 as ok"));
  } catch {
    db = false;
  }
  return json({ web: true, database: db, discordConfigured: discordConfigured() }, db ? 200 : 503);
}
