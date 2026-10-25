import { adminOnly } from "@/lib/admin-http";
import { recentAudit } from "@/lib/admin";
import { api, json } from "@/lib/http";

export const dynamic = "force-dynamic";

export const GET = api(async (req) => {
  await adminOnly(req);
  return json({ entries: await recentAudit(150) });
});
