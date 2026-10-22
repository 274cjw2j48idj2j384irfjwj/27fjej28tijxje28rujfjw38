import { requireProductAccess, requireToken } from "@/lib/authz";
import { ApiError, compatFor, getVersionPayload, recordEvent } from "@/lib/configs";
import { api, json } from "@/lib/http";
import { loadVisible } from "@/lib/config-api";

export const dynamic = "force-dynamic";

// The config data for the import. Refused when the config is for the other Lua or its format is not supported.
export const GET = api<{ slug: string }>(async (req, { params }) => {
  const auth = await requireToken(req, "configs:read");
  await requireProductAccess(auth.userId, auth.productId);
  const cfg = await loadVisible(params.slug, { id: auth.userId, isAdmin: false });
  if (cfg.product_id !== auth.productId) throw new ApiError(404, "not_found", "Config not found.");
  const asked = Number(new URL(req.url).searchParams.get("version") ?? cfg.latest_version);
  const found = await getVersionPayload(cfg.id, Number.isInteger(asked) && asked > 0 ? asked : cfg.latest_version);
  if (!found) throw new ApiError(404, "no_version", "That version does not exist.");
  const compat = await compatFor(cfg.id, found.version);
  if (compat && !compat.ok) throw new ApiError(409, "incompatible", `This config version is not compatible (${compat.reason}).`);
  await recordEvent(cfg.id, auth.userId, "client_import");
  return json({ name: cfg.name, author: cfg.owner_name, version: found.version, payload: found.payload });
});
