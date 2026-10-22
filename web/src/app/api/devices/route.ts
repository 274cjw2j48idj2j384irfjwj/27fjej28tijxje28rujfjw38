import { requireUser } from "@/lib/authz";
import { listDevices } from "@/lib/devices";
import { api, json } from "@/lib/http";

export const dynamic = "force-dynamic";

export const GET = api(async () => {
  const user = await requireUser();
  return json({ devices: (await listDevices(user.id)).map((d) => ({ id: d.id, product: d.product_id, name: d.name, createdAt: d.created_at, lastUsedAt: d.last_used_at, expiresAt: d.expires_at })) });
});
