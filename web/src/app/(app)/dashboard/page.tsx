import type { Metadata } from "next";
import Link from "next/link";
import { Avatar, Badge, ButtonLink, Card, Notice, PageHeader, SectionTitle, Stat } from "@/components/ui";
import { expiryLine, viaLabel } from "@/components/dashboard/access";
import { Row, StatusPill, rankText } from "@/components/dashboard/parts";
import { isAdmin } from "@/lib/authz";
import { accessAll, countsOf, myBoards, requireDashboardUser } from "@/lib/dashboard-data";
import { avatarUrl } from "@/lib/discord";
import { formatDate } from "@/components/ui";

export const dynamic = "force-dynamic";
export const metadata: Metadata = { title: "Dashboard" };

export default async function Overview() {
  const user = await requireDashboardUser("/dashboard");
  const [access, ranks, counts] = await Promise.all([accessAll(user.id), myBoards(user.id), countsOf(user.id)]);
  const name = user.global_name || user.username;
  const soon = access.filter((a) => a.access.status === "expiring_soon");
  const unchecked = access.filter((a) => a.access.integrationError);
  const overall = ranks.boards.find((b) => b.board.id === "overall");

  return (
    <div className="space-y-10">
      <PageHeader eyebrow="Dashboard" title={`Welcome back, ${name}`}>Your access, configs and rank at a glance.</PageHeader>

      {(unchecked.length > 0 || soon.length > 0) && (
        <div className="space-y-3">
          {unchecked.length > 0 && (
            <Notice tone="amber">
              <span className="font-medium">Could not check your Discord roles right now.</span> The status of {unchecked.map((a) => a.product.name).join(" and ")} may be incomplete: only grants from the team are counted until Discord answers. This is not the same as having no access. Reload in a minute.
            </Notice>
          )}
          {soon.map((a) => (
            <Notice key={a.product.id} tone="amber">
              <span className="font-medium">{a.product.name} expires {formatDate(a.access.expiresAt)}.</span> It works until then; ask for a new grant or role on Discord to keep it.
            </Notice>
          ))}
        </div>
      )}

      <section aria-labelledby="luas-h">
        <SectionTitle eyebrow="Access" title="Your Luas" action={<ButtonLink href="/dashboard/access" variant="ghost" small>Details</ButtonLink>} />
        <h2 id="luas-h" className="sr-only">Your Luas</h2>
        <div className="grid gap-5 md:grid-cols-2">
          {access.map(({ product, access: a }) => {
            const board = ranks.boards.find((b) => b.board.id === product.id);
            return (
              <Card key={product.id} className="flex flex-col p-6">
                <div className="flex flex-wrap items-start justify-between gap-3">
                  <div>
                    <h3 className="text-lg font-semibold text-white">{product.name}</h3>
                    <p className="muted mt-0.5 text-xs">{product.platform}</p>
                  </div>
                  <StatusPill access={a} />
                </div>
                <dl className="mt-4">
                  <Row label="Expires">{expiryLine(a)}</Row>
                  <Row label="Via">{viaLabel(a.via)}</Row>
                  <Row label="Rank this month">{board ? rankText(board) : "-"}</Row>
                </dl>
                <div className="mt-5 flex flex-wrap gap-2">
                  <ButtonLink href="/dashboard/downloads" small>Downloads</ButtonLink>
                  <ButtonLink href={`/luas/${product.slug}`} variant="ghost" small>About this Lua</ButtonLink>
                </div>
              </Card>
            );
          })}
        </div>
      </section>

      <section>
        <SectionTitle eyebrow="Account" title="At a glance" />
        <div className="grid grid-cols-2 gap-4 lg:grid-cols-4">
          <Link href="/dashboard/configs" className="rounded-2xl focus-visible:outline-offset-4"><Stat label="My configs" value={counts.configs} hint="Uploaded by you" /></Link>
          <Link href="/dashboard/saved" className="rounded-2xl"><Stat label="Saved configs" value={counts.saved} hint="In your library" /></Link>
          <Link href="/dashboard/devices" className="rounded-2xl"><Stat label="Devices" value={counts.devices} hint="Linked Luas" /></Link>
          <Link href="/dashboard/notifications" className="rounded-2xl"><Stat label="Unread" value={counts.unread} hint="Notifications" /></Link>
        </div>
      </section>

      <section>
        <SectionTitle eyebrow="This month" title="Leaderboard" action={<ButtonLink href="/dashboard/leaderboard" variant="ghost" small>Details</ButtonLink>} />
        <div className="grid gap-4 sm:grid-cols-3">
          {ranks.boards.map((b) => (
            <Card key={b.board.id} className="px-5 py-4">
              <p className="text-xs uppercase tracking-wider text-[color:var(--muted)]">{b.board.name}</p>
              <p className="mt-1.5 text-xl font-semibold text-white">{b.me ? `#${b.me.rank}` : "-"}</p>
              <p className="mt-1 text-xs text-[color:var(--faint)]">{b.me ? `${b.me.points} points` : b.board.scoring_enabled ? "No points yet" : "Point collection is off"}</p>
            </Card>
          ))}
        </div>
        {overall && !overall.me && !overall.board.scoring_enabled && <p className="muted mt-3 text-sm">Scoring is switched off, so nobody collects points right now.</p>}
      </section>

      <Card className="flex flex-wrap items-center gap-4 p-5">
        <Avatar src={avatarUrl(user.discord_id, user.avatar, 96)} name={name} size={44} />
        <div className="min-w-0 flex-1">
          <p className="truncate font-medium text-white">{name}</p>
          <p className="truncate text-xs text-[color:var(--faint)]">@{user.username}</p>
        </div>
        <div className="flex flex-wrap gap-2">
          {isAdmin(user) && <Badge tone="violet">Admin</Badge>}
          {user.verified_creator && <Badge tone="violet">Verified creator</Badge>}
        </div>
        <ButtonLink href="/dashboard/settings" variant="ghost" small>Account settings</ButtonLink>
      </Card>
    </div>
  );
}
