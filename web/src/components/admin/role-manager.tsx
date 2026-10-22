"use client";

import { useState } from "react";
import { ActionButton, Feedback, Field, callApi, useRun } from "./kit";
import { Badge, Card } from "@/components/ui";

type P = { id: string; name: string; envIds: string[] };
type M = { id: string; product: string; roleId: string; label: string };

export function RoleManager({ products, mappings }: { products: P[]; mappings: M[] }) {
  return (
    <div className="grid gap-6 md:grid-cols-2">
      {products.map((p) => <ProductRoles key={p.id} p={p} rows={mappings.filter((m) => m.product === p.id)} />)}
    </div>
  );
}

function ProductRoles({ p, rows }: { p: P; rows: M[] }) {
  const r = useRun();
  const [roleId, setRoleId] = useState("");
  const [label, setLabel] = useState("");
  const valid = /^\d{15,22}$/.test(roleId.trim());
  const add = async () => {
    const ok = await r.run(() => callApi("/api/admin/role-mappings", { method: "POST", json: { product: p.id, role_id: roleId.trim(), label: label.trim() || undefined } }), "Role added.");
    if (ok) { setRoleId(""); setLabel(""); }
  };
  return (
    <Card className="p-5">
      <div className="flex items-center justify-between gap-3">
        <h2 className="text-lg font-medium text-white">{p.name}</h2>
        <Badge tone={rows.length ? "green" : p.envIds.length ? "amber" : "red"}>{rows.length ? `${rows.length} mapped` : p.envIds.length ? "Using env fallback" : "No roles"}</Badge>
      </div>

      {rows.length === 0 ? (
        <div className="mt-4 text-sm">
          {p.envIds.length ? (
            <>
              <p className="muted">No rows yet. Currently granting through the environment list:</p>
              <ul className="mt-2 flex flex-wrap gap-2">{p.envIds.map((id) => <li key={id}><code className="rounded-md border border-line bg-white/[0.03] px-2 py-1 font-mono text-xs">{id}</code></li>)}</ul>
            </>
          ) : <p className="text-amber-300">No role is mapped, so no Discord role gives access to this Lua. Grants and rewards still work.</p>}
        </div>
      ) : (
        <ul className="mt-4 divide-y divide-[color:var(--line)]">
          {rows.map((m) => (
            <li key={m.id} className="flex items-center justify-between gap-3 py-2.5">
              <span className="min-w-0"><span className="block truncate text-sm text-white">{m.label || "Unnamed role"}</span><code className="font-mono text-xs text-[color:var(--faint)]">{m.roleId}</code></span>
              <ActionButton variant="danger" confirm={`Remove ${m.label || m.roleId}?`} onRun={() => callApi("/api/admin/role-mappings", { method: "DELETE", json: { id: m.id } })} success="Role removed." label={`Remove role ${m.label || m.roleId}`}>Remove</ActionButton>
            </li>
          ))}
        </ul>
      )}

      <form onSubmit={(e) => { e.preventDefault(); void add(); }} className="mt-5 space-y-3 border-t border-line pt-5">
        <Field label="Discord role id" hint="Server settings, Roles, right click, Copy role ID. 15 to 22 digits.">{(id) => <input id={id} inputMode="numeric" className="input font-mono" value={roleId} onChange={(e) => setRoleId(e.target.value)} placeholder="123456789012345678" />}</Field>
        <Field label="Label (optional)">{(id) => <input id={id} className="input" maxLength={60} value={label} onChange={(e) => setLabel(e.target.value)} placeholder="e.g. Customer" />}</Field>
        <div className="flex flex-wrap items-center gap-3">
          <button className="btn-primary btn-sm" type="submit" disabled={r.busy || !valid}>{r.busy ? "Adding..." : "Add role"}</button>
          <Feedback run={r} />
        </div>
      </form>
    </Card>
  );
}
