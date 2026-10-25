import { z } from "zod";
import { assertSameOrigin, currentUser } from "@/lib/authz";
import { api, body, json } from "@/lib/http";
import { attachProvider, createOrder, failOrder } from "@/lib/orders";
import { createInvoice } from "@/lib/nowpayments";
import { createCheckoutSession } from "@/lib/stripe";
import { clientIp, rateLimit } from "@/lib/rate-limit";

export const dynamic = "force-dynamic";

const schema = z.object({
  plan: z.string().trim().min(1).max(60),
  provider: z.enum(["card", "crypto"]),
  email: z.string().trim().toLowerCase().email().max(200).optional().or(z.literal("").transform(() => undefined)),
});

// The price is read from the database plan; the request can only pick which plan and which method.
export const POST = api(async (req) => {
  assertSameOrigin(req);
  const input = await body(req, schema, 4096);
  await rateLimit(`checkout:ip:${clientIp(req.headers)}`, 10, 600);
  const user = await currentUser();
  if (user && !user.suspended) await rateLimit(`checkout:user:${user.id}`, 10, 600);
  const provider = input.provider === "card" ? "stripe" : "nowpayments";
  const { order, plan } = await createOrder(input.plan, provider, input.email ?? null, user && !user.suspended ? user.id : null);
  try {
    if (provider === "stripe") {
      const s = await createCheckoutSession({ id: order.id, email: order.email }, plan);
      await attachProvider(order.id, s.id, s.payment_intent ?? null);
      return json({ orderId: order.id, url: s.url }, 201);
    }
    const inv = await createInvoice({ id: order.id }, plan);
    await attachProvider(order.id, inv.id, null);
    return json({ orderId: order.id, url: inv.invoice_url }, 201);
  } catch (err) {
    await failOrder(order.id, err instanceof Error ? err.message : "Could not start the payment.");
    throw err;
  }
});
