"use client";

import { useCallback, useEffect, useState } from "react";
import type { Media } from "@/lib/site-data";

const CATS = [
  { id: "all", label: "All" },
  { id: "menu", label: "Menu" },
  { id: "visuals", label: "Visuals" },
  { id: "configuration", label: "Configuration" },
] as const;

function Slot({ m, large }: { m: Media; large?: boolean }) {
  if (m.kind === "video") {
    // only https links are stored; an embed is used when the link is a known video page, else a plain link
    const yt = m.src.match(/(?:youtube\.com\/watch\?v=|youtu\.be\/)([\w-]{11})/);
    if (yt) return <iframe className="aspect-video w-full rounded-xl" src={`https://www.youtube-nocookie.com/embed/${yt[1]}`} title={m.caption || "Video"} allow="encrypted-media; picture-in-picture" allowFullScreen loading="lazy" />;
    return <a href={m.src} target="_blank" rel="noopener noreferrer" className="flex aspect-video items-center justify-center rounded-xl border border-line text-sm text-violet-300">Open video</a>;
  }
  // eslint-disable-next-line @next/next/no-img-element
  return <img src={m.src} alt={m.caption || "Preview"} loading={large ? "eager" : "lazy"} className={`h-full w-full object-cover ${large ? "rounded-xl" : "rounded-lg"}`} referrerPolicy="no-referrer" />;
}

// Big main image, selectable thumbnails, category filter and a full screen view.
export function Gallery({ media, empty }: { media: Media[]; empty: string }) {
  const [cat, setCat] = useState<(typeof CATS)[number]["id"]>("all");
  const shown = media.filter((m) => cat === "all" || m.category === cat);
  const [i, setI] = useState(0);
  const [full, setFull] = useState(false);
  const current = shown[Math.min(i, shown.length - 1)];

  const step = useCallback((d: number) => setI((x) => (shown.length ? (x + d + shown.length) % shown.length : 0)), [shown.length]);
  useEffect(() => {
    if (!full) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") setFull(false);
      if (e.key === "ArrowRight") step(1);
      if (e.key === "ArrowLeft") step(-1);
    };
    window.addEventListener("keydown", onKey);
    document.body.style.overflow = "hidden";
    return () => {
      window.removeEventListener("keydown", onKey);
      document.body.style.overflow = "";
    };
  }, [full, step]);

  if (media.length === 0) {
    return (
      <div className="card flex aspect-video items-center justify-center px-6 text-center">
        <p className="muted max-w-sm text-sm">{empty}</p>
      </div>
    );
  }
  return (
    <div>
      <div className="mb-4 flex flex-wrap gap-2" role="tablist" aria-label="Preview category">
        {CATS.map((c) => (
          <button key={c.id} role="tab" aria-selected={cat === c.id} onClick={() => { setCat(c.id); setI(0); }} className={`rounded-full border px-3.5 py-1.5 text-xs transition ${cat === c.id ? "border-violet-400/50 bg-violet-500/15 text-white" : "border-line text-[color:var(--muted)] hover:text-white"}`}>
            {c.label}
          </button>
        ))}
      </div>
      {current ? (
        <>
          <div className="card relative aspect-video overflow-hidden p-1.5">
            <Slot m={current} large />
            {current.kind === "screenshot" && (
              <button onClick={() => setFull(true)} className="absolute bottom-4 right-4 rounded-lg border border-line bg-ink-950/80 px-3 py-1.5 text-xs backdrop-blur hover:border-violet-400/50">
                Full screen
              </button>
            )}
            {current.is_demo && <span className="absolute left-4 top-4 rounded-full border border-amber-400/30 bg-ink-950/80 px-2.5 py-0.5 text-[10px] uppercase tracking-wider text-amber-200">Demo image</span>}
          </div>
          {current.caption && <p className="muted mt-3 text-sm">{current.caption}</p>}
          <div className="scroll-thin mt-4 flex gap-3 overflow-x-auto pb-2">
            {shown.map((m, idx) => (
              <button key={m.id} onClick={() => setI(idx)} aria-label={`Show ${m.caption || `item ${idx + 1}`}`} aria-current={idx === i} className={`aspect-video h-16 shrink-0 overflow-hidden rounded-lg border p-0.5 transition ${idx === i ? "border-violet-400/70" : "border-line opacity-70 hover:opacity-100"}`}>
                {m.kind === "video" ? <span className="flex h-full items-center justify-center text-[10px] text-[color:var(--muted)]">Video</span> : <Slot m={m} />}
              </button>
            ))}
          </div>
        </>
      ) : (
        <div className="card flex aspect-video items-center justify-center"><p className="muted text-sm">Nothing in this category yet.</p></div>
      )}
      {full && current && current.kind === "screenshot" && (
        <div className="fixed inset-0 z-[95] flex items-center justify-center bg-black/90 p-4" role="dialog" aria-modal="true" aria-label="Full screen preview" onClick={() => setFull(false)}>
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src={current.src} alt={current.caption || "Preview"} className="max-h-full max-w-full rounded-lg object-contain" onClick={(e) => e.stopPropagation()} />
          <button onClick={() => setFull(false)} className="absolute right-5 top-5 rounded-lg border border-line bg-ink-900 px-3 py-1.5 text-sm" aria-label="Close">Close</button>
          {shown.length > 1 && (
            <>
              <button onClick={(e) => { e.stopPropagation(); step(-1); }} className="absolute left-4 top-1/2 -translate-y-1/2 rounded-full border border-line bg-ink-900 px-3 py-2" aria-label="Previous">‹</button>
              <button onClick={(e) => { e.stopPropagation(); step(1); }} className="absolute right-4 top-1/2 -translate-y-1/2 rounded-full border border-line bg-ink-900 px-3 py-2" aria-label="Next">›</button>
            </>
          )}
        </div>
      )}
    </div>
  );
}
