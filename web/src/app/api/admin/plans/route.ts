import { adminOnly } from "@/lib/admin-http";
import { api, body, json } from "@/lib/http";
import { createPlan, listPlans, planSchema } from "@/lib/plans";

export const dynamic = "force-dynamic";

export const GET = api(async (req) => {
  await adminOnly(req);
  return json({ plans: await listPlans() });
});

export const POST = api(async (req) => {
  const admin = await adminOnly(req);
  const input = await body(req, planSchema, 8192);
  return json({ plan: await createPlan(admin.id, input) }, 201);
});
