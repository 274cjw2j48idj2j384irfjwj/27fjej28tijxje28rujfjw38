import type { Metadata } from "next";
import Link from "next/link";
import { Download, Heart, Inbox } from "lucide-react";
import { Badge, Card, EmptyState, PageHeader, SectionTitle, formatDate } from "@/components/ui";
import { canUse, reasonFor } from "@/components/dashboard/access";
import { UploadForm, type ProductOption } from "@/components/dashboard/upload-form";
import { getProduct } from "@/config/site";
import { myConfigs } from "@/lib/configs";
import { accessAll, requireDashboardUser } from "@/lib/dashboard-data";
import { getAllProducts } from "@/lib/site-data";

export const dynamic = "force-dynamic";
export const metadata: Metadata = { title: "My Configs" };

const VIS = { public: { label: "Public", tone: "green" }, unlisted: { label: "Unlisted", tone: "violet" }, private: { label: "Private", tone: "gray" } } as const;

export default async function MyConfigsPage() {
  const user = await requireDashboardUser("/dashboard/configs");
  const [configs, access, content] = await Promise.all([myConfigs(user.id), accessAll(user.id), getAllProducts()]);
  const options: ProductOption[] = access.map(({ product, access: a }) => {
    const c = content.find((x) => x.id === product.id);
    return {
      id: product.id,
      name: product.name,
      slug: product.slug,
      canUpload: canUse(a),
      reason: reasonFor(a, product.name).text,
      template: { product: product.id, format: c?.maxFormat ?? 1, lua: c?.latestVersion || "1.0.0" },
    };
  });
  return (
    <div className="space-y-12">
      <PageHeader eyebrow="Dashboard" title="My Configs">Configs you uploaded to the cloud. Manage versions, previews and who can see them.</PageHeader>

      <section aria-labelledby="mine-h">
        <SectionTitle eyebrow="Library" title="Your uploads" />
        <h2 id="mine-h" className="sr-only">Your uploads</h2>
        {configs.length === 0 ? (
          <EmptyState title="You have not uploaded a config yet" icon={<Inbox size={28} aria-hidden="true" />}>Use the form below to publish your first one. You can keep it private while you test it.</EmptyState>
        ) : (
          <ul className="grid gap-4 md:grid-cols-2">
            {configs.map((c) => {
              const v = VIS[c.visibility];
              return (
                <li key={c.id}>
                  <Link href={`/dashboard/configs/${c.slug}`} className="card card-hover block h-full p-5">
                    <div className="flex items-start justify-between gap-3">
                      <h3 className="line-clamp-1 font-semibold text-white">{c.name}</h3>
                      <span className="shrink-0 text-xs text-[color:var(--faint)]">v{c.latest_version}</span>
                    </div>
                    <p className="muted mt-0.5 text-xs">{getProduct(c.product_id)?.name ?? c.product_id}</p>
                    <div className="mt-3 flex flex-wrap gap-1.5">
                      <Badge tone={v.tone}>{v.label}</Badge>
                      {c.hidden && <Badge tone="red">Hidden by moderation</Badge>}
                      {c.is_official && <Badge tone="violet">Official</Badge>}
                      {c.is_featured && <Badge tone="amber">Featured</Badge>}
                      {c.is_demo && <Badge tone="amber" className="uppercase">Demo</Badge>}
                    </div>
                    <p className="muted mt-3 line-clamp-2 min-h-[2.5rem] text-[13px] leading-relaxed">{c.description || "No description."}</p>
                    <div className="mt-4 flex flex-wrap items-center gap-x-4 gap-y-1 text-xs text-[color:var(--faint)]">
                      <span className="flex items-center gap-1" title="Likes"><Heart size={12} aria-hidden="true" />{c.likes_count} likes</span>
                      <span className="flex items-center gap-1" title="Downloads"><Download size={12} aria-hidden="true" />{c.downloads_count} downloads</span>
                      <span>{c.imports_count} imports</span>
                      <span className="ml-auto">updated {formatDate(c.updated_at)}</span>
                    </div>
                  </Link>
                </li>
              );
            })}
          </ul>
        )}
      </section>

      <section aria-labelledby="up-h">
        <SectionTitle eyebrow="Upload" title="Upload a config">
          A config is a JSON file with a <code className="font-mono text-xs">meta</code> block (which Lua, format and Lua version) and your settings as <code className="font-mono text-xs">data</code>. Export one from the Lua menu, or start from the template.
        </SectionTitle>
        <h2 id="up-h" className="sr-only">Upload a config</h2>
        <UploadForm products={options} />
      </section>
    </div>
  );
}
