import { adminOnly } from "@/lib/admin-http";
import { boardSchema, updateBoard } from "@/lib/admin";
import { api, body, json } from "@/lib/http";

export const dynamic = "force-dynamic";

export const PUT = api<{ id: string }>(async (req, { params }) => {
  const admin = await adminOnly(req);
  await updateBoard(admin.id, params.id, await body(req, boardSchema, 20 * 1024));
  return json({ ok: true });
});
