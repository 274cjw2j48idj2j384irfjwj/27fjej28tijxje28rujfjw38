import type { Metadata } from "next";
import { Gift, Trophy } from "lucide-react";
import { Badge, Card, EmptyState, PageHeader, SectionTitle, formatDate } from "@/components/ui";
import { getProduct } from "@/config/site";
import { requireDashboardUser, rewardsOf } from "@/lib/dashboard-data";

export const dynamic = "force-dynamic";
export const metadata: Metadata = { title: "Rewards" };

export default async function RewardsPage() {
  const user = await requireDashboardUser("/dashboard/rewards");
  const { rewards, results } = await rewardsOf(user.id);
  return (
    <div className="space-y-12">
      <PageHeader eyebrow="Dashboard" title="Rewards">Subscription days won on the monthly leaderboard, and your past results.</PageHeader>

      <section>
        <SectionTitle eyebrow="Won" title="Monthly rewards">Days are added to the end of your running access, or start now if it had ended.</SectionTitle>
        {rewards.length === 0 ? (
          <EmptyState title="No rewards yet" icon={<Gift size={28} aria-hidden="true" />}>Finish in the top places of a month to win days. Rewards are paid once, when the month is closed.</EmptyState>
        ) : (
          <div className="card overflow-hidden">
            <div className="scroll-thin overflow-x-auto">
              <table className="w-full min-w-[640px] text-left text-sm">
                <thead>
                  <tr className="border-b border-line text-xs uppercase tracking-wider text-[color:var(--muted)]">
                    <th scope="col" className="px-5 py-3 font-medium">Month</th>
                    <th scope="col" className="px-5 py-3 font-medium">Board</th>
                    <th scope="col" className="px-5 py-3 font-medium">Place</th>
                    <th scope="col" className="px-5 py-3 font-medium">Reward</th>
                    <th scope="col" className="px-5 py-3 font-medium">New expiry</th>
                  </tr>
                </thead>
                <tbody>
                  {rewards.map((r) => (
                    <tr key={`${r.board_id}-${r.period}-${r.rank}`} className="border-b border-line/60 last:border-0">
                      <td className="px-5 py-3 whitespace-nowrap text-white">{r.period}</td>
                      <td className="px-5 py-3">{r.board_name}</td>
                      <td className="px-5 py-3">#{r.rank}</td>
                      <td className="px-5 py-3 whitespace-nowrap">{r.days} days of {getProduct(r.product_id)?.name ?? r.product_id}</td>
                      <td className="px-5 py-3 whitespace-nowrap">
                        {r.note === "permanent_access" ? <span className="muted">Access never expires</span> : r.new_expires_at ? formatDate(r.new_expires_at) : "-"}
                        {r.note === "started" && <span className="muted"> (started)</span>}
                        {r.note === "extended" && <span className="muted"> (extended)</span>}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        )}
      </section>

      <section>
        <SectionTitle eyebrow="History" title="Monthly results" />
        {results.length === 0 ? (
          <EmptyState title="No finished months yet" icon={<Trophy size={28} aria-hidden="true" />}>Your final place shows up here after a month closes.</EmptyState>
        ) : (
          <ul className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {results.map((r) => (
              <li key={`${r.board_id}-${r.period}`}>
                <Card className="p-5">
                  <div className="flex items-center justify-between gap-2">
                    <span className="text-xs uppercase tracking-wider text-[color:var(--muted)]">{r.period} · {r.board_name}</span>
                    {r.is_demo && <Badge tone="amber" className="uppercase">Demo</Badge>}
                  </div>
                  <p className="mt-2 text-3xl font-semibold tracking-tight text-white">#{r.rank}</p>
                  <p className="muted text-sm">{r.points} points</p>
                  <div className="mt-3"><Badge tone="violet"><Trophy size={11} aria-hidden="true" />Leaderboard winner</Badge></div>
                </Card>
              </li>
            ))}
          </ul>
        )}
      </section>
    </div>
  );
}
