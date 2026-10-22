import type { ReactNode } from "react";
import { SiteFooter, SiteHeader } from "@/components/header";
import { Avatar, Badge, Notice } from "@/components/ui";
import { DashNav, type NavItem } from "@/components/dashboard/nav";
import { NotificationBell } from "@/components/dashboard/bell";
import { isAdmin } from "@/lib/authz";
import { requireDashboardUser } from "@/lib/dashboard-data";
import { avatarUrl } from "@/lib/discord";

export const dynamic = "force-dynamic";

const ITEMS: NavItem[] = [
  { href: "/dashboard", label: "Overview", icon: "overview" },
  { href: "/dashboard/access", label: "My Access", icon: "access" },
  { href: "/dashboard/downloads", label: "Downloads", icon: "downloads" },
  { href: "/dashboard/configs", label: "My Configs", icon: "configs" },
  { href: "/dashboard/saved", label: "Saved Configs", icon: "saved" },
  { href: "/dashboard/leaderboard", label: "Leaderboard", icon: "leaderboard" },
  { href: "/dashboard/rewards", label: "Rewards", icon: "rewards" },
  { href: "/dashboard/devices", label: "Connected Devices", icon: "devices" },
  { href: "/dashboard/orders", label: "Orders", icon: "orders" },
  { href: "/dashboard/settings", label: "Account Settings", icon: "settings" },
];

export default async function DashboardLayout({ children }: { children: ReactNode }) {
  const user = await requireDashboardUser("/dashboard");
  const admin = isAdmin(user);
  const items = admin ? [...ITEMS, { href: "/admin", label: "Admin", icon: "admin" as const }] : ITEMS;
  const name = user.global_name || user.username;
  return (
    <>
      <SiteHeader />
      <div className="mx-auto max-w-6xl px-4 pt-6 sm:px-6 lg:grid lg:grid-cols-[232px_minmax(0,1fr)] lg:gap-10 lg:pt-12">
        <aside className="mb-8 lg:sticky lg:top-24 lg:mb-0 lg:self-start">
          <div className="mb-4 flex items-center gap-3 lg:mb-6">
            <Avatar src={avatarUrl(user.discord_id, user.avatar, 96)} name={name} size={40} />
            <div className="min-w-0 flex-1">
              <p className="truncate text-sm font-medium text-white">{name}</p>
              <p className="truncate text-xs text-[color:var(--faint)]">Signed in with Discord</p>
            </div>
            <NotificationBell />
          </div>
          <DashNav items={items} />
        </aside>
        <main id="main" className="min-w-0 pb-4 lg:pt-1">
          {user.suspended && (
            <div className="mb-6">
              <Notice tone="red">
                <span className="font-medium">Your account is suspended.</span> <Badge tone="red">Suspended</Badge> You can look around, but uploads, downloads and linking are refused. Ask the team on Discord if this is a mistake.
              </Notice>
            </div>
          )}
          {children}
        </main>
      </div>
      <SiteFooter />
    </>
  );
}
