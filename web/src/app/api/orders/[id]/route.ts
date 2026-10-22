import { ApiError } from "@/lib/configs";
import { api, json } from "@/lib/http";
import { getOrderPublic } from "@/lib/orders";
import { clientIp, rateLimit } from "@/lib/rate-limit";

export const dynamic = "force-dynamic";

// The polling endpoint of the order page. The order id is the secret; the key is only in the answer once the order is issued.
export const GET = api<{ id: string }>(async (req, { params }) => {
  await rateLimit(`order:${clientIp(req.headers)}`, 120, 60);
  const order = await getOrderPublic(params.id);
  if (!order) throw new ApiError(404, "not_found", "Order not found.");
  return json({ order });
});
