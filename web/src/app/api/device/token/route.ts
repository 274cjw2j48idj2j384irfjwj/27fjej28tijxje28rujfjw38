import { z } from "zod";
import { pollDevice } from "@/lib/devices";
import { api, body, json } from "@/lib/http";
import { clientIp, rateLimit } from "@/lib/rate-limit";

export const dynamic = "force-dynamic";

const schema = z.object({ device_code: z.string().min(10).max(100) });

// Step 3, polled by the Lua every `interval` seconds until it gets the token (once).
export const POST = api(async (req) => {
  await rateLimit(`dev-poll:${clientIp(req.headers)}`, 120, 600);
  const input = await body(req, schema, 1024);
  const r = await pollDevice(input.device_code);
  if (r.status === "approved") return json({ status: "approved", access_token: r.token, token_type: "Bearer", scope: r.scopes.join(" "), product: r.productId, expires_at: r.expiresAt });
  return json({ status: r.status }, r.status === "invalid" ? 400 : 200);
});
