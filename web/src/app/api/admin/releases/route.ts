import { adminOnly } from "@/lib/admin-http";
import { addRelease, releaseSchema } from "@/lib/admin";
import { api, body, json } from "@/lib/http";

export const dynamic = "force-dynamic";

export const POST = api(async (req) => {
  const admin = await adminOnly(req);
  const input = await body(req, releaseSchema, 20 * 1024);
  return json({ id: await addRelease(admin.id, input) }, 201);
});
