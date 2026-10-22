"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useEffect, useState } from "react";

export function SignOutButton() {
  async function out() {
    await fetch("/api/auth/logout", { method: "POST" });
    window.location.href = "/";
  }
  return (
    <button onClick={out} className="block w-full rounded-lg px-3 py-2 text-left text-sm text-[color:var(--muted)] hover:bg-white/[0.05] hover:text-white">
      Sign out
    </button>
  );
}

export function MobileMenu({ links, signedIn, admin }: { links: { href: string; label: string }[]; signedIn: boolean; admin: boolean }) {
  const [open, setOpen] = useState(false);
  const path = usePathname();
  useEffect(() => setOpen(false), [path]);
  useEffect(() => {
    document.body.style.overflow = open ? "hidden" : "";
    return () => {
      document.body.style.overflow = "";
    };
  }, [open]);
  return (
    <div className="lg:hidden">
      <button onClick={() => setOpen(!open)} aria-expanded={open} aria-label="Menu" className="flex size-10 items-center justify-center rounded-xl border border-line bg-white/[0.03]">
        <svg width="18" height="18" viewBox="0 0 18 18" aria-hidden="true">
          {open ? <path d="M4 4l10 10M14 4 4 14" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" /> : <path d="M3 5h12M3 9h12M3 13h12" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" />}
        </svg>
      </button>
      {open && (
        <div className="fixed inset-x-0 top-16 z-50 max-h-[calc(100dvh-4rem)] overflow-y-auto border-b border-line bg-ink-950/95 px-4 pb-6 pt-2 backdrop-blur-xl">
          <nav className="flex flex-col" aria-label="Mobile">
            {links.map((l) => (
              <Link key={l.href} href={l.href} className="border-b border-line/60 py-3.5 text-[15px] text-[color:var(--text)]">
                {l.label}
              </Link>
            ))}
            {signedIn && <Link href="/dashboard" className="border-b border-line/60 py-3.5 text-[15px] text-violet-300">Dashboard</Link>}
            {admin && <Link href="/admin" className="py-3.5 text-[15px] text-violet-300">Admin</Link>}
          </nav>
        </div>
      )}
    </div>
  );
}
