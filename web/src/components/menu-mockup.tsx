"use client";

import { useMemo, useState } from "react";
import type { Feature } from "@/lib/site-data";

// An illustration of a Lua menu, built from the feature list the admins wrote. It is NOT the real menu and says so.
export function MenuMockup({ features, name }: { features: Feature[]; name: string }) {
  const groups = useMemo(() => {
    const map = new Map<string, Feature[]>();
    for (const f of features) map.set(f.category, [...(map.get(f.category) ?? []), f]);
    return [...map.entries()];
  }, [features]);
  const [tab, setTab] = useState(0);
  const [on, setOn] = useState<Record<string, boolean>>({});
  const current = groups[tab];

  return (
    <figure className="card overflow-hidden">
      <div className="flex items-center justify-between border-b border-line px-4 py-2.5">
        <div className="flex gap-1.5" aria-hidden="true">
          <span className="size-2.5 rounded-full bg-white/10" />
          <span className="size-2.5 rounded-full bg-white/10" />
          <span className="size-2.5 rounded-full bg-white/10" />
        </div>
        <span className="wordmark text-[11px] font-semibold tracking-[0.3em]">SPECTER</span>
        <span className="text-[10px] uppercase tracking-wider text-amber-200/80">Mockup</span>
      </div>
      {groups.length === 0 ? (
        <div className="space-y-3 px-6 py-8" aria-hidden="true">
          {[60, 80, 45, 70].map((w, i) => (
            <div key={i} className="flex items-center justify-between">
              <div className="h-3 rounded bg-white/[0.06]" style={{ width: `${w}%` }} />
              <div className="h-5 w-9 rounded-full bg-white/[0.06]" />
            </div>
          ))}
          <p className="muted pt-3 text-center text-xs">The feature list has not been filled in yet.</p>
        </div>
      ) : (
        <div className="grid min-h-[280px] grid-cols-[120px_1fr] sm:grid-cols-[150px_1fr]">
          <div className="border-r border-line p-2" role="tablist" aria-label={`${name} menu tabs`}>
            {groups.map(([cat], i) => (
              <button key={cat} role="tab" aria-selected={i === tab} onClick={() => setTab(i)} className={`block w-full rounded-lg px-3 py-2 text-left text-xs transition ${i === tab ? "bg-violet-500/15 text-white" : "text-[color:var(--muted)] hover:text-white"}`}>
                {cat}
              </button>
            ))}
          </div>
          <div className="scroll-thin max-h-[340px] space-y-1 overflow-y-auto p-3" role="tabpanel">
            {current?.[1].map((f) => {
              const key = `${current[0]}:${f.title}`;
              const state = on[key] ?? false;
              return (
                <button key={key} onClick={() => setOn({ ...on, [key]: !state })} className="flex w-full items-center justify-between gap-3 rounded-lg px-3 py-2.5 text-left transition hover:bg-white/[0.04]" title={f.text}>
                  <span className="text-[13px]">{f.title}</span>
                  <span className={`relative h-5 w-9 shrink-0 rounded-full transition ${state ? "bg-violet-500" : "bg-white/10"}`} aria-hidden="true">
                    <span className={`absolute top-0.5 size-4 rounded-full bg-white transition-all ${state ? "left-[18px]" : "left-0.5"}`} />
                  </span>
                </button>
              );
            })}
          </div>
        </div>
      )}
      <figcaption className="border-t border-line px-4 py-2 text-[11px] text-[color:var(--faint)]">Illustration built from the feature list. The real menu lives inside the Lua.</figcaption>
    </figure>
  );
}
