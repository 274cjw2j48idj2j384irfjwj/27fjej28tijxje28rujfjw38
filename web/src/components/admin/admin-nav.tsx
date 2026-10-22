"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { cx } from "@/components/ui";

export const ADMIN_LINKS = [
  { href: "/admin", label: "Overview" },
  { href: "/admin/users", label: "Users & Access" },
  { href: "/admin/roles", label: "Discord Roles" },
  { href: "/admin/products", label: "Products & Releases" },
  { href: "/admin/moderation", label: "Config Moderation" },
  { href: "/admin/leaderboard", label: "Leaderboard" },
  { href: "/admin/rewards", label: "Monthly Rewards" },
  { href: "/admin/audit", label: "Audit Log" },
];

export function AdminNav() {
  const path = usePathname();
  const active = (href: string) => (href === "/admin" ? path === "/admin" : path === href || path.startsWith(href + "/"));
  return (
    <nav aria-label="Admin" className="lg:sticky lg:top-24">
      <p className="eyebrow mb-3 hidden px-3 lg:block">Admin</p>
      <ul className="scroll-thin -mx-4 flex gap-2 overflow-x-auto px-4 pb-2 lg:mx-0 lg:flex-col lg:gap-1 lg:overflow-visible lg:px-0 lg:pb-0">
        {ADMIN_LINKS.map((l) => (
          <li key={l.href} className="shrink-0">
            <Link
              href={l.href}
              aria-current={active(l.href) ? "page" : undefined}
              className={cx(
                "block whitespace-nowrap rounded-xl border px-3.5 py-2 text-sm transition lg:border-transparent",
                active(l.href) ? "border-violet-400/40 bg-violet-500/15 text-white" : "border-line text-[color:var(--muted)] hover:bg-white/[0.04] hover:text-white",
              )}
            >
              {l.label}
            </Link>
          </li>
        ))}
      </ul>
    </nav>
  );
}
