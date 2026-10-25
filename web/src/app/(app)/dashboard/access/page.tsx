import type { Metadata } from "next";
import { Badge, Card, EmptyState, Notice, PageHeader, SectionTitle, formatDate } from "@/components/ui";
import { reasonFor, viaLabel, expiryLine } from "@/components/dashboard/access";
import { Row, StatusPill } from "@/components/dashboard/parts";
import { getProduct } from "@/config/site";
import { accessAll, grantsOf, lastDiscordCheck, requireDashboardUser } from "@/lib/dashboard-data";

export const dynamic = "force-dynamic";
export const metadata: Metadata = { title: "My Access" };

export default async function AccessPage() {
  const user = await requireDashboardUser("/dashboard/access");
  const [access, grants, check] = await Promise.all([accessAll(user.id), grantsOf(user.id), lastDiscordCheck(user.id)]);
  const now = Date.now();
  return (
    <div className="space-y-10">
      <PageHeader eyebrow="Dashboard" title="My Access">Each Lua has its own access. A role or grant for one never unlocks the other.</PageHeader>

      <div className="grid gap-5 md:grid-cols-2">
        {access.map(({ product, access: a }) => {
          const r = reasonFor(a, product.name);
          return (
            <Card key={product.id} className="p-6">
              <div className="flex flex-wrap items-start justify-between gap-3">
                <div>
                  <h2 className="text-lg font-semibold text-white">{product.name}</h2>
                  <p className="muted mt-0.5 text-xs">{product.platform}</p>
                </div>
                <StatusPill access={a} />
              </div>
              <dl className="mt-4">
                <Row label="Status">{r.title}</Row>
                <Row label="Expires">{expiryLine(a)}</Row>
                <Row label="Via">{viaLabel(a.via)}</Row>
              </dl>
              <div className="mt-4"><Notice tone={r.tone === "green" ? "green" : r.tone === "amber" ? "amber" : r.tone === "red" ? "red" : "gray"}>{r.text}</Notice></div>
            </Card>
          );
        })}
      </div>

      <section>
        <SectionTitle eyebrow="Discord" title="Role check">Roles on the Specter Discord server decide most access. They are re-read every few minutes.</SectionTitle>
        <Card className="p-6">
          {check ? (
            <p className="text-sm leading-relaxed">
              {check.in_guild ? "You are a member of the Specter Discord server." : "You are not a member of the Specter Discord server, so no role counts."}{" "}
              <span className="muted">Last checked {formatDate(check.fetched_at, true)}.</span>
            </p>
          ) : (
            <p className="muted text-sm">Your roles have not been read yet. They are checked the first time something needs them. The check is off when Discord is not connected to this site.</p>
          )}
        </Card>
      </section>

      <section>
        <SectionTitle eyebrow="History" title="Grants from the team and rewards" />
        {grants.length === 0 ? (
          <EmptyState title="No grants">Time limited access from the team or from leaderboard rewards shows up here.</EmptyState>
        ) : (
          <div className="card overflow-hidden">
            <div className="scroll-thin overflow-x-auto">
              <table className="w-full min-w-[560px] text-left text-sm">
                <thead>
                  <tr className="border-b border-line text-xs uppercase tracking-wider text-[color:var(--muted)]">
                    <th scope="col" className="px-5 py-3 font-medium">Lua</th>
                    <th scope="col" className="px-5 py-3 font-medium">Source</th>
                    <th scope="col" className="px-5 py-3 font-medium">Starts</th>
                    <th scope="col" className="px-5 py-3 font-medium">Ends</th>
                    <th scope="col" className="px-5 py-3 font-medium">State</th>
                  </tr>
                </thead>
                <tbody>
                  {grants.map((g) => {
                    const state = g.revoked_at ? { t: "Revoked", tone: "red" as const } : g.starts_at.getTime() > now ? { t: "Scheduled", tone: "gray" as const } : g.expires_at && g.expires_at.getTime() <= now ? { t: "Ended", tone: "gray" as const } : { t: "Running", tone: "green" as const };
                    return (
                      <tr key={g.id} className="border-b border-line/60 last:border-0">
                        <td className="px-5 py-3 text-white">{getProduct(g.product_id)?.name ?? g.product_id}</td>
                        <td className="px-5 py-3">{g.source === "admin" ? "Admin grant" : "Leaderboard reward"}</td>
                        <td className="px-5 py-3 whitespace-nowrap">{formatDate(g.starts_at)}</td>
                        <td className="px-5 py-3 whitespace-nowrap">{g.expires_at ? formatDate(g.expires_at) : "No expiry"}</td>
                        <td className="px-5 py-3"><Badge tone={state.tone}>{state.t}</Badge></td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          </div>
        )}
      </section>
    </div>
  );
}
