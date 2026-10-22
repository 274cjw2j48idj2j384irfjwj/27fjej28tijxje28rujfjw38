import { adminOnly } from "@/lib/admin-http";
import { searchUsers } from "@/lib/admin";
import { api, json } from "@/lib/http";

export const dynamic = "force-dynamic";

export const GET = api(async (req) => {
  await adminOnly(req);
  const q = new URL(req.url).searchParams.get("q")?.trim() ?? "";
  return json({ users: await searchUsers(q) });
});
