"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";

type Props = {
  slug: string;
  signedIn: boolean;
  canUse: boolean;       // access to the Lua of this config
  lockedReason: string;  // shown when canUse is false
  compatible: boolean;
  incompatibleReason: string;
  liked: boolean;
  saved: boolean;
  likes: number;
  mine: boolean;
  loginHref: string;
};

async function call(url: string, method = "POST", body?: unknown): Promise<{ ok: boolean; data: any }> {
  const res = await fetch(url, { method, headers: body ? { "content-type": "application/json" } : undefined, body: body ? JSON.stringify(body) : undefined });
  let data: any = null;
  try {
    data = await res.json();
  } catch {
    data = null;
  }
  return { ok: res.ok, data };
}

const REASONS = ["Contains secrets", "Spam or fake", "Stolen config", "Does not work", "Other"];

export function ConfigActions(p: Props) {
  const router = useRouter();
  const [liked, setLiked] = useState(p.liked);
  const [likes, setLikes] = useState(p.likes);
  const [saved, setSaved] = useState(p.saved);
  const [msg, setMsg] = useState<{ tone: "ok" | "err"; text: string } | null>(null);
  const [busy, setBusy] = useState("");
  const [reporting, setReporting] = useState(false);
  const [reason, setReason] = useState(REASONS[0]);
  const [details, setDetails] = useState("");

  const base = `/api/configs/${p.slug}`;
  const fail = (data: any) => setMsg({ tone: "err", text: data?.error?.message ?? "The request failed." });

  async function like() {
    setBusy("like");
    const r = await call(`${base}/like`);
    setBusy("");
    if (!r.ok) return fail(r.data);
    setLiked(r.data.liked);
    setLikes(r.data.likes);
  }
  async function save() {
    setBusy("save");
    const r = await call(`${base}/library`, saved ? "DELETE" : "POST");
    setBusy("");
    if (!r.ok) return fail(r.data);
    setSaved(r.data.saved);
    setMsg({ tone: "ok", text: r.data.saved ? "Saved to your library." : "Removed from your library." });
    router.refresh();
  }
  async function copyCode() {
    setBusy("code");
    const r = await call(`${base}/import-code`);
    setBusy("");
    if (!r.ok) return fail(r.data);
    try {
      await navigator.clipboard.writeText(r.data.code);
      setMsg({ tone: "ok", text: `Import code ${r.data.code} copied.` });
    } catch {
      setMsg({ tone: "ok", text: `Import code: ${r.data.code}` });
    }
  }
  async function report() {
    setBusy("report");
    const r = await call(`${base}/report`, "POST", { reason, details });
    setBusy("");
    if (!r.ok) return fail(r.data);
    setReporting(false);
    setMsg({ tone: "ok", text: "Thanks, the team will look at it." });
  }

  if (!p.signedIn) {
    return (
      <div className="space-y-3">
        <a href={p.loginHref} className="btn-primary w-full">Sign in with Discord to use this config</a>
        <p className="muted text-center text-xs">Browsing is open to everyone. Downloading needs access to the Lua.</p>
      </div>
    );
  }

  const blocked = !p.canUse || !p.compatible;
  return (
    <div className="space-y-3">
      {!p.compatible && <p className="rounded-xl border border-red-400/25 bg-red-500/[0.06] px-4 py-3 text-sm text-red-200">Not compatible: {p.incompatibleReason}</p>}
      {!p.canUse && <p className="rounded-xl border border-amber-400/25 bg-amber-500/[0.06] px-4 py-3 text-sm text-amber-200">{p.lockedReason}</p>}
      {blocked ? (
        <span className="btn-primary pointer-events-none w-full opacity-40" aria-disabled="true">Download Config</span>
      ) : (
        <a href={`${base}/download`} className="btn-primary w-full">Download Config</a>
      )}
      <div className="grid grid-cols-2 gap-3">
        <button className="btn-ghost" disabled={blocked || busy === "code"} onClick={copyCode}>Copy Import Code</button>
        <button className="btn-ghost" disabled={!p.canUse || busy === "save"} onClick={save}>{saved ? "Remove from library" : "Save to My Library"}</button>
      </div>
      <div className="grid grid-cols-2 gap-3">
        <button className="btn-ghost" disabled={busy === "like"} onClick={like} aria-pressed={liked}>{liked ? "♥ Liked" : "♡ Like"} · {likes}</button>
        {p.mine ? <a href={`/dashboard/configs/${p.slug}`} className="btn-ghost">Manage</a> : <button className="btn-ghost" onClick={() => setReporting(!reporting)}>Report</button>}
      </div>
      {reporting && (
        <div className="card space-y-3 p-4">
          <label className="label" htmlFor="reason">Reason</label>
          <select id="reason" className="input" value={reason} onChange={(e) => setReason(e.target.value)}>{REASONS.map((r) => <option key={r}>{r}</option>)}</select>
          <label className="label" htmlFor="details">Details (optional)</label>
          <textarea id="details" className="input min-h-20" maxLength={500} value={details} onChange={(e) => setDetails(e.target.value)} />
          <button className="btn-primary btn-sm" disabled={busy === "report"} onClick={report}>Send report</button>
        </div>
      )}
      {msg && <p role="status" className={`text-sm ${msg.tone === "ok" ? "text-emerald-300" : "text-red-300"}`}>{msg.text}</p>}
    </div>
  );
}
