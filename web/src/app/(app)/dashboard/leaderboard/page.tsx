import type { Metadata } from "next";
import { Badge, ButtonLink, Card, Notice, PageHeader, formatDate } from "@/components/ui";
import { Countdown } from "@/components/dashboard/small-actions";
import { getProduct } from "@/config/site";
import { myBoards, requireDashboardUser } from "@/lib/dashboard-data";

export const dynamic = "force-dynamic";
export const metadata: Metadata = { title: "My Leaderboard Rank" };

export default async function LeaderboardPage() {
  const user = await requireDashboardUser("/dashboard/leaderboard");
  const { period, resetsAt, boards } = await myBoards(user.id);
  const anyScoring = boards.some((b) => b.board.scoring_enabled);
  return (
    <div className="space-y-8">
      <PageHeader eyebrow="Dashboard" title="My Leaderboard Rank" actions={<ButtonLink href="/leaderboard" variant="ghost" small>Public leaderboard</ButtonLink>}>
        Your place on each board for {period}. Months run on UTC and the board starts fresh every month.
      </PageHeader>

      <Card className="flex flex-wrap items-center justify-between gap-4 p-5">
        <div>
          <p className="text-xs uppercase tracking-wider text-[color:var(--muted)]">Month resets in</p>
          <p className="mt-1 text-2xl font-semibold text-white"><Countdown to={resetsAt.toISOString()} /></p>
        </div>
        <p className="muted text-sm">on {formatDate(resetsAt, true)}</p>
      </Card>

      {!anyScoring && <Notice tone="gray">Point collection is off right now: no board is counting points, so nobody has a rank. This is a setting of the team, not a problem with your account.</Notice>}

      <div className="grid gap-5 lg:grid-cols-3">
        {boards.map((b) => {
          const days = b.board.reward_days;
          const rewardLua = b.board.reward_product_id ? getProduct(b.board.reward_product_id)?.name : null;
          return (
            <Card key={b.board.id} className="flex flex-col p-6">
              <div className="flex items-center justify-between gap-3">
                <h2 className="text-lg font-semibold text-white">{b.board.name}</h2>
                {!b.board.scoring_enabled && <Badge tone="gray">Scoring off</Badge>}
              </div>
              <div className="mt-5">
                {b.me ? (
                  <>
                    <p className="text-4xl font-semibold tracking-tight text-white">#{b.me.rank}</p>
                    <p className="muted mt-1 text-sm">{b.me.points} points · {b.players} {b.players === 1 ? "player" : "players"} on the board</p>
                    <p className="mt-3 text-sm">
                      {b.ahead ? (b.gap === 0 ? `Level on points with ${b.ahead.name}, who reached them first.` : `${b.gap} ${b.gap === 1 ? "point" : "points"} behind ${b.ahead.name} (#${b.ahead.rank}).`) : <span className="text-emerald-300">You lead this board.</span>}
                    </p>
                  </>
                ) : (
                  <>
                    <p className="text-4xl font-semibold tracking-tight text-[color:var(--faint)]">-</p>
                    <p className="muted mt-1 text-sm">{b.board.scoring_enabled ? "You have no points on this board yet this month." : "Point collection is off for this board."}</p>
                  </>
                )}
              </div>
              <div className="mt-auto border-t border-line/60 pt-4 text-sm">
                {b.board.rewards_enabled ? (
                  <p className="muted">Rewards{rewardLua ? ` for ${rewardLua}` : ""}: {days.map((d, i) => `#${i + 1} ${d} days`).join(", ")}.</p>
                ) : (
                  <p className="muted">No rewards on this board right now.</p>
                )}
              </div>
            </Card>
          );
        })}
      </div>
    </div>
  );
}
