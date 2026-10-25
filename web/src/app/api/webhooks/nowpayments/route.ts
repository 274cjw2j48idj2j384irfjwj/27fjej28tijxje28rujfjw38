import { json } from "@/lib/http";
import { verifyNowpaymentsSignature } from "@/lib/nowpayments";
import { eventSeen, handleNowpaymentsEvent, recordEvent } from "@/lib/webhooks";

export const dynamic = "force-dynamic";

// NOWPayments IPN: the signature (HMAC-SHA512 of the key sorted JSON) is the only authentication.
export async function POST(req: Request): Promise<Response> {
  const secret = process.env.NOWPAYMENTS_IPN_SECRET?.trim() ?? "";
  const raw = await req.text();
  let body: Record<string, unknown>;
  try {
    const parsed = JSON.parse(raw);
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) throw new Error("not an object");
    body = parsed;
  } catch {
    return json({ error: { code: "bad_json", message: "Bad body." } }, 400);
  }
  if (!secret || !verifyNowpaymentsSignature(body, req.headers.get("x-nowpayments-sig"), secret)) return json({ error: { code: "bad_signature", message: "Bad signature." } }, 400);
  const eventId = `${body.payment_id ?? ""}:${body.payment_status ?? ""}`;
  try {
    if (await eventSeen("nowpayments", eventId)) return json({ received: true, duplicate: true });
    const res = await handleNowpaymentsEvent(body);
    await recordEvent("nowpayments", eventId);
    return json({ received: true, ...res });
  } catch (err) {
    console.error("nowpayments webhook failed", eventId, err instanceof Error ? err.message : "");
    return json({ error: { code: "processing_failed", message: "Could not process the event, retry later." } }, 500);
  }
}
