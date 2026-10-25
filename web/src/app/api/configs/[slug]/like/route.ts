import { assertSameOrigin, isAdmin, requireUser } from "@/lib/authz";
import { toggleLike } from "@/lib/configs";
import { api, json } from "@/lib/http";
import { loadVisible } from "@/lib/config-api";
import { rateLimit } from "@/lib/rate-limit";

export const dynamic = "force-dynamic";

export const POST = api<{ slug: string }>(async (req, { params }) => {
  assertSameOrigin(req);
  const user = await requireUser();
  await rateLimit(`like:${user.id}`, 60, 60);
  const cfg = await loadVisible(params.slug, { id: user.id, isAdmin: isAdmin(user) });
  return json(await toggleLike(user.id, cfg.id));
});
