"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { sendJson } from "./api";

type Option = { id: string; label: string };
type Spin = { prize: string; label: string; hours: number; status: string };

const COLORS = ["#2a2540", "#6d4fd6", "#8b6df0", "#a78bfa", "#c4b5fd", "#e0d4ff", "#f5f0ff"];

export function RouletteWheel({ prizes, canSpin, luas, nextSpinAt }: { prizes: Option[]; canSpin: boolean; luas: { id: string; name: string }[]; nextSpinAt: string | null }) {
  const router = useRouter();
  const [angle, setAngle] = useState(0);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [won, setWon] = useState<Spin | null>(null);
  const [lua, setLua] = useState(luas[0]?.id ?? "");
  const n = prizes.length;
  const seg = 360 / n;
  const gradient = `conic-gradient(${prizes.map((_, i) => `${COLORS[i % COLORS.length]} ${i * seg}deg ${(i + 1) * seg}deg`).join(",")})`;

  async function go() {
    setBusy(true);
    setError("");
    setWon(null);
    const res = await sendJson<{ spin: Spin }>("/api/roulette", "POST", luas.length > 1 ? { lua } : {});
    if (!res.ok) {
      setBusy(false);
      return setError(res.message);
    }
    const i = Math.max(0, prizes.findIndex((p) => p.id === res.data.spin.prize));
    const reduce = typeof window !== "undefined" && window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    // land the middle of the segment under the pointer (top)
    const target = 360 * 6 - (i * seg + seg / 2);
    setAngle((a) => a + (target - (a % 360)));
    window.setTimeout(() => {
      setWon(res.data.spin);
      setBusy(false);
      router.refresh();
    }, reduce ? 0 : 4200);
  }

  return (
    <div className="flex flex-col items-center gap-6">
      <div className="relative h-72 w-72 sm:h-80 sm:w-80">
        <div aria-hidden="true" className="absolute left-1/2 top-[-6px] z-10 h-0 w-0 -translate-x-1/2 border-x-[10px] border-t-[18px] border-x-transparent border-t-white" />
        <div
          className="relative h-full w-full rounded-full border-4 border-line shadow-[0_0_60px_rgba(139,109,240,0.25)]"
          style={{ background: gradient, transform: `rotate(${angle}deg)`, transition: "transform 4s cubic-bezier(0.12, 0.7, 0.1, 1)" }}
        >
          {prizes.map((p, i) => (
            <span
              key={p.id}
              className="absolute left-1/2 top-1/2 origin-[0_0] text-xs font-semibold text-black/80"
              style={{ transform: `rotate(${i * seg + seg / 2 - 90}deg) translate(62px, -8px)` }}
            >
              {p.label}
            </span>
          ))}
        </div>
      </div>

      {luas.length > 1 && canSpin && (
        <label className="text-sm">
          <span className="muted mr-2">Prize goes to</span>
          <select className="input" value={lua} onChange={(e) => setLua(e.target.value)} disabled={busy}>
            {luas.map((l) => <option key={l.id} value={l.id}>{l.name}</option>)}
          </select>
        </label>
      )}

      <button type="button" className="btn-primary" disabled={busy || !canSpin} onClick={go}>
        {busy ? "Spinning..." : canSpin ? "Spin" : "Come back later"}
      </button>
      {!canSpin && nextSpinAt && <p className="muted text-sm">Next spin: {new Date(nextSpinAt).toLocaleString()}</p>}
      {error && <p role="alert" className="text-sm text-red-300">{error}</p>}
      {won && (
        <p role="status" className="text-lg font-semibold text-white">
          {won.hours === 0 ? "No luck this week. Nothing won." : `You won ${won.label}!`}
        </p>
      )}
    </div>
  );
}
