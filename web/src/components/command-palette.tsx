"use client";

import { useRouter } from "next/navigation";
import { useEffect, useMemo, useRef, useState } from "react";

type Item = { label: string; href: string; hint?: string };

const ITEMS: Item[] = [
  { label: "Home", href: "/" },
  { label: "Features", href: "/features" },
  { label: "Previews", href: "/previews" },
  { label: "Pricing", href: "/pricing", hint: "Buy a license" },
  { label: "Cloud Configs", href: "/cloud", hint: "Browse configs" },
  { label: "Leaderboard", href: "/leaderboard" },
  { label: "Changelog", href: "/changelog" },
  { label: "FAQ", href: "/faq" },
  { label: "Discord / Support", href: "/support" },
  { label: "Status", href: "/status" },
  { label: "Dashboard", href: "/dashboard", hint: "Overview" },
  { label: "My Access", href: "/dashboard/access" },
  { label: "Downloads", href: "/dashboard/downloads" },
  { label: "My Configs", href: "/dashboard/configs" },
  { label: "Saved Configs", href: "/dashboard/saved" },
  { label: "Rewards", href: "/dashboard/rewards" },
  { label: "Orders", href: "/dashboard/orders", hint: "Invoice IDs" },
  { label: "Connected Devices", href: "/dashboard/devices" },
  { label: "Account Settings", href: "/dashboard/settings" },
  { label: "Link a device", href: "/link", hint: "Enter a code from the Lua" },
];

export function CommandPalette() {
  const [open, setOpen] = useState(false);
  const [q, setQ] = useState("");
  const [cursor, setCursor] = useState(0);
  const router = useRouter();
  const input = useRef<HTMLInputElement>(null);

  useEffect(() => {
    function onKey(e: KeyboardEvent) {
      if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === "k") {
        e.preventDefault();
        setOpen((o) => !o);
      } else if (e.key === "Escape") setOpen(false);
    }
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, []);

  useEffect(() => {
    if (open) {
      setQ("");
      setCursor(0);
      setTimeout(() => input.current?.focus(), 0);
    }
  }, [open]);

  const results = useMemo(() => {
    const s = q.trim().toLowerCase();
    return s ? ITEMS.filter((i) => i.label.toLowerCase().includes(s) || i.hint?.toLowerCase().includes(s)) : ITEMS;
  }, [q]);

  function go(item: Item | undefined) {
    if (!item) return;
    setOpen(false);
    router.push(item.href);
  }

  if (!open) return null;
  return (
    <div className="fixed inset-0 z-[90] flex items-start justify-center bg-black/60 px-4 pt-[14vh] backdrop-blur-sm" onClick={() => setOpen(false)} role="dialog" aria-modal="true" aria-label="Quick search">
      <div className="card w-full max-w-lg overflow-hidden shadow-glow" onClick={(e) => e.stopPropagation()}>
        <input
          ref={input}
          value={q}
          onChange={(e) => {
            setQ(e.target.value);
            setCursor(0);
          }}
          onKeyDown={(e) => {
            if (e.key === "ArrowDown") {
              e.preventDefault();
              setCursor((c) => Math.min(c + 1, results.length - 1));
            } else if (e.key === "ArrowUp") {
              e.preventDefault();
              setCursor((c) => Math.max(c - 1, 0));
            } else if (e.key === "Enter") go(results[cursor]);
          }}
          placeholder="Jump to a page..."
          className="w-full border-b border-line bg-transparent px-5 py-4 text-sm outline-none placeholder:text-[color:var(--faint)]"
        />
        <ul className="scroll-thin max-h-72 overflow-y-auto p-2" role="listbox">
          {results.length === 0 && <li className="muted px-3 py-6 text-center text-sm">Nothing found.</li>}
          {results.map((r, i) => (
            <li key={r.href} role="option" aria-selected={i === cursor}>
              <button onMouseEnter={() => setCursor(i)} onClick={() => go(r)} className={`flex w-full items-center justify-between rounded-lg px-3 py-2.5 text-left text-sm ${i === cursor ? "bg-violet-500/15 text-white" : "text-[color:var(--muted)]"}`}>
                <span>{r.label}</span>
                {r.hint && <span className="text-xs text-[color:var(--faint)]">{r.hint}</span>}
              </button>
            </li>
          ))}
        </ul>
      </div>
    </div>
  );
}
