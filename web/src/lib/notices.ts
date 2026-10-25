import { getProduct, site } from "@/config/site";
import { query, tx } from "./db";
import { mappedRoleIds } from "./access";

// Notifications that are produced by the month job: a new release, an access that is about to end.

const RELEASE_WINDOW_DAYS = 7;
const EXPIRY_WARN_DAYS = 3;

// Users who may care about a Lua: they have a running grant, or their last known Discord roles include a mapped role.
async function interestedUsers(productId: string): Promise<string[]> {
  const roles = await mappedRoleIds(productId as "gamesense" | "primordial");
  const rows = await query<{ id: string }>(
    `select u.id from users u where not u.suspended and (
       exists (select 1 from access_grants g where g.user_id = u.id and g.product_id = $1 and g.revoked_at is null and g.starts_at <= now() and (g.expires_at is null or g.expires_at > now()))
       or exists (select 1 from member_cache m where m.user_id = u.id and m.in_guild and m.roles && $2::text[]))`,
    [productId, roles],
  );
  return rows.map((r) => r.id);
}

export async function fanoutReleases(now = new Date()): Promise<number> {
  const rel = await query<{ id: string; product_id: string; version: string; title: string; is_demo: boolean }>(
    `select r.id, r.product_id, r.version, r.title, r.is_demo from releases r
      where r.released_at > $1 and not r.is_demo and not exists (select 1 from release_notices n where n.release_id = r.id)`,
    [new Date(now.getTime() - RELEASE_WINDOW_DAYS * 86_400_000)],
  );
  let total = 0;
  for (const r of rel) {
    const users = await interestedUsers(r.product_id);
    const name = getProduct(r.product_id)?.name ?? r.product_id;
    await tx(async (db) => {
      const claimed = await db.query("insert into release_notices (release_id, recipients) values ($1,$2) on conflict do nothing returning release_id", [r.id, users.length]);
      if (!claimed.rows.length) return; // another run was first
      if (users.length) {
        await db.query(
          `insert into notifications (user_id, kind, title, body, link) select u, 'release', $2, $3, '/changelog' from unnest($1::uuid[]) u`,
          [users, `${name} ${r.version} is out`, r.title],
        );
      }
    });
    total += users.length;
    await announce(`${name} ${r.version}: ${r.title}`, `${site.url}/changelog`);
  }
  return total;
}

export async function warnExpiring(now = new Date()): Promise<number> {
  const until = new Date(now.getTime() + EXPIRY_WARN_DAYS * 86_400_000);
  const rows = await query<{ id: string; user_id: string; product_id: string; expires_at: Date }>(
    `select g.id, g.user_id, g.product_id, g.expires_at from access_grants g
      where g.revoked_at is null and g.expires_at > $1 and g.expires_at <= $2 and not exists (select 1 from expiry_notices e where e.grant_id = g.id)
        and not exists (select 1 from access_grants o where o.user_id = g.user_id and o.product_id = g.product_id and o.id <> g.id and o.revoked_at is null and o.starts_at <= $1 and (o.expires_at is null or o.expires_at > g.expires_at))`,
    [now, until],
  );
  let sent = 0;
  for (const g of rows) {
    const name = getProduct(g.product_id)?.name ?? g.product_id;
    await tx(async (db) => {
      const claimed = await db.query("insert into expiry_notices (grant_id) values ($1) on conflict do nothing returning grant_id", [g.id]);
      if (!claimed.rows.length) return;
      await db.query(
        `insert into notifications (user_id, kind, title, body, link) values ($1,'expiry',$2,$3,'/dashboard/access')`,
        [g.user_id, `Your ${name} access ends soon`, `It ends on ${g.expires_at.toISOString().slice(0, 10)} (UTC).`],
      );
      sent++;
    });
  }
  return sent;
}

// Optional Discord announcement through a channel webhook. Nothing happens while DISCORD_ANNOUNCE_WEBHOOK is empty.
export async function announce(text: string, url?: string): Promise<boolean> {
  const hook = (process.env.DISCORD_ANNOUNCE_WEBHOOK ?? "").trim();
  if (!/^https:\/\/(discord|discordapp)\.com\/api\/webhooks\//.test(hook)) return false;
  try {
    const res = await fetch(hook, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ allowed_mentions: { parse: [] }, embeds: [{ title: "SPECTER", description: text.slice(0, 1800), url, color: 0x8b5cf6 }] }),
      signal: AbortSignal.timeout(5000),
    });
    return res.ok;
  } catch {
    return false;
  }
}
