"use client";

import { useState } from "react";
import { Feedback, callApi, useRun } from "./kit";

type Mode = "issue" | "mark_paid" | "refund" | "note";

const COPY: Record<Mode, { button: string; title: string; need: boolean; warn?: string }> = {
  issue: { button: "Issue key", title: "Create the key for this paid order now?", need: false },
  mark_paid: { button: "Mark paid", title: "Mark as paid and create the key. Only do this after you saw the money.", need: true },
  refund: { button: "Refund", title: "Revoke the key and mark refunded.", need: false, warn: "This does not send money back: refund the payment in the Stripe / NOWPayments dashboard yourself." },
  note: { button: "Note", title: "Save an internal note.", need: true },
};

export function OrderActions({ id, status, hasKey }: { id: string; status: string; hasKey: boolean }) {
  const [mode, setMode] = useState<Mode | null>(null);
  const [reason, setReason] = useState("");
  const r = useRun();
  const available: Mode[] = [
    ...(status === "paid" ? (["issue"] as Mode[]) : []),
    ...(["pending", "review", "expired", "failed"].includes(status) ? (["mark_paid"] as Mode[]) : []),
    ...(status !== "refunded" ? (["refund"] as Mode[]) : []),
    "note",
  ];
  const submit = async () => {
    if (!mode) return;
    const ok = await r.run(() => callApi(`/api/admin/orders/${id}`, { method: "POST", json: { action: mode, reason: reason.trim() || undefined } }), "Done.");
    if (ok) { setMode(null); setReason(""); }
  };
  const c = mode ? COPY[mode] : null;
  return (
    <div className="space-y-2">
      <div className="flex flex-wrap gap-1.5">
        {available.map((m) => (
          <button key={m} type="button" className={m === "refund" ? "btn-danger btn-sm" : "btn-ghost btn-sm"} aria-pressed={mode === m} onClick={() => { setMode(mode === m ? null : m); r.reset(); }}>{COPY[m].button}</button>
        ))}
      </div>
      {mode && c && (
        <form onSubmit={(e) => { e.preventDefault(); void submit(); }} className="max-w-sm space-y-2 rounded-xl border border-line bg-white/[0.02] p-3" aria-label={c.button}>
          <p className="text-xs text-[color:var(--muted)]">{c.title}{mode === "refund" && hasKey ? " The key stops working." : ""}</p>
          {c.warn && <p className="text-xs text-amber-300">{c.warn}</p>}
          <label className="sr-only" htmlFor={`reason-${id}`}>Reason</label>
          <input id={`reason-${id}`} className="input" maxLength={300} value={reason} onChange={(e) => setReason(e.target.value)} placeholder={c.need ? "Reason (required, min 5 characters)" : "Reason (optional)"} />
          <div className="flex gap-2">
            <button className={mode === "refund" ? "btn-danger btn-sm" : "btn-primary btn-sm"} type="submit" disabled={r.busy || (c.need && reason.trim().length < 5 && mode !== "note") || (mode === "note" && !reason.trim())}>{r.busy ? "Working..." : "Confirm"}</button>
            <button className="btn-ghost btn-sm" type="button" onClick={() => setMode(null)}>Cancel</button>
          </div>
        </form>
      )}
      <Feedback run={r} />
    </div>
  );
}
