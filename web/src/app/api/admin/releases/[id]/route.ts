import { adminOnly } from "@/lib/admin-http";
import { deleteRelease } from "@/lib/admin";
import { api, json } from "@/lib/http";

export const dynamic = "force-dynamic";

export const DELETE = api<{ id: string }>(async (req, { params }) => {
  const admin = await adminOnly(req);
  await deleteRelease(admin.id, params.id);
  return json({ ok: true });
});
