import { z } from "zod";
import { adminOnly } from "@/lib/admin-http";
import { ApiError } from "@/lib/configs";
import { api, body, json } from "@/lib/http";
import { deletePlan, planSchema, updatePlan } from "@/lib/plans";

export const dynamic = "force-dynamic";

const id = z.string().uuid();

export const PUT = api<{ id: string }>(async (req, { params }) => {
  const admin = await adminOnly(req);
  if (!id.safeParse(params.id).success) throw new ApiError(404, "not_found", "Plan not found.");
  const input = await body(req, planSchema, 8192);
  return json({ plan: await updatePlan(admin.id, params.id, input) });
});

export const DELETE = api<{ id: string }>(async (req, { params }) => {
  const admin = await adminOnly(req);
  if (!id.safeParse(params.id).success) throw new ApiError(404, "not_found", "Plan not found.");
  return json(await deletePlan(admin.id, params.id));
});
