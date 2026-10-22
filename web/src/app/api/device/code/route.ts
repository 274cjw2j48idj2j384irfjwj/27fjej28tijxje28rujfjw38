import { z } from "zod";
import { site } from "@/config/site";
import { startDeviceFlow } from "@/lib/devices";
import { api, body, json } from "@/lib/http";
import { productParam } from "@/lib/config-api";
import { clientIp, rateLimit } from "@/lib/rate-limit";

export const dynamic = "force-dynamic";

const schema = z.object({ product: productParam, client_name: z.string().max(60).optional() });

// Step 1, called by the Lua: shows the user code, the user approves it on the website.
export const POST = api(async (req) => {
  await rateLimit(`dev-code:${clientIp(req.headers)}`, 20, 600);
  const input = await body(req, schema, 2048);
  const f = await startDeviceFlow(input.product, input.client_name ?? "");
  return json({
    device_code: f.deviceCode,
    user_code: f.userCode,
    verification_uri: `${site.url}/link`,
    verification_uri_complete: `${site.url}/link?code=${f.userCode}`,
    expires_in: f.expiresIn,
    interval: f.interval,
  });
});
