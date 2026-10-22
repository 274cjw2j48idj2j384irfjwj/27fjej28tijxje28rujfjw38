import { createHmac } from "node:crypto";
import { site } from "@/config/site";
import { ApiError } from "./configs";
import { safeEqual } from "./crypto";

export function nowpaymentsConfigured(): boolean {
  return !!(process.env.NOWPAYMENTS_API_KEY?.trim() && process.env.NOWPAYMENTS_IPN_SECRET?.trim());
}

const apiBase = () => (process.env.NOWPAYMENTS_API_BASE?.trim() || "https://api.nowpayments.io/v1").replace(/\/+$/, "");

export type CheckoutOrder = { id: string };
export type CheckoutPlan = { name: string; price_cents: number; currency: string };

// NOWPayments takes the price in major units (12.5), the database keeps cents.
export function centsToMajor(cents: number): number {
  return Number((cents / 100).toFixed(2));
}

export async function createInvoice(order: CheckoutOrder, plan: CheckoutPlan): Promise<{ id: string; invoice_url: string }> {
  const key = process.env.NOWPAYMENTS_API_KEY?.trim();
  if (!key) throw new ApiError(503, "provider_not_configured", "Crypto payments are not available right now.");
  const ctl = new AbortController();
  const timer = setTimeout(() => ctl.abort(), 15_000);
  let res: Response;
  try {
    res = await fetch(`${apiBase()}/invoice`, {
      method: "POST",
      headers: { "x-api-key": key, "content-type": "application/json" },
      body: JSON.stringify({
        price_amount: centsToMajor(plan.price_cents),
        price_currency: plan.currency,
        order_id: order.id,
        order_description: `${plan.name} (order ${order.id.slice(0, 8)})`,
        ipn_callback_url: `${site.url}/api/webhooks/nowpayments`,
        success_url: `${site.url}/order/${order.id}`,
        cancel_url: `${site.url}/pricing`,
      }),
      signal: ctl.signal,
      cache: "no-store",
    });
  } catch {
    throw new ApiError(502, "provider_unreachable", "The crypto payment provider could not be reached. Try again in a moment.");
  } finally {
    clearTimeout(timer);
  }
  let data: { id?: string | number; invoice_url?: string; message?: string } | null = null;
  try {
    data = await res.json();
  } catch {
    /* no body */
  }
  if (!res.ok || data?.id === undefined || !data.invoice_url) {
    console.error("nowpayments invoice failed", res.status, data?.message ?? "");
    throw new ApiError(502, "provider_error", "The crypto payment could not be started. Try again in a moment.");
  }
  return { id: String(data.id), invoice_url: data.invoice_url };
}

// Keys sorted alphabetically at every nesting level (arrays keep their order).
export function sortKeysRecursively(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(sortKeysRecursively);
  if (value && typeof value === "object") {
    const out: Record<string, unknown> = {};
    for (const k of Object.keys(value as Record<string, unknown>).sort()) out[k] = sortKeysRecursively((value as Record<string, unknown>)[k]);
    return out;
  }
  return value;
}

export function nowpaymentsSignature(parsedBody: unknown, secret: string): string {
  return createHmac("sha512", secret).update(JSON.stringify(sortKeysRecursively(parsedBody))).digest("hex");
}

export function verifyNowpaymentsSignature(parsedBody: unknown, header: string | null | undefined, secret: string): boolean {
  if (!header || !secret) return false;
  return safeEqual(header.trim().toLowerCase(), nowpaymentsSignature(parsedBody, secret));
}
