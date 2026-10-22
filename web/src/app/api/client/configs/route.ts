import { z } from "zod";
import { requireProductAccess, requireToken } from "@/lib/authz";
import { createConfig, listConfigs, type Sort, type Visibility } from "@/lib/configs";
import { api, body, json } from "@/lib/http";
import { publicConfig } from "@/lib/config-api";
import { VISIBILITIES } from "@/lib/configs";
import { audit } from "@/lib/audit";
import { rateLimit } from "@/lib/rate-limit";
import { site } from "@/config/site";

export const dynamic = "force-dynamic";

const SORTS = ["latest", "popular", "downloads", "featured"] as const;

// "Browse Cloud": the catalog of the Lua the token belongs to, and only of that Lua.
export const GET = api(async (req) => {
  const auth = await requireToken(req, "configs:read");
  await requireProductAccess(auth.userId, auth.productId);
  const sp = new URL(req.url).searchParams;
  const sort = (SORTS as readonly string[]).includes(sp.get("sort") ?? "") ? (sp.get("sort") as Sort) : "latest";
  const page = Math.max(1, Number(sp.get("page") ?? 1) || 1);
  const res = await listConfigs({ productId: auth.productId, q: sp.get("q")?.trim() || undefined, tag: sp.get("tag") || undefined, sort, official: sp.get("official") === "1", limit: 20, offset: (page - 1) * 20 });
  return json({ items: res.items.map((c) => publicConfig(c)), total: res.total, page, pageSize: 20 });
});

const schema = z.object({
  name: z.string().min(2).max(120),
  description: z.string().max(2000).optional(),
  tags: z.array(z.string().max(60)).max(20).optional(),
  visibility: z.enum(VISIBILITIES as [string, ...string[]]).optional(),
  payload: z.unknown(),
});

// "Upload to Cloud": the config always goes to the Lua of the token, a config of the other Lua is refused by the validation.
export const POST = api(async (req) => {
  const auth = await requireToken(req, "configs:write");
  await rateLimit(`cli-upload:${auth.userId}`, 30, 3600);
  await requireProductAccess(auth.userId, auth.productId);
  const input = await body(req, schema);
  const created = await createConfig({
    ownerId: auth.userId,
    productId: auth.productId,
    name: input.name,
    description: input.description,
    tags: input.tags,
    visibility: input.visibility as Visibility | undefined,
    payload: input.payload,
  });
  await audit(auth.userId, "config.create", "config", created.id, { product: auth.productId, via: "lua" });
  return json({ id: created.id, slug: created.slug, share_code: created.slug, url: `${site.url}/cloud/${auth.productId}/${created.slug}` }, 201);
});
