import { assertSameOrigin, isAdmin, requireProductAccess, requireUser } from "@/lib/authz";
import { ApiError, compatFor, recordEvent } from "@/lib/configs";
import { api, json } from "@/lib/http";
import { loadVisible } from "@/lib/config-api";

export const dynamic = "force-dynamic";

// The short import code is the share id: the Lua asks the cloud for it, and shows name, author and compatibility before it imports.
export const POST = api<{ slug: string }>(async (req, { params }) => {
  assertSameOrigin(req);
  const user = await requireUser();
  const cfg = await loadVisible(params.slug, { id: user.id, isAdmin: isAdmin(user) });
  await requireProductAccess(user.id, cfg.product_id);
  const compat = await compatFor(cfg.id, cfg.latest_version);
  if (compat && !compat.ok) throw new ApiError(409, "incompatible", `This config version is not compatible (${compat.reason}).`);
  await recordEvent(cfg.id, user.id, "import_code");
  return json({ code: cfg.slug, product: cfg.product_id });
});
