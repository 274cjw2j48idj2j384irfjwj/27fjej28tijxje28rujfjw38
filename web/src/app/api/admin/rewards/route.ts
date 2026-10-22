import { adminOnly } from "@/lib/admin-http";
import { recentRewards } from "@/lib/admin";
import { api, json } from "@/lib/http";

export const dynamic = "force-dynamic";

export const GET = api(async (req) => {
  await adminOnly(req);
  return json({ rewards: await recentRewards(150) });
});
