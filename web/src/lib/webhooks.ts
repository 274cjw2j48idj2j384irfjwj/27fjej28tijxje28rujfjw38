import { one, query } from "./db";
import { closePending, getOrder, markReview, refundOrder, settleOrder, type Order } from "./orders";

export type WebhookResult = { handled: boolean; note: string };

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export async function eventSeen(provider: string, eventId: string): Promise<boolean> {
  return !!(await one("select 1 from payment_events where provider = $1 and event_id = $2", [provider, eventId]));
}

// Recorded only after the event was processed: a retry of an event that failed is processed again.
export async function recordEvent(provider: string, eventId: string): Promise<void> {
  await query("insert into payment_events (provider, event_id) values ($1,$2) on conflict do nothing", [provider, eventId]);
}

async function orderByPayment(provider: string, payment: unknown): Promise<Order | null> {
  if (typeof payment !== "string" || !payment) return null;
  return one<Order>("select * from orders where provider = $1 and provider_payment = $2", [provider, payment]);
}

type Obj = Record<string, unknown>;
const str = (v: unknown): string => (typeof v === "string" ? v : "");

// ---- Stripe -------------------------------------------------------------------------------------------------------

export async function handleStripeEvent(event: { id?: string; type?: string; data?: { object?: Obj } }): Promise<WebhookResult> {
  const obj = (event.data?.object ?? {}) as Obj;
  switch (event.type) {
    case "checkout.session.completed":
    case "checkout.session.async_payment_succeeded": {
      if (obj.payment_status !== "paid") return { handled: false, note: "not paid yet" };
      const orderId = str(obj.client_reference_id);
      const order = UUID.test(orderId) ? await getOrder(orderId) : null;
      if (!order || order.provider !== "stripe") return { handled: false, note: "unknown order" };
      if (order.status === "issued" || order.status === "refunded") return { handled: true, note: order.status };
      if (order.provider_ref !== str(obj.id)) {
        await markReview(order.id, "Stripe session id does not match the order.");
        return { handled: true, note: "session mismatch" };
      }
      if (obj.amount_total !== order.amount_cents || str(obj.currency).toLowerCase() !== order.currency) {
        await markReview(order.id, `Amount mismatch: paid ${String(obj.amount_total)} ${str(obj.currency)}, expected ${order.amount_cents} ${order.currency}.`);
        return { handled: true, note: "amount mismatch" };
      }
      await settleOrder(order.id, { provider_payment: str(obj.payment_intent) || null });
      return { handled: true, note: "settled" };
    }
    case "checkout.session.expired":
    case "checkout.session.async_payment_failed": {
      const orderId = str(obj.client_reference_id);
      const order = UUID.test(orderId) ? await getOrder(orderId) : null;
      if (!order || order.provider !== "stripe" || order.provider_ref !== str(obj.id)) return { handled: false, note: "unknown order" };
      const expired = event.type === "checkout.session.expired";
      await closePending(order.id, expired ? "expired" : "failed", expired ? "The checkout session expired." : "The payment failed.");
      return { handled: true, note: expired ? "expired" : "failed" };
    }
    case "charge.refunded":
    case "charge.dispute.created": {
      // A partial refund keeps the license; a full refund and any dispute revoke it.
      if (event.type === "charge.refunded" && obj.refunded !== true) return { handled: false, note: "partial refund" };
      const order = await orderByPayment("stripe", obj.payment_intent);
      if (!order) return { handled: false, note: "unknown payment" };
      await refundOrder(order.id);
      return { handled: true, note: "refunded" };
    }
    default:
      return { handled: false, note: "ignored" };
  }
}

// ---- NOWPayments --------------------------------------------------------------------------------------------------

export async function handleNowpaymentsEvent(body: Obj): Promise<WebhookResult> {
  const status = str(body.payment_status);
  const paymentId = body.payment_id === undefined || body.payment_id === null ? "" : String(body.payment_id);
  const orderId = str(body.order_id);
  const order = UUID.test(orderId) ? await getOrder(orderId) : null;
  if (!order || order.provider !== "nowpayments") return { handled: false, note: "unknown order" };
  switch (status) {
    case "finished": {
      if (order.status === "issued" || order.status === "refunded") return { handled: true, note: order.status };
      const price = Number(body.price_amount);
      const paid = body.actually_paid === undefined || body.actually_paid === null ? null : Number(body.actually_paid);
      const due = body.pay_amount === undefined || body.pay_amount === null ? null : Number(body.pay_amount);
      let problem = "";
      if (!Number.isFinite(price) || Math.round(price * 100) !== order.amount_cents || str(body.price_currency).toLowerCase() !== order.currency) {
        problem = `Amount mismatch: ${String(body.price_amount)} ${str(body.price_currency)}, expected ${order.amount_cents / 100} ${order.currency}.`;
      } else if (paid !== null && due !== null && (!Number.isFinite(paid) || !Number.isFinite(due) || paid < due)) {
        problem = `Underpaid: ${String(body.actually_paid)} of ${String(body.pay_amount)}.`;
      } else if (body.invoice_id !== undefined && body.invoice_id !== null && order.provider_ref && String(body.invoice_id) !== order.provider_ref) {
        problem = "Invoice id does not match the order.";
      }
      if (problem) {
        await markReview(order.id, problem);
        return { handled: true, note: "mismatch" };
      }
      await settleOrder(order.id, { provider_payment: paymentId || null });
      return { handled: true, note: "settled" };
    }
    case "partially_paid":
      await markReview(order.id, `Partially paid: ${String(body.actually_paid)} of ${String(body.pay_amount)} ${str(body.pay_currency)}.`);
      return { handled: true, note: "review" };
    case "failed":
    case "expired":
      await closePending(order.id, status, `NOWPayments reported ${status}.`);
      return { handled: true, note: status };
    case "refunded":
      await refundOrder(order.id);
      return { handled: true, note: "refunded" };
    default:
      return { handled: false, note: "ignored" };
  }
}
