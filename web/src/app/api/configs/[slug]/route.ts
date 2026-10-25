import { assertSameOrigin, currentUser, isAdmin, requireUser } from "@/lib/authz";
import { ApiError, configImages, deleteConfig, listVersions, updateConfigMeta, type Visibility } from "@/lib/configs";
import { api, body, json } from "@/lib/http";
import { loadVisible, patchSchema, publicConfig } from "@/lib/config-api";
import { audit } from "@/lib/audit";
import { one } from "@/lib/db";

export const dynamic = "force-dynamic";

export const GET = api<{ slug: string }>(async (_req, { params }) => {
  const user = await currentUser();
  const viewer = user ? { id: user.id, isAdmin: isAdmin(user) } : null;
  const cfg = await loadVisible(params.slug, viewer);
  const state = user
    ? await one<{ liked: boolean; saved: boolean }>(
        `select exists (select 1 from config_likes where user_id = $1 and config_id = $2) as liked,
                exists (select 1 from config_library where user_id = $1 and config_id = $2) as saved`,
        [user.id, cfg.id],
      )
    : null;
  return json({
    config: publicConfig(cfg, viewer),
    versions: (await listVersions(cfg.id)).map((v) => ({ version: v.version, luaVersion: v.lua_version, formatVersion: v.format_version, bytes: v.payload_bytes, changelog: v.changelog, createdAt: v.created_at })),
    images: (await configImages(cfg.id)).map((id) => `/api/media/${id}`),
    viewer: { liked: state?.liked ?? false, saved: state?.saved ?? false },
  });
});

export const PATCH = api<{ slug: string }>(async (req, { params }) => {
  assertSameOrigin(req);
  const user = await requireUser();
  const cfg = await loadVisible(params.slug, { id: user.id, isAdmin: false });
  if (cfg.owner_id !== user.id) throw new ApiError(404, "not_found", "Config not found.");
  const patch = await body(req, patchSchema);
  await updateConfigMeta(cfg.id, user.id, { ...patch, visibility: patch.visibility as Visibility | undefined });
  await audit(user.id, "config.update", "config", cfg.id);
  return json({ ok: true });
});

export const DELETE = api<{ slug: string }>(async (req, { params }) => {
  assertSameOrigin(req);
  const user = await requireUser();
  const cfg = await loadVisible(params.slug, { id: user.id, isAdmin: false });
  if (cfg.owner_id !== user.id) throw new ApiError(404, "not_found", "Config not found.");
  await deleteConfig(cfg.id, user.id);
  await audit(user.id, "config.delete", "config", cfg.id, { name: cfg.name });
  return json({ ok: true });
});
