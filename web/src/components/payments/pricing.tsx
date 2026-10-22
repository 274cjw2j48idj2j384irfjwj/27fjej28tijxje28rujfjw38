"use client";

import { useState } from "react";
import { CreditCard, Bitcoin } from "lucide-react";
import { Card } from "@/components/ui";
import { sendJson } from "@/components/dashboard/api";

export type PlanView = {
  id: string; slug: string; name: string; description: string; price: string; duration: string;
  card: "ok" | "off" | "unconfigured"; crypto: "ok" | "off" | "unconfigured";
};
export type LuaGroup = { id: string; name: string; tagline: string; plans: PlanView[] };

const NOTE = { off: "Not offered for this plan.", unconfigured: "Not available right now." };

export function PricingGroups({ groups }: { groups: LuaGroup[] }) {
  const [email, setEmail] = useState("");
  const [busy, setBusy] = useState<string | null>(null);
  const [error, setError] = useState<{ plan: string; text: string } | null>(null);

  async function pay(plan: PlanView, provider: "card" | "crypto") {
    setBusy(`${plan.id}:${provider}`);
    setError(null);
    const res = await sendJson<{ url: string }>("/api/checkout", "POST", { plan: plan.slug, provider, email: email.trim() || undefined });
    if (res.ok && res.data?.url) {
      window.location.href = res.data.url;
      return; // keep the buttons locked while the browser leaves
    }
    setBusy(null);
    setError({ plan: plan.id, text: res.ok ? "The payment page did not open. Try again." : res.message });
  }

  return (
    <div className="space-y-14">
      <div className="card p-5">
        <label htmlFor="buyer-email" className="label">E-mail (optional)</label>
        <input id="buyer-email" type="email" autoComplete="email" inputMode="email" maxLength={200} value={email} onChange={(e) => setEmail(e.target.value)} placeholder="you@example.com" className="input max-w-md" />
        <p className="mt-2 text-xs text-[color:var(--faint)]">Only used for the payment receipt and so support can find your order. Your Invoice ID is shown on the order page, not sent by e-mail.</p>
      </div>

      {groups.map((g) => (
        <section key={g.id} aria-labelledby={`lua-${g.id}`}>
          <div className="mb-5">
            <h2 id={`lua-${g.id}`} className="text-2xl font-semibold tracking-tight text-white">{g.name}</h2>
            <p className="muted mt-1.5 text-sm">{g.tagline}</p>
          </div>
          {g.plans.length === 0 ? (
            <p className="muted card px-5 py-6 text-sm">No plans for this Lua right now.</p>
          ) : (
            <ul className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
              {g.plans.map((p) => (
                <li key={p.id}>
                  <Card className="flex h-full flex-col p-6">
                    <h3 className="text-lg font-medium text-white">{p.name}</h3>
                    <p className="mt-3 flex items-baseline gap-2"><span className="text-3xl font-semibold tracking-tight text-white">{p.price}</span><span className="muted text-sm">{p.duration}</span></p>
                    {p.description && <p className="muted mt-3 text-sm leading-relaxed">{p.description}</p>}
                    <div className="mt-auto space-y-2 pt-6">
                      <Method plan={p} kind="card" busy={busy} onPay={pay} />
                      <Method plan={p} kind="crypto" busy={busy} onPay={pay} />
                      {error?.plan === p.id && <p role="alert" className="rounded-lg border border-red-400/25 bg-red-500/[0.07] px-3 py-2 text-sm text-red-200">{error.text}</p>}
                    </div>
                  </Card>
                </li>
              ))}
            </ul>
          )}
        </section>
      ))}
    </div>
  );
}

function Method({ plan, kind, busy, onPay }: { plan: PlanView; kind: "card" | "crypto"; busy: string | null; onPay: (p: PlanView, k: "card" | "crypto") => void }) {
  const state = plan[kind];
  const Icon = kind === "card" ? CreditCard : Bitcoin;
  const label = kind === "card" ? "Pay with card" : "Pay with crypto";
  if (state !== "ok") {
    return (
      <div>
        <button type="button" disabled className="btn-ghost w-full"><Icon size={16} aria-hidden="true" />{label}</button>
        <p className="mt-1 text-xs text-[color:var(--faint)]">{NOTE[state]}</p>
      </div>
    );
  }
  const mine = busy === `${plan.id}:${kind}`;
  return (
    <button type="button" disabled={busy !== null} onClick={() => onPay(plan, kind)} className={kind === "card" ? "btn-primary w-full" : "btn-ghost w-full"}>
      <Icon size={16} aria-hidden="true" />{mine ? "Opening payment page..." : label}
    </button>
  );
}
