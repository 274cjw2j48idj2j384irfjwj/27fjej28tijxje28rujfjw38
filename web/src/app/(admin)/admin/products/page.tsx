import Link from "next/link";
import { ProductEditor } from "@/components/admin/product-editor";
import { adminPageUser } from "@/components/admin/server";
import { PageHeader, cx, formatDate } from "@/components/ui";
import { getProducts } from "@/config/site";
import { listDownloads } from "@/lib/downloads";
import { getProductContent } from "@/lib/site-data";

export const dynamic = "force-dynamic";

export default async function ProductsPage({ searchParams }: { searchParams: Promise<{ lua?: string }> }) {
  if (!(await adminPageUser())) return null;
  const products = getProducts();
  const wanted = (await searchParams).lua;
  const sel = products.find((p) => p.id === wanted) ?? products[0];
  const [content, downloads] = await Promise.all([getProductContent(sel.id), listDownloads(sel.id)]);
  if (!content) return null;
  return (
    <div className="space-y-6">
      <PageHeader eyebrow="Admin" title="Products & Releases">Edit what the public Lua pages show: features, install guide, releases, screenshots and the loader download.</PageHeader>
      <nav aria-label="Lua" className="flex flex-wrap gap-2">
        {products.map((p) => (
          <Link key={p.id} href={`/admin/products?lua=${p.id}`} aria-current={p.id === sel.id ? "page" : undefined}
            className={cx("rounded-xl border px-4 py-2 text-sm transition", p.id === sel.id ? "border-violet-400/40 bg-violet-500/15 text-white" : "border-line text-[color:var(--muted)] hover:text-white")}>
            {p.name}
          </Link>
        ))}
      </nav>
      <ProductEditor
        key={sel.id}
        product={{ id: sel.id, name: sel.name, slug: sel.slug }}
        initial={{
          features: content.features.map((f) => ({ category: f.category, title: f.title, text: f.text })),
          installGuide: content.installGuide, compatNotes: content.compatNotes, latestVersion: content.latestVersion, minFormat: content.minFormat, maxFormat: content.maxFormat,
        }}
        releases={content.releases.map((r) => ({ id: r.id, version: r.version, title: r.title, notes: r.notes, date: formatDate(r.released_at), demo: r.is_demo }))}
        media={content.media.map((m) => ({ id: m.id, kind: m.kind, category: m.category, src: m.src, caption: m.caption, demo: m.is_demo }))}
        downloads={downloads.map((d) => ({ id: d.id, filename: d.filename, version: d.version, note: d.note, bytes: d.bytes, date: formatDate(d.created_at, true) }))}
      />
    </div>
  );
}
