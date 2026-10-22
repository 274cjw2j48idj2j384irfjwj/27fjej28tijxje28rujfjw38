import type { Metadata } from "next";
import { Gift } from "lucide-react";
import { PricingGroups, type LuaGroup, type PlanView } from "@/components/payments/pricing";
import { EmptyState, PageHeader, ButtonLink } from "@/components/ui";
import { getProducts } from "@/config/site";
import { providerConfigured } from "@/lib/orders";
import { durationLabel, formatMoney, luaOfLicensePlan } from "@/lib/plan-format";
import { listPlans } from "@/lib/plans";

export const dynamic = "force-dynamic";
export const metadata: Metadata = { title: "Pricing" };

const STEPS = [
  ["Pay", "Choose a plan and pay by card or crypto."],
  ["Get your Invoice ID", "It is shown on your order page the moment the payment is confirmed. Save it."],
  ["Register in Discord", "In the Specter Discord run /register key:<your Invoice ID>."],
  ["Download", "Run /download in Discord to get the loader."],
  ["Load it", "Start the loader in your game and enter the same Invoice ID."],
];

export default async function PricingPage() {
  const plans = await listPlans(true);
  const card = providerConfigured("stripe");
  const crypto = providerConfigured("nowpayments");
  const view = (p: (typeof plans)[number]): PlanView => ({
    id: p.id, slug: p.slug, name: p.name, description: p.description, price: formatMoney(p.price_cents, p.currency), duration: durationLabel(p.duration),
    card: !p.card_enabled ? "off" : card ? "ok" : "unconfigured", crypto: !p.crypto_enabled ? "off" : crypto ? "ok" : "unconfigured",
  });
  const groups: LuaGroup[] = getProducts()
    .map((pr) => ({ id: pr.id, name: pr.name, tagline: pr.tagline, plans: plans.filter((p) => luaOfLicensePlan(p.license_plan) === pr.id).map(view) }))
    .filter((g) => g.plans.length > 0);

  return (
    <div className="space-y-16 pb-4">
      <PageHeader eyebrow="Pricing" title="Get a Specter license">
        Pay once per plan. Your license key, the Invoice ID, is created right after the payment is confirmed.
      </PageHeader>

      {groups.length === 0 ? (
        <EmptyState title="No plans on sale right now" icon={<Gift size={28} aria-hidden="true" />} action={<ButtonLink href="/support" variant="ghost" small>Ask on Discord</ButtonLink>}>
          The team has not published any plan yet. Check back soon or ask in the Discord.
        </EmptyState>
      ) : (
        <PricingGroups groups={groups} />
      )}

      <section aria-labelledby="how">
        <h2 id="how" className="mb-6 text-2xl font-semibold tracking-tight text-white">How it works</h2>
        <ol className="grid gap-4 sm:grid-cols-2 lg:grid-cols-5">
          {STEPS.map(([title, text], i) => (
            <li key={title} className="card p-5">
              <span className="flex size-7 items-center justify-center rounded-full border border-violet-400/40 bg-violet-500/15 text-xs font-medium text-violet-200">{i + 1}</span>
              <p className="mt-3 text-sm font-medium text-white">{title}</p>
              <p className="muted mt-1.5 text-sm leading-relaxed">{text}</p>
            </li>
          ))}
        </ol>
      </section>
    </div>
  );
}
