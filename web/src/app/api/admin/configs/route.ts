import { adminOnly } from "@/lib/admin-http";
import { listAdminConfigs } from "@/lib/admin-configs";
import { api, json } from "@/lib/http";

export const dynamic = "force-dynamic";

// Moderation list: every config, hidden and private ones included.
export const GET = api(async (req) => {
  await adminOnly(req);
  const sp = new URL(req.url).searchParams;
  return json(await listAdminConfigs({ q: sp.get("q") ?? "", product: sp.get("product") ?? "", page: Number(sp.get("page") ?? 1) }));
});
