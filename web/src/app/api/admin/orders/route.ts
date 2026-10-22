import { adminOnly } from "@/lib/admin-http";
import { api, json } from "@/lib/http";
import { searchOrders } from "@/lib/admin-orders";

export const dynamic = "force-dynamic";

export const GET = api(async (req) => {
  await adminOnly(req);
  const u = new URL(req.url);
  return json(await searchOrders({ q: u.searchParams.get("q") ?? "", status: u.searchParams.get("status") ?? "", page: Number(u.searchParams.get("page") ?? 1) }));
});
