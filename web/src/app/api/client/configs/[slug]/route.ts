import { requireProductAccess, requireToken } from "@/lib/authz";
import { ApiError, addVersion, compatFor, listVersions } from "@/lib/configs";
import { api, body, json } from "@/lib/http";
import { loadVisible, publicConfig, versionSchema } from "@/lib/config-api";
import { audit } from "@/lib/audit";
import { one } from "@/lib/db";

export const dynamic = "force-dynamic";

// What the Lua shows before it imports: name, author and compatibility. No config data in this answer.
export const GET = api<{ slug: string }>(async (req, { params }) => {
  const auth = await requireToken(req, "configs:read");
  await requireProductAccess(auth.userId, auth.productId);
  const cfg = await loadVisible(params.slug, { id: auth.userId, isAdmin: false });
  if (cfg.product_id !== auth.productId) throw new ApiError(404, "not_found", "Config not found.");
  const compat = await compatFor(cfg.id, cfg.latest_version);
  const product = await one<{ latest_version: string }>("select latest_version from products where id = $1", [auth.productId]);
  return json({
    config: publicConfig(cfg),
    compat: { compatible: compat?.ok ?? false, reason: compat?.reason ?? null, outdated: compat?.outdated ?? false, current_lua_version: product?.latest_version ?? "" },
    versions: (await listVersions(cfg.id)).map((v) => ({ version: v.version, luaVersion: v.lua_version, createdAt: v.created_at })),
  });
});

// A new version of an own config.
export const PUT = api<{ slug: string }>(async (req, { params }) => {
  const auth = await requireToken(req, "configs:write");
  await requireProductAccess(auth.userId, auth.productId);
  const cfg = await loadVisible(params.slug, { id: auth.userId, isAdmin: false });
  if (cfg.owner_id !== auth.userId || cfg.product_id !== auth.productId) throw new ApiError(404, "not_found", "Config not found.");
  const input = await body(req, versionSchema);
  const v = await addVersion(cfg.id, auth.userId, input.payload, input.changelog);
  await audit(auth.userId, "config.version", "config", cfg.id, { version: v.version, via: "lua" });
  return json(v, 201);
});
