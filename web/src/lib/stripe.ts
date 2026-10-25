import { createHmac } from "node:crypto";
import { site } from "@/config/site";
import { ApiError } from "./configs";
import { safeEqual } from "./crypto";

// Stripe over plain fetch (no SDK). Amounts always come from the database plan, never from the client.

export function stripeConfigured(): boolean {
  return !!(process.env.STRIPE_SECRET_KEY?.trim() && process.env.STRIPE_WEBHOOK_SECRET?.trim());
}

const apiBase = () => (process.env.STRIPE_API_BASE?.trim() || "https://api.stripe.com").replace(/\/+$/, "");

export type CheckoutOrder = { id: string; email: string | null };
export type CheckoutPlan = { name: string; price_cents: number; currency: string };
export type CheckoutSession = { id: string; url: string; payment_intent?: string | null };

export async function createCheckoutSession(order: CheckoutOrder, plan: CheckoutPlan, now = Date.now()): Promise<CheckoutSession> {
  const key = process.env.STRIPE_SECRET_KEY?.trim();
  if (!key) throw new ApiError(503, "provider_not_configured", "Card payments are not available right now.");
  const form = new URLSearchParams();
  form.set("mode", "payment");
  form.set("line_items[0][quantity]", "1");
  form.set("line_items[0][price_data][currency]", plan.currency);
  form.set("line_items[0][price_data][unit_amount]", String(plan.price_cents));
  form.set("line_items[0][price_data][product_data][name]", plan.name);
  form.set("client_reference_id", order.id);
  form.set("metadata[order_id]", order.id);
  form.set("success_url", `${site.url}/order/${order.id}`);
  form.set("cancel_url", `${site.url}/pricing`);
  if (order.email) form.set("customer_email", order.email);
  // Stripe wants at least 30 minutes; one more minute keeps a small clock difference from failing the call.
  form.set("expires_at", String(Math.floor(now / 1000) + 31 * 60));

  const ctl = new AbortController();
  const timer = setTimeout(() => ctl.abort(), 15_000);
  let res: Response;
  try {
    res = await fetch(`${apiBase()}/v1/checkout/sessions`, {
      method: "POST",
      headers: { authorization: `Bearer ${key}`, "content-type": "application/x-www-form-urlencoded", "idempotency-key": order.id },
      body: form.toString(),
      signal: ctl.signal,
      cache: "no-store",
    });
  } catch {
    throw new ApiError(502, "provider_unreachable", "The card payment provider could not be reached. Try again in a moment.");
  } finally {
    clearTimeout(timer);
  }
  let data: { id?: string; url?: string; payment_intent?: string | null; error?: { message?: string } } | null = null;
  try {
    data = await res.json();
  } catch {
    /* no body */
  }
  if (!res.ok || !data?.id || !data.url) {
    console.error("stripe checkout failed", res.status, data?.error?.message ?? "");
    throw new ApiError(502, "provider_error", "The card payment could not be started. Try again in a moment.");
  }
  return { id: data.id, url: data.url, payment_intent: typeof data.payment_intent === "string" ? data.payment_intent : null };
}

// Stripe-Signature: t=<unix>,v1=<hex>[,v1=<hex>...]; the signed text is `${t}.${rawBody}`.
export function verifyStripeSignature(rawBody: string, header: string | null | undefined, secret: string, toleranceSec = 300, nowMs = Date.now()): boolean {
  if (!header || !secret) return false;
  let t = "";
  const sigs: string[] = [];
  for (const part of header.split(",")) {
    const i = part.indexOf("=");
    if (i < 0) continue;
    const k = part.slice(0, i).trim();
    const v = part.slice(i + 1).trim();
    if (k === "t") t = v;
    else if (k === "v1") sigs.push(v);
  }
  if (!/^\d+$/.test(t) || sigs.length === 0) return false;
  if (Math.abs(nowMs / 1000 - Number(t)) > toleranceSec) return false;
  const expected = createHmac("sha256", secret).update(`${t}.${rawBody}`).digest("hex");
  return sigs.some((s) => safeEqual(s.toLowerCase(), expected));
}

export function signStripePayload(rawBody: string, secret: string, nowMs = Date.now()): string {
  const t = Math.floor(nowMs / 1000);
  return `t=${t},v1=${createHmac("sha256", secret).update(`${t}.${rawBody}`).digest("hex")}`;
}
