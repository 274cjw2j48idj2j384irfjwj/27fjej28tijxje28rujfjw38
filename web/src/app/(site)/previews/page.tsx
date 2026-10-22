import type { Metadata } from "next";
import { Gallery } from "@/components/gallery";
import { MenuMockup } from "@/components/menu-mockup";
import { Badge, PageHeader } from "@/components/ui";
import { getAllProducts } from "@/lib/site-data";

export const dynamic = "force-dynamic";
export const metadata: Metadata = { title: "Previews" };

export default async function PreviewsPage() {
  const products = await getAllProducts();
  return (
    <div className="space-y-20">
      <PageHeader eyebrow="Previews" title="See it before you use it">Screenshots, videos and an interactive illustration of each menu.</PageHeader>
      {products.map((p) => (
        <section key={p.id} id={p.slug} className="scroll-mt-24">
          <div className="mb-6 flex items-center gap-3">
            <h2 className="text-2xl font-semibold tracking-tight text-white">{p.name}</h2>
            <Badge tone="violet">{p.platform}</Badge>
          </div>
          <div className="grid gap-8 lg:grid-cols-[1.4fr_1fr]">
            <Gallery media={p.media} empty="Screenshots and videos are added by the team." />
            <MenuMockup features={p.features} name={p.name} />
          </div>
        </section>
      ))}
    </div>
  );
}
