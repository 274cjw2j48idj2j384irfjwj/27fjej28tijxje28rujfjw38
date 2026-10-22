import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { ArrowLeft } from "lucide-react";
import { Badge, Card, Notice, PageHeader, formatDate } from "@/components/ui";
import { canUse, reasonFor } from "@/components/dashboard/access";
import { formatBytes } from "@/components/dashboard/api";
import { CopyButton } from "@/components/dashboard/copy-button";
import { DeleteConfig, DetailsForm, ImagesPanel, VersionForm } from "@/components/dashboard/manage";
import { getProduct, site } from "@/config/site";
import { accessOf } from "@/lib/authz";
import { configImages, getConfigBySlug, listVersions } from "@/lib/configs";
import { requireDashboardUser } from "@/lib/dashboard-data";
import { getProductContent } from "@/lib/site-data";

export const dynamic = "force-dynamic";
export const metadata: Metadata = { title: "Manage config" };

function Block({ title, children, help }: { title: string; children: React.ReactNode; help?: string }) {
  return (
    <Card className="p-6">
      <h2 className="text-lg font-semibold text-white">{title}</h2>
      {help && <p className="muted mt-1 text-sm">{help}</p>}
      <div className="mt-5">{children}</div>
    </Card>
  );
}

export default async function ManageConfig({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params;
  const user = await requireDashboardUser(`/dashboard/configs/${slug}`);
  const cfg = await getConfigBySlug(slug, { id: user.id, isAdmin: false });
  if (!cfg || cfg.owner_id !== user.id) notFound();
  const product = getProduct(cfg.product_id)!;
  const [versions, images, access, content] = await Promise.all([listVersions(cfg.id), configImages(cfg.id), accessOf(user.id, cfg.product_id), getProductContent(cfg.product_id)]);
  const reason = reasonFor(access, product.name);
  const publicPath = `/cloud/${product.slug}/${cfg.slug}`;
  const listed = cfg.visibility !== "private" && !cfg.hidden;
  return (
    <div className="space-y-6">
      <Link href="/dashboard/configs" className="muted inline-flex items-center gap-1.5 text-sm transition hover:text-white"><ArrowLeft size={14} aria-hidden="true" />My Configs</Link>
      <PageHeader eyebrow={product.name} title={cfg.name}>
        <span className="flex flex-wrap items-center gap-2">
          <Badge tone={cfg.visibility === "public" ? "green" : cfg.visibility === "unlisted" ? "violet" : "gray"}>{cfg.visibility}</Badge>
          <span>Version {cfg.latest_version} · {cfg.likes_count} likes · {cfg.downloads_count} downloads · {cfg.imports_count} imports</span>
        </span>
      </PageHeader>

      {cfg.hidden && <Notice tone="red">This config is hidden by moderation. Only you and the team can see it. Contact the team on Discord if you think this is wrong.</Notice>}

      <Block title="Share" help="Players paste the code in the Lua menu, or open the link.">
        <dl className="space-y-4">
          <div>
            <dt className="label">Import code</dt>
            <dd className="flex flex-wrap items-center gap-3">
              <code className="rounded-lg border border-line bg-ink-900 px-3 py-2 font-mono text-sm text-white">{cfg.slug}</code>
              <CopyButton text={cfg.slug} label="Copy code" />
            </dd>
          </div>
          <div>
            <dt className="label">Public link</dt>
            <dd className="flex flex-wrap items-center gap-3">
              <code className="break-all rounded-lg border border-line bg-ink-900 px-3 py-2 font-mono text-xs text-white">{site.url}{publicPath}</code>
              <CopyButton text={`${site.url}${publicPath}`} label="Copy link" />
              {listed && <Link href={publicPath} className="btn-ghost btn-sm">Open</Link>}
            </dd>
            {!listed && <p className="mt-2 text-xs text-amber-200/80">{cfg.hidden ? "The page is not public while the config is hidden." : "The config is private, so only you can open this link."}</p>}
          </div>
        </dl>
      </Block>

      <Block title="Details"><DetailsForm slug={cfg.slug} initial={{ name: cfg.name, description: cfg.description, tags: cfg.tags, visibility: cfg.visibility }} /></Block>

      <Block title="Preview images" help="Shown on the config card and page. They follow the visibility of the config.">
        <ImagesPanel slug={cfg.slug} images={images.map((id) => `/api/media/${id}`)} />
      </Block>

      <Block title="Publish a new version" help="Players who saved the config see an update badge. Older versions stay downloadable by version number.">
        <VersionForm
          slug={cfg.slug}
          productName={product.name}
          canUpload={canUse(access)}
          reason={reason.text}
          template={{ product: product.id, format: content?.maxFormat ?? 1, lua: content?.latestVersion || "1.0.0" }}
        />
      </Block>

      <Block title="Versions">
        <ul className="divide-y divide-line/60">
          {versions.map((v) => (
            <li key={v.version} className="flex flex-wrap items-baseline justify-between gap-x-4 gap-y-1 py-3 text-sm first:pt-0 last:pb-0">
              <span className="flex items-center gap-2 font-medium text-white">v{v.version}{v.version === cfg.latest_version && <Badge tone="green">Latest</Badge>}</span>
              <span className="muted text-xs">Lua {v.lua_version} · format {v.format_version} · {formatBytes(v.payload_bytes)} · {formatDate(v.created_at, true)}</span>
              {v.changelog && <p className="basis-full text-[13px] text-[color:var(--text)]/80">{v.changelog}</p>}
            </li>
          ))}
        </ul>
      </Block>

      <Block title="Delete" help="Removes the config, all versions, images, likes and saved copies.">
        <DeleteConfig slug={cfg.slug} name={cfg.name} />
      </Block>
    </div>
  );
}
