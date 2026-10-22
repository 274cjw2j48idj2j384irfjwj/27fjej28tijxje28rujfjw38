import type { Metadata } from "next";
import Link from "next/link";
import { ShoppingBag } from "lucide-react";
import { CopyButton } from "@/components/dashboard/copy-button";
import { OrderStatusBadge } from "@/components/payments/status";
import { ButtonLink, Card, EmptyState, PageHeader, formatDate } from "@/components/ui";
import { requireDashboardUser } from "@/lib/dashboard-data";
import { ordersOfUser } from "@/lib/orders";
import { PROVIDER_LABEL, durationLabel, formatMoney } from "@/lib/plan-format";

export const dynamic = "force-dynamic";
export const metadata: Metadata = { title: "Orders" };

export default async function OrdersPage() {
  const user = await requireDashboardUser("/dashboard/orders");
  const orders = await ordersOfUser(user.id);
  return (
    <div className="space-y-8">
      <PageHeader eyebrow="Dashboard" title="Orders" actions={<ButtonLink href="/pricing" small>Buy a plan</ButtonLink>}>
        Your purchases. The Invoice ID of a finished order is your license key: use it with /register in Discord. Orders you made while signed out are not listed here, open their order link instead.
      </PageHeader>
      {orders.length === 0 ? (
        <EmptyState title="No orders yet" icon={<ShoppingBag size={28} aria-hidden="true" />} action={<ButtonLink href="/pricing" variant="ghost" small>See the plans</ButtonLink>}>
          When you buy a plan while signed in, it shows up here.
        </EmptyState>
      ) : (
        <ul className="space-y-3">
          {orders.map((o) => (
            <li key={o.id}>
              <Card className="p-5">
                <div className="flex flex-wrap items-start justify-between gap-3">
                  <div className="min-w-0">
                    <h2 className="font-medium text-white">{o.plan_name}</h2>
                    <p className="muted mt-1 text-sm">{formatMoney(o.amount_cents, o.currency)} · {durationLabel(o.duration)} · {PROVIDER_LABEL[o.provider] ?? o.provider} · {formatDate(o.created_at, true)}</p>
                  </div>
                  <OrderStatusBadge status={o.status} />
                </div>
                {o.license_key ? (
                  <div className="mt-4 flex flex-col gap-2 sm:flex-row sm:items-center">
                    <code className="min-w-0 flex-1 select-all break-all rounded-xl border border-line bg-ink-900/80 px-3.5 py-2.5 font-mono text-sm text-white">{o.license_key}</code>
                    <CopyButton text={o.license_key} label="Copy Invoice ID" />
                  </div>
                ) : null}
                <p className="mt-3 text-xs"><Link href={`/order/${o.id}`} className="text-violet-300 underline">Open order page</Link></p>
              </Card>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
