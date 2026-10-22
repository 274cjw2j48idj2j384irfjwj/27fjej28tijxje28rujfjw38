"use client";

import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { call, sendJson } from "./api";
import { NOTIFICATIONS_EVENT } from "./bell";

export function RevokeDevice({ id, name }: { id: string; name: string }) {
  const router = useRouter();
  const [confirm, setConfirm] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  async function revoke() {
    setBusy(true);
    setError("");
    const res = await sendJson(`/api/devices/${id}`, "DELETE");
    setBusy(false);
    if (!res.ok) return setError(res.message);
    router.refresh();
  }
  return (
    <div className="flex flex-col items-end gap-2">
      {!confirm ? (
        <button type="button" className="btn-ghost btn-sm" onClick={() => setConfirm(true)} aria-label={`Revoke ${name}`}>Revoke</button>
      ) : (
        <div className="flex gap-2">
          <button type="button" className="btn-danger btn-sm" disabled={busy} onClick={revoke}>{busy ? "Revoking..." : "Confirm revoke"}</button>
          <button type="button" className="btn-ghost btn-sm" disabled={busy} onClick={() => setConfirm(false)}>Cancel</button>
        </div>
      )}
      {error && <p role="alert" className="text-xs text-red-300">{error}</p>}
    </div>
  );
}

export function SignOutButtons() {
  const [busy, setBusy] = useState("");
  const [error, setError] = useState("");
  const [confirmAll, setConfirmAll] = useState(false);
  async function out(all: boolean) {
    setBusy(all ? "all" : "one");
    setError("");
    const res = all ? await sendJson("/api/me/sessions", "DELETE") : await sendJson("/api/auth/logout", "POST");
    if (!res.ok) {
      setBusy("");
      return setError(res.message);
    }
    window.location.href = "/";
  }
  return (
    <div>
      <div className="flex flex-wrap gap-3">
        <button type="button" className="btn-ghost" disabled={!!busy} onClick={() => out(false)}>{busy === "one" ? "Signing out..." : "Sign out"}</button>
        {!confirmAll ? (
          <button type="button" className="btn-ghost" disabled={!!busy} onClick={() => setConfirmAll(true)}>Sign out everywhere</button>
        ) : (
          <>
            <button type="button" className="btn-danger" disabled={!!busy} onClick={() => out(true)}>{busy === "all" ? "Signing out..." : "Sign out of all devices"}</button>
            <button type="button" className="btn-ghost" disabled={!!busy} onClick={() => setConfirmAll(false)}>Cancel</button>
          </>
        )}
      </div>
      {error && <p role="alert" className="mt-3 text-sm text-red-300">{error}</p>}
    </div>
  );
}

export function MarkAllRead({ unread }: { unread: number }) {
  const router = useRouter();
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  async function mark() {
    setBusy(true);
    setError("");
    const res = await call("/api/notifications/read", { method: "POST" });
    setBusy(false);
    if (!res.ok) return setError(res.message);
    window.dispatchEvent(new Event(NOTIFICATIONS_EVENT));
    router.refresh();
  }
  return (
    <div className="flex items-center gap-3">
      <button type="button" className="btn-ghost btn-sm" disabled={busy || unread === 0} onClick={mark}>{busy ? "Working..." : "Mark all as read"}</button>
      {error && <p role="alert" className="text-xs text-red-300">{error}</p>}
    </div>
  );
}

// Counts down to a UTC date. The first render shows nothing dynamic, so the server and the browser agree.
export function Countdown({ to }: { to: string }) {
  const [text, setText] = useState("");
  useEffect(() => {
    const tick = () => {
      const ms = new Date(to).getTime() - Date.now();
      if (ms <= 0) return setText("resetting now");
      const d = Math.floor(ms / 86_400_000);
      const h = Math.floor((ms % 86_400_000) / 3_600_000);
      const m = Math.floor((ms % 3_600_000) / 60_000);
      setText(`${d}d ${h}h ${m}m`);
    };
    tick();
    const t = setInterval(tick, 30_000);
    return () => clearInterval(t);
  }, [to]);
  return <span suppressHydrationWarning>{text || "..."}</span>;
}
