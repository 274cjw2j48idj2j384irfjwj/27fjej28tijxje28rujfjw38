import { EXPIRING_SOON_DAYS, getProduct, type ProductId } from "@/config/site";
import { one, query, type Db } from "./db";

export type AccessStatus = "no_access" | "active" | "expiring_soon" | "expired" | "suspended";

export type GrantRow = { starts_at: Date; expires_at: Date | null; revoked_at: Date | null; source: string };

export type AccessInput = {
  now: Date;
  suspended: boolean;
  roleAccess: boolean | null; // null: the Discord check failed, the roles are unknown
  grants: GrantRow[];
};

export type AccessResult = {
  status: AccessStatus;
  expiresAt: Date | null;     // the end of the access, null when it does not end
  via: "discord_role" | "admin" | "reward" | null;
  integrationError: boolean;  // Discord could not be asked: the result only covers the grants
};

const DAY = 86_400_000;

// Pure decision. The backend calls it for every protected request; the pages call it for the status badge.
export function computeAccess(input: AccessInput): AccessResult {
  const { now, grants, roleAccess } = input;
  const integrationError = roleAccess === null;
  if (input.suspended) return { status: "suspended", expiresAt: null, via: null, integrationError };

  if (roleAccess === true) return { status: "active", expiresAt: null, via: "discord_role", integrationError };

  const live = grants.filter((g) => !g.revoked_at && g.starts_at <= now);
  const open = live.find((g) => g.expires_at === null);
  if (open) return { status: "active", expiresAt: null, via: open.source as "admin" | "reward", integrationError };

  const running = live.filter((g) => g.expires_at !== null && g.expires_at > now);
  if (running.length) {
    const last = running.reduce((a, b) => (a.expires_at! >= b.expires_at! ? a : b));
    const soon = last.expires_at!.getTime() - now.getTime() <= EXPIRING_SOON_DAYS * DAY;
    return { status: soon ? "expiring_soon" : "active", expiresAt: last.expires_at, via: last.source as "admin" | "reward", integrationError };
  }

  const ended = live.filter((g) => g.expires_at !== null && g.expires_at <= now);
  if (ended.length) {
    const last = ended.reduce((a, b) => (a.expires_at! >= b.expires_at! ? a : b));
    return { status: "expired", expiresAt: last.expires_at, via: null, integrationError };
  }
  return { status: "no_access", expiresAt: null, via: null, integrationError };
}

export function hasAccess(status: AccessStatus): boolean {
  return status === "active" || status === "expiring_soon";
}

export function rolesGrantAccess(memberRoles: string[], mapped: string[]): boolean {
  if (!mapped.length) return false;
  const set = new Set(memberRoles);
  return mapped.some((r) => set.has(r));
}

export type MemberLookup = { inGuild: boolean; roles: string[] };
export type MemberFetcher = (discordId: string) => Promise<MemberLookup>;

const CACHE_FRESH_MS = 5 * 60_000;  // no Discord call while the last answer is this young
const CACHE_STALE_OK_MS = 15 * 60_000; // when Discord fails, an answer up to this old is still used

export async function mappedRoleIds(productId: ProductId, db?: Db): Promise<string[]> {
  const rows = await query<{ discord_role_id: string }>("select discord_role_id from role_mappings where product_id = $1", [productId], db);
  if (rows.length) return rows.map((r) => r.discord_role_id);
  return getProduct(productId)?.discordRoleIds ?? [];
}

// The member roles of a user: the cached answer while it is fresh, else Discord. null = the check failed.
export async function memberRoles(userId: string, discordId: string, fetcher: MemberFetcher, now = new Date(), db?: Db): Promise<string[] | null> {
  const cached = await one<{ in_guild: boolean; roles: string[]; fetched_at: Date }>("select in_guild, roles, fetched_at from member_cache where user_id = $1", [userId], db);
  const age = cached ? now.getTime() - cached.fetched_at.getTime() : Infinity;
  if (cached && age < CACHE_FRESH_MS) return cached.in_guild ? cached.roles : [];
  try {
    const m = await fetcher(discordId);
    await query(
      `insert into member_cache (user_id, in_guild, roles, fetched_at) values ($1,$2,$3,$4)
       on conflict (user_id) do update set in_guild = excluded.in_guild, roles = excluded.roles, fetched_at = excluded.fetched_at`,
      [userId, m.inGuild, m.roles, now],
      db,
    );
    return m.inGuild ? m.roles : [];
  } catch {
    if (cached && age < CACHE_STALE_OK_MS) return cached.in_guild ? cached.roles : [];
    return null;
  }
}

export async function resolveAccess(userId: string, productId: ProductId, fetcher: MemberFetcher, now = new Date(), db?: Db): Promise<AccessResult> {
  const user = await one<{ discord_id: string; suspended: boolean }>("select discord_id, suspended from users where id = $1", [userId], db);
  if (!user) return { status: "no_access", expiresAt: null, via: null, integrationError: false };
  const productSuspended = await one("select 1 as x from suspensions where user_id = $1 and product_id = $2 and lifted_at is null", [userId, productId], db);
  const grants = await query<GrantRow>("select starts_at, expires_at, revoked_at, source from access_grants where user_id = $1 and product_id = $2", [userId, productId], db);
  const mapped = await mappedRoleIds(productId, db);
  let roleAccess: boolean | null = false;
  if (mapped.length) {
    const roles = await memberRoles(userId, user.discord_id, fetcher, now, db);
    roleAccess = roles === null ? null : rolesGrantAccess(roles, mapped);
  }
  return computeAccess({ now, suspended: user.suspended || !!productSuspended, roleAccess, grants });
}

export async function resolveAllAccess(userId: string, fetcher: MemberFetcher, now = new Date()): Promise<Record<ProductId, AccessResult>> {
  const [gamesense, primordial] = await Promise.all([resolveAccess(userId, "gamesense", fetcher, now), resolveAccess(userId, "primordial", fetcher, now)]);
  return { gamesense, primordial };
}
