import { assertSameOrigin, currentUser, isAdmin, requireProductAccess, requireUser } from "@/lib/authz";
import { createConfig, listConfigs, type Sort, type Visibility } from "@/lib/configs";
import { body, api, json } from "@/lib/http";
import { createSchema, productParam, publicConfig } from "@/lib/config-api";
import { audit } from "@/lib/audit";
import { rateLimit } from "@/lib/rate-limit";
import { site } from "@/config/site";

export const dynamic = "force-dynamic";

const SORTS = ["latest", "popular", "downloads", "featured"] as const;

export const GET = api(async (req) => {
  const sp = new URL(req.url).searchParams;
  const product = sp.get("product") ? productParam.parse(sp.get("product")) : undefined;
  const sort = (SORTS as readonly string[]).includes(sp.get("sort") ?? "") ? (sp.get("sort") as Sort) : "latest";
  const page = Math.max(1, Number(sp.get("page") ?? 1) || 1);
  const limit = 24;
  const viewer = await currentUser();
  const mine = sp.get("mine") === "1" && viewer;
  const res = await listConfigs({
    productId: product,
    q: sp.get("q")?.trim() || undefined,
    tag: sp.get("tag") || undefined,
    luaVersion: sp.get("lua") || undefined,
    sort,
    official: sp.get("official") === "1",
    featuredOnly: sp.get("featured") === "1",
    ownerId: mine ? viewer.id : undefined,
    includeOwn: !!mine,
    likedBy: sp.get("liked") === "1" && viewer ? viewer.id : undefined,
    limit,
    offset: (page - 1) * limit,
  });
  const v = viewer ? { id: viewer.id, isAdmin: isAdmin(viewer) } : null;
  return json({ items: res.items.map((c) => publicConfig(c, v)), total: res.total, page, pageSize: limit });
});

export const POST = api(async (req) => {
  assertSameOrigin(req);
  const user = await requireUser();
  const input = await body(req, createSchema);
  await rateLimit(`cfg-create:${user.id}`, 30, 3600);
  await requireProductAccess(user.id, input.product);
  const created = await createConfig({
    ownerId: user.id,
    productId: input.product,
    name: input.name,
    description: input.description,
    tags: input.tags,
    visibility: input.visibility as Visibility | undefined,
    payload: input.payload,
  });
  await audit(user.id, "config.create", "config", created.id, { product: input.product, via: "web" });
  return json({ id: created.id, slug: created.slug, url: `${site.url}/cloud/${input.product}/${created.slug}` }, 201);
});

