import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { ConfigCard } from "@/components/config-card";
import { Gallery } from "@/components/gallery";
import { MenuMockup } from "@/components/menu-mockup";
import { Badge, ButtonLink, Card, DemoTag, EmptyState, Notice, SectionTitle, StatusBadge, daysLeft, formatDate } from "@/components/ui";
import { getProduct, getProducts } from "@/config/site";
import { hasAccess } from "@/lib/access";
import { accessOf, currentUser } from "@/lib/authz";
import { listConfigs } from "@/lib/configs";
import { listDownloads } from "@/lib/downloads";
import { getProductContent, groupBy } from "@/lib/site-data";

export const dynamic = "force-dynamic";

export async function generateMetadata({ params }: { params: Promise<{ slug: string }> }): Promise<Metadata> {
  const p = getProduct((await params).slug);
  return { title: p?.name ?? "Lua", description: p?.description };
}

export default async function ProductPage({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params;
  const p = await getProductContent(slug);
  if (!p) notFound();
  const user = await currentUser();
  const access = user ? await accessOf(user.id, p.id) : null;
  const [files, popular, official] = await Promise.all([
    listDownloads(p.id),
    listConfigs({ productId: p.id, sort: "popular", limit: 3 }),
    listConfigs({ productId: p.id, official: true, limit: 3 }),
  ]);
  const byCategory = Object.entries(groupBy(p.features, (f) => f.category));
  const other = getProducts().find((x) => x.id !== p.id);
  const allowed = access ? hasAccess(access.status) : false;

  return (
    <div className="space-y-24">
      <section className="grid items-center gap-10 lg:grid-cols-[1.1fr_1fr]">
        <div>
          <div className="reveal flex flex-wrap items-center gap-2">
            <Badge tone="violet">{p.platform}</Badge>
            {p.latestVersion && <Badge>Version {p.latestVersion}</Badge>}
          </div>
          <h1 className="reveal-2 mt-5 text-4xl font-semibold tracking-tight text-white sm:text-5xl">{p.name}</h1>
          <p className="reveal-3 muted mt-5 max-w-lg text-[17px] leading-relaxed">{p.tagline} {p.description}</p>
          <div className="reveal-3 mt-8 flex flex-wrap gap-3">
            {user ? <ButtonLink href="/dashboard/downloads">Downloads</ButtonLink> : <a href={`/api/auth/login?next=/luas/${p.slug}`} className="btn-primary">Sign in with Discord</a>}
            <ButtonLink href={`/cloud/${p.slug}`} variant="ghost">Browse {p.platform} configs</ButtonLink>
          </div>
          {access && (
            <div className="mt-8 flex flex-wrap items-center gap-3 text-sm">
              <span className="muted">Your access</span>
              <StatusBadge status={access.status} />
              {access.expiresAt && <span className="muted">{daysLeft(access.expiresAt)} · ends {formatDate(access.expiresAt)}</span>}
            </div>
          )}
          {access?.integrationError && <div className="mt-4"><Notice tone="amber">We could not check your Discord roles right now, so only your direct grants are counted. This is not the same as having no access. Try again in a minute.</Notice></div>}
        </div>
        <MenuMockup features={p.features} name={p.name} />
      </section>

      <section>
        <SectionTitle eyebrow="Preview" title="Screenshots and videos">Pick a category, open an image full screen.</SectionTitle>
        <Gallery media={p.media} empty="Screenshots and videos are added by the team and will show up here." />
      </section>

      <section>
        <SectionTitle eyebrow="Features" title={`What ${p.platform} gets`}>Only features the team has listed are shown here.</SectionTitle>
        {byCategory.length ? (
          <div className="grid gap-5 md:grid-cols-2 lg:grid-cols-3">
            {byCategory.map(([cat, items]) => (
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
          <EmptyState title="The feature list is not filled in yet">The team adds features in the admin area.</EmptyState>
        )}
      </section>

      <section className="grid gap-8 lg:grid-cols-2">
        <div>
          <SectionTitle eyebrow="Version" title="Compatibility" />
          <Card className="divide-y divide-line">
            <Row label="Current version" value={p.latestVersion || "Not set"} />
            <Row label="Config formats" value={p.minFormat === p.maxFormat ? `Format ${p.minFormat}` : `Formats ${p.minFormat} to ${p.maxFormat}`} />
            <Row label="Platform" value={p.platform} />
            <div className="p-5 text-sm leading-relaxed"><p className="muted whitespace-pre-line">{p.compatNotes || "No extra compatibility notes."}</p></div>
          </Card>
        </div>
        <div>
          <SectionTitle eyebrow="Setup" title="Install and import a config" />
          <Card className="p-6">
            <p className="whitespace-pre-line text-sm leading-relaxed text-[color:var(--text)]/90">{p.installGuide || "The installation guide has not been written yet."}</p>
            <div className="hairline my-5" />
            <p className="muted text-sm leading-relaxed">Config import: open a config in the cloud, check that it is made for {p.platform}, then use its <span className="text-white">Download Config</span> button or copy its <span className="text-white">import code</span>. A config for {other?.platform} cannot be imported here.</p>
          </Card>
        </div>
      </section>

      <section>
        <SectionTitle eyebrow="Download" title="Get the Lua">The download is only for members with access to {p.name}.</SectionTitle>
        <Card className="p-6">
          {files.length === 0 ? (
            <p className="muted text-sm">No file has been published yet.</p>
          ) : (
            <ul className="divide-y divide-line">
              {files.map((f) => (
                <li key={f.id} className="flex flex-wrap items-center justify-between gap-4 py-4 first:pt-0 last:pb-0">
                  <div>
                    <p className="text-[15px] font-medium text-white">{f.filename}</p>
                    <p className="muted text-xs">{f.version ? `Version ${f.version} · ` : ""}{(f.bytes / 1024).toFixed(1)} KB · {formatDate(f.created_at)}{f.note ? ` · ${f.note}` : ""}</p>
                  </div>
                  {allowed ? (
                    <a href={`/api/downloads/${f.id}`} className="btn-primary btn-sm">Download</a>
                  ) : user ? (
                    <span className="text-xs text-[color:var(--muted)]">{access?.status === "expired" ? "Your access has expired" : access?.status === "suspended" ? "Access suspended" : "No access to this Lua"}</span>
                  ) : (
                    <a href={`/api/auth/login?next=/luas/${p.slug}`} className="btn-ghost btn-sm">Sign in to download</a>
                  )}
                </li>
              ))}
            </ul>
          )}
        </Card>
      </section>

      <section>
        <SectionTitle eyebrow="Changelog" title={`${p.platform} releases`} />
        {p.releases.length ? (
          <div className="space-y-4">
            {p.releases.slice(0, 5).map((r) => (
              <Card key={r.id} className="p-6">
                <div className="flex flex-wrap items-center justify-between gap-2">
                  <h3 className="text-base font-medium text-white">{r.title} <span className="font-normal text-[color:var(--muted)]">v{r.version}</span></h3>
                  <span className="flex items-center gap-2 text-xs text-[color:var(--faint)]">{r.is_demo && <DemoTag />}{formatDate(r.released_at)}</span>
                </div>
                <ul className="muted mt-3 space-y-1.5 text-sm">{r.notes.map((n, i) => <li key={i} className="flex gap-2"><span className="text-violet-400">·</span>{n}</li>)}</ul>
              </Card>
            ))}
          </div>
        ) : (
          <EmptyState title="No releases yet" />
        )}
      </section>

      <section>
        <SectionTitle eyebrow="Cloud" title={`${p.platform} config cloud`} action={<ButtonLink href={`/cloud/${p.slug}`} variant="ghost" small>Open catalog</ButtonLink>}>
          Configs here are only for {p.name}.
        </SectionTitle>
        {official.items.length + popular.items.length ? (
          <div className="grid gap-5 sm:grid-cols-2 lg:grid-cols-3">
            {[...official.items, ...popular.items.filter((c) => !official.items.some((o) => o.id === c.id))].slice(0, 3).map((c) => <ConfigCard key={c.id} c={c} />)}
          </div>
        ) : (
          <EmptyState title="No configs yet" action={<ButtonLink href="/dashboard/configs" variant="ghost" small>Upload the first one</ButtonLink>} />
        )}
      </section>
    </div>
  );
}

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex items-center justify-between gap-4 px-5 py-4 text-sm">
      <span className="muted">{label}</span>
      <span className="font-medium text-white">{value}</span>
    </div>
  );
}
