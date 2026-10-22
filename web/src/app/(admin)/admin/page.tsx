import Link from "next/link";
import { adminPageUser, metaText } from "@/components/admin/server";
import { Badge, Card, PageHeader, SectionTitle, Stat, formatDate } from "@/components/ui";
import { recentAudit } from "@/lib/admin";
import { adminOverview, boardOverviews } from "@/lib/admin-boards";
import { discordConfigured } from "@/lib/discord";

export const dynamic = "force-dynamic";

type AuditRow = { id: string; action: string; target_type: string; target_id: string; meta: unknown; created_at: Date; actor: string | null };

export default async function AdminOverview() {
  if (!(await adminPageUser())) return null;
  const [o, boards, audit] = await Promise.all([adminOverview(), boardOverviews(), recentAudit(8) as Promise<AuditRow[]>]);
  return (
    <div className="space-y-10 pb-4">
      <PageHeader eyebrow="Admin" title="Overview">The state of the platform at a glance. Everything here is read live from the database.</PageHeader>

      <section aria-label="Counters" className="grid grid-cols-2 gap-4 lg:grid-cols-4">
        <Link href="/admin/users" className="block rounded-2xl focus-visible:outline-offset-4"><Stat label="Users" value={o.users} hint={`${o.admins} admins · ${o.banned} banned`} /></Link>
        <Link href="/admin/moderation" className="block rounded-2xl"><Stat label="Active configs" value={o.configsActive} hint={`${o.configs} total · ${o.configsHidden} hidden`} /></Link>
        <Link href="/admin/moderation" className="block rounded-2xl"><Stat label="Open reports" value={<span className={o.reportsOpen ? "text-amber-300" : ""}>{o.reportsOpen}</span>} hint={o.reportsOpen ? "Need a decision" : "Nothing waiting"} /></Link>
        <Link href="/admin/users" className="block rounded-2xl"><Stat label="Live grants" value={o.activeGrants} hint={`${o.suspensions} product suspensions`} /></Link>
      </section>

      <section>
        <SectionTitle eyebrow="Leaderboard" title="Boards" />
        <div className="grid gap-4 md:grid-cols-3">
          {boards.map(({ board, standings, events, period }) => (
            <Card key={board.id} className="p-5">
              <div className="flex items-center justify-between gap-2">
                <h3 className="font-medium text-white">{board.name}</h3>
                <Badge tone={board.kind === "overall" ? "gray" : board.scoring_enabled ? "green" : "amber"}>
                  {board.kind === "overall" ? "Sum of both" : board.scoring_enabled ? "Collecting" : "Scoring off"}
                </Badge>
              </div>
              <p className="muted mt-3 text-sm">{period}: {events} score events, {standings.length ? `leader ${standings[0].name} (${standings[0].points})` : "no points yet"}</p>
              <p className="mt-1 text-xs text-[color:var(--faint)]">Rewards {board.rewards_enabled ? "on" : "off"}</p>
            </Card>
          ))}
        </div>
        <p className="mt-3 text-sm"><Link href="/admin/leaderboard" className="text-violet-300 hover:text-white">Manage boards</Link></p>
      </section>

      <section>
        <SectionTitle eyebrow="Integrations" title="Status" />
        <Card className="flex flex-wrap items-center gap-3 p-5">
          <Badge tone={discordConfigured() ? "green" : "amber"}>Discord {discordConfigured() ? "configured" : "not configured"}</Badge>
          <Badge tone={process.env.CRON_SECRET && process.env.CRON_SECRET.length >= 24 ? "green" : "amber"}>Cron secret {process.env.CRON_SECRET && process.env.CRON_SECRET.length >= 24 ? "set" : "missing"}</Badge>
          <Link href="/admin/roles" className="ml-auto text-sm text-violet-300 hover:text-white">Role mapping</Link>
        </Card>
      </section>

      <section>
        <SectionTitle eyebrow="Activity" title="Latest audit entries" action={<Link href="/admin/audit" className="text-sm text-violet-300 hover:text-white">Full log</Link>} />
        <Card className="divide-y divide-[color:var(--line)]">
          {audit.length === 0 && <p className="muted p-5 text-sm">No admin actions recorded yet.</p>}
          {audit.map((a) => (
            <div key={a.id} className="flex flex-col gap-1 px-5 py-3 sm:flex-row sm:items-baseline sm:gap-4">
              <time className="w-40 shrink-0 text-xs text-[color:var(--faint)]">{formatDate(a.created_at, true)}</time>
              <span className="font-mono text-sm text-violet-200">{a.action}</span>
              <span className="muted min-w-0 truncate text-sm">{a.actor ?? "system"}{metaText(a.meta) ? ` · ${metaText(a.meta)}` : ""}</span>
            </div>
          ))}
        </Card>
      </section>
    </div>
  );
}
