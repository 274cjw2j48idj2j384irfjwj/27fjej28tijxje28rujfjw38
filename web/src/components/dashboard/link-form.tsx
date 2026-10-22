"use client";

import Link from "next/link";
import { useEffect, useRef, useState } from "react";
import { CheckCircle2, XCircle } from "lucide-react";
import { Badge, Notice, formatDate } from "@/components/ui";
import { sendJson } from "./api";

type Pending = { product: string; client: string; expiresAt: string };
type Names = Record<string, { name: string; platform: string; canUse: boolean }>;

export function LinkForm({ initialCode, products }: { initialCode: string; products: Names }) {
  const [code, setCode] = useState(initialCode);
  const [pending, setPending] = useState<Pending | null>(null);
  const [checking, setChecking] = useState(false);
  const [deciding, setDeciding] = useState<"" | "approve" | "deny">("");
  const [error, setError] = useState("");
  const [result, setResult] = useState<"approved" | "denied" | null>(null);
  const auto = useRef(false);

  async function check(value = code) {
    setError("");
    setPending(null);
    setChecking(true);
    const res = await sendJson<Pending>("/api/device/approve", "POST", { user_code: value.trim(), check: true });
    setChecking(false);
    if (!res.ok) return setError(res.message);
    setPending(res.data);
  }

  useEffect(() => {
    if (initialCode && !auto.current) {
      auto.current = true;
      void check(initialCode);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  async function decide(approve: boolean) {
    setDeciding(approve ? "approve" : "deny");
    setError("");
    const res = await sendJson("/api/device/approve", "POST", { user_code: code.trim(), approve });
    setDeciding("");
    if (!res.ok) return setError(res.message);
    setResult(approve ? "approved" : "denied");
    setPending(null);
  }

  if (result) {
    const ok = result === "approved";
    return (
      <div role="status" className="card p-8 text-center">
        <div className={`mx-auto mb-4 flex size-12 items-center justify-center rounded-full ${ok ? "bg-emerald-500/15 text-emerald-300" : "bg-white/[0.05] text-[color:var(--muted)]"}`}>
          {ok ? <CheckCircle2 size={24} aria-hidden="true" /> : <XCircle size={24} aria-hidden="true" />}
        </div>
        <h2 className="text-xl font-semibold text-white">{ok ? "Device linked" : "Request denied"}</h2>
        <p className="muted mx-auto mt-2 max-w-sm text-sm leading-relaxed">
          {ok ? "Go back to the Lua menu. It picks up the link within a few seconds." : "Nothing was linked. The Lua shows that the request was denied."}
        </p>
        <div className="mt-6 flex flex-wrap justify-center gap-3">
          <Link href="/dashboard/devices" className="btn-primary btn-sm">Connected devices</Link>
          <button type="button" className="btn-ghost btn-sm" onClick={() => { setResult(null); setCode(""); }}>Link another</button>
        </div>
      </div>
    );
  }

  const info = pending ? products[pending.product] : null;
  return (
    <div className="card p-6 sm:p-8">
      <form onSubmit={(e) => { e.preventDefault(); void check(); }} className="space-y-4">
        <div>
          <label htmlFor="link-code" className="label">Code from the Lua menu</label>
          <input
            id="link-code"
            className="input text-center font-mono text-2xl uppercase tracking-[0.3em] sm:text-3xl"
            value={code}
            onChange={(e) => { setCode(e.target.value.toUpperCase()); setPending(null); setError(""); }}
            placeholder="XXXX-XXXX"
            maxLength={12}
            autoComplete="off"
            autoCapitalize="characters"
            spellCheck={false}
            inputMode="text"
            aria-describedby="link-help"
          />
          <p id="link-help" className="mt-2 text-center text-xs text-[color:var(--faint)]">8 letters and numbers. The code is valid for 10 minutes.</p>
        </div>
        <button type="submit" className="btn-primary w-full" disabled={checking || code.replace(/[^A-Za-z0-9]/g, "").length < 8}>{checking ? "Checking..." : "Check code"}</button>
      </form>

      {error && <div role="alert" className="mt-5 rounded-xl border border-red-400/30 bg-red-500/10 px-4 py-3 text-sm text-red-100">{error}</div>}

      {pending && (
        <div className="mt-6 border-t border-line pt-6">
          <p className="eyebrow">Link request</p>
          <h2 className="mt-2 text-lg font-semibold text-white">{info?.name ?? pending.product} is asking to link to your account</h2>
          <dl className="mt-4 grid grid-cols-[auto_1fr] gap-x-6 gap-y-2 text-sm">
            <dt className="muted">Lua</dt>
            <dd className="text-white">{info?.name ?? pending.product}{info && <Badge tone="violet" className="ml-2">{info.platform}</Badge>}</dd>
            <dt className="muted">Client</dt>
            <dd className="break-all text-white">{pending.client || "Unnamed client"}</dd>
            <dt className="muted">Expires</dt>
            <dd className="text-white">{formatDate(pending.expiresAt, true)}</dd>
          </dl>
          <div className="mt-4">
            <Notice tone="violet">Only approve it if you just started the link from the Lua menu on your own computer. The linked Lua can read and upload your configs and report your score until you revoke it.</Notice>
          </div>
          {info && !info.canUse && (
            <div className="mt-3">
              <Notice tone="amber">You do not have active access to {info.name} right now. You can still link it, but cloud features of that Lua stay locked until your access is active.</Notice>
            </div>
          )}
          <div className="mt-5 grid gap-3 sm:grid-cols-2">
            <button type="button" className="btn-primary" disabled={!!deciding} onClick={() => decide(true)}>{deciding === "approve" ? "Approving..." : "Approve"}</button>
            <button type="button" className="btn-ghost" disabled={!!deciding} onClick={() => decide(false)}>{deciding === "deny" ? "Denying..." : "Deny"}</button>
          </div>
        </div>
      )}
    </div>
  );
}
