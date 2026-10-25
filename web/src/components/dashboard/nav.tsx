"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useEffect, useRef } from "react";
import { Bookmark, Download, Dices, Gift, KeyRound, LayoutDashboard, MonitorSmartphone, Settings, ShieldCheck, ShoppingBag, SlidersHorizontal, Trophy } from "lucide-react";
import { cx } from "@/components/ui";

const ICONS = { overview: LayoutDashboard, access: KeyRound, downloads: Download, configs: SlidersHorizontal, saved: Bookmark, leaderboard: Trophy, rewards: Gift, roulette: Dices, devices: MonitorSmartphone, orders: ShoppingBag, settings: Settings, admin: ShieldCheck } as const;

export type NavItem = { href: string; label: string; icon: keyof typeof ICONS };

export function DashNav({ items }: { items: NavItem[] }) {
  const path = usePathname();
  const active = useRef<HTMLAnchorElement | null>(null);
  const current = items.reduce<string>((best, it) => ((path === it.href || path.startsWith(it.href + "/")) && it.href.length > best.length ? it.href : best), "");
  useEffect(() => {
    active.current?.scrollIntoView({ inline: "center", block: "nearest" });
  }, [current]);
  return (
    <nav aria-label="Dashboard" className="scroll-thin -mx-4 flex gap-1.5 overflow-x-auto px-4 pb-1 sm:-mx-6 sm:px-6 lg:mx-0 lg:flex-col lg:gap-1 lg:overflow-visible lg:px-0 lg:pb-0">
      {items.map((it) => {
        const Icon = ICONS[it.icon];
        const on = it.href === current;
        return (
          <Link
            key={it.href}
            href={it.href}
            ref={on ? active : undefined}
            aria-current={on ? "page" : undefined}
            className={cx(
              "flex shrink-0 items-center gap-2.5 whitespace-nowrap rounded-xl border px-3.5 py-2 text-sm transition lg:px-3",
              on ? "border-violet-400/35 bg-violet-500/[0.12] text-white" : "border-line bg-white/[0.02] text-[color:var(--muted)] hover:border-violet-400/30 hover:text-white lg:border-transparent lg:bg-transparent lg:hover:bg-white/[0.04]",
            )}
          >
            <Icon size={16} className={on ? "text-violet-300" : "text-[color:var(--faint)]"} aria-hidden="true" />
            {it.label}
          </Link>
        );
      })}
    </nav>
  );
}
