import type { Metadata } from "next";
import Link from "next/link";
import { BellOff } from "lucide-react";
import { Badge, Card, EmptyState, PageHeader, formatDate } from "@/components/ui";
import { MarkAllRead } from "@/components/dashboard/small-actions";
import { notificationsOf, requireDashboardUser } from "@/lib/dashboard-data";

export const dynamic = "force-dynamic";
export const metadata: Metadata = { title: "Notifications" };

export default async function NotificationsPage() {
  const user = await requireDashboardUser("/dashboard/notifications");
  const items = await notificationsOf(user.id);
  const unread = items.filter((n) => !n.read_at).length;
  return (
    <div className="space-y-8">
      <PageHeader eyebrow="Dashboard" title="Notifications" actions={<MarkAllRead unread={unread} />}>Your latest 50 messages.</PageHeader>
      {items.length === 0 ? (
        <EmptyState title="Nothing here yet" icon={<BellOff size={28} aria-hidden="true" />}>Reward payouts and account messages appear here.</EmptyState>
      ) : (
        <ul className="space-y-3">
          {items.map((n) => {
            const body = (
              <>
                <div className="flex flex-wrap items-center gap-2">
                  {!n.read_at && <span className="size-2 rounded-full bg-violet-400" aria-label="Unread" />}
                  <span className="font-medium text-white">{n.title}</span>
                  <Badge tone="gray">{n.kind}</Badge>
                  <span className="ml-auto text-xs text-[color:var(--faint)]">{formatDate(n.created_at, true)}</span>
                </div>
                {n.body && <p className="muted mt-1.5 text-sm leading-relaxed">{n.body}</p>}
              </>
            );
            const safe = n.link && n.link.startsWith("/") && !n.link.startsWith("//") ? n.link : null;
            return (
              <li key={n.id}>
                {safe ? <Link href={safe} className={`card card-hover block p-5 ${n.read_at ? "opacity-75" : ""}`}>{body}</Link> : <Card className={`p-5 ${n.read_at ? "opacity-75" : ""}`}>{body}</Card>}
              </li>
            );
          })}
        </ul>
      )}
    </div>
  );
}
