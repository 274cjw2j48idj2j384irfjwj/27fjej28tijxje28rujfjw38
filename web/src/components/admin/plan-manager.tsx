"use client";

import { useState } from "react";
import { ActionButton, Feedback, Field, Switch, TableWrap, callApi, td, th, useRun } from "./kit";
import { Badge, Card, EmptyState } from "@/components/ui";
import { CURRENCIES, DURATION_RE, LICENSE_PLANS, durationLabel, formatMoney, luaOfLicensePlan } from "@/lib/plan-format";

export type PlanRow = {
  id: string; slug: string; name: string; description: string; license_plan: string; duration: string; price_cents: number; currency: string;
  active: boolean; sort: number; card_enabled: boolean; crypto_enabled: boolean; orders: number;
};

type Draft = { id: string | null; slug: string; name: string; description: string; license_plan: string; duration: string; price: string; currency: string; sort: string; active: boolean; card_enabled: boolean; crypto_enabled: boolean };

const EMPTY: Draft = { id: null, slug: "", name: "", description: "", license_plan: "specter", duration: "30d", price: "", currency: "usd", sort: "0", active: true, card_enabled: true, crypto_enabled: true };

function fromRow(p: PlanRow): Draft {
  return { id: p.id, slug: p.slug, name: p.name, description: p.description, license_plan: p.license_plan, duration: p.duration, price: (p.price_cents / 100).toFixed(2), currency: p.currency, sort: String(p.sort), active: p.active, card_enabled: p.card_enabled, crypto_enabled: p.crypto_enabled };
}

function problems(d: Draft): string | null {
  if (!/^[a-z0-9][a-z0-9-]{1,39}$/.test(d.slug.trim().toLowerCase())) return "Slug: 2 to 40 letters, digits or dashes.";
  if (!d.name.trim()) return "Name is required.";
  if (!DURATION_RE.test(d.duration.trim().toLowerCase())) return "Duration: lifetime or a number with d, w or m (30d, 1w, 1m).";
  if (!/^\d+(\.\d{1,2})?$/.test(d.price.trim()) || Math.round(Number(d.price) * 100) < 1) return "Price: a positive amount with at most 2 decimals.";
  if (!/^-?\d+$/.test(d.sort.trim())) return "Sort: a whole number.";
  return null;
}

export function PlanManager({ plans }: { plans: PlanRow[] }) {
  const [draft, setDraft] = useState<Draft | null>(null);
  return (
    <div className="space-y-6">
      <div><button type="button" className="btn-primary btn-sm" onClick={() => setDraft({ ...EMPTY })}>New plan</button></div>
      {draft && <PlanForm key={draft.id ?? "new"} initial={draft} onClose={() => setDraft(null)} />}
      {plans.length === 0 ? (
        <EmptyState title="No plans yet">Nothing is on sale. Create a plan with the button above: it appears on the pricing page as soon as it is active. No prices are made up.</EmptyState>
      ) : (
        <TableWrap label="Plans">
          <table className="w-full min-w-[860px]">
            <thead className="border-b border-line"><tr><th className={th}>Plan</th><th className={th}>Lua</th><th className={th}>License</th><th className={th}>Price</th><th className={th}>Methods</th><th className={th}>Sort</th><th className={th}>Orders</th><th className={th}><span className="sr-only">Actions</span></th></tr></thead>
            <tbody className="divide-y divide-[color:var(--line)]">
              {plans.map((p) => (
                <tr key={p.id}>
                  <td className={td}><span className="block font-medium text-white">{p.name}</span><code className="font-mono text-xs text-[color:var(--faint)]">{p.slug}</code> {!p.active && <Badge tone="gray">Inactive</Badge>}</td>
                  <td className={`${td} capitalize`}>{luaOfLicensePlan(p.license_plan)}</td>
                  <td className={`${td} whitespace-nowrap`}><code className="font-mono text-xs">{p.license_plan}</code> · {durationLabel(p.duration)}</td>
                  <td className={`${td} whitespace-nowrap`}>{formatMoney(p.price_cents, p.currency)}</td>
                  <td className={td}><span className="flex gap-1.5"><Badge tone={p.card_enabled ? "green" : "gray"}>Card</Badge><Badge tone={p.crypto_enabled ? "green" : "gray"}>Crypto</Badge></span></td>
                  <td className={td}>{p.sort}</td>
                  <td className={td}>{p.orders}</td>
                  <td className={`${td} whitespace-nowrap`}>
                    <span className="flex flex-wrap items-start gap-2">
                      <button type="button" className="btn-ghost btn-sm" onClick={() => setDraft(fromRow(p))}>Edit</button>
                      <ActionButton variant="danger" confirm={p.orders ? `${p.orders} order(s) use this plan: it will only be deactivated.` : `Delete ${p.name}?`} onRun={() => callApi(`/api/admin/plans/${p.id}`, { method: "DELETE" })} success={p.orders ? "Deactivated." : "Deleted."} label={`Delete ${p.name}`}>{p.orders ? "Deactivate" : "Delete"}</ActionButton>
                    </span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </TableWrap>
      )}
    </div>
  );
}

function PlanForm({ initial, onClose }: { initial: Draft; onClose: () => void }) {
  const [d, setD] = useState(initial);
  const r = useRun();
  const set = <K extends keyof Draft>(k: K, v: Draft[K]) => setD((x) => ({ ...x, [k]: v }));
  const invalid = problems(d);
  const save = async () => {
    const json = {
      slug: d.slug.trim().toLowerCase(), name: d.name.trim(), description: d.description.trim(), license_plan: d.license_plan, duration: d.duration.trim().toLowerCase(),
      price_cents: Math.round(Number(d.price) * 100), currency: d.currency, active: d.active, sort: Number(d.sort), card_enabled: d.card_enabled, crypto_enabled: d.crypto_enabled,
    };
    const ok = await r.run(() => (d.id ? callApi(`/api/admin/plans/${d.id}`, { method: "PUT", json }) : callApi("/api/admin/plans", { method: "POST", json })), d.id ? "Plan saved." : "Plan created.");
    if (ok && !d.id) onClose();
  };
  return (
    <Card className="p-5">
      <h2 className="text-lg font-medium text-white">{d.id ? `Edit ${initial.name}` : "New plan"}</h2>
      <p className="muted mt-1 text-xs">Existing orders keep the price and plan they were bought with.</p>
      <form onSubmit={(e) => { e.preventDefault(); void save(); }} className="mt-4 grid gap-4 sm:grid-cols-2">
        <Field label="Name">{(id) => <input id={id} className="input" maxLength={80} value={d.name} onChange={(e) => set("name", e.target.value)} />}</Field>
        <Field label="Slug" hint="Used in the checkout request. Lower case letters, digits, dashes.">{(id) => <input id={id} className="input font-mono" maxLength={40} value={d.slug} onChange={(e) => set("slug", e.target.value)} />}</Field>
        <Field label="License plan" hint="What the license server creates. pm_* = Primordial.">{(id) => (
          <select id={id} className="input" value={d.license_plan} onChange={(e) => set("license_plan", e.target.value)}>
            {LICENSE_PLANS.map((p) => <option key={p} value={p}>{p} ({luaOfLicensePlan(p)})</option>)}
          </select>
        )}</Field>
        <Field label="Duration" hint="lifetime, or 7d, 30d, 90d, 1w, 1m.">{(id) => <input id={id} className="input font-mono" list="durations" maxLength={12} value={d.duration} onChange={(e) => set("duration", e.target.value)} />}</Field>
        <Field label="Price" hint="In the major unit, e.g. 12.50.">{(id) => <input id={id} className="input" inputMode="decimal" value={d.price} onChange={(e) => set("price", e.target.value)} />}</Field>
        <Field label="Currency">{(id) => <select id={id} className="input" value={d.currency} onChange={(e) => set("currency", e.target.value)}>{CURRENCIES.map((c) => <option key={c} value={c}>{c.toUpperCase()}</option>)}</select>}</Field>
        <Field label="Description (optional)" className="sm:col-span-2">{(id) => <textarea id={id} className="input min-h-20" maxLength={400} value={d.description} onChange={(e) => set("description", e.target.value)} />}</Field>
        <Field label="Sort" hint="Lower numbers first.">{(id) => <input id={id} className="input w-28" inputMode="numeric" value={d.sort} onChange={(e) => set("sort", e.target.value)} />}</Field>
        <div className="space-y-3 sm:col-span-2">
          <Switch checked={d.active} onChange={(v) => set("active", v)} label="Active (shown on the pricing page and can be bought)" />
          <Switch checked={d.card_enabled} onChange={(v) => set("card_enabled", v)} label="Card payments (Stripe)" />
          <Switch checked={d.crypto_enabled} onChange={(v) => set("crypto_enabled", v)} label="Crypto payments (NOWPayments)" />
        </div>
        <datalist id="durations">{["lifetime", "7d", "30d", "90d", "1w", "1m"].map((x) => <option key={x} value={x} />)}</datalist>
        <div className="flex flex-wrap items-center gap-3 sm:col-span-2">
          <button className="btn-primary btn-sm" type="submit" disabled={r.busy || !!invalid}>{r.busy ? "Saving..." : d.id ? "Save plan" : "Create plan"}</button>
          <button className="btn-ghost btn-sm" type="button" onClick={onClose}>Close</button>
          {invalid && <span className="text-xs text-amber-300">{invalid}</span>}
          <Feedback run={r} />
        </div>
      </form>
    </Card>
  );
}
