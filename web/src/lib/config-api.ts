import { z } from "zod";
import { getProduct, type ProductId } from "@/config/site";
import { ApiError, VISIBILITIES, getConfigBySlug, type ConfigListItem, type Viewer } from "./configs";
import { PRODUCT_IDS } from "./config-validate";
import { avatarUrl } from "./discord";

export const productParam = z.enum(PRODUCT_IDS);

export const createSchema = z.object({
  product: productParam,
  name: z.string().min(2).max(120),
  description: z.string().max(2000).optional(),
  tags: z.array(z.string().max(60)).max(20).optional(),
  visibility: z.enum(VISIBILITIES as [string, ...string[]]).optional(),
  payload: z.unknown(),
});

export const versionSchema = z.object({ payload: z.unknown(), changelog: z.string().max(1000).optional() });

export const patchSchema = z.object({
  name: z.string().min(2).max(120).optional(),
  description: z.string().max(2000).optional(),
  tags: z.array(z.string().max(60)).max(20).optional(),
  visibility: z.enum(VISIBILITIES as [string, ...string[]]).optional(),
});

// What a list or a page gets to see of a config. The payload is never part of it.
export function publicConfig(c: ConfigListItem, viewer: Viewer = null) {
  return {
    id: c.id,
    slug: c.slug,
    product: c.product_id,
    name: c.name,
    description: c.description,
    tags: c.tags,
    visibility: c.visibility,
    official: c.is_official,
    featured: c.is_featured,
    hidden: c.hidden,
    demo: c.is_demo,
    version: c.latest_version,
    luaVersion: c.lua_version,
    formatVersion: c.format_version,
    likes: c.likes_count,
    downloads: c.downloads_count,
    imports: c.imports_count,
    createdAt: c.created_at,
    updatedAt: c.updated_at,
    image: c.image_id ? `/api/media/${c.image_id}` : null,
    author: { name: c.owner_name, avatar: avatarUrl(c.owner_discord_id, c.owner_avatar, 64), verified: c.owner_verified },
    mine: !!viewer && viewer.id === c.owner_id,
  };
}

export async function loadVisible(slug: string, viewer: Viewer): Promise<ConfigListItem> {
  const cfg = await getConfigBySlug(slug, viewer);
  if (!cfg) throw new ApiError(404, "not_found", "Config not found.");
  return cfg;
}

export function productName(id: ProductId): string {
  return getProduct(id)?.name ?? id;
}
