import type { Metadata } from "next";
import Link from "next/link";
import { Countdown } from "@/components/countdown";
import { Podium } from "@/components/podium";
import { VerifiedMark } from "@/components/config-card";
import { Avatar, Badge, Card, DemoTag, EmptyState, Notice, PageHeader, cx, formatDate } from "@/components/ui";
import { currentUser } from "@/lib/authz";
import { avatarUrl } from "@/lib/discord";
import { query } from "@/lib/db";
import { archive, getBoard, isPeriod, listBoards, nextPeriodStart, periodOf, standings } from "@/lib/leaderboard";

export const dynamic = "force-dynamic";
export const metadata: Metadata = { title: "Leaderboard" };

export default async function LeaderboardPage({ searchParams }: { searchParams: Promise<{ board?: string; period?: string }> }) {
  const sp = await searchParams;
  const now = new Date();
  const current = periodOf(now);
  const boards = await listBoards();
  const board = (await getBoard(sp.board ?? "overall")) ?? boards[0];
  const period = sp.period && isPeriod(sp.period) ? sp.period : current;
  const user = await currentUser();
  const [rows, past, periods] = await Promise.all([
    standings(board.id, period, { limit: 100 }),
    archive(board.id, 6),
    query<{ period: string }>("select distinct period from score_events union select distinct period from monthly_results where board_id = $1 order by period desc limit 12", [board.id]),
  ]);
  const options = [...new Set([current, ...periods.map((p) => p.period)])].sort().reverse();
  const open = nextPeriodStart(period) > now;
  const mine = user ? rows.find((r) => r.user_id === user.id) : null;
  const tab = (id: string) => `/leaderboard?board=${id}${sp.period ? `&period=${sp.period}` : ""}`;
  const byPeriod = new Map<string, typeof past>();
  for (const a of past) byPeriod.set(a.period, [...(byPeriod.get(a.period) ?? []), a]);

  return (
    <div>
      <PageHeader eyebrow="Leaderboard" title="Monthly ranking">
        A new race every UTC month. {board.rewards_enabled ? `Top three win ${board.reward_days.join(" / ")} days of subscription.` : "Rewards are not switched on for this board."}
      </PageHeader>

      <div className="mb-8 flex flex-wrap items-center justify-between gap-4">
        <div className="flex flex-wrap gap-2" role="tablist" aria-label="Board">
          {boards.map((b) => <Link key={b.id} href={tab(b.id)} role="tab" aria-selected={b.id === board.id} className={cx("rounded-full border px-4 py-1.5 text-sm", b.id === board.id ? "border-violet-400/50 bg-violet-500/15 text-white" : "border-line text-[color:var(--muted)] hover:text-white")}>{b.name}</Link>)}
        </div>
        <form method="get" className="flex items-center gap-2">
          <input type="hidden" name="board" value={board.id} />
          <label htmlFor="period" className="sr-only">Month</label>
          <select id="period" name="period" defaultValue={period} className="input w-auto">{options.map((o) => <option key={o} value={o}>{o}{o === current ? " (running)" : ""}</option>)}</select>
          <button className="btn-ghost btn-sm">Show</button>
        </form>
      </div>

      {!board.scoring_enabled && board.kind === "product" && <div className="mb-6"><Notice tone="gray">Point collection is switched off for this board. Nothing is counted until the team approves the scoring rules.</Notice></div>}

      <Card className="mb-8 flex flex-wrap items-center justify-between gap-4 px-6 py-4 text-sm">
        <span className="muted">{open ? "Month ends in" : `Month ${period} is closed`}</span>
        <span className="text-white">{open ? <Countdown to={nextPeriodStart(period).toISOString()} /> : formatDate(nextPeriodStart(period))}</span>
        <span className="muted text-xs">All times UTC</span>
      </Card>

      {rows.length === 0 ? (
        <EmptyState title="No ranking for this month">No points were recorded for this board in {period}.</EmptyState>
      ) : (
        <>
          <Podium rows={rows.slice(0, 3)} rewardDays={board.reward_days} rewardsOn={board.rewards_enabled} />
          <Card className="mt-8 overflow-hidden">
            <table className="w-full text-sm">
              <thead><tr className="border-b border-line text-left text-xs uppercase tracking-wider text-[color:var(--muted)]"><th className="w-16 px-5 py-3">Rank</th><th className="px-3 py-3">Player</th><th className="px-5 py-3 text-right">Points</th></tr></thead>
              <tbody>
                {rows.map((r) => (
                  <tr key={r.user_id} className={cx("border-b border-line/60 last:border-0", user?.id === r.user_id && "bg-violet-500/10")}>
                    <td className="px-5 py-3 tabular-nums text-[color:var(--muted)]">{r.rank}</td>
                    <td className="px-3 py-3">
                      <Link href={`/u/${r.discord_id}`} className="flex items-center gap-3 hover:text-violet-200">
                        <Avatar src={avatarUrl(r.discord_id, r.avatar, 48)} name={r.name} size={28} />
                        <span className="truncate">{r.name}</span>{r.verified && <VerifiedMark />}
                        {user?.id === r.user_id && <Badge tone="violet">You</Badge>}
                        {r.demo && <DemoTag />}
                        {board.rewards_enabled && r.rank <= board.reward_days.length && <Badge tone="violet">+{board.reward_days[r.rank - 1]}d</Badge>}
                      </Link>
                    </td>
                    <td className="px-5 py-3 text-right font-medium tabular-nums text-white">{r.points.toLocaleString("en-US")}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </Card>
          {user && !mine && <p className="muted mt-4 text-sm">You are not on this board for {period} yet.</p>}
        </>
      )}

      <section className="mt-16">
        <h2 className="mb-6 text-2xl font-semibold tracking-tight text-white">Previous winners</h2>
        {byPeriod.size === 0 ? <EmptyState title="No closed months yet">Winners are archived here when a month ends.</EmptyState> : (
          <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
            {[...byPeriod.entries()].map(([per, list]) => (
              <Card key={per} className="p-5">
                <p className="eyebrow mb-3">{per}</p>
                <ol className="space-y-2 text-sm">
                  {list.map((w) => (
                    <li key={w.rank} className="flex items-center justify-between gap-3">
                      <span className="flex items-center gap-2"><span className="w-5 text-[color:var(--faint)]">{w.rank}.</span><Link href={`/u/${w.discord_id}`} className="hover:text-violet-200">{w.name}</Link>{w.demo && <DemoTag />}</span>
                      <span className="tabular-nums text-[color:var(--muted)]">{w.points}</span>
                    </li>
                  ))}
                </ol>
              </Card>
            ))}
          </div>
        )}
      </section>
    </div>
  );
}
