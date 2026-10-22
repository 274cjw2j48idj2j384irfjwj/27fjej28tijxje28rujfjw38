import { requireToken, accessOf } from "@/lib/authz";
import { one } from "@/lib/db";
import { api, json } from "@/lib/http";

export const dynamic = "force-dynamic";

export const GET = api(async (req) => {
  const auth = await requireToken(req, "library:read");
  const u = await one<{ username: string; global_name: string | null }>("select username, global_name from users where id = $1", [auth.userId]);
  const access = await accessOf(auth.userId, auth.productId);
  return json({ user: u?.global_name || u?.username, product: auth.productId, access: { status: access.status, expiresAt: access.expiresAt, integrationError: access.integrationError } });
});

