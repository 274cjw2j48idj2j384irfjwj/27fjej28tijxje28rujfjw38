import { td, th } from "@/components/admin/kit";
import { adminPageUser } from "@/components/admin/server";
import { Badge, Card, EmptyState, Notice, PageHeader, SectionTitle, formatDate } from "@/components/ui";
import { getProduct, site } from "@/config/site";
import { recentRewards } from "@/lib/admin";
import { monthlyResults, rewardPreview } from "@/lib/admin-boards";

export const dynamic = "force-dynamic";

type Reward = { id: string; board_id: string; period: string; rank: number; product_id: string; days: number; note: string; previous_expires_at: Date | null; new_expires_at: Date | null; created_at: Date; winner: string };

const NOTE: Record<string, string> = { extended: "Extended", started: "Started", permanent_access: "Skipped: permanent access" };

export default async function RewardsPage() {
  if (!(await adminPageUser())) return null;
  const [rewards, results, preview] = await Promise.all([recentRewards(100) as Promise<Reward[]>, monthlyResults(6), rewardPreview()]);
  const pname = (id: string) => getProduct(id)?.platform ?? id;
  const byMonth = new Map<string, typeof results>();
  for (const r of results) byMonth.set(r.period, [...(byMonth.get(r.period) ?? []), r]);
  const cronUrl = `${site.url}/api/cron/close-month`;
  const hasSecret = (process.env.CRON_SECRET ?? "").length >= 24;
  return (
    <div className="space-y-12 pb-4">
      <PageHeader eyebrow="Admin" title="Monthly Rewards">What was paid, how past months ended and what the running month would pay.</PageHeader>

      <section>
        <SectionTitle eyebrow="Preview" title="If the running month closed now">
          A preview only: nothing is paid until the month ends and is closed. Standings can still change until then.
        </SectionTitle>
        <div className="grid gap-4 lg:grid-cols-3">
          {preview.map((p) => (
            <Card key={p.board.id} className="p-5">
              <div className="flex items-center justify-between gap-2"><h3 className="font-medium text-white">{p.board.name}</h3><Badge tone="amber" className="uppercase">Preview</Badge></div>
              <p className="muted mt-1 text-xs">{p.period} · closes {formatDate(p.closesAt)} 00:00 UTC</p>
              <p className="mt-3 text-sm">{p.enabled ? <>Rewards on: access to <strong className="text-white">{pname(p.product!)}</strong></> : <span className="text-amber-300">Rewards are off or have no product: nothing would be paid.</span>}</p>
              {p.rows.length === 0 ? <p className="muted mt-3 text-sm">No points yet, so nobody would win.</p> : (
                <ol className="mt-3 space-y-1.5 text-sm">
                  {p.rows.map((r) => (
                    <li key={r.rank} className="flex items-center justify-between gap-2"><span className="min-w-0 truncate"><span className="mr-2 font-mono text-[color:var(--faint)]">#{r.rank}</span>{r.name}{r.demo && " (demo)"}</span><span className="shrink-0 text-[color:var(--muted)]">{r.points} pts{p.enabled && !r.demo ? ` · +${r.days} d` : ""}</span></li>
                  ))}
                </ol>
              )}
            </Card>
          ))}
        </div>
      </section>

      <section>
        <SectionTitle eyebrow="Results" title="Closed months" />
        {byMonth.size === 0 ? <EmptyState title="No month closed yet">Results appear here after the first month is closed.</EmptyState> : (
          <div className="grid gap-4 md:grid-cols-2">
            {[...byMonth.entries()].map(([period, rows]) => (
              <Card key={period} className="p-5">
                <h3 className="font-mono font-medium text-white">{period}</h3>
                <div className="mt-3 space-y-3">
                  {[...new Set(rows.map((r) => r.board_id))].map((bid) => (
                    <div key={bid}>
                      <p className="eyebrow mb-1">{preview.find((p) => p.board.id === bid)?.board.name ?? bid}</p>
                      <ol className="space-y-1 text-sm">{rows.filter((r) => r.board_id === bid).map((r) => <li key={r.rank} className="flex justify-between gap-2"><span className="truncate"><span className="mr-2 font-mono text-[color:var(--faint)]">#{r.rank}</span>{r.name}{r.is_demo && " (demo)"}</span><span className="text-[color:var(--muted)]">{r.points} pts</span></li>)}</ol>
                    </div>
                  ))}
                </div>
              </Card>
            ))}
          </div>
        )}
      </section>

      <section>
        <SectionTitle eyebrow="Log" title="Reward log">Every payout, once per board, month and rank.</SectionTitle>
        {rewards.length === 0 ? <EmptyState title="No rewards paid yet" /> : (
          <div className="card overflow-hidden"><div className="scroll-thin overflow-x-auto" role="region" aria-label="Reward log" tabIndex={0}>
            <table className="w-full min-w-[820px]">
              <thead className="border-b border-line"><tr><th className={th}>Month</th><th className={th}>Board</th><th className={th}>Rank</th><th className={th}>Winner</th><th className={th}>Reward</th><th className={th}>Access before</th><th className={th}>Access after</th><th className={th}>Outcome</th></tr></thead>
              <tbody className="divide-y divide-[color:var(--line)]">
                {rewards.map((r) => (
                  <tr key={r.id}>
                    <td className={`${td} font-mono`}>{r.period}</td><td className={`${td} capitalize`}>{r.board_id}</td><td className={td}>#{r.rank}</td><td className={td}>{r.winner}</td>
                    <td className={`${td} whitespace-nowrap`}>{r.days} d {pname(r.product_id)}</td>
                    <td className={`${td} whitespace-nowrap text-[color:var(--muted)]`}>{r.previous_expires_at ? formatDate(r.previous_expires_at) : "-"}</td>
                    <td className={`${td} whitespace-nowrap text-[color:var(--muted)]`}>{r.new_expires_at ? formatDate(r.new_expires_at) : "-"}</td>
                    <td className={td}><Badge tone={r.note === "permanent_access" ? "amber" : "green"}>{NOTE[r.note] ?? r.note}</Badge></td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div></div>
        )}
      </section>

      <section>
        <SectionTitle eyebrow="Automation" title="Month close job">Run this once an hour (or once a day) from any scheduler: Railway cron, GitHub Actions, cron-job.org. It closes every finished month that was not closed and pays its rewards.</SectionTitle>
        <Card className="space-y-4 p-5">
          {!hasSecret && <Notice tone="amber">CRON_SECRET is not set (or shorter than 24 characters), so the endpoint refuses every call. Set it in the server environment first.</Notice>}
          <pre className="scroll-thin overflow-x-auto rounded-xl border border-line bg-ink-900 p-4 font-mono text-[13px] leading-relaxed text-lav-100"><code>{`curl -X POST ${cronUrl} \\\n  -H "Authorization: Bearer $CRON_SECRET"`}</code></pre>
          <ul className="muted list-disc space-y-1.5 pl-5 text-sm">
            <li><span className="font-mono text-[color:var(--text)]">POST</span> with the header <span className="font-mono text-[color:var(--text)]">Authorization: Bearer CRON_SECRET</span>, where the value is the CRON_SECRET of the server. The secret is never shown here.</li>
            <li>Safe to call repeatedly: a closed month is never paid twice, the second call returns an empty list.</li>
            <li>Answer: <span className="font-mono text-[color:var(--text)]">{`{"closed":[{boardId,period,results,rewards}]}`}</span>. A wrong secret answers 401.</li>
            <li>It also clears expired sessions and old rate limit rows.</li>
            <li>You can close one month by hand on the Leaderboard page.</li>
          </ul>
        </Card>
      </section>
    </div>
  );
}
