import { requireToken } from "@/lib/authz";
import { myConfigs } from "@/lib/configs";
import { api, json } from "@/lib/http";
import { publicConfig } from "@/lib/config-api";

export const dynamic = "force-dynamic";

// "My Uploads": all configs of the user for the Lua of the token, private ones included.
export const GET = api(async (req) => {
  const auth = await requireToken(req, "configs:read");
  const items = (await myConfigs(auth.userId)).filter((c) => c.product_id === auth.productId);
  return json({ items: items.map((c) => publicConfig(c, { id: auth.userId, isAdmin: false })) });
});
