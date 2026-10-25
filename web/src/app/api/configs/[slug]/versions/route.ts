import { assertSameOrigin, requireProductAccess, requireUser } from "@/lib/authz";
import { ApiError, addVersion } from "@/lib/configs";
import { api, body, json } from "@/lib/http";
import { loadVisible, versionSchema } from "@/lib/config-api";
import { audit } from "@/lib/audit";

export const dynamic = "force-dynamic";

export const POST = api<{ slug: string }>(async (req, { params }) => {
  assertSameOrigin(req);
  const user = await requireUser();
  const cfg = await loadVisible(params.slug, { id: user.id, isAdmin: false });
  if (cfg.owner_id !== user.id) throw new ApiError(404, "not_found", "Config not found.");
  await requireProductAccess(user.id, cfg.product_id);
  const input = await body(req, versionSchema);
  const v = await addVersion(cfg.id, user.id, input.payload, input.changelog);
  await audit(user.id, "config.version", "config", cfg.id, { version: v.version, via: "web" });
  return json(v, 201);
});
