import { adminOnly } from "@/lib/admin-http";
import { moderateConfig, moderationSchema } from "@/lib/admin";
import { api, body, json } from "@/lib/http";

export const dynamic = "force-dynamic";

export const POST = api<{ id: string }>(async (req, { params }) => {
  const admin = await adminOnly(req);
  const input = await body(req, moderationSchema, 1024);
  await moderateConfig(admin.id, params.id, input.action);
  return json({ ok: true });
});
