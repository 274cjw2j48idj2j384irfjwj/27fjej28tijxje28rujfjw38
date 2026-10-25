"use client";

import { useState } from "react";
import { ActionButton, Feedback, Field, TableWrap, callApi, td, th, useRun } from "./kit";
import { Badge, Card, Notice, SectionTitle } from "@/components/ui";

type Product = { id: string; name: string; suspended: boolean };
type Grant = { id: string; product: string; source: string; starts: string; ends: string; note: string; state: "live" | "revoked" | "ended" | "scheduled" };

const STATE_TONE = { live: "green", revoked: "red", ended: "gray", scheduled: "amber" } as const;

export function UserActions({ userId, name, isSelf, owner, flags, products, grants }: {
  userId: string; name: string; isSelf: boolean; owner: boolean;
  flags: { admin: boolean; banned: boolean; verified: boolean };
  products: Product[]; grants: Grant[];
}) {
  const act = (body: Record<string, unknown>) => () => callApi(`/api/admin/users/${userId}`, { method: "POST", json: body });
  return (
    <>
      <GrantForm userId={userId} products={products} />

      <section>
        <SectionTitle eyebrow="Grants" title="Access grants">Time limited or open ended access added by an admin or won on the leaderboard. Revoking ends it at once.</SectionTitle>
        {grants.length === 0 ? <p className="muted text-sm">This user has no grants.</p> : (
          <TableWrap label="Grants">
            <table className="w-full min-w-[720px]">
              <thead className="border-b border-line"><tr><th className={th}>Lua</th><th className={th}>Source</th><th className={th}>Starts</th><th className={th}>Ends</th><th className={th}>Note</th><th className={th}>State</th><th className={th}><span className="sr-only">Action</span></th></tr></thead>
              <tbody className="divide-y divide-[color:var(--line)]">
                {grants.map((g) => (
                  <tr key={g.id}>
                    <td className={td}>{g.product}</td><td className={`${td} capitalize`}>{g.source}</td><td className={`${td} whitespace-nowrap`}>{g.starts}</td><td className={`${td} whitespace-nowrap`}>{g.ends}</td>
                    <td className={`${td} muted max-w-[180px] truncate`}>{g.note || "-"}</td>
                    <td className={td}><Badge tone={STATE_TONE[g.state]}>{g.state}</Badge></td>
                    <td className={`${td} text-right`}>
                      {(g.state === "live" || g.state === "scheduled") && <ActionButton variant="danger" confirm={`Revoke this ${g.product} grant?`} onRun={act({ action: "revoke_grant", grant_id: g.id })} success="Grant revoked." label={`Revoke ${g.product} grant`}>Revoke</ActionButton>}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </TableWrap>
        )}
      </section>

      <section>
        <SectionTitle eyebrow="Per Lua" title="Suspensions">A suspended user keeps the account but loses that Lua: downloads, config upload and score.</SectionTitle>
        <div className="grid gap-4 md:grid-cols-2">
          {products.map((p) => <SuspendCard key={p.id} userId={userId} p={p} />)}
        </div>
      </section>

      <section>
        <SectionTitle eyebrow="Account" title="Platform controls" />
        <Card className="divide-y divide-[color:var(--line)]">
          <Row title="Platform ban" text={flags.banned ? `${name} is banned: sign-in is refused and all sessions were ended.` : "Blocks the whole account and ends its sessions."}>
            {isSelf ? <span className="muted text-sm">You cannot ban yourself</span> : flags.banned
              ? <ActionButton onRun={act({ action: "unban" })} success="User unbanned.">Unban</ActionButton>
              : <ActionButton variant="danger" confirm={`Ban ${name} from the whole platform?`} onRun={act({ action: "ban" })} success="User banned.">Ban user</ActionButton>}
          </Row>
          <Row title="Verified creator" text="Shows a check mark next to this user's configs in the cloud.">
            <ActionButton onRun={act({ action: flags.verified ? "unverify" : "verify" })} success={flags.verified ? "Verification removed." : "Marked as verified."}>{flags.verified ? "Remove verified" : "Mark verified"}</ActionButton>
          </Row>
          <Row title="Admin rights" text={owner ? "Admins can open this area and manage users, content and boards." : "Only the owners can change admin rights."}>
            {!owner ? <Badge>{flags.admin ? "Is admin" : "Not admin"}</Badge> : flags.admin
              ? <ActionButton variant="danger" confirm={`Remove admin rights from ${name}?`} onRun={act({ action: "remove_admin" })} success="Admin rights removed.">Remove admin</ActionButton>
              : <ActionButton confirm={`Make ${name} an admin?`} onRun={act({ action: "make_admin" })} success="Admin rights given.">Make admin</ActionButton>}
          </Row>
        </Card>
      </section>
    </>
  );
}

function Row({ title, text, children }: { title: string; text: string; children: React.ReactNode }) {
  return (
    <div className="flex flex-col gap-3 p-5 sm:flex-row sm:items-center sm:justify-between">
      <div className="min-w-0"><p className="font-medium text-white">{title}</p><p className="muted mt-1 text-sm">{text}</p></div>
      <div className="shrink-0">{children}</div>
    </div>
  );
}

function GrantForm({ userId, products }: { userId: string; products: Product[] }) {
  const r = useRun();
  const [product, setProduct] = useState(products[0]?.id ?? "gamesense");
  const [mode, setMode] = useState<"days" | "open">("days");
  const [days, setDays] = useState("30");
  const [note, setNote] = useState("");
  const [askOpen, setAskOpen] = useState(false);
  const n = Number(days);
  const valid = mode === "open" || (Number.isInteger(n) && n >= 1 && n <= 3650);
  const submit = async () => {
    setAskOpen(false);
    const ok = await r.run(() => callApi(`/api/admin/users/${userId}`, { method: "POST", json: { action: "grant", product, days: mode === "open" ? null : n, note: note || undefined } }), mode === "open" ? "Open ended access granted." : `${n} days granted.`);
    if (ok) setNote("");
  };
  return (
    <section>
      <SectionTitle eyebrow="Grant" title="Give access">Adds a grant on top of whatever the user already has. Days run from now.</SectionTitle>
      <Card className="p-5">
        <form onSubmit={(e) => { e.preventDefault(); if (mode === "open" && !askOpen) setAskOpen(true); else void submit(); }} className="grid gap-4 md:grid-cols-2">
          <Field label="Lua">{(id) => <select id={id} className="input" value={product} onChange={(e) => setProduct(e.target.value)}>{products.map((p) => <option key={p.id} value={p.id}>{p.name}</option>)}</select>}</Field>
          <fieldset>
            <legend className="label">Length</legend>
            <div className="flex flex-wrap items-center gap-4 pt-1.5 text-sm">
              <label className="flex items-center gap-2"><input type="radio" name="mode" checked={mode === "days"} onChange={() => setMode("days")} className="accent-violet-500" /> Days</label>
              <label className="flex items-center gap-2"><input type="radio" name="mode" checked={mode === "open"} onChange={() => setMode("open")} className="accent-violet-500" /> Open ended</label>
              {mode === "days" && (<><label htmlFor="grant-days" className="sr-only">Number of days</label><input id="grant-days" type="number" min={1} max={3650} className="input w-28" value={days} onChange={(e) => setDays(e.target.value)} /></>)}
            </div>
          </fieldset>
          <Field label="Note (optional)" className="md:col-span-2" hint="Shown in the grant list and the audit log.">{(id) => <input id={id} className="input" maxLength={200} value={note} onChange={(e) => setNote(e.target.value)} placeholder="e.g. giveaway winner" />}</Field>
          <div className="flex flex-wrap items-center gap-3 md:col-span-2">
            {askOpen ? (
              <>
                <Notice tone="amber">Open ended access never runs out. Grant it?</Notice>
                <button type="submit" className="btn-primary btn-sm" autoFocus>Yes, grant open ended</button>
                <button type="button" className="btn-ghost btn-sm" onClick={() => setAskOpen(false)}>Cancel</button>
              </>
            ) : (
              <button type="submit" className="btn-primary" disabled={r.busy || !valid}>{r.busy ? "Granting..." : "Grant access"}</button>
            )}
            <Feedback run={r} />
          </div>
        </form>
      </Card>
    </section>
  );
}

function SuspendCard({ userId, p }: { userId: string; p: Product }) {
  const [reason, setReason] = useState("");
  const call = (body: Record<string, unknown>) => () => callApi(`/api/admin/users/${userId}`, { method: "POST", json: body });
  return (
    <Card className="p-5">
      <div className="flex items-center justify-between gap-3">
        <h3 className="font-medium text-white">{p.name}</h3>
        <Badge tone={p.suspended ? "red" : "green"}>{p.suspended ? "Suspended" : "Not suspended"}</Badge>
      </div>
      {p.suspended ? (
        <div className="mt-4"><ActionButton onRun={call({ action: "unsuspend", product: p.id })} success="Suspension lifted.">Lift suspension</ActionButton></div>
      ) : (
        <div className="mt-4 space-y-3">
          <Field label="Reason (optional)">{(id) => <input id={id} className="input" maxLength={200} value={reason} onChange={(e) => setReason(e.target.value)} placeholder="Shown to staff only" />}</Field>
          <ActionButton variant="danger" confirm={`Suspend access to ${p.name}?`} onRun={call({ action: "suspend", product: p.id, reason: reason || undefined })} success="Suspended.">Suspend</ActionButton>
        </div>
      )}
    </Card>
  );
}
