import { assertSameOrigin, requireUser } from "@/lib/authz";
import { query } from "@/lib/db";
import { api, json } from "@/lib/http";

export const dynamic = "force-dynamic";

export const POST = api(async (req) => {
  assertSameOrigin(req);
  const user = await requireUser();
  await query("update notifications set read_at = now() where user_id = $1 and read_at is null", [user.id]);
  return json({ ok: true });
});
