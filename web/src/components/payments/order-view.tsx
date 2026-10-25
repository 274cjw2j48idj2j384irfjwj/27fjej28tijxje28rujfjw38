"use client";

import Link from "next/link";
import { useEffect, useRef, useState } from "react";
import { AlertTriangle, Check, Circle, Loader2 } from "lucide-react";
import { CopyButton } from "@/components/dashboard/copy-button";
import { call } from "@/components/dashboard/api";
import { Card, Notice, cx } from "@/components/ui";
import { OrderStatusBadge } from "./status";
import { PROVIDER_LABEL, durationLabel, formatMoney } from "@/lib/plan-format";

export type OrderData = {
  id: string; status: string; plan_name: string; duration: string; amount_cents: number; currency: string; provider: string;
  created_at: string; paid_at: string | null; issued_at: string | null; license_key: string | null;
};

const POLL_MS = 3000;
const ACTIVE = new Set(["pending", "paid"]);

export function OrderView({ initial }: { initial: OrderData }) {
  const [order, setOrder] = useState(initial);
  const [pollError, setPollError] = useState<string | null>(null);
  const status = useRef(order.status);
  status.current = order.status;

  useEffect(() => {
    if (!ACTIVE.has(initial.status)) return;
    let stop = false;
    let timer: ReturnType<typeof setTimeout>;
    const tick = async () => {
      const res = await call<{ order: OrderData }>(`/api/orders/${initial.id}`);
      if (stop) return;
      if (res.ok && res.data?.order) {
        setPollError(null);
        setOrder(res.data.order);
        if (!ACTIVE.has(res.data.order.status)) return;
      } else if (!res.ok) {
        setPollError(res.message);
      }
      timer = setTimeout(tick, POLL_MS);
    };
    timer = setTimeout(tick, POLL_MS);
    return () => { stop = true; clearTimeout(timer); };
  }, [initial.id, initial.status]);

  return (
    <div className="mx-auto max-w-2xl space-y-6">
      <header>
        <p className="eyebrow mb-2">Order</p>
        <h1 className="text-3xl font-semibold tracking-tight text-white sm:text-4xl">{order.plan_name}</h1>
        <p className="muted mt-3 flex flex-wrap items-center gap-x-3 gap-y-2 text-sm">
          <OrderStatusBadge status={order.status} />
          <span>{formatMoney(order.amount_cents, order.currency)} · {durationLabel(order.duration)} · {PROVIDER_LABEL[order.provider] ?? order.provider}</span>
        </p>
      </header>

      <Timeline status={order.status} />

      <div aria-live="polite" className="space-y-6">
        {order.status === "issued" && order.license_key && <Invoice keyText={order.license_key} />}
        {order.status === "pending" && <Notice tone="amber">Waiting for your payment. If you already paid, this page updates by itself as soon as the provider confirms it{pollError ? "" : " (checking every few seconds)"}. Crypto payments can take a few minutes to confirm.</Notice>}
        {order.status === "paid" && <Notice tone="violet"><span className="flex items-start gap-2"><Loader2 size={16} className="mt-0.5 shrink-0 animate-spin" aria-hidden="true" />Payment confirmed. Your Invoice ID is being created, this takes a few seconds. You do not need to pay again.</span></Notice>}
        {order.status === "failed" && <Notice tone="red">The payment failed and nothing was charged for this order. You can start again from the <Link href="/pricing" className="underline">pricing page</Link>. If money left your account, contact <Link href="/support" className="underline">support</Link> with this order reference.</Notice>}
        {order.status === "expired" && <Notice tone="gray">This order expired without a payment. Start a new one from the <Link href="/pricing" className="underline">pricing page</Link>. If you did pay, contact <Link href="/support" className="underline">support</Link> with this order reference and we will fix it.</Notice>}
        {order.status === "review" && <Notice tone="amber"><span className="flex items-start gap-2"><AlertTriangle size={16} className="mt-0.5 shrink-0" aria-hidden="true" />Your payment needs a manual check, for example because the amount did not match. No key was created yet. Contact <Link href="/support" className="underline">support</Link> with the order reference below, we will sort it out or refund you.</span></Notice>}
        {order.status === "refunded" && <Notice tone="gray">This order was refunded and its license key was revoked. Questions? Contact <Link href="/support" className="underline">support</Link>.</Notice>}
        {pollError && ACTIVE.has(order.status) && <p role="alert" className="text-sm text-red-300">Could not refresh the status: {pollError} Trying again.</p>}
      </div>

      <Card className="p-5 text-sm">
        <p className="eyebrow mb-2">Order reference</p>
        <div className="flex flex-wrap items-center gap-3"><code className="break-all font-mono text-xs text-[color:var(--muted)]">{order.id}</code><CopyButton text={order.id} label="Copy reference" /></div>
        <p className="muted mt-3 text-xs">Keep this link or reference: it is how you and support find this order. Questions? <Link href="/support" className="text-violet-300 underline">Support</Link>.</p>
      </Card>
    </div>
  );
}

function Invoice({ keyText }: { keyText: string }) {
  return (
    <Card className="glow-ring p-6">
      <p className="eyebrow mb-3">Your Invoice ID</p>
      <div className="flex flex-col gap-3 sm:flex-row sm:items-center">
        <code data-testid="invoice-id" className="min-w-0 flex-1 select-all break-all rounded-xl border border-violet-400/30 bg-ink-900/80 px-4 py-3 font-mono text-base tracking-wide text-white sm:text-lg">{keyText}</code>
        <CopyButton text={keyText} label="Copy" className="btn-primary" />
      </div>
      <ol className="mt-5 list-decimal space-y-2 pl-5 text-sm leading-relaxed">
        <li>In the Specter Discord run <code className="rounded bg-white/[0.06] px-1.5 py-0.5 font-mono text-xs">/register key:{keyText}</code></li>
        <li>Then run <code className="rounded bg-white/[0.06] px-1.5 py-0.5 font-mono text-xs">/download</code> to get the loader.</li>
        <li>Start the loader and enter the same Invoice ID when it asks for your key.</li>
      </ol>
      <div className="mt-5"><Notice tone="amber"><strong className="font-medium text-amber-100">Save it now and never share it.</strong> Anyone who has this Invoice ID can use your license.</Notice></div>
    </Card>
  );
}

const STEPS = [["pending", "Payment"], ["paid", "Confirmed"], ["issued", "Invoice ID"]] as const;

function Timeline({ status }: { status: string }) {
  const finished = status === "issued" || status === "refunded";
  const at = status === "paid" ? 1 : 0; // the step that is happening now (only while pending / paid)
  const active = status === "pending" || status === "paid";
  return (
    <ol aria-label="Order progress" className="grid grid-cols-3 gap-2">
      {STEPS.map(([id, label], i) => {
        const done = finished || (active && i < at);
        const current = active && i === at;
        return (
          <li key={id} aria-current={current ? "step" : undefined} className={cx("rounded-xl border px-3 py-3 text-sm", done ? "border-emerald-400/30 bg-emerald-500/[0.07] text-emerald-100" : current ? "border-violet-400/40 bg-violet-500/[0.1] text-white" : "border-line text-[color:var(--faint)]")}>
            <span className="flex items-center gap-2">
              {done ? <Check size={14} aria-hidden="true" /> : current ? <Loader2 size={14} className="animate-spin" aria-hidden="true" /> : <Circle size={14} aria-hidden="true" />}
              <span className="sr-only">{done ? "Done: " : current ? "Now: " : "Next: "}</span>{label}
            </span>
          </li>
        );
      })}
    </ol>
  );
}
