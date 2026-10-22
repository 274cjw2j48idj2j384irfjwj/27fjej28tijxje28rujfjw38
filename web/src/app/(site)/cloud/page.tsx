import type { Metadata } from "next";
import Link from "next/link";
import { ConfigCard } from "@/components/config-card";
import { ButtonLink, EmptyState, PageHeader, SectionTitle } from "@/components/ui";
import { getProducts } from "@/config/site";
import { listConfigs } from "@/lib/configs";
import { query } from "@/lib/db";

export const dynamic = "force-dynamic";
export const metadata: Metadata = { title: "Cloud Configs" };

export default async function CloudIndex() {
  const products = getProducts();
  const blocks = await Promise.all(
    products.map(async (p) => ({
      p,
      official: (await listConfigs({ productId: p.id, official: true, sort: "featured", limit: 3 })).items,
      latest: (await listConfigs({ productId: p.id, sort: "latest", limit: 3 })).items,
      total: (await query<{ n: string }>("select count(*) as n from configs where product_id = $1 and visibility = 'public' and not hidden", [p.id]))[0]?.n ?? "0",
    })),
  );
  return (
    <div className="space-y-20">
      <PageHeader eyebrow="Cloud" title="Config cloud">Each Lua has its own catalog. A config is made for exactly one Lua and cannot be imported into the other.</PageHeader>
      {blocks.map(({ p, official, latest, total }) => (
        <section key={p.id}>
          <SectionTitle eyebrow={p.platform} title={`${p.name} configs`} action={<ButtonLink href={`/cloud/${p.slug}`} variant="ghost" small>Open catalog ({total})</ButtonLink>} />
          {official.length > 0 && (
            <div className="mb-8">
              <p className="eyebrow mb-3">Official collection</p>
              <div className="grid gap-5 sm:grid-cols-2 lg:grid-cols-3">{official.map((c) => <ConfigCard key={c.id} c={c} />)}</div>
            </div>
          )}
          {latest.length > 0 ? (
            <div>
              <p className="eyebrow mb-3">Latest</p>
              <div className="grid gap-5 sm:grid-cols-2 lg:grid-cols-3">{latest.map((c) => <ConfigCard key={c.id} c={c} />)}</div>
            </div>
          ) : (
            <EmptyState title="No configs yet" action={<Link href="/dashboard/configs" className="btn-ghost btn-sm">Upload the first one</Link>} />
          )}
        </section>
      ))}
    </div>
  );
}
