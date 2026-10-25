import { adminOnly } from "@/lib/admin-http";
import { addMediaUrl, mediaSchema } from "@/lib/admin";
import { api, body, json } from "@/lib/http";

export const dynamic = "force-dynamic";

export const POST = api(async (req) => {
  const admin = await adminOnly(req);
  const input = await body(req, mediaSchema, 4096);
  return json({ id: await addMediaUrl(admin.id, input) }, 201);
});
