import type { ProductId } from "@/config/site";
import { one, query, tx, type Db } from "./db";
import { ApiError } from "./configs";

// All month borders are UTC. A period is 'YYYY-MM'.
export function periodOf(d: Date): string {
  return `${d.getUTCFullYear()}-${String(d.getUTCMonth() + 1).padStart(2, "0")}`;
}

export function periodStart(period: string): Date {
  const [y, m] = period.split("-").map(Number);
  return new Date(Date.UTC(y, m - 1, 1));
}

export function nextPeriodStart(period: string): Date {
  const [y, m] = period.split("-").map(Number);
  return new Date(Date.UTC(y, m, 1));
}

export function isPeriod(s: string): boolean {
  return /^\d{4}-(0[1-9]|1[0-2])$/.test(s);
}

export function previousPeriod(period: string): string {
  const [y, m] = period.split("-").map(Number);
  return periodOf(new Date(Date.UTC(y, m - 2, 1)));
}

export type BoardRow = {
  id: string;
  name: string;
  kind: "product" | "overall";
  product_id: ProductId | null;
  scoring_enabled: boolean;
  rules: { events: Record<string, { points: number; dailyCap?: number }> };
  rewards_enabled: boolean;
  reward_product_id: ProductId | null;
  reward_days: number[];
};

export async function getBoard(id: string, db?: Db): Promise<BoardRow | null> {
  return one<BoardRow>("select * from boards where id = $1", [id], db);
}

export async function listBoards(): Promise<BoardRow[]> {
  return query<BoardRow>("select * from boards order by case kind when 'product' then 0 else 1 end, id");
}

export type ScoreResult = { accepted: true; points: number } | { accepted: false; reason: "disabled" | "unknown_event" | "duplicate" | "daily_cap" | "bad_board" };

// Points come from the admin rules, never from the client: the client only reports that an event happened.
export async function ingestScore(input: { boardId: string; userId: string; eventType: string; dedupeKey: string; now?: Date }): Promise<ScoreResult> {
  const now = input.now ?? new Date();
  const board = await getBoard(input.boardId);
  if (!board || board.kind !== "product") return { accepted: false, reason: "bad_board" };
  if (!board.scoring_enabled) return { accepted: false, reason: "disabled" };
  const rule = board.rules.events?.[input.eventType];
  if (!rule || !Number.isInteger(rule.points) || rule.points <= 0) return { accepted: false, reason: "unknown_event" };
  if (!/^[\w:.-]{1,80}$/.test(input.dedupeKey)) return { accepted: false, reason: "duplicate" };
  return tx(async (db) => {
    await query("select pg_advisory_xact_lock(hashtext($1))", [`score:${input.boardId}:${input.userId}`], db);
    if (rule.dailyCap && rule.dailyCap > 0) {
      const day = await one<{ n: string }>(
        `select coalesce(sum(points),0) as n from score_events
          where board_id = $1 and user_id = $2 and event_type = $3 and created_at >= date_trunc('day', $4::timestamptz at time zone 'utc') at time zone 'utc'`,
        [input.boardId, input.userId, input.eventType, now],
        db,
      );
      if (Number(day?.n ?? 0) + rule.points > rule.dailyCap) return { accepted: false, reason: "daily_cap" } as ScoreResult;
    }
    const ins = await query(
      `insert into score_events (board_id, user_id, period, event_type, points, dedupe_key, created_at)
       values ($1,$2,$3,$4,$5,$6,$7) on conflict (board_id, dedupe_key) do nothing returning id`,
      [input.boardId, input.userId, periodOf(now), input.eventType, rule.points, input.dedupeKey, now],
      db,
    );
    return ins.length ? ({ accepted: true, points: rule.points } as ScoreResult) : ({ accepted: false, reason: "duplicate" } as ScoreResult);
  });
}

export async function manualScore(input: { boardId: string; userId: string; points: number; reason: string; actorId: string; now?: Date }): Promise<void> {
  const board = await getBoard(input.boardId);
  if (!board || board.kind !== "product") throw new ApiError(400, "bad_board", "Points can only be added to a product board.");
  if (!Number.isInteger(input.points) || input.points === 0 || Math.abs(input.points) > 100000) throw new ApiError(400, "bad_points", "Points must be a non zero integer.");
  const now = input.now ?? new Date();
  await query(
    `insert into score_events (board_id, user_id, period, event_type, points, dedupe_key, created_at) values ($1,$2,$3,'manual',$4,$5,$6)`,
    [input.boardId, input.userId, periodOf(now), input.points, `manual:${input.actorId}:${now.getTime()}:${Math.random().toString(36).slice(2, 8)}`, now],
  );
}

export type StandingRow = {
  rank: number;
  user_id: string;
  discord_id: string;
  name: string;
  avatar: string | null;
  verified: boolean;
  points: number;
  demo: boolean;
};

// Order: more points first; the same points: who reached them first (earliest last score), then the older account,
// then the id, so two players never share a place and the order never changes between two runs.
export async function standings(boardId: string, period: string, opts: { limit?: number; excludeDemo?: boolean } = {}, db?: Db): Promise<StandingRow[]> {
  const board = await getBoard(boardId, db);
  if (!board) return [];
  const boardIds = board.kind === "overall" ? (await query<{ id: string }>("select id from boards where kind = 'product'", [], db)).map((b) => b.id) : [board.id];
  const rows = await query<{ user_id: string; discord_id: string; name: string; avatar: string | null; verified: boolean; pts: number; demo: boolean }>(
    `select u.id as user_id, u.discord_id, coalesce(u.global_name, u.username) as name, u.avatar, u.verified_creator as verified,
            sum(e.points)::int as pts, bool_or(e.is_demo) as demo
       from score_events e join users u on u.id = e.user_id
      where e.board_id = any($1) and e.period = $2 ${opts.excludeDemo ? "and not e.is_demo" : ""}
      group by u.id
     having sum(e.points) > 0
      order by pts desc, max(e.created_at) asc, u.created_at asc, u.id asc
      limit ${Math.min(opts.limit ?? 100, 500)}`,
    [boardIds, period],
    db,
  );
  return rows.map((r, i) => ({ rank: i + 1, user_id: r.user_id, discord_id: r.discord_id, name: r.name, avatar: r.avatar, verified: r.verified, points: r.pts, demo: r.demo }));
}

export async function rankOf(boardId: string, period: string, userId: string): Promise<StandingRow | null> {
  const all = await standings(boardId, period, { limit: 500 });
  return all.find((r) => r.user_id === userId) ?? null;
}

export type ArchiveRow = { period: string; rank: number; user_id: string; name: string; avatar: string | null; discord_id: string; points: number; demo: boolean };

export async function archive(boardId: string, limitPeriods = 12): Promise<ArchiveRow[]> {
  return query<ArchiveRow>(
    `select r.period, r.rank, r.user_id, coalesce(u.global_name, u.username) as name, u.avatar, u.discord_id, r.points, r.is_demo as demo
       from monthly_results r join users u on u.id = r.user_id
      where r.board_id = $1 and r.period in (select distinct period from monthly_results where board_id = $1 order by period desc limit $2)
      order by r.period desc, r.rank`,
    [boardId, limitPeriods],
  );
}

export type RewardOutcome = { grantId: string | null; previousExpiresAt: Date | null; newExpiresAt: Date | null; note: string };

// Adds days to the access of a product: running access is extended from its end, ended or no access starts now,
// an open ended access gets nothing (it never runs out).
export async function applyReward(db: Db, userId: string, productId: ProductId, days: number, now: Date, createdBy: string | null, note: string): Promise<RewardOutcome> {
  const grants = await query<{ expires_at: Date | null }>(
    `select expires_at from access_grants where user_id = $1 and product_id = $2 and revoked_at is null and starts_at <= $3
        and (expires_at is null or expires_at > $3)`,
    [userId, productId, now],
    db,
  );
  if (grants.some((g) => g.expires_at === null)) return { grantId: null, previousExpiresAt: null, newExpiresAt: null, note: "permanent_access" };
  const prev = grants.length ? new Date(Math.max(...grants.map((g) => g.expires_at!.getTime()))) : null;
  const base = prev ?? now;
  const next = new Date(base.getTime() + days * 86_400_000);
  const g = await one<{ id: string }>(
    `insert into access_grants (user_id, product_id, source, starts_at, expires_at, note, created_by) values ($1,$2,'reward',$3,$4,$5,$6) returning id`,
    [userId, productId, now, next, note, createdBy],
    db,
  );
  return { grantId: g!.id, previousExpiresAt: prev, newExpiresAt: next, note: prev ? "extended" : "started" };
}

export type CloseSummary = { boardId: string; period: string; alreadyClosed: boolean; results: number; rewards: number };

// Closes one month of one board: stores the final result and pays the rewards, once. The closure row is the lock
// against a second run (a repeated cron call, two servers at the same moment).
export async function closePeriod(boardId: string, period: string, now = new Date()): Promise<CloseSummary> {
  if (!isPeriod(period)) throw new ApiError(400, "bad_period", "Period must look like 2026-10.");
  if (nextPeriodStart(period) > now) throw new ApiError(409, "period_open", "That month is not over yet.");
  return tx(async (db) => {
    await query("select pg_advisory_xact_lock(hashtext($1))", [`close:${boardId}:${period}`], db);
    const done = await one("select 1 as x from period_closures where board_id = $1 and period = $2", [boardId, period], db);
    if (done) return { boardId, period, alreadyClosed: true, results: 0, rewards: 0 };
    const board = await getBoard(boardId, db);
    if (!board) throw new ApiError(404, "no_board", "Unknown board.");

    const top = (await standings(boardId, period, { limit: board.reward_days.length, excludeDemo: true }, db)).slice(0, board.reward_days.length);
    let rewards = 0;
    for (const row of top) {
      await query("insert into monthly_results (board_id, period, rank, user_id, points) values ($1,$2,$3,$4,$5)", [boardId, period, row.rank, row.user_id, row.points], db);
      if (board.rewards_enabled && board.reward_product_id) {
        const days = board.reward_days[row.rank - 1];
        const out = await applyReward(db, row.user_id, board.reward_product_id, days, now, null, `${board.name} ${period} #${row.rank}`);
        await query(
          `insert into reward_log (board_id, period, rank, user_id, product_id, days, grant_id, previous_expires_at, new_expires_at, note)
           values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)`,
          [boardId, period, row.rank, row.user_id, board.reward_product_id, days, out.grantId, out.previousExpiresAt, out.newExpiresAt, out.note],
          db,
        );
        await query(
          `insert into notifications (user_id, kind, title, body, link) values ($1,'reward',$2,$3,'/dashboard/rewards')`,
          [
            row.user_id,
            `You placed #${row.rank} on the ${board.name} leaderboard`,
            out.note === "permanent_access" ? `Your ${period} reward is ${days} days, but your access never expires.` : `${days} days of access were added for ${period}.`,
          ],
          db,
        );
        rewards++;
      }
    }
    await query("insert into period_closures (board_id, period) values ($1,$2)", [boardId, period], db);
    await query(
      `insert into audit_log (actor_id, action, target_type, target_id, meta) values (null,'leaderboard.close','board',$1,$2)`,
      [boardId, JSON.stringify({ period, results: top.length, rewards })],
      db,
    );
    return { boardId, period, alreadyClosed: false, results: top.length, rewards };
  });
}

// The month job: closes every finished month that has points and was not closed yet. Safe to call as often as you like.
export async function closeDuePeriods(now = new Date()): Promise<CloseSummary[]> {
  const current = periodOf(now);
  const due = await query<{ board_id: string; period: string }>(
    `select distinct e.board_id, e.period from score_events e
      where e.period < $1 and not e.is_demo and not exists (select 1 from period_closures c where c.board_id = e.board_id and c.period = e.period)
      order by e.period, e.board_id`,
    [current],
  );
  const overall = new Map<string, true>();
  for (const d of due) overall.set(d.period, true);
  const jobs = [...due];
  for (const period of overall.keys()) {
    const done = await one("select 1 as x from period_closures where board_id = 'overall' and period = $1", [period]);
    if (!done) jobs.push({ board_id: "overall", period });
  }
  const out: CloseSummary[] = [];
  for (const j of jobs) out.push(await closePeriod(j.board_id, j.period, now));
  return out;
}
