"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useCallback, useEffect, useState } from "react";
import { Bell } from "lucide-react";
import { call } from "./api";

export const NOTIFICATIONS_EVENT = "specter:notifications";

export function NotificationBell({ initial = 0 }: { initial?: number }) {
  const [unread, setUnread] = useState(initial);
  const path = usePathname();
  const load = useCallback(async () => {
    const res = await call<{ unread: number }>("/api/notifications");
    if (res.ok && typeof res.data?.unread === "number") setUnread(res.data.unread);
  }, []);
  useEffect(() => {
    void load();
  }, [load, path]);
  useEffect(() => {
    window.addEventListener(NOTIFICATIONS_EVENT, load);
    return () => window.removeEventListener(NOTIFICATIONS_EVENT, load);
  }, [load]);
  return (
    <Link href="/dashboard/notifications" className="relative flex size-10 items-center justify-center rounded-xl border border-line bg-white/[0.03] text-[color:var(--muted)] transition hover:border-violet-400/40 hover:text-white" aria-label={unread ? `Notifications, ${unread} unread` : "Notifications"}>
      <Bell size={17} aria-hidden="true" />
      {unread > 0 && <span className="absolute -right-1 -top-1 flex min-w-[18px] items-center justify-center rounded-full bg-violet-500 px-1 text-[10px] font-semibold leading-[18px] text-white">{unread > 99 ? "99+" : unread}</span>}
    </Link>
  );
}
