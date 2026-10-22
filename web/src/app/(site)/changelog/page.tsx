import type { Metadata } from "next";
import Link from "next/link";
import { Badge, Card, DemoTag, EmptyState, PageHeader, cx, formatDate } from "@/components/ui";
import { getProduct, getProducts } from "@/config/site";
import { query } from "@/lib/db";
import type { Release } from "@/lib/site-data";

export const dynamic = "force-dynamic";
export const metadata: Metadata = { title: "Changelog" };

export default async function ChangelogPage({ searchParams }: { searchParams: Promise<{ lua?: string }> }) {
  const sp = await searchParams;
  const filter = getProduct(sp.lua ?? "");
  const releases = await query<Release>("select id, product_id, version, title, notes, released_at, is_demo from releases where ($1::text is null or product_id = $1) order by released_at desc limit 60", [filter?.id ?? null]);
  return (
    <div>
      <PageHeader eyebrow="Changelog" title="Release history">Every Lua has its own history.</PageHeader>
      <div className="mb-8 flex flex-wrap gap-2">
        <Link href="/changelog" className={cx("rounded-full border px-3.5 py-1.5 text-xs", !filter ? "border-violet-400/50 bg-violet-500/15 text-white" : "border-line text-[color:var(--muted)]")}>All</Link>
        {getProducts().map((p) => (
          <Link key={p.id} href={`/changelog?lua=${p.slug}`} className={cx("rounded-full border px-3.5 py-1.5 text-xs", filter?.id === p.id ? "border-violet-400/50 bg-violet-500/15 text-white" : "border-line text-[color:var(--muted)]")}>{p.platform}</Link>
        ))}
      </div>
      {releases.length === 0 ? (
        <EmptyState title="No releases yet">The first release will appear here.</EmptyState>
      ) : (
        <ol className="relative space-y-5 border-l border-line pl-6 sm:pl-8">
          {releases.map((r) => (
            <li key={r.id} className="relative">
              <span className="absolute -left-[31px] top-7 size-2.5 rounded-full bg-violet-400 shadow-[0_0_12px_rgba(167,139,250,0.7)] sm:-left-[39px]" aria-hidden="true" />
              <Card className="p-6">
                <div className="flex flex-wrap items-center justify-between gap-3">
                  <div className="flex items-center gap-3">
                    <Badge tone="violet">{getProduct(r.product_id)?.platform}</Badge>
                    <h2 className="text-lg font-medium text-white">{r.title} <span className="text-sm font-normal text-[color:var(--muted)]">v{r.version}</span></h2>
                  </div>
                  <span className="flex items-center gap-2 text-xs text-[color:var(--faint)]">{r.is_demo && <DemoTag />}{formatDate(r.released_at)}</span>
                </div>
                <ul className="muted mt-4 space-y-2 text-sm">{r.notes.map((n, i) => <li key={i} className="flex gap-2.5"><span className="text-violet-400">·</span>{n}</li>)}</ul>
              </Card>
            </li>
          ))}
        </ol>
      )}
    </div>
  );
}
