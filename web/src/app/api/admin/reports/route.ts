import { adminOnly } from "@/lib/admin-http";
import { listOpenReports } from "@/lib/admin";
import { api, json } from "@/lib/http";

export const dynamic = "force-dynamic";

export const GET = api(async (req) => {
  await adminOnly(req);
  return json({ reports: await listOpenReports() });
});
