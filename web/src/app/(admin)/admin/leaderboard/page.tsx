import { BoardPanel, CloseMonth } from "@/components/admin/board-panel";
import { td, th } from "@/components/admin/kit";
import { adminPageUser } from "@/components/admin/server";
import { Card, PageHeader, SectionTitle, formatDate } from "@/components/ui";
import { getProducts } from "@/config/site";
import { boardOverviews, closedPeriods, unclosedPeriods } from "@/lib/admin-boards";
import { avatarUrl } from "@/lib/discord";
import { periodOf, previousPeriod } from "@/lib/leaderboard";

export const dynamic = "force-dynamic";

export default async function LeaderboardAdmin() {
  if (!(await adminPageUser())) return null;
  const [boards, closed, unclosed] = await Promise.all([boardOverviews(), closedPeriods(), unclosedPeriods()]);
  const products = getProducts().map((p) => ({ id: p.id, name: p.name }));
  const boardName = (id: string) => boards.find((b) => b.board.id === id)?.board.name ?? id;
  return (
    <div className="space-y-10 pb-4">
      <PageHeader eyebrow="Admin" title="Leaderboard Management">Scoring rules, rewards and the monthly close for each board. Month borders are UTC.</PageHeader>
      <Card className="p-5 text-sm leading-relaxed">
        <p className="font-medium text-white">How the ranking works</p>
        <p className="muted mt-2">Tie-break rule: <strong className="text-[color:var(--text)]">more points first</strong>; with equal points, <strong className="text-[color:var(--text)]">whoever reached them first</strong> (the earlier last score) ranks higher; if that is equal too, <strong className="text-[color:var(--text)]">the older account</strong>. A month runs from the 1st 00:00 UTC to the 1st 00:00 UTC of the next month. Demo rows are shown but never rewarded.</p>
      </Card>
      <div className="space-y-8">
        {boards.map((o) => (
          <BoardPanel
            key={o.board.id}
            products={products}
            b={{
              id: o.board.id, name: o.board.name, kind: o.board.kind, scoring: o.board.scoring_enabled, rewards: o.board.rewards_enabled, rewardProduct: o.board.reward_product_id, rewardDays: o.board.reward_days,
              rules: Object.entries(o.board.rules?.events ?? {}).map(([key, v]) => ({ key, points: v.points, cap: v.dailyCap })),
              period: o.period, events: o.events,
              standings: o.standings.map((s) => ({ rank: s.rank, name: s.name, avatar: avatarUrl(s.discord_id, s.avatar, 64), points: s.points, demo: s.demo })),
            }}
          />
        ))}
      </div>
      <section>
        <SectionTitle eyebrow="Months" title="Closing" />
        <CloseMonth boards={boards.map((o) => ({ id: o.board.id, name: o.board.name }))} suggestions={unclosed} defaultPeriod={previousPeriod(periodOf(new Date()))} />
      </section>
      <section>
        <SectionTitle eyebrow="History" title="Closed periods" />
        {closed.length === 0 ? <p className="muted text-sm">No month has been closed yet.</p> : (
          <div className="card overflow-hidden"><div className="scroll-thin overflow-x-auto" role="region" aria-label="Closed periods" tabIndex={0}>
            <table className="w-full min-w-[480px]">
              <thead className="border-b border-line"><tr><th className={th}>Month</th><th className={th}>Board</th><th className={th}>Closed</th><th className={th}>Results</th><th className={th}>Rewards paid</th></tr></thead>
              <tbody className="divide-y divide-[color:var(--line)]">
                {closed.map((c) => <tr key={c.board_id + c.period}><td className={`${td} font-mono`}>{c.period}</td><td className={td}>{boardName(c.board_id)}</td><td className={td}>{formatDate(c.closed_at, true)}</td><td className={td}>{c.results}</td><td className={td}>{c.rewards}</td></tr>)}
              </tbody>
            </table>
          </div></div>
        )}
      </section>
    </div>
  );
}
