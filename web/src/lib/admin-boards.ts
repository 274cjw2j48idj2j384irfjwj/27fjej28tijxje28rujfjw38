import type { ProductId } from "@/config/site";
import { one, query } from "./db";
import { listBoards, nextPeriodStart, periodOf, standings, type BoardRow, type StandingRow } from "./leaderboard";

export type ClosedPeriod = { board_id: string; period: string; closed_at: Date; results: number; rewards: number };

export async function closedPeriods(limit = 36): Promise<ClosedPeriod[]> {
  return query<ClosedPeriod>(
    `select c.board_id, c.period, c.closed_at,
            (select count(*)::int from monthly_results m where m.board_id = c.board_id and m.period = c.period) as results,
            (select count(*)::int from reward_log r where r.board_id = c.board_id and r.period = c.period) as rewards
       from period_closures c order by c.period desc, c.board_id limit ${Math.min(limit, 200)}`,
  );
}

// Finished months that still have points and no closure: the ones a manual close or the cron job would handle.
export async function unclosedPeriods(now = new Date()): Promise<{ board_id: string; period: string }[]> {
  return query<{ board_id: string; period: string }>(
    `select distinct e.board_id, e.period from score_events e
      where e.period < $1 and not e.is_demo and not exists (select 1 from period_closures c where c.board_id = e.board_id and c.period = e.period)
      order by e.period desc, e.board_id`,
    [periodOf(now)],
  );
}

export type MonthlyResult = { board_id: string; period: string; rank: number; points: number; name: string; is_demo: boolean };

export async function monthlyResults(limitPeriods = 6): Promise<MonthlyResult[]> {
  return query<MonthlyResult>(
    `select m.board_id, m.period, m.rank, m.points, coalesce(u.global_name, u.username) as name, m.is_demo
       from monthly_results m join users u on u.id = m.user_id
      where m.period in (select distinct period from monthly_results order by period desc limit $1)
      order by m.period desc, m.board_id, m.rank`,
    [limitPeriods],
  );
}

export type BoardOverview = { board: BoardRow; period: string; standings: StandingRow[]; events: number };

export async function boardOverviews(now = new Date()): Promise<BoardOverview[]> {
  const period = periodOf(now);
  const boards = await listBoards();
  const out: BoardOverview[] = [];
  for (const board of boards) {
    const ids = board.kind === "overall" ? boards.filter((b) => b.kind === "product").map((b) => b.id) : [board.id];
    const ev = await one<{ n: string }>("select count(*) as n from score_events where board_id = any($1) and period = $2", [ids, period]);
    out.push({ board, period, standings: await standings(board.id, period, { limit: 10 }), events: Number(ev?.n ?? 0) });
  }
  return out;
}

export type RewardPreview = { board: BoardRow; period: string; closesAt: Date; enabled: boolean; product: ProductId | null; rows: { rank: number; name: string; points: number; days: number; demo: boolean }[] };

// What closing the running month would pay if it ended now: the standings with the board's reward settings. Demo rows are shown but never paid.
export async function rewardPreview(now = new Date()): Promise<RewardPreview[]> {
  const period = periodOf(now);
  const out: RewardPreview[] = [];
  for (const board of await listBoards()) {
    const top = await standings(board.id, period, { limit: board.reward_days.length });
    out.push({
      board,
      period,
      closesAt: nextPeriodStart(period),
      enabled: board.rewards_enabled && !!board.reward_product_id,
      product: board.reward_product_id,
      rows: top.map((r) => ({ rank: r.rank, name: r.name, points: r.points, days: board.reward_days[r.rank - 1], demo: r.demo })),
    });
  }
  return out;
}

export type Overview = {
  users: number; admins: number; banned: number;
  configs: number; configsActive: number; configsHidden: number;
  reportsOpen: number; activeGrants: number; suspensions: number;
};

export async function adminOverview(): Promise<Overview> {
  const r = await one<Record<keyof Overview, string>>(
    `select
       (select count(*) from users) as users,
       (select count(*) from users where is_admin) as admins,
       (select count(*) from users where suspended) as banned,
       (select count(*) from configs) as configs,
       (select count(*) from configs where not hidden and visibility = 'public') as "configsActive",
       (select count(*) from configs where hidden) as "configsHidden",
       (select count(*) from config_reports where status = 'open') as "reportsOpen",
       (select count(*) from access_grants where revoked_at is null and starts_at <= now() and (expires_at is null or expires_at > now())) as "activeGrants",
       (select count(*) from suspensions where lifted_at is null) as suspensions`,
  );
  const n = (k: keyof Overview) => Number(r?.[k] ?? 0);
  return { users: n("users"), admins: n("admins"), banned: n("banned"), configs: n("configs"), configsActive: n("configsActive"), configsHidden: n("configsHidden"), reportsOpen: n("reportsOpen"), activeGrants: n("activeGrants"), suspensions: n("suspensions") };
}
