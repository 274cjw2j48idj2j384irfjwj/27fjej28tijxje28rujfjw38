import { z } from "zod";
import { assertSameOrigin, requireUser } from "@/lib/authz";
import { decideDevice, lookupUserCode } from "@/lib/devices";
import { api, body, json } from "@/lib/http";
import { rateLimit } from "@/lib/rate-limit";
import { audit } from "@/lib/audit";
import { ApiError } from "@/lib/configs";

export const dynamic = "force-dynamic";

const schema = z.object({ user_code: z.string().min(4).max(20), approve: z.boolean().optional(), check: z.boolean().optional() });

// Step 2, on the website: the signed in user looks at the code (check) and approves or denies it.
export const POST = api(async (req) => {
  assertSameOrigin(req);
  const user = await requireUser();
  await rateLimit(`dev-approve:${user.id}`, 15, 600); // the code is short, so guessing is slowed down
  const input = await body(req, schema, 1024);
  if (input.check) {
    const p = await lookupUserCode(input.user_code);
    if (!p) throw new ApiError(404, "code_not_found", "The code is wrong, used or expired.");
    return json({ product: p.product_id, client: p.client_name, expiresAt: p.expires_at });
  }
  const approve = input.approve !== false;
  const p = await decideDevice(input.user_code, user.id, approve);
  await audit(user.id, approve ? "device.approve" : "device.deny", "device", "", { product: p.product_id });
  return json({ ok: true, approved: approve, product: p.product_id });
});
