import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { ConfigCard } from "@/components/config-card";
import { ButtonLink, EmptyState, PageHeader, cx } from "@/components/ui";
import { getProduct } from "@/config/site";
import { currentUser } from "@/lib/authz";
import { listConfigs, type Sort } from "@/lib/configs";
import { query } from "@/lib/db";

export const dynamic = "force-dynamic";

export async function generateMetadata({ params }: { params: Promise<{ product: string }> }): Promise<Metadata> {
  const p = getProduct((await params).product);
  return { title: p ? `${p.platform} configs` : "Cloud Configs" };
}

const SORTS: { id: Sort; label: string }[] = [
  { id: "latest", label: "Latest" },
  { id: "popular", label: "Popular" },
  { id: "downloads", label: "Most downloaded" },
  { id: "featured", label: "Featured" },
];

type SP = { q?: string; tag?: string; lua?: string; sort?: string; official?: string; liked?: string; page?: string };

export default async function Catalog({ params, searchParams }: { params: Promise<{ product: string }>; searchParams: Promise<SP> }) {
  const p = getProduct((await params).product);
  if (!p) notFound();
  const sp = await searchParams;
  const user = await currentUser();
  const sort = SORTS.some((s) => s.id === sp.sort) ? (sp.sort as Sort) : "latest";
  const page = Math.max(1, Number(sp.page) || 1);
  const size = 24;
  const [res, tags, versions] = await Promise.all([
    listConfigs({ productId: p.id, q: sp.q?.trim() || undefined, tag: sp.tag || undefined, luaVersion: sp.lua || undefined, sort, official: sp.official === "1", likedBy: sp.liked === "1" && user ? user.id : undefined, limit: size, offset: (page - 1) * size }),
    query<{ tag: string; n: string }>("select t as tag, count(*) as n from configs c, unnest(c.tags) t where c.product_id = $1 and c.visibility = 'public' and not c.hidden group by t order by count(*) desc, t limit 14", [p.id]),
    query<{ lua_version: string }>("select distinct v.lua_version from config_versions v join configs c on c.id = v.config_id and v.version = c.latest_version where c.product_id = $1 and c.visibility = 'public' and not c.hidden order by 1 desc", [p.id]),
  ]);
  const pages = Math.max(1, Math.ceil(res.total / size));
  const link = (over: Partial<SP>) => {
    const q = new URLSearchParams();
    const merged: SP = { ...sp, ...over };
    for (const [k, v] of Object.entries(merged)) if (v) q.set(k, String(v));
    const s = q.toString();
    return `/cloud/${p.slug}${s ? `?${s}` : ""}`;
  };

  return (
    <div>
      <PageHeader eyebrow={p.platform} title={`${p.name} configs`} actions={<ButtonLink href="/dashboard/configs" small>Upload a config</ButtonLink>}>
        Only configs made for {p.name}. {res.total} {res.total === 1 ? "config" : "configs"} found.
      </PageHeader>

      <form method="get" className="card mb-6 grid gap-4 p-5 sm:grid-cols-2 lg:grid-cols-[2fr_1fr_1fr_auto]" role="search">
        <div>
          <label htmlFor="q" className="label">Search</label>
          <input id="q" name="q" defaultValue={sp.q ?? ""} placeholder="Name, description or tag" className="input" />
        </div>
        <div>
          <label htmlFor="sort" className="label">Sort</label>
          <select id="sort" name="sort" defaultValue={sort} className="input">{SORTS.map((s) => <option key={s.id} value={s.id}>{s.label}</option>)}</select>
        </div>
        <div>
          <label htmlFor="lua" className="label">Lua version</label>
          <select id="lua" name="lua" defaultValue={sp.lua ?? ""} className="input">
            <option value="">Any</option>
            {versions.map((v) => <option key={v.lua_version} value={v.lua_version}>{v.lua_version}</option>)}
          </select>
        </div>
        <div className="flex items-end gap-2">
          <button className="btn-primary">Apply</button>
          {(sp.q || sp.tag || sp.lua || sp.official || sp.liked || sp.sort) && <Link href={`/cloud/${p.slug}`} className="btn-ghost">Reset</Link>}
        </div>
        {sp.tag && <input type="hidden" name="tag" value={sp.tag} />}
        <div className="flex flex-wrap items-center gap-2 sm:col-span-2 lg:col-span-4">
          <Link href={link({ official: sp.official === "1" ? "" : "1", page: "" })} className={cx("rounded-full border px-3 py-1 text-xs", sp.official === "1" ? "border-violet-400/50 bg-violet-500/15 text-white" : "border-line text-[color:var(--muted)]")}>Official only</Link>
          {user && <Link href={link({ liked: sp.liked === "1" ? "" : "1", page: "" })} className={cx("rounded-full border px-3 py-1 text-xs", sp.liked === "1" ? "border-violet-400/50 bg-violet-500/15 text-white" : "border-line text-[color:var(--muted)]")}>My favorites</Link>}
          {tags.map((t) => (
            <Link key={t.tag} href={link({ tag: sp.tag === t.tag ? "" : t.tag, page: "" })} className={cx("rounded-full border px-3 py-1 text-xs", sp.tag === t.tag ? "border-violet-400/50 bg-violet-500/15 text-white" : "border-line text-[color:var(--muted)] hover:text-white")}>#{t.tag}</Link>
          ))}
        </div>
      </form>

      {res.items.length === 0 ? (
        <EmptyState title="No configs match" action={<Link href={`/cloud/${p.slug}`} className="btn-ghost btn-sm">Clear filters</Link>}>Try another search or upload your own.</EmptyState>
      ) : (
        <div className="grid gap-5 sm:grid-cols-2 lg:grid-cols-3">{res.items.map((c) => <ConfigCard key={c.id} c={c} />)}</div>
      )}

      {pages > 1 && (
        <nav className="mt-10 flex items-center justify-center gap-3 text-sm" aria-label="Pages">
          {page > 1 && <Link href={link({ page: String(page - 1) })} className="btn-ghost btn-sm">← Previous</Link>}
          <span className="muted">Page {page} of {pages}</span>
          {page < pages && <Link href={link({ page: String(page + 1) })} className="btn-ghost btn-sm">Next →</Link>}
        </nav>
      )}
    </div>
  );
}
