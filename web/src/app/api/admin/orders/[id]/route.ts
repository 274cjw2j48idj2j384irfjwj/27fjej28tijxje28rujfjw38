import { z } from "zod";
import { adminOnly } from "@/lib/admin-http";
import { runOrderAction } from "@/lib/admin-orders";
import { ApiError } from "@/lib/configs";
import { api, body, json } from "@/lib/http";

export const dynamic = "force-dynamic";

const schema = z.object({
  action: z.enum(["issue", "mark_paid", "refund", "note"]),
  reason: z.string().trim().max(300).optional(),
});

export const POST = api<{ id: string }>(async (req, { params }) => {
  const admin = await adminOnly(req);
  if (!z.string().uuid().safeParse(params.id).success) throw new ApiError(404, "not_found", "Order not found.");
  const input = await body(req, schema, 2048);
  return json({ order: await runOrderAction(admin.id, params.id, input.action, input.reason ?? "") });
});
