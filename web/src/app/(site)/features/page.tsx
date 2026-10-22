import type { Metadata } from "next";
import { Badge, Card, DemoTag, EmptyState, PageHeader } from "@/components/ui";
import { getAllProducts, groupBy } from "@/lib/site-data";
import Link from "next/link";

export const dynamic = "force-dynamic";
export const metadata: Metadata = { title: "Features" };

export default async function FeaturesPage() {
  const products = await getAllProducts();
  return (
    <div className="space-y-16">
      <PageHeader eyebrow="Features" title="What each Lua does">Features are listed per Lua, by the team. A feature that is not listed here is not promised.</PageHeader>
      {products.map((p) => {
        const groups = Object.entries(groupBy(p.features, (f) => f.category));
        return (
          <section key={p.id}>
            <div className="mb-6 flex flex-wrap items-center justify-between gap-3">
              <div className="flex items-center gap-3">
                <h2 className="text-2xl font-semibold tracking-tight text-white">{p.name}</h2>
                <Badge tone="violet">{p.platform}</Badge>
              </div>
              <Link href={`/luas/${p.slug}`} className="text-sm text-violet-300 hover:text-violet-200">Product page →</Link>
            </div>
            {groups.length ? (
              <div className="grid gap-5 md:grid-cols-2 lg:grid-cols-3">
                {groups.map(([cat, items]) => (
                  <Card key={cat} className="p-6">
                    <p className="eyebrow mb-4">{cat}</p>
                    <ul className="space-y-4">
                      {items.map((f) => (
                        <li key={f.title}>
                          <p className="flex items-center gap-2 text-[15px] font-medium text-white">{f.title}{f.demo && <DemoTag />}</p>
                          {f.text && <p className="muted mt-1 text-sm leading-relaxed">{f.text}</p>}
                        </li>
                      ))}
                    </ul>
                  </Card>
                ))}
              </div>
            ) : (
              <EmptyState title="No features listed yet">The team fills this list in the admin area.</EmptyState>
            )}
          </section>
        );
      })}
    </div>
  );
}
