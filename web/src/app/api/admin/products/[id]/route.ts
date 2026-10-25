import { adminOnly } from "@/lib/admin-http";
import { productSchema, updateProduct } from "@/lib/admin";
import { api, body, json } from "@/lib/http";
import { productParam } from "@/lib/config-api";

export const dynamic = "force-dynamic";

export const PUT = api<{ id: string }>(async (req, { params }) => {
  const admin = await adminOnly(req);
  const input = await body(req, productSchema, 60 * 1024);
  await updateProduct(admin.id, productParam.parse(params.id), input);
  return json({ ok: true });
});
