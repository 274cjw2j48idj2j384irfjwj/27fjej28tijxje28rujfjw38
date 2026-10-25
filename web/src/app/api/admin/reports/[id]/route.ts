import { z } from "zod";
import { adminOnly } from "@/lib/admin-http";
import { resolveReport } from "@/lib/admin";
import { api, body, json } from "@/lib/http";

export const dynamic = "force-dynamic";

export const POST = api<{ id: string }>(async (req, { params }) => {
  const admin = await adminOnly(req);
  const input = await body(req, z.object({ status: z.enum(["resolved", "dismissed"]) }), 1024);
  await resolveReport(admin.id, params.id, input.status);
  return json({ ok: true });
});
