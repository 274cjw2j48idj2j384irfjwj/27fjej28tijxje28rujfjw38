import { one, query, tx } from "./db";
import { ApiError } from "./configs";
import { createLicense, licenseServerConfigured, LicenseServerError, revokeLicense } from "./license-server";
import { findPlan, type Plan } from "./plans";
import { nowpaymentsConfigured } from "./nowpayments";
import { stripeConfigured } from "./stripe";

export type Provider = "stripe" | "nowpayments" | "manual";
export type OrderStatus = "pending" | "paid" | "issued" | "expired" | "failed" | "review" | "refunded";

export type Order = {
  id: string; plan_id: string; plan_snapshot: { name: string; license_plan: string; duration: string; price_cents: number; currency: string };
  provider: Provider; provider_ref: string | null; provider_payment: string | null; amount_cents: number; currency: string; status: OrderStatus;
  license_key: string | null; email: string | null; user_id: string | null; last_error: string | null; admin_note: string | null; issue_attempts: number;
  created_at: Date; paid_at: Date | null; issued_at: Date | null; revoked_at: Date | null;
};

export const MAX_ISSUE_ATTEMPTS = 20;

export function providerConfigured(p: "stripe" | "nowpayments"): boolean {
  return (p === "stripe" ? stripeConfigured() : nowpaymentsConfigured()) && licenseServerConfigured();
}

export async function createOrder(planKey: string, provider: "stripe" | "nowpayments", email: string | null, userId: string | null): Promise<{ order: Order; plan: Plan }> {
  const plan = await findPlan(planKey);
  if (!plan || !plan.active) throw new ApiError(404, "plan_not_found", "This plan is not available.");
  const enabled = provider === "stripe" ? plan.card_enabled : plan.crypto_enabled;
  if (!enabled) throw new ApiError(409, "method_disabled", `${provider === "stripe" ? "Card" : "Crypto"} payment is not offered for this plan.`);
  if (!providerConfigured(provider)) throw new ApiError(503, "provider_not_configured", `${provider === "stripe" ? "Card" : "Crypto"} payments are not available right now.`);
  const snapshot = { name: plan.name, license_plan: plan.license_plan, duration: plan.duration, price_cents: plan.price_cents, currency: plan.currency };
  const order = await one<Order>(
    `insert into orders (plan_id, plan_snapshot, provider, amount_cents, currency, email, user_id)
     values ($1,$2,$3,$4,$5,$6,$7) returning *`,
    [plan.id, JSON.stringify(snapshot), provider, plan.price_cents, plan.currency, email, userId],
  );
  return { order: order!, plan };
}

export async function getOrder(id: string): Promise<Order | null> {
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(id)) return null;
  return one<Order>("select * from orders where id = $1", [id.toLowerCase()]);
}

export async function attachProvider(orderId: string, ref: string, payment: string | null): Promise<void> {
  await query("update orders set provider_ref = $2, provider_payment = coalesce($3, provider_payment) where id = $1", [orderId, ref, payment]);
}

export async function failOrder(orderId: string, error: string): Promise<void> {
  await query("update orders set status = 'failed', last_error = $2 where id = $1 and status = 'pending'", [orderId, error.slice(0, 300)]);
}

// pending -> expired / failed (a provider said so); never touches an order that was paid.
export async function closePending(orderId: string, status: "expired" | "failed", reason: string): Promise<boolean> {
  const row = await one("update orders set status = $2, last_error = $3 where id = $1 and status = 'pending' returning id", [orderId, status, reason.slice(0, 300)]);
  return !!row;
}

// A payment that does not match the order (amount, currency, session) is held for a human: nothing is issued.
export async function markReview(orderId: string, reason: string): Promise<void> {
  await query("update orders set status = 'review', last_error = $2 where id = $1 and status in ('pending','paid','expired','failed') and license_key is null", [orderId, reason.slice(0, 300)]);
}

type Settle = { provider_payment?: string | null; manual?: boolean };

// Paid -> license. Phase 1 (row lock): record the payment. Phase 2 (no DB transaction): ask the license server, `ref` = order id
// makes it idempotent, so a parallel delivery gets the same key. Phase 3: store the key.
export async function settleOrder(orderId: string, opts: Settle = {}): Promise<Order> {
  const phase1 = await tx(async (db) => {
    const o = (await db.query<Order>("select * from orders where id = $1 for update", [orderId])).rows[0];
    if (!o) throw new ApiError(404, "order_not_found", "Order not found.");
    if (o.status === "issued" || o.status === "refunded") return { order: o, go: false };
    const allowed = o.status === "pending" || o.status === "paid" || (opts.manual && (o.status === "review" || o.status === "expired" || o.status === "failed"));
    if (!allowed) {
      // A confirmed payment for an order we had given up on: keep the money visible, a human decides.
      if (!opts.manual && (o.status === "expired" || o.status === "failed")) {
        const r = (await db.query<Order>("update orders set status='review', last_error=$2, provider_payment=coalesce($3, provider_payment) where id=$1 returning *", [orderId, `Payment confirmed for an order that was ${o.status}.`, opts.provider_payment ?? null])).rows[0];
        return { order: r, go: false };
      }
      return { order: o, go: false };
    }
    const r = (await db.query<Order>(
      `update orders set status='paid', paid_at=coalesce(paid_at, now()), provider_payment=coalesce($2, provider_payment), last_error=null where id=$1 returning *`,
      [orderId, opts.provider_payment ?? null],
    )).rows[0];
    return { order: r, go: true };
  });
  if (!phase1.go) return phase1.order;
  return issueLicense(phase1.order);
}

async function issueLicense(o: Order): Promise<Order> {
  let key: string;
  try {
    const lic = await createLicense({ plan: o.plan_snapshot.license_plan, duration: o.plan_snapshot.duration, note: `web order ${o.id}`, ref: o.id });
    key = lic.key;
  } catch (err) {
    const msg = err instanceof LicenseServerError ? err.message : "License creation failed.";
    await query("update orders set issue_attempts = issue_attempts + 1, last_error = $2 where id = $1 and status = 'paid'", [o.id, msg.slice(0, 300)]);
    throw new ApiError(502, "license_unavailable", msg);
  }
  const done = await one<Order>("update orders set license_key = $2, status = 'issued', issued_at = now(), last_error = null where id = $1 and status = 'paid' returning *", [o.id, key]);
  if (done) return done;
  const now = (await getOrder(o.id))!;
  // Refunded while the key was being made: the key must not stay alive.
  if (now.status === "refunded") {
    await revokeLicense(key).catch((e) => console.error("revoke after refund failed", o.id, e instanceof Error ? e.message : ""));
    await query("update orders set license_key = coalesce(license_key, $2), revoked_at = now() where id = $1", [o.id, key]);
  }
  return (await getOrder(o.id))!;
}

// Refund / dispute: status 'refunded' and the key is revoked on the license server. Safe to call again.
export async function refundOrder(orderId: string): Promise<Order> {
  const o = await tx(async (db) => {
    const cur = (await db.query<Order>("select * from orders where id = $1 for update", [orderId])).rows[0];
    if (!cur) throw new ApiError(404, "order_not_found", "Order not found.");
    if (cur.status === "refunded") return cur;
    return (await db.query<Order>("update orders set status='refunded' where id=$1 returning *", [orderId])).rows[0];
  });
  if (o.license_key && !o.revoked_at) {
    try {
      await revokeLicense(o.license_key);
    } catch (err) {
      const msg = err instanceof LicenseServerError ? err.message : "Revoke failed.";
      await query("update orders set last_error = $2 where id = $1", [orderId, `Revoke failed: ${msg}`.slice(0, 300)]);
      throw new ApiError(502, "license_unavailable", `Marked refunded, but the key could not be revoked: ${msg}`);
    }
    return (await one<Order>("update orders set revoked_at = now(), last_error = null where id = $1 returning *", [orderId]))!;
  }
  return o;
}

export async function retryPaidOrders(): Promise<number> {
  const rows = await query<{ id: string }>(
    "select id from orders where status = 'paid' and issue_attempts < $1 and paid_at < now() - interval '1 minute' order by paid_at limit 50",
    [MAX_ISSUE_ATTEMPTS],
  );
  let issued = 0;
  for (const r of rows) {
    try {
      if ((await settleOrder(r.id)).status === "issued") issued++;
    } catch (err) {
      console.error("retry issue failed", r.id, err instanceof Error ? err.message : "");
    }
  }
  return issued;
}

export async function expirePending(): Promise<number> {
  const rows = await query("update orders set status='expired', last_error='No payment within 24 hours.' where status='pending' and created_at < now() - interval '24 hours' returning id");
  return rows.length;
}

export type OrderPublic = {
  id: string; status: OrderStatus; plan_name: string; duration: string; amount_cents: number; currency: string; provider: Provider;
  created_at: Date; paid_at: Date | null; issued_at: Date | null; license_key: string | null;
};

export function toPublic(o: Order): OrderPublic {
  return {
    id: o.id, status: o.status, plan_name: o.plan_snapshot.name, duration: o.plan_snapshot.duration, amount_cents: o.amount_cents, currency: o.currency,
    provider: o.provider, created_at: o.created_at, paid_at: o.paid_at, issued_at: o.issued_at,
    license_key: o.status === "issued" ? o.license_key : null, // never before it is issued
  };
}

export async function getOrderPublic(id: string): Promise<OrderPublic | null> {
  const o = await getOrder(id);
  return o ? toPublic(o) : null;
}

export async function ordersOfUser(userId: string): Promise<OrderPublic[]> {
  const rows = await query<Order>("select * from orders where user_id = $1 order by created_at desc limit 100", [userId]);
  return rows.map(toPublic);
}
