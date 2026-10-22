import { json } from "@/lib/http";
import { verifyStripeSignature } from "@/lib/stripe";
import { eventSeen, handleStripeEvent, recordEvent } from "@/lib/webhooks";

export const dynamic = "force-dynamic";

// Stripe calls this; only the signature counts (no cookies, no origin check). The RAW body is what is signed.
export async function POST(req: Request): Promise<Response> {
  const secret = process.env.STRIPE_WEBHOOK_SECRET?.trim() ?? "";
  const raw = await req.text();
  if (!secret || !verifyStripeSignature(raw, req.headers.get("stripe-signature"), secret)) return json({ error: { code: "bad_signature", message: "Bad signature." } }, 400);
  let event: { id?: string; type?: string; data?: { object?: Record<string, unknown> } };
  try {
    event = JSON.parse(raw);
  } catch {
    return json({ error: { code: "bad_json", message: "Bad body." } }, 400);
  }
  const id = typeof event.id === "string" ? event.id : "";
  if (!id) return json({ error: { code: "bad_event", message: "No event id." } }, 400);
  try {
    if (await eventSeen("stripe", id)) return json({ received: true, duplicate: true });
    const res = await handleStripeEvent(event);
    await recordEvent("stripe", id);
    return json({ received: true, ...res });
  } catch (err) {
    console.error("stripe webhook failed", event.type, id, err instanceof Error ? err.message : "");
    return json({ error: { code: "processing_failed", message: "Could not process the event, retry later." } }, 500);
  }
}
