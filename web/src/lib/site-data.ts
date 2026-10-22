import { getProduct, getProducts, type ProductConfig, type ProductId } from "@/config/site";
import { query, one } from "./db";
import { listConfigs } from "./configs";
import { periodOf, standings } from "./leaderboard";

export type Feature = { category: string; title: string; text: string; demo?: boolean };
export type Release = { id: string; product_id: ProductId; version: string; title: string; notes: string[]; released_at: Date; is_demo: boolean };
export type Media = { id: string; kind: "screenshot" | "video"; category: "menu" | "visuals" | "configuration"; src: string; caption: string; is_demo: boolean };

export type ProductContent = ProductConfig & {
  features: Feature[];
  installGuide: string;
  compatNotes: string;
  latestVersion: string;
  minFormat: number;
  maxFormat: number;
  releases: Release[];
  media: Media[];
};

type ProductRow = { id: ProductId; features: Feature[]; install_guide: string; compat_notes: string; latest_version: string; min_format: number; max_format: number };

export async function getProductContent(idOrSlug: string): Promise<ProductContent | null> {
  const cfg = getProduct(idOrSlug);
  if (!cfg) return null;
  const row = await one<ProductRow>("select id, features, install_guide, compat_notes, latest_version, min_format, max_format from products where id = $1", [cfg.id]);
  const releases = await query<Release>("select id, product_id, version, title, notes, released_at, is_demo from releases where product_id = $1 order by released_at desc limit 20", [cfg.id]);
  const media = await query<{ id: string; kind: Media["kind"]; category: Media["category"]; url: string | null; blob_id: string | null; caption: string; is_demo: boolean }>(
    "select id, kind, category, url, blob_id, caption, is_demo from product_media where product_id = $1 order by sort, id",
    [cfg.id],
  );
  return {
    ...cfg,
    features: row?.features ?? [],
    installGuide: row?.install_guide ?? "",
    compatNotes: row?.compat_notes ?? "",
    latestVersion: row?.latest_version ?? "",
    minFormat: row?.min_format ?? 1,
    maxFormat: row?.max_format ?? 1,
    releases,
    media: media.map((m) => ({ id: m.id, kind: m.kind, category: m.category, src: m.blob_id ? `/api/media/${m.blob_id}` : (m.url ?? ""), caption: m.caption, is_demo: m.is_demo })),
  };
}

export async function getAllProducts(): Promise<ProductContent[]> {
  const out: ProductContent[] = [];
  for (const p of getProducts()) {
    const c = await getProductContent(p.id);
    if (c) out.push(c);
  }
  return out;
}

export async function latestReleases(limit = 6): Promise<(Release & { product: string })[]> {
  const rows = await query<Release>("select id, product_id, version, title, notes, released_at, is_demo from releases order by released_at desc limit $1", [limit]);
  return rows.map((r) => ({ ...r, product: getProduct(r.product_id)?.name ?? r.product_id }));
}

export async function featuredConfigs(limit = 6) {
  return (await listConfigs({ featuredOnly: true, sort: "featured", limit })).items;
}

export async function topThree(boardId = "overall", now = new Date()) {
  const period = periodOf(now);
  return { period, rows: (await standings(boardId, period, { limit: 3 })) };
}

export function groupBy<T, K extends string>(items: T[], key: (t: T) => K): Record<K, T[]> {
  const out = {} as Record<K, T[]>;
  for (const it of items) (out[key(it)] ??= []).push(it);
  return out;
}
