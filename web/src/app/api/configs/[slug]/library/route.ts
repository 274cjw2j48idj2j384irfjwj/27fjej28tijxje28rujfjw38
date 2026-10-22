import { assertSameOrigin, isAdmin, requireProductAccess, requireUser } from "@/lib/authz";
import { removeFromLibrary, saveToLibrary } from "@/lib/configs";
import { api, json } from "@/lib/http";
import { loadVisible } from "@/lib/config-api";

export const dynamic = "force-dynamic";

export const POST = api<{ slug: string }>(async (req, { params }) => {
  assertSameOrigin(req);
  const user = await requireUser();
  const cfg = await loadVisible(params.slug, { id: user.id, isAdmin: isAdmin(user) });
  await requireProductAccess(user.id, cfg.product_id);
  await saveToLibrary(user.id, cfg.id);
  return json({ saved: true, version: cfg.latest_version });
});

export const DELETE = api<{ slug: string }>(async (req, { params }) => {
  assertSameOrigin(req);
  const user = await requireUser();
  const cfg = await loadVisible(params.slug, { id: user.id, isAdmin: isAdmin(user) });
  await removeFromLibrary(user.id, cfg.id);
  return json({ saved: false });
});
