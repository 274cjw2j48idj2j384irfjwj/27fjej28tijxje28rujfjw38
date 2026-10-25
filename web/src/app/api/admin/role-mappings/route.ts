import { z } from "zod";
import { adminOnly } from "@/lib/admin-http";
import { addRoleMapping, listRoleMappings, removeRoleMapping, roleSchema } from "@/lib/admin";
import { api, body, json } from "@/lib/http";

export const dynamic = "force-dynamic";

export const GET = api(async (req) => {
  await adminOnly(req);
  return json({ mappings: await listRoleMappings() });
});

export const POST = api(async (req) => {
  const admin = await adminOnly(req);
  const input = await body(req, roleSchema, 2048);
  await addRoleMapping(admin.id, input.product, input.role_id, input.label);
  return json({ ok: true }, 201);
});

export const DELETE = api(async (req) => {
  const admin = await adminOnly(req);
  const input = await body(req, z.object({ id: z.string().uuid() }), 1024);
  await removeRoleMapping(admin.id, input.id);
  return json({ ok: true });
});
