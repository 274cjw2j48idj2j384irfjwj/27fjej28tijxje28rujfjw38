import type { Metadata } from "next";
import Link from "next/link";
import { Avatar, Badge, Card, PageHeader, SectionTitle, formatDate } from "@/components/ui";
import { SignOutButtons } from "@/components/dashboard/small-actions";
import { CopyButton } from "@/components/dashboard/copy-button";
import { isAdmin } from "@/lib/authz";
import { Row } from "@/components/dashboard/parts";
import { accountDates, requireDashboardUser } from "@/lib/dashboard-data";
import { avatarUrl } from "@/lib/discord";

export const dynamic = "force-dynamic";
export const metadata: Metadata = { title: "Account Settings" };

export default async function SettingsPage() {
  const user = await requireDashboardUser("/dashboard/settings");
  const dates = await accountDates(user.id);
  const name = user.global_name || user.username;
  return (
    <div className="space-y-12">
      <PageHeader eyebrow="Dashboard" title="Account Settings">Your account is your Discord account. There is no separate password.</PageHeader>

      <section>
        <SectionTitle eyebrow="Identity" title="Discord account">Read only. Change your name or avatar in Discord; it updates here the next time you sign in.</SectionTitle>
        <Card className="p-6">
          <div className="flex flex-wrap items-center gap-4">
            <Avatar src={avatarUrl(user.discord_id, user.avatar, 128)} name={name} size={56} />
            <div className="min-w-0 flex-1">
              <p className="truncate text-lg font-semibold text-white">{name}</p>
              <p className="truncate text-sm text-[color:var(--muted)]">@{user.username}</p>
            </div>
            <div className="flex flex-wrap gap-2">
              {isAdmin(user) && <Badge tone="violet">Admin</Badge>}
              {user.verified_creator && <Badge tone="violet">Verified creator</Badge>}
              {user.suspended && <Badge tone="red">Suspended</Badge>}
            </div>
          </div>
          <dl className="mt-5">
            <Row label="Discord ID">
              <span className="inline-flex flex-wrap items-center justify-end gap-2"><code className="font-mono text-xs">{user.discord_id}</code><CopyButton text={user.discord_id} /></span>
            </Row>
            <Row label="Member since">{dates ? formatDate(dates.created_at) : "-"}</Row>
            <Row label="Last sign in">{dates ? formatDate(dates.last_login_at, true) : "-"}</Row>
          </dl>
        </Card>
      </section>

      <section>
        <SectionTitle eyebrow="Security" title="Sessions">Sign out here, or end every session on every browser if you used a shared computer.</SectionTitle>
        <Card className="p-6"><SignOutButtons /></Card>
      </section>

      <section>
        <SectionTitle eyebrow="Inbox" title="Notifications" />
        <Card className="flex flex-wrap items-center justify-between gap-3 p-6">
          <p className="muted text-sm">Reward and account messages are collected on one page.</p>
          <Link href="/dashboard/notifications" className="btn-ghost btn-sm">Open notifications</Link>
        </Card>
      </section>

      <section>
        <SectionTitle eyebrow="Privacy" title="Your data" />
        <Card className="p-6 text-sm leading-relaxed">
          <p>We store your Discord ID, name and avatar, the configs and likes you make, your library, the Luas you linked and your leaderboard points. We do not store a password, and sign-in asks Discord only for your identity.</p>
          <p className="muted mt-3">Deleting an account is not self service yet. To have your data removed, ask the team in the <Link href="/support" className="text-violet-300 underline-offset-2 hover:underline">support channel</Link>.</p>
        </Card>
      </section>
    </div>
  );
}
