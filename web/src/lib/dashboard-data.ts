// Server queries of the signed in area (/dashboard, /link). Read only; every change goes through the real API routes.
import { headers } from "next/headers";
import { redirect } from "next/navigation";
import { getProducts, type ProductConfig, type ProductId } from "@/config/site";
import type { AccessResult } from "./access";
import { accessOf, currentUser } from "./authz";
import { one, query } from "./db";
import { getBoard, nextPeriodStart, periodOf, standings, type BoardRow, type StandingRow } from "./leaderboard";
import type { SessionUser } from "./sessions";

// The page asks for its own path, so the sign in brings the visitor back to it.
export async function requireDashboardUser(path = "/dashboard"): Promise<SessionUser> {
  const user = await currentUser();
  if (!user) {
    // the middleware passes the real path, so a deep link survives the sign in
    const real = (await headers()).get("x-pathname");
    redirect(`/api/auth/login?next=${encodeURIComponent(real && real.startsWith("/") ? real : path)}`);
  }
  return user;
}

export type ProductAccess = { product: ProductConfig; access: AccessResult };

export async function accessAll(userId: string): Promise<ProductAccess[]> {
  return Promise.all(getProducts().map(async (product) => ({ product, access: await accessOf(userId, product.id) })));
}

export type BoardStanding = {
  board: BoardRow;
  period: string;
  me: StandingRow | null;
  ahead: StandingRow | null;     // the player one place above
  gap: number | null;            // points to the player above
  players: number;
};

export async function myBoards(userId: string, now = new Date()): Promise<{ period: string; resetsAt: Date; boards: BoardStanding[] }> {
  const period = periodOf(now);
  const ids = [...getProducts().map((p) => p.id as string), "overall"];
  const boards: BoardStanding[] = [];
  for (const id of ids) {
    const board = await getBoard(id);
    if (!board) continue;
    const rows = await standings(id, period, { limit: 500 });
    const i = rows.findIndex((r) => r.user_id === userId);
    const me = i >= 0 ? rows[i] : null;
    const ahead = i > 0 ? rows[i - 1] : null;
    boards.push({ board, period, me, ahead, gap: me && ahead ? ahead.points - me.points : null, players: rows.length });
  }
  return { period, resetsAt: nextPeriodStart(period), boards };
}

export type Counts = { configs: number; saved: number; devices: number; unread: number };

export async function countsOf(userId: string): Promise<Counts> {
  const row = await one<{ configs: string; saved: string; devices: string; unread: string }>(
    `select
       (select count(*) from configs where owner_id = $1) as configs,
       (select count(*) from config_library l join configs c on c.id = l.config_id
         where l.user_id = $1 and (c.visibility <> 'private' or c.owner_id = $1) and (not c.hidden or c.owner_id = $1)) as saved,
       (select count(*) from client_tokens where user_id = $1 and revoked_at is null and expires_at > now()) as devices,
       (select count(*) from notifications where user_id = $1 and read_at is null) as unread`,
    [userId],
  );
  return { configs: Number(row?.configs ?? 0), saved: Number(row?.saved ?? 0), devices: Number(row?.devices ?? 0), unread: Number(row?.unread ?? 0) };
}

export type RewardEntry = {
  board_id: string;
  board_name: string;
  period: string;
  rank: number;
  product_id: ProductId;
  days: number;
  previous_expires_at: Date | null;
  new_expires_at: Date | null;
  note: string;
  created_at: Date;
};

export type ResultEntry = { board_id: string; board_name: string; period: string; rank: number; points: number; is_demo: boolean };

export async function rewardsOf(userId: string): Promise<{ rewards: RewardEntry[]; results: ResultEntry[] }> {
  const rewards = await query<RewardEntry>(
    `select r.board_id, b.name as board_name, r.period, r.rank, r.product_id, r.days, r.previous_expires_at, r.new_expires_at, r.note, r.created_at
       from reward_log r join boards b on b.id = r.board_id where r.user_id = $1 order by r.period desc, r.rank, r.id desc`,
    [userId],
  );
  const results = await query<ResultEntry>(
    `select m.board_id, b.name as board_name, m.period, m.rank, m.points, m.is_demo
       from monthly_results m join boards b on b.id = m.board_id where m.user_id = $1 order by m.period desc, m.rank, m.board_id`,
    [userId],
  );
  return { rewards, results };
}

export type NotificationEntry = { id: string; kind: string; title: string; body: string; link: string | null; read_at: Date | null; created_at: Date };

export async function notificationsOf(userId: string, limit = 50): Promise<NotificationEntry[]> {
  return query<NotificationEntry>("select id, kind, title, body, link, read_at, created_at from notifications where user_id = $1 order by created_at desc limit $2", [userId, limit]);
}

export async function accountDates(userId: string): Promise<{ created_at: Date; last_login_at: Date } | null> {
  return one<{ created_at: Date; last_login_at: Date }>("select created_at, last_login_at from users where id = $1", [userId]);
}

export type GrantEntry = { id: string; product_id: ProductId; source: "admin" | "reward"; starts_at: Date; expires_at: Date | null; revoked_at: Date | null; created_at: Date };

export async function grantsOf(userId: string): Promise<GrantEntry[]> {
  return query<GrantEntry>(
    "select id, product_id, source, starts_at, expires_at, revoked_at, created_at from access_grants where user_id = $1 order by created_at desc limit 50",
    [userId],
  );
}

export async function lastDiscordCheck(userId: string): Promise<{ in_guild: boolean; fetched_at: Date } | null> {
  return one<{ in_guild: boolean; fetched_at: Date }>("select in_guild, fetched_at from member_cache where user_id = $1", [userId]);
}
