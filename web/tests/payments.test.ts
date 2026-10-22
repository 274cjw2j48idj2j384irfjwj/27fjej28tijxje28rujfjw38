import { afterAll, beforeEach, describe, expect, it, vi } from "vitest";

const jar = { value: "" as string | undefined };
vi.mock("next/headers", () => ({
  cookies: async () => ({ get: (name: string) => (name === "specter_session" && jar.value ? { value: jar.value } : undefined) }),
}));

process.env.PUBLIC_URL = "http://localhost:3000";
process.env.CRON_SECRET = "c".repeat(32);
process.env.STRIPE_SECRET_KEY = "sk_test_abc";
process.env.STRIPE_WEBHOOK_SECRET = "whsec_test_secret";
process.env.STRIPE_API_BASE = "https://stripe.test";
process.env.NOWPAYMENTS_API_KEY = "np_key";
process.env.NOWPAYMENTS_IPN_SECRET = "np_ipn_secret";
process.env.NOWPAYMENTS_API_BASE = "https://np.test/v1";
process.env.LICENSE_SERVER_URL = "https://license.test";
process.env.LICENSE_ADMIN_SECRET = "admin-secret";

import { POST as checkoutPost } from "@/app/api/checkout/route";
import { GET as orderGet } from "@/app/api/orders/[id]/route";
import { POST as stripeHook } from "@/app/api/webhooks/stripe/route";
import { POST as npHook } from "@/app/api/webhooks/nowpayments/route";
import { GET as plansGet, POST as plansPost } from "@/app/api/admin/plans/route";
import { PUT as planPut, DELETE as planDelete } from "@/app/api/admin/plans/[id]/route";
import { GET as ordersGet } from "@/app/api/admin/orders/route";
import { POST as orderAction } from "@/app/api/admin/orders/[id]/route";
import { POST as cronPost } from "@/app/api/cron/close-month/route";
import { createPlan, type Plan } from "@/lib/plans";
import { getOrder, retryPaidOrders } from "@/lib/orders";
import { createSession } from "@/lib/sessions";
import { sortKeysRecursively, nowpaymentsSignature, verifyNowpaymentsSignature } from "@/lib/nowpayments";
import { signStripePayload, verifyStripeSignature } from "@/lib/stripe";
import { createHmac } from "node:crypto";
import { one, query } from "@/lib/db";
import { done, mkUser, resetDb } from "./helpers";

const ORIGIN = "http://localhost:3000";
const ctx = <P>(params: P) => ({ params: Promise.resolve(params) });
const WH = "whsec_test_secret";
const IPN = "np_ipn_secret";

// ---- mocked outside world ------------------------------------------------------------------------------------------
const world = {
  keys: new Map<string, string>(), // ref -> key
  creates: [] as any[], revoked: [] as string[], licenseDown: false, busyOnce: false, stripe: [] as { body: URLSearchParams; headers: Record<string, string> }[], np: [] as any[], providerDown: false,
};
let seq = 0;
beforeEach(() => {
  world.keys.clear(); world.creates = []; world.revoked = []; world.licenseDown = false; world.busyOnce = false; world.stripe = []; world.np = []; world.providerDown = false; seq = 0;
  vi.stubGlobal("fetch", async (input: any, init: any = {}) => {
    const url = String(input);
    const headers = Object.fromEntries(Object.entries(init.headers ?? {}).map(([k, v]) => [k.toLowerCase(), String(v)]));
    const reply = (status: number, data: unknown) => new Response(JSON.stringify(data), { status, headers: { "content-type": "application/json" } });
    if (url.startsWith("https://license.test")) {
      if (headers["x-admin-secret"] !== "admin-secret") return reply(401, { error: "unauthorized" });
      if (world.licenseDown) throw new Error("connect ECONNREFUSED");
      const b = JSON.parse(init.body);
      if (url.endsWith("/admin/create")) {
        if (world.busyOnce) { world.busyOnce = false; return reply(409, { error: "busy" }); }
        world.creates.push(b);
        await Promise.resolve();
        const existing = world.keys.has(b.ref);
        if (!existing) world.keys.set(b.ref, `KEY${String(++seq).padStart(2, "0")}-AAAAAA-BBBBBB-CCCCCC`);
        return reply(200, { key: world.keys.get(b.ref), plan: b.plan, expires_at: 1, note: b.note, existing });
      }
      if (url.endsWith("/admin/revoke")) { world.revoked.push(b.key); return reply(200, { revoked: b.key }); }
    }
    if (url === "https://stripe.test/v1/checkout/sessions") {
      if (world.providerDown) return reply(500, { error: { message: "boom" } });
      world.stripe.push({ body: new URLSearchParams(init.body), headers });
      return reply(200, { id: `cs_test_${world.stripe.length}`, url: `https://checkout.stripe.test/c/${world.stripe.length}`, payment_intent: null });
    }
    if (url === "https://np.test/v1/invoice") {
      world.np.push({ body: JSON.parse(init.body), headers });
      return reply(200, { id: `inv_${world.np.length}`, invoice_url: `https://nowpayments.test/payment/?iid=${world.np.length}` });
    }
    throw new Error("unexpected fetch " + url);
  });
});

function req(url: string, init: { method?: string; body?: unknown; headers?: Record<string, string>; origin?: string | null; raw?: string } = {}) {
  const headers: Record<string, string> = { "content-type": "application/json", ...(init.headers ?? {}) };
  if (init.origin !== null && init.method && init.method !== "GET") headers.origin = init.origin ?? ORIGIN;
  return new Request(`${ORIGIN}${url}`, { method: init.method ?? "GET", headers, body: init.raw ?? (init.body === undefined ? undefined : JSON.stringify(init.body)) });
}
const jbody = async (res: Response) => (await res.json()) as any;
async function login(userId: string) { jar.value = (await createSession(userId, "test")).token; }

let admin: { id: string };
let plan: Plan;
beforeEach(async () => {
  await resetDb();
  jar.value = undefined;
  admin = await mkUser("boss", { admin: true });
  plan = await createPlan(admin.id, { slug: "gs-30d", name: "Gamesense 30 days", description: "", license_plan: "specter", duration: "30d", price_cents: 1250, currency: "usd", active: true, sort: 0, card_enabled: true, crypto_enabled: true });
});
afterAll(done);

// ---- helpers -------------------------------------------------------------------------------------------------------
async function checkout(provider: "card" | "crypto" = "card", extra: Record<string, unknown> = {}) {
  const res = await checkoutPost(req("/api/checkout", { method: "POST", body: { plan: plan.slug, provider, ...extra } }), ctx({}));
  return { res, data: await jbody(res.clone()) };
}
function stripeReq(event: unknown, opts: { secret?: string; at?: number; tamper?: boolean } = {}) {
  const raw = JSON.stringify(event);
  const header = signStripePayload(raw, opts.secret ?? WH, opts.at ?? Date.now());
  return new Request(`${ORIGIN}/api/webhooks/stripe`, { method: "POST", headers: { "stripe-signature": header }, body: opts.tamper ? raw.replace("evt_", "evx_") : raw });
}
const session = (orderId: string, id: string, over: Record<string, unknown> = {}) => ({ id, client_reference_id: orderId, payment_status: "paid", amount_total: 1250, currency: "usd", payment_intent: "pi_1", ...over });
const ev = (type: string, object: unknown, id = "evt_" + type + "_" + Math.random().toString(36).slice(2)) => ({ id, type, data: { object } });
function npReq(body: Record<string, unknown>, secret = IPN) {
  return new Request(`${ORIGIN}/api/webhooks/nowpayments`, { method: "POST", headers: { "x-nowpayments-sig": nowpaymentsSignature(body, secret) }, body: JSON.stringify(body) });
}
const npBody = (orderId: string, over: Record<string, unknown> = {}) => ({ payment_id: 5001, payment_status: "finished", order_id: orderId, price_amount: 12.5, price_currency: "usd", pay_amount: 0.0002, actually_paid: 0.0002, invoice_id: "inv_1", ...over });
async function paidStripe(id = "evt_paid_1") {
  const { data } = await checkout("card");
  const res = await stripeHook(stripeReq(ev("checkout.session.completed", session(data.orderId, `cs_test_${world.stripe.length}`), id)));
  return { orderId: data.orderId as string, res };
}

// ---- signatures ----------------------------------------------------------------------------------------------------
describe("signatures", () => {
  const raw = '{"id":"evt_1"}';
  it("Stripe: good, wrong secret, old timestamp, tampered body, several v1", () => {
    const now = Date.now();
    const h = signStripePayload(raw, WH, now);
    expect(verifyStripeSignature(raw, h, WH, 300, now)).toBe(true);
    expect(verifyStripeSignature(raw, h, "other", 300, now)).toBe(false);
    expect(verifyStripeSignature(raw, signStripePayload(raw, WH, now - 10 * 60_000), WH, 300, now)).toBe(false);
    expect(verifyStripeSignature(raw + " ", h, WH, 300, now)).toBe(false);
    const t = Math.floor(now / 1000);
    const good = createHmac("sha256", WH).update(`${t}.${raw}`).digest("hex");
    expect(verifyStripeSignature(raw, `t=${t},v1=${"0".repeat(64)},v1=${good}`, WH, 300, now)).toBe(true);
    expect(verifyStripeSignature(raw, `t=${t},v1=${"0".repeat(64)},v1=bad`, WH, 300, now)).toBe(false);
    expect(verifyStripeSignature(raw, null, WH)).toBe(false);
    expect(verifyStripeSignature(raw, "garbage", WH)).toBe(false);
  });
  it("NOWPayments: keys are sorted at every level", () => {
    const body = { z: 1, a: { y: [{ d: 1, c: 2 }], b: 3 } };
    expect(JSON.stringify(sortKeysRecursively(body))).toBe('{"a":{"b":3,"y":[{"c":2,"d":1}]},"z":1}');
    const sig = createHmac("sha512", "s").update('{"a":{"b":3,"y":[{"c":2,"d":1}]},"z":1}').digest("hex");
    expect(nowpaymentsSignature(body, "s")).toBe(sig);
    expect(verifyNowpaymentsSignature({ a: { y: [{ c: 2, d: 1 }], b: 3 }, z: 1 }, sig.toUpperCase(), "s")).toBe(true);
    expect(verifyNowpaymentsSignature(body, sig, "t")).toBe(false);
    expect(verifyNowpaymentsSignature({ ...body, z: 2 }, sig, "s")).toBe(false);
  });
  it("the routes answer 400 to a bad signature and change nothing", async () => {
    const { data } = await checkout("card");
    const bad = await stripeHook(stripeReq(ev("checkout.session.completed", session(data.orderId, "cs_test_1")), { secret: "nope" }));
    expect(bad.status).toBe(400);
    const tamper = await stripeHook(stripeReq(ev("checkout.session.completed", session(data.orderId, "cs_test_1"), "evt_x"), { tamper: true }));
    expect(tamper.status).toBe(400);
    const np = await npHook(npReq(npBody(data.orderId), "wrong"));
    expect(np.status).toBe(400);
    expect((await getOrder(data.orderId))!.status).toBe("pending");
    expect(world.creates).toHaveLength(0);
  });
});

// ---- checkout ------------------------------------------------------------------------------------------------------
describe("checkout", () => {
  it("sends the database amount to Stripe, never the client's", async () => {
    const { res, data } = await checkout("card", { email: "Buyer@Example.com", price_cents: 1, amount: 1, unit_amount: 1 });
    expect(res.status).toBe(201);
    expect(data.url).toMatch(/^https:\/\/checkout\.stripe\.test\//);
    const s = world.stripe[0];
    expect(s.body.get("line_items[0][price_data][unit_amount]")).toBe("1250");
    expect(s.body.get("line_items[0][price_data][currency]")).toBe("usd");
    expect(s.body.get("client_reference_id")).toBe(data.orderId);
    expect(s.body.get("metadata[order_id]")).toBe(data.orderId);
    expect(s.body.get("customer_email")).toBe("buyer@example.com");
    expect(s.body.get("success_url")).toBe(`http://localhost:3000/order/${data.orderId}`);
    expect(s.body.get("cancel_url")).toBe("http://localhost:3000/pricing");
    expect(Number(s.body.get("expires_at"))).toBeGreaterThan(Date.now() / 1000 + 30 * 60);
    expect(s.headers["idempotency-key"]).toBe(data.orderId);
    expect(s.headers.authorization).toBe("Bearer sk_test_abc");
    const o = (await getOrder(data.orderId))!;
    expect(o.status).toBe("pending");
    expect(o.amount_cents).toBe(1250);
    expect(o.provider_ref).toBe("cs_test_1");
  });

  it("creates a NOWPayments invoice with the amount in major units", async () => {
    const { res, data } = await checkout("crypto");
    expect(res.status).toBe(201);
    expect(data.url).toContain("nowpayments.test");
    const b = world.np[0].body;
    expect(b).toMatchObject({ price_amount: 12.5, price_currency: "usd", order_id: data.orderId, ipn_callback_url: "http://localhost:3000/api/webhooks/nowpayments", success_url: `http://localhost:3000/order/${data.orderId}` });
    expect(world.np[0].headers["x-api-key"]).toBe("np_key");
    expect((await getOrder(data.orderId))!.provider_ref).toBe("inv_1");
  });

  it("a later price edit never changes an order", async () => {
    const { data } = await checkout("card");
    await query("update plans set price_cents = 9999, name = 'Renamed' where id = $1", [plan.id]);
    const o = (await getOrder(data.orderId))!;
    expect(o.amount_cents).toBe(1250);
    expect(o.plan_snapshot).toMatchObject({ name: "Gamesense 30 days", price_cents: 1250 });
  });

  it("refuses an inactive plan, an unknown plan, a disabled method, an unconfigured provider, bad input, a foreign origin", async () => {
    await query("update plans set active = false");
    expect((await checkout("card")).res.status).toBe(404);
    await query("update plans set active = true, crypto_enabled = false");
    const off = await checkout("crypto");
    expect(off.res.status).toBe(409);
    expect(off.data.error.code).toBe("method_disabled");
    await query("update plans set crypto_enabled = true");
    const saved = process.env.STRIPE_SECRET_KEY;
    delete process.env.STRIPE_SECRET_KEY;
    const nc = await checkout("card");
    process.env.STRIPE_SECRET_KEY = saved;
    expect(nc.res.status).toBe(503);
    expect(nc.data.error.code).toBe("provider_not_configured");
    expect((await checkoutPost(req("/api/checkout", { method: "POST", body: { plan: "nope", provider: "card" } }), ctx({}))).status).toBe(404);
    expect((await checkoutPost(req("/api/checkout", { method: "POST", body: { plan: plan.slug, provider: "paypal" } }), ctx({}))).status).toBe(400);
    expect((await checkoutPost(req("/api/checkout", { method: "POST", body: { plan: plan.slug, provider: "card", email: "no" } }), ctx({}))).status).toBe(400);
    expect((await checkoutPost(req("/api/checkout", { method: "POST", origin: "https://evil.example", body: { plan: plan.slug, provider: "card" } }), ctx({}))).status).toBe(403);
    expect((await one<{ n: number }>("select count(*)::int as n from orders"))!.n).toBe(0);
    expect(world.stripe).toHaveLength(0);
  });

  it("a provider failure marks the order failed and answers a clean error", async () => {
    world.providerDown = true;
    const { res, data } = await checkout("card");
    expect(res.status).toBe(502);
    expect(data.error.code).toBe("provider_error");
    const rows = await query<{ status: string }>("select status from orders");
    expect(rows).toEqual([{ status: "failed" }]);
  });

  it("links the order to the signed in user", async () => {
    const u = await mkUser("buyer");
    await login(u.id);
    const { data } = await checkout("card");
    expect((await getOrder(data.orderId))!.user_id).toBe(u.id);
  });

  it("rate limits per IP (10 per 10 minutes)", async () => {
    for (let i = 0; i < 10; i++) expect((await checkout("card")).res.status).toBe(201);
    const over = await checkout("card");
    expect(over.res.status).toBe(429);
  });
});

// ---- Stripe webhook ------------------------------------------------------------------------------------------------
describe("Stripe webhook", () => {
  it("a paid session creates exactly one license, the same event twice too", async () => {
    const { orderId, res } = await paidStripe();
    expect(res.status).toBe(200);
    const o = (await getOrder(orderId))!;
    expect(o.status).toBe("issued");
    expect(o.license_key).toMatch(/^KEY01/);
    expect(o.provider_payment).toBe("pi_1");
    expect(world.creates[0]).toEqual({ plan: "specter", duration: "30d", note: `web order ${orderId}`, ref: orderId });
    const again = await stripeHook(stripeReq(ev("checkout.session.completed", session(orderId, "cs_test_1"), "evt_paid_1")));
    expect(again.status).toBe(200);
    expect((await jbody(again)).duplicate).toBe(true);
    expect(world.creates).toHaveLength(1);
    // a second event id for the same payment (async_payment_succeeded after completed) must not make a second key either
    await stripeHook(stripeReq(ev("checkout.session.async_payment_succeeded", session(orderId, "cs_test_1"), "evt_paid_2")));
    expect(world.keys.size).toBe(1);
    expect((await getOrder(orderId))!.license_key).toBe(o.license_key);
  });

  it("5 parallel deliveries make one license", async () => {
    const { data } = await checkout("card");
    const results = await Promise.all(
      [1, 2, 3, 4, 5].map((i) => stripeHook(stripeReq(ev("checkout.session.completed", session(data.orderId, "cs_test_1"), i <= 3 ? "evt_same" : "evt_other_" + i)))),
    );
    expect(results.every((r) => r.status === 200)).toBe(true);
    expect(world.keys.size).toBe(1);
    const o = (await getOrder(data.orderId))!;
    expect(o.status).toBe("issued");
    expect([...world.keys.values()]).toEqual([o.license_key]);
  });

  it("an unpaid session is waited for, not issued", async () => {
    const { data } = await checkout("card");
    await stripeHook(stripeReq(ev("checkout.session.completed", session(data.orderId, "cs_test_1", { payment_status: "unpaid" }))));
    expect((await getOrder(data.orderId))!.status).toBe("pending");
    await stripeHook(stripeReq(ev("checkout.session.async_payment_succeeded", session(data.orderId, "cs_test_1"))));
    expect((await getOrder(data.orderId))!.status).toBe("issued");
  });

  it("amount, currency or session mismatch goes to review and issues nothing", async () => {
    for (const over of [{ amount_total: 100 }, { currency: "eur" }, { id: "cs_other" }]) {
      const { data } = await checkout("card");
      const id = (over as any).id ?? "cs_test_" + world.stripe.length;
      const res = await stripeHook(stripeReq(ev("checkout.session.completed", session(data.orderId, id, over))));
      expect(res.status).toBe(200);
      const o = (await getOrder(data.orderId))!;
      expect(o.status).toBe("review");
      expect(o.last_error).toBeTruthy();
      expect(o.license_key).toBeNull();
    }
    expect(world.creates).toHaveLength(0);
  });

  it("license server down: order stays paid, the webhook answers 500, a retry issues exactly one key", async () => {
    world.licenseDown = true;
    const { data } = await checkout("card");
    const e = ev("checkout.session.completed", session(data.orderId, "cs_test_1"), "evt_down");
    const res = await stripeHook(stripeReq(e));
    expect(res.status).toBe(500);
    let o = (await getOrder(data.orderId))!;
    expect(o.status).toBe("paid");
    expect(o.issue_attempts).toBe(1);
    expect(o.last_error).toBeTruthy();
    expect(o.license_key).toBeNull();
    // the event was not recorded, so Stripe's retry is processed
    world.licenseDown = false;
    const retry = await stripeHook(stripeReq(e));
    expect(retry.status).toBe(200);
    o = (await getOrder(data.orderId))!;
    expect(o.status).toBe("issued");
    expect(world.keys.size).toBe(1);
  });

  it("the cron retry issues a paid order after the license server is back, once", async () => {
    world.licenseDown = true;
    const { data } = await checkout("card");
    await stripeHook(stripeReq(ev("checkout.session.completed", session(data.orderId, "cs_test_1"))));
    world.licenseDown = false;
    expect(await retryPaidOrders()).toBe(0); // younger than a minute
    await query("update orders set paid_at = now() - interval '2 minutes'");
    const cron = await cronPost(req("/api/cron/close-month", { method: "POST", headers: { authorization: `Bearer ${"c".repeat(32)}` } }), ctx({}));
    expect(await jbody(cron)).toMatchObject({ issued: 1, expired: 0 });
    expect((await getOrder(data.orderId))!.status).toBe("issued");
    expect(world.keys.size).toBe(1);
    expect(await retryPaidOrders()).toBe(0);
  });

  it("a busy answer of the license server is retried", async () => {
    world.busyOnce = true;
    const { orderId } = await paidStripe();
    expect((await getOrder(orderId))!.status).toBe("issued");
  });

  it("refund and dispute revoke the key; partial refunds and repeats do nothing more", async () => {
    const { orderId } = await paidStripe();
    const key = (await getOrder(orderId))!.license_key!;
    const partial = await stripeHook(stripeReq(ev("charge.refunded", { id: "ch_1", payment_intent: "pi_1", refunded: false, amount_refunded: 100 })));
    expect(partial.status).toBe(200);
    expect((await getOrder(orderId))!.status).toBe("issued");
    expect(world.revoked).toEqual([]);
    const full = await stripeHook(stripeReq(ev("charge.refunded", { id: "ch_1", payment_intent: "pi_1", refunded: true })));
    expect(full.status).toBe(200);
    expect((await getOrder(orderId))!.status).toBe("refunded");
    expect(world.revoked).toEqual([key]);
    await stripeHook(stripeReq(ev("charge.dispute.created", { id: "dp_1", payment_intent: "pi_1" })));
    expect(world.revoked).toEqual([key]);
    // a late "paid" event cannot bring a refunded order back
    await stripeHook(stripeReq(ev("checkout.session.completed", session(orderId, "cs_test_1"))));
    expect((await getOrder(orderId))!.status).toBe("refunded");
  });

  it("a dispute revokes", async () => {
    const { orderId } = await paidStripe();
    await stripeHook(stripeReq(ev("charge.dispute.created", { id: "dp_1", payment_intent: "pi_1" })));
    expect((await getOrder(orderId))!.status).toBe("refunded");
    expect(world.revoked).toHaveLength(1);
  });

  it("a failed revoke answers 500 and the retry revokes", async () => {
    const { orderId } = await paidStripe();
    const key = (await getOrder(orderId))!.license_key!;
    world.licenseDown = true;
    const e = ev("charge.refunded", { payment_intent: "pi_1", refunded: true }, "evt_ref");
    expect((await stripeHook(stripeReq(e))).status).toBe(500);
    expect((await getOrder(orderId))!.status).toBe("refunded");
    world.licenseDown = false;
    expect((await stripeHook(stripeReq(e))).status).toBe(200);
    expect(world.revoked).toEqual([key]);
    expect((await getOrder(orderId))!.revoked_at).not.toBeNull();
  });

  it("expired and failed sessions close a pending order only", async () => {
    const a = (await checkout("card")).data.orderId;
    await stripeHook(stripeReq(ev("checkout.session.expired", session(a, "cs_test_1", { payment_status: "unpaid" }))));
    expect((await getOrder(a))!.status).toBe("expired");
    const b = (await checkout("card")).data.orderId;
    await stripeHook(stripeReq(ev("checkout.session.async_payment_failed", session(b, "cs_test_2", { payment_status: "unpaid" }))));
    expect((await getOrder(b))!.status).toBe("failed");
    const { orderId } = await paidStripe("evt_p");
    await stripeHook(stripeReq(ev("checkout.session.expired", session(orderId, "cs_test_3", { payment_status: "unpaid" }))));
    expect((await getOrder(orderId))!.status).toBe("issued");
  });

  it("a payment for an order that had expired goes to review, not to a key", async () => {
    const { data } = await checkout("card");
    await query("update orders set status = 'expired'");
    await stripeHook(stripeReq(ev("checkout.session.completed", session(data.orderId, "cs_test_1"))));
    expect((await getOrder(data.orderId))!.status).toBe("review");
    expect(world.creates).toHaveLength(0);
  });

  it("unknown orders and unknown events are acknowledged with 200", async () => {
    const r1 = await stripeHook(stripeReq(ev("checkout.session.completed", session("00000000-0000-4000-8000-000000000000", "cs_x"))));
    expect(r1.status).toBe(200);
    const r2 = await stripeHook(stripeReq(ev("checkout.session.completed", session("not-a-uuid", "cs_x"))));
    expect(r2.status).toBe(200);
    const r3 = await stripeHook(stripeReq(ev("customer.created", { id: "cus_1" })));
    expect(r3.status).toBe(200);
    const r4 = await stripeHook(stripeReq(ev("charge.refunded", { payment_intent: "pi_unknown", refunded: true })));
    expect(r4.status).toBe(200);
    expect(world.creates).toHaveLength(0);
  });
});

// ---- NOWPayments ---------------------------------------------------------------------------------------------------
describe("NOWPayments webhook", () => {
  it("finished issues one license, repeated and parallel deliveries too", async () => {
    const { data } = await checkout("crypto");
    const results = await Promise.all([1, 2, 3].map(() => npHook(npReq(npBody(data.orderId)))));
    expect(results.every((r) => r.status === 200)).toBe(true);
    const o = (await getOrder(data.orderId))!;
    expect(o.status).toBe("issued");
    expect(o.provider_payment).toBe("5001");
    expect(world.keys.size).toBe(1);
    expect(world.creates[0].ref).toBe(data.orderId);
    expect((await jbody(await npHook(npReq(npBody(data.orderId))))).duplicate).toBe(true);
  });

  it("waiting / confirming / sending are ignored", async () => {
    const { data } = await checkout("crypto");
    for (const s of ["waiting", "confirming", "confirmed", "sending"]) expect((await npHook(npReq(npBody(data.orderId, { payment_status: s })))).status).toBe(200);
    expect((await getOrder(data.orderId))!.status).toBe("pending");
  });

  it("wrong price, wrong currency, underpaid and partially_paid go to review", async () => {
    for (const over of [{ price_amount: 1.5 }, { price_currency: "eur" }, { actually_paid: 0.0001 }, { payment_status: "partially_paid", actually_paid: 0.0001 }]) {
      const { data } = await checkout("crypto");
      expect((await npHook(npReq(npBody(data.orderId, { payment_id: 7000 + world.np.length, ...over, invoice_id: "inv_" + world.np.length })))).status).toBe(200);
      const o = (await getOrder(data.orderId))!;
      expect(o.status).toBe("review");
      expect(o.license_key).toBeNull();
    }
    expect(world.creates).toHaveLength(0);
  });

  it("price compare works on cents (12.50 as a string, float noise)", async () => {
    const { data } = await checkout("crypto");
    await npHook(npReq(npBody(data.orderId, { price_amount: "12.50" })));
    expect((await getOrder(data.orderId))!.status).toBe("issued");
  });

  it("failed / expired close a pending order, refunded revokes", async () => {
    const a = (await checkout("crypto")).data.orderId;
    await npHook(npReq(npBody(a, { payment_status: "failed", payment_id: 1 })));
    expect((await getOrder(a))!.status).toBe("failed");
    const b = (await checkout("crypto")).data.orderId;
    await npHook(npReq(npBody(b, { payment_status: "expired", payment_id: 2, invoice_id: "inv_2" })));
    expect((await getOrder(b))!.status).toBe("expired");
    const c = (await checkout("crypto")).data.orderId;
    await npHook(npReq(npBody(c, { payment_id: 3, invoice_id: "inv_3" })));
    const key = (await getOrder(c))!.license_key;
    await npHook(npReq(npBody(c, { payment_id: 3, payment_status: "refunded", invoice_id: "inv_3" })));
    expect((await getOrder(c))!.status).toBe("refunded");
    expect(world.revoked).toEqual([key]);
  });

  it("unknown order is acknowledged; a Stripe order cannot be settled through the IPN", async () => {
    expect((await npHook(npReq(npBody("00000000-0000-4000-8000-000000000000")))).status).toBe(200);
    const { data } = await checkout("card");
    await npHook(npReq(npBody(data.orderId)));
    expect((await getOrder(data.orderId))!.status).toBe("pending");
  });
});

// ---- order page endpoint -------------------------------------------------------------------------------------------
describe("GET /api/orders/[id]", () => {
  it("never shows the key before the order is issued", async () => {
    const { data } = await checkout("card");
    for (const status of ["pending", "paid", "review", "failed", "expired", "refunded"]) {
      await query("update orders set status = $1, license_key = 'SECRET-KEY-VALUE'", [status]);
      const res = await orderGet(req(`/api/orders/${data.orderId}`), ctx({ id: data.orderId }));
      const text = await res.text();
      expect(text).not.toContain("SECRET-KEY-VALUE");
      expect(JSON.parse(text).order.license_key).toBeNull();
      expect(res.headers.get("cache-control")).toBe("no-store");
    }
    await query("update orders set status = 'issued'");
    const ok = await jbody(await orderGet(req(`/api/orders/${data.orderId}`), ctx({ id: data.orderId })));
    expect(ok.order.license_key).toBe("SECRET-KEY-VALUE");
    expect(ok.order.plan_name).toBe("Gamesense 30 days");
    expect(ok.order.email).toBeUndefined();
  });
  it("404 for an unknown or malformed id", async () => {
    expect((await orderGet(req("/api/orders/x"), ctx({ id: "x" }))).status).toBe(404);
    expect((await orderGet(req("/api/orders/u"), ctx({ id: "00000000-0000-4000-8000-000000000000" }))).status).toBe(404);
  });
});

// ---- expiry --------------------------------------------------------------------------------------------------------
describe("expiry", () => {
  it("pending orders older than 24 h expire through the cron", async () => {
    const old = (await checkout("card")).data.orderId;
    const fresh = (await checkout("card")).data.orderId;
    await query("update orders set created_at = now() - interval '25 hours' where id = $1", [old]);
    const cron = await jbody(await cronPost(req("/api/cron/close-month", { method: "POST", headers: { authorization: `Bearer ${"c".repeat(32)}` } }), ctx({})));
    expect(cron.expired).toBe(1);
    expect((await getOrder(old))!.status).toBe("expired");
    expect((await getOrder(fresh))!.status).toBe("pending");
  });
});

// ---- admin ---------------------------------------------------------------------------------------------------------
describe("admin plans and orders", () => {
  const input = { slug: "pm-lifetime", name: "Primordial lifetime", description: "x", license_plan: "pm_nightly", duration: "lifetime", price_cents: 4900, currency: "usd", active: true, sort: 2, card_enabled: true, crypto_enabled: false };

  it("need an admin", async () => {
    expect((await plansGet(req("/api/admin/plans"), ctx({}))).status).toBe(401);
    const u = await mkUser("plain");
    await login(u.id);
    expect((await plansGet(req("/api/admin/plans"), ctx({}))).status).toBe(403);
    expect((await plansPost(req("/api/admin/plans", { method: "POST", body: input }), ctx({}))).status).toBe(403);
    expect((await ordersGet(req("/api/admin/orders"), ctx({}))).status).toBe(403);
    expect((await orderAction(req("/api/admin/orders/x", { method: "POST", body: { action: "refund" } }), ctx({ id: "00000000-0000-4000-8000-000000000000" }))).status).toBe(403);
    await login(admin.id);
    expect((await plansPost(req("/api/admin/plans", { method: "POST", body: input, origin: "https://evil.example" }), ctx({}))).status).toBe(403);
  });

  it("create, validate, edit and delete a plan", async () => {
    await login(admin.id);
    const bad = await plansPost(req("/api/admin/plans", { method: "POST", body: { ...input, duration: "forever" } }), ctx({}));
    expect(bad.status).toBe(400);
    expect((await plansPost(req("/api/admin/plans", { method: "POST", body: { ...input, price_cents: 0 } }), ctx({}))).status).toBe(400);
    expect((await plansPost(req("/api/admin/plans", { method: "POST", body: { ...input, license_plan: "root" } }), ctx({}))).status).toBe(400);
    const made = await jbody(await plansPost(req("/api/admin/plans", { method: "POST", body: input }), ctx({})));
    expect(made.plan.slug).toBe("pm-lifetime");
    expect((await plansPost(req("/api/admin/plans", { method: "POST", body: input }), ctx({}))).status).toBe(409);
    const put = await jbody(await planPut(req(`/api/admin/plans/${made.plan.id}`, { method: "PUT", body: { ...input, price_cents: 5900 } }), ctx({ id: made.plan.id })));
    expect(put.plan.price_cents).toBe(5900);
    const list = await jbody(await plansGet(req("/api/admin/plans"), ctx({})));
    expect(list.plans.map((p: any) => p.slug).sort()).toEqual(["gs-30d", "pm-lifetime"]);
    const del = await jbody(await planDelete(req(`/api/admin/plans/${made.plan.id}`, { method: "DELETE" }), ctx({ id: made.plan.id })));
    expect(del).toEqual({ deleted: true, deactivated: false });
    // a plan with orders is only deactivated
    await checkout("card");
    const d2 = await jbody(await planDelete(req(`/api/admin/plans/${plan.id}`, { method: "DELETE" }), ctx({ id: plan.id })));
    expect(d2).toEqual({ deleted: false, deactivated: true });
    expect((await one<{ active: boolean }>("select active from plans where id = $1", [plan.id]))!.active).toBe(false);
    expect((await one<{ n: number }>("select count(*)::int n from audit_log where action like 'plan.%'"))!.n).toBeGreaterThanOrEqual(4);
  });

  it("lists and searches orders", async () => {
    const u = await mkUser("searchme");
    await login(u.id);
    const a = (await checkout("card", { email: "alice@example.com" })).data.orderId;
    jar.value = undefined;
    const b = (await checkout("crypto")).data.orderId;
    await login(admin.id);
    const all = await jbody(await ordersGet(req("/api/admin/orders"), ctx({})));
    expect(all.total).toBe(2);
    expect((await jbody(await ordersGet(req("/api/admin/orders?q=alice"), ctx({})))).items.map((o: any) => o.id)).toEqual([a]);
    expect((await jbody(await ordersGet(req("/api/admin/orders?q=searchme"), ctx({})))).items.map((o: any) => o.id)).toEqual([a]);
    expect((await jbody(await ordersGet(req(`/api/admin/orders?q=${b.slice(0, 8)}`), ctx({})))).items.map((o: any) => o.id)).toEqual([b]);
    expect((await jbody(await ordersGet(req("/api/admin/orders?status=issued"), ctx({})))).total).toBe(0);
    expect((await jbody(await ordersGet(req("/api/admin/orders?q=%25"), ctx({})))).total).toBe(0);
  });

  it("issue retries a paid order; mark_paid needs a reason; refund revokes; note stores text; all are audited", async () => {
    world.licenseDown = true;
    const { data } = await checkout("card");
    await stripeHook(stripeReq(ev("checkout.session.completed", session(data.orderId, "cs_test_1"))));
    world.licenseDown = false;
    await login(admin.id);
    const act = async (id: string, action: string, reason?: string) => orderAction(req(`/api/admin/orders/${id}`, { method: "POST", body: { action, reason } }), ctx({ id }));
    expect((await act(data.orderId, "mark_paid", "x")).status).toBe(400);
    expect((await act(data.orderId, "mark_paid", "valid reason here")).status).toBe(409); // paid is not markable
    const issued = await jbody(await act(data.orderId, "issue"));
    expect(issued.order.status).toBe("issued");
    expect((await act(data.orderId, "issue")).status).toBe(409);

    const crypto = (await checkout("crypto")).data.orderId;
    expect((await act(crypto, "mark_paid")).status).toBe(400);
    const mp = await jbody(await act(crypto, "mark_paid", "paid by hand, tx confirmed"));
    expect(mp.order.status).toBe("issued");
    expect(mp.order.admin_note).toContain("tx confirmed");
    expect(world.keys.size).toBe(2);

    const note = await jbody(await act(crypto, "note", "customer wrote on discord"));
    expect(note.order.admin_note).toBe("customer wrote on discord");

    const refunded = await jbody(await act(crypto, "refund"));
    expect(refunded.order.status).toBe("refunded");
    expect(world.revoked).toEqual([mp.order.license_key]);
    expect((await act(crypto, "refund")).status).toBe(200);
    expect(world.revoked).toHaveLength(1);

    const log = await query<{ action: string }>("select action from audit_log where action like 'order.%' order by created_at");
    expect(log.map((l) => l.action)).toEqual(expect.arrayContaining(["order.issue", "order.mark_paid", "order.note", "order.refund"]));
    expect((await act("00000000-0000-4000-8000-000000000000", "refund")).status).toBe(404);
  });
});
