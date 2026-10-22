import { api, json } from "@/lib/http";
import { archive, getBoard, isPeriod, nextPeriodStart, periodOf, standings } from "@/lib/leaderboard";
import { ApiError } from "@/lib/configs";
import { avatarUrl } from "@/lib/discord";

export const dynamic = "force-dynamic";

export const GET = api(async (req) => {
  const sp = new URL(req.url).searchParams;
  const boardId = sp.get("board") ?? "overall";
  const board = await getBoard(boardId);
  if (!board) throw new ApiError(404, "no_board", "Unknown board.");
  const now = new Date();
  const period = sp.get("period") ?? periodOf(now);
  if (!isPeriod(period)) throw new ApiError(400, "bad_period", "Period must look like 2026-10.");
  const rows = await standings(boardId, period, { limit: 100 });
  return json({
    board: { id: board.id, name: board.name, kind: board.kind, rewardDays: board.reward_days, rewardsEnabled: board.rewards_enabled, scoringEnabled: board.scoring_enabled },
    period,
    open: nextPeriodStart(period) > now,
    resetsAt: nextPeriodStart(periodOf(now)),
    rows: rows.map((r) => ({ rank: r.rank, name: r.name, avatar: avatarUrl(r.discord_id, r.avatar, 64), points: r.points, verified: r.verified, demo: r.demo })),
    archive: (await archive(boardId, 12)).map((a) => ({ period: a.period, rank: a.rank, name: a.name, points: a.points, demo: a.demo })),
  });
});
