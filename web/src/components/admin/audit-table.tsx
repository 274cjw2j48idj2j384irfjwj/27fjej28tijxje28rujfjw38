"use client";

import { useMemo, useState } from "react";
import { td, th } from "./kit";
import { EmptyState } from "@/components/ui";

export type AuditEntry = { id: string; action: string; actor: string; target: string; meta: string; at: string };

export function AuditTable({ rows }: { rows: AuditEntry[] }) {
  const [action, setAction] = useState("");
  const [text, setText] = useState("");
  const [shown, setShown] = useState(50);
  const actions = useMemo(() => [...new Set(rows.map((r) => r.action))].sort(), [rows]);
  const filtered = useMemo(() => {
    const t = text.trim().toLowerCase();
    return rows.filter((r) => (!action || r.action === action) && (!t || `${r.action} ${r.actor} ${r.target} ${r.meta}`.toLowerCase().includes(t)));
  }, [rows, action, text]);
  return (
    <div className="space-y-5">
      <div className="flex flex-col gap-2 sm:flex-row" role="search">
        <label htmlFor="audit-q" className="sr-only">Search the log</label>
        <input id="audit-q" className="input sm:max-w-sm" placeholder="Search actor, target or details" value={text} onChange={(e) => { setText(e.target.value); setShown(50); }} />
        <label htmlFor="audit-a" className="sr-only">Action</label>
        <select id="audit-a" className="input sm:w-56" value={action} onChange={(e) => { setAction(e.target.value); setShown(50); }}>
          <option value="">All actions</option>
          {actions.map((a) => <option key={a}>{a}</option>)}
        </select>
      </div>
      <p className="muted text-sm" aria-live="polite">{filtered.length} of {rows.length} entries</p>
      {filtered.length === 0 ? <EmptyState title="Nothing matches">Clear the search or pick another action.</EmptyState> : (
        <>
          <div className="card overflow-hidden"><div className="scroll-thin overflow-x-auto" role="region" aria-label="Audit log" tabIndex={0}>
            <table className="w-full min-w-[760px]">
              <thead className="border-b border-line"><tr><th className={th}>When</th><th className={th}>Action</th><th className={th}>Actor</th><th className={th}>Target</th><th className={th}>Details</th></tr></thead>
              <tbody className="divide-y divide-[color:var(--line)]">
                {filtered.slice(0, shown).map((r) => (
                  <tr key={r.id} className="align-top">
                    <td className={`${td} whitespace-nowrap muted`}>{r.at}</td>
                    <td className={`${td} whitespace-nowrap font-mono text-violet-200`}>{r.action}</td>
                    <td className={td}>{r.actor}</td>
                    <td className={`${td} max-w-[200px] break-all text-xs muted`}>{r.target || "-"}</td>
                    <td className={`${td} muted max-w-[320px] break-words text-xs`}>{r.meta || "-"}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div></div>
          {filtered.length > shown && <button className="btn-ghost btn-sm" onClick={() => setShown(shown + 50)}>Show 50 more</button>}
        </>
      )}
    </div>
  );
}
