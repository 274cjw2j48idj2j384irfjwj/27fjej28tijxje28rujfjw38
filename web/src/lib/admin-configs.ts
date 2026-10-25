import type { ProductId } from "@/config/site";
import { one, query } from "./db";
import type { Visibility } from "./configs";

export type AdminConfigRow = {
  id: string;
  slug: string;
  product_id: ProductId;
  name: string;
  visibility: Visibility;
  hidden: boolean;
  is_featured: boolean;
  is_official: boolean;
  is_demo: boolean;
  likes_count: number;
  downloads_count: number;
  latest_version: number;
  updated_at: Date;
  owner_id: string;
  owner_name: string;
  owner_discord_id: string;
  reports_open: number;
  reports_total: number;
};

export type AdminConfigQuery = { q?: string; product?: string; page?: number; pageSize?: number };

export const ADMIN_CONFIG_PAGE = 25;

// Moderation list: every config whatever its visibility (hidden and private ones too), with the owner and the report counts.
// The search matches the name, the slug, the owner's name and the owner's Discord id.
export async function listAdminConfigs(input: AdminConfigQuery = {}): Promise<{ items: AdminConfigRow[]; total: number; page: number; pages: number; pageSize: number }> {
  const pageSize = Math.min(Math.max(Math.floor(input.pageSize ?? ADMIN_CONFIG_PAGE), 1), 100);
  const page = Math.max(Math.floor(input.page ?? 1) || 1, 1);
  const where: string[] = [];
  const params: unknown[] = [];
  const q = (input.q ?? "").trim().slice(0, 60);
  if (q) {
    params.push(`%${q.replace(/[%_\\]/g, "\\$&")}%`);
    const p = `$${params.length}`;
    params.push(q);
    where.push(`(c.name ilike ${p} or c.slug ilike ${p} or u.username ilike ${p} or u.global_name ilike ${p} or u.discord_id = $${params.length})`);
  }
  if (input.product === "gamesense" || input.product === "primordial") {
    params.push(input.product);
    where.push(`c.product_id = $${params.length}`);
  }
  const w = where.length ? `where ${where.join(" and ")}` : "";
  const total = Number((await one<{ n: string }>(`select count(*) as n from configs c join users u on u.id = c.owner_id ${w}`, params))?.n ?? 0);
  const pages = Math.max(Math.ceil(total / pageSize), 1);
  const safePage = Math.min(page, pages);
  const items = await query<AdminConfigRow>(
    `select c.id, c.slug, c.product_id, c.name, c.visibility, c.hidden, c.is_featured, c.is_official, c.is_demo, c.likes_count, c.downloads_count,
            c.latest_version, c.updated_at, c.owner_id, coalesce(u.global_name, u.username) as owner_name, u.discord_id as owner_discord_id,
            (select count(*)::int from config_reports r where r.config_id = c.id and r.status = 'open') as reports_open,
            (select count(*)::int from config_reports r where r.config_id = c.id) as reports_total
       from configs c join users u on u.id = c.owner_id ${w}
      order by (select count(*) from config_reports r where r.config_id = c.id and r.status = 'open') desc, c.updated_at desc, c.id
      limit ${pageSize} offset ${(safePage - 1) * pageSize}`,
    params,
  );
  return { items, total, page: safePage, pages, pageSize };
}
