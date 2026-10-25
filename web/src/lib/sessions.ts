import { one, query } from "./db";
import { randomToken, sha256 } from "./crypto";

export const SESSION_COOKIE = "specter_session";
export const SESSION_DAYS = 30;

export type SessionUser = {
  id: string;
  discord_id: string;
  username: string;
  global_name: string | null;
  avatar: string | null;
  is_admin: boolean;
  suspended: boolean;
  verified_creator: boolean;
};

export async function upsertUser(d: { id: string; username: string; global_name: string | null; avatar: string | null }, adminIds: string[]): Promise<SessionUser> {
  const row = await one<SessionUser>(
    `insert into users (discord_id, username, global_name, avatar, is_admin) values ($1,$2,$3,$4,$5)
     on conflict (discord_id) do update set username = excluded.username, global_name = excluded.global_name, avatar = excluded.avatar,
       is_admin = users.is_admin or excluded.is_admin, last_login_at = now()
     returning id, discord_id, username, global_name, avatar, is_admin, suspended, verified_creator`,
    [d.id, d.username, d.global_name, d.avatar, adminIds.includes(d.id)],
  );
  return row!;
}

export async function createSession(userId: string, userAgent: string | null, now = new Date()): Promise<{ token: string; expires: Date }> {
  const token = randomToken("sps_");
  const expires = new Date(now.getTime() + SESSION_DAYS * 86_400_000);
  await query("insert into sessions (user_id, token_hash, expires_at, user_agent) values ($1,$2,$3,$4)", [userId, sha256(token), expires, userAgent?.slice(0, 200) ?? null]);
  return { token, expires };
}

export async function userFromSession(token: string | undefined, now = new Date()): Promise<SessionUser | null> {
  if (!token || !token.startsWith("sps_")) return null;
  return one<SessionUser>(
    `select u.id, u.discord_id, u.username, u.global_name, u.avatar, u.is_admin, u.suspended, u.verified_creator
       from sessions s join users u on u.id = s.user_id where s.token_hash = $1 and s.expires_at > $2`,
    [sha256(token), now],
  );
}

export async function destroySession(token: string | undefined): Promise<void> {
  if (token) await query("delete from sessions where token_hash = $1", [sha256(token)]);
}

export async function destroyAllSessions(userId: string): Promise<void> {
  await query("delete from sessions where user_id = $1", [userId]);
}

export async function purgeSessions(): Promise<void> {
  await query("delete from sessions where expires_at < now()");
}
