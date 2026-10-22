import type { Metadata } from "next";
import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { ConfigActions } from "@/components/config-actions";
import { VerifiedMark } from "@/components/config-card";
import { Avatar, Badge, Card, DemoTag, Notice, SectionTitle, cx, formatDate } from "@/components/ui";
import { getProduct } from "@/config/site";
import { hasAccess } from "@/lib/access";
import { accessOf, currentUser, isAdmin } from "@/lib/authz";
import { compatFor, configImages, getConfigBySlug, getVersionPayload, listVersions } from "@/lib/configs";
import { diffData, shortValue } from "@/lib/config-diff";
import { avatarUrl } from "@/lib/discord";
import { one } from "@/lib/db";

export const dynamic = "force-dynamic";

type Params = { product: string; slug: string };

export async function generateMetadata({ params }: { params: Promise<Params> }): Promise<Metadata> {
  const { slug } = await params;
  const c = await getConfigBySlug(slug, null);
  return { title: c?.name ?? "Config", robots: c && c.visibility !== "public" ? { index: false } : undefined };
}

export default async function ConfigPage({ params, searchParams }: { params: Promise<Params>; searchParams: Promise<{ a?: string; b?: string }> }) {
  const { product, slug } = await params;
  const sp = await searchParams;
  const user = await currentUser();
  const viewer = user ? { id: user.id, isAdmin: isAdmin(user) } : null;
  const cfg = await getConfigBySlug(slug, viewer);
  if (!cfg) notFound();
  const p = getProduct(cfg.product_id)!;
  if (p.slug !== product) redirect(`/cloud/${p.slug}/${cfg.slug}`);

  const [versions, images, access, state] = await Promise.all([
    listVersions(cfg.id),
    configImages(cfg.id),
    user ? accessOf(user.id, cfg.product_id) : null,
    user ? one<{ liked: boolean; saved: boolean }>("select exists (select 1 from config_likes where user_id = $1 and config_id = $2) as liked, exists (select 1 from config_library where user_id = $1 and config_id = $2) as saved", [user.id, cfg.id]) : null,
  ]);
  const compat = await compatFor(cfg.id, cfg.latest_version);
  const canUse = access ? hasAccess(access.status) : false;
  const lockedReason = !access ? "" : access.integrationError && !canUse ? "We could not check your Discord roles right now. Try again in a minute." : access.status === "expired" ? "Your access has expired." : access.status === "suspended" ? "Your access is suspended." : `You need access to ${p.name} to use this config.`;
  const reasonText: Record<string, string> = { wrong_product: `it is made for another Lua`, format_too_old: "its config format is too old for the current Lua", format_too_new: "its config format is newer than this Lua supports" };

  // version compare: only for members who may use the config, the data is not shown to anybody else
  const a = Number(sp.a) || (versions[1]?.version ?? 0);
  const b = Number(sp.b) || (versions[0]?.version ?? 0);
  let diff: ReturnType<typeof diffData> | null = null;
  if (canUse && a && b && a !== b) {
    const [pa, pb] = await Promise.all([getVersionPayload(cfg.id, a), getVersionPayload(cfg.id, b)]);
    if (pa && pb) diff = diffData(pa.payload.data, pb.payload.data);
  }

  return (
    <div className="space-y-12">
      <nav className="text-sm text-[color:var(--muted)]" aria-label="Breadcrumb">
        <Link href="/cloud" className="hover:text-white">Cloud</Link> <span className="px-1.5">/</span> <Link href={`/cloud/${p.slug}`} className="hover:text-white">{p.platform}</Link> <span className="px-1.5">/</span> <span className="text-white">{cfg.name}</span>
      </nav>

      <div className="grid gap-8 lg:grid-cols-[1.5fr_1fr]">
        <div className="space-y-8">
          <div>
            <div className="mb-4 flex flex-wrap items-center gap-2">
              <Badge tone="violet">{p.platform}</Badge>
              {cfg.is_official && <Badge tone="violet">Official</Badge>}
              {cfg.is_featured && <Badge tone="amber">Featured</Badge>}
              {cfg.visibility !== "public" && <Badge>{cfg.visibility}</Badge>}
              {cfg.hidden && <Badge tone="red">Hidden by moderation</Badge>}
              {cfg.is_demo && <DemoTag />}
            </div>
            <h1 className="text-3xl font-semibold tracking-tight text-white sm:text-4xl">{cfg.name}</h1>
            <p className="muted mt-4 whitespace-pre-line text-[15px] leading-relaxed">{cfg.description || "No description."}</p>
            {cfg.tags.length > 0 && <div className="mt-4 flex flex-wrap gap-2">{cfg.tags.map((t) => <Link key={t} href={`/cloud/${p.slug}?tag=${encodeURIComponent(t)}`} className="rounded-md bg-white/[0.04] px-2.5 py-1 text-xs text-[color:var(--muted)] hover:text-white">#{t}</Link>)}</div>}
          </div>

          {images.length > 0 && (
            <div className="grid gap-3 sm:grid-cols-2">
              {images.map((id) => (
                // eslint-disable-next-line @next/next/no-img-element
                <img key={id} src={`/api/media/${id}`} alt={`${cfg.name} preview`} loading="lazy" className="aspect-video w-full rounded-xl border border-line object-cover" />
              ))}
            </div>
          )}

          <section>
            <SectionTitle title="Version history" />
            <Card className="divide-y divide-line">
              {versions.map((v) => (
                <div key={v.version} className="flex flex-wrap items-center justify-between gap-3 px-5 py-4 text-sm">
                  <div>
                    <p className="font-medium text-white">Version {v.version}{v.version === cfg.latest_version && <span className="ml-2 text-xs text-violet-300">latest</span>}</p>
                    <p className="muted text-xs">{v.changelog || "No notes"} · Lua {v.lua_version} · format {v.format_version}</p>
                  </div>
                  <span className="text-xs text-[color:var(--faint)]">{formatDate(v.created_at)} · {(v.payload_bytes / 1024).toFixed(1)} KB</span>
                </div>
              ))}
            </Card>
          </section>

          {versions.length > 1 && (
            <section>
              <SectionTitle title="Compare versions">See what the author changed between two versions.</SectionTitle>
              {canUse ? (
                <Card className="p-5">
                  <form method="get" className="flex flex-wrap items-end gap-3">
                    <div><label className="label" htmlFor="a">From</label><select id="a" name="a" defaultValue={a} className="input">{versions.map((v) => <option key={v.version} value={v.version}>v{v.version}</option>)}</select></div>
                    <div><label className="label" htmlFor="b">To</label><select id="b" name="b" defaultValue={b} className="input">{versions.map((v) => <option key={v.version} value={v.version}>v{v.version}</option>)}</select></div>
                    <button className="btn-ghost">Compare</button>
                  </form>
                  {diff && (
                    <div className="mt-5">
                      {diff.entries.length === 0 ? <p className="muted text-sm">No difference in the config data.</p> : (
                        <ul className="scroll-thin max-h-80 space-y-1.5 overflow-y-auto font-mono text-xs">
                          {diff.entries.map((e) => (
                            <li key={e.path} className={cx("rounded-lg px-3 py-2", e.kind === "added" ? "bg-emerald-500/10 text-emerald-200" : e.kind === "removed" ? "bg-red-500/10 text-red-200" : "bg-violet-500/10 text-violet-100")}>
                              <span className="text-[color:var(--muted)]">{e.path}</span> {e.kind === "changed" ? `${shortValue(e.before)} → ${shortValue(e.after)}` : e.kind === "added" ? `+ ${shortValue(e.after)}` : `- ${shortValue(e.before)}`}
                            </li>
                          ))}
                        </ul>
                      )}
                      {diff.truncated && <p className="muted mt-2 text-xs">Only the first changes are listed.</p>}
                    </div>
                  )}
                </Card>
              ) : (
                <Notice tone="gray">The config data is only shown to members with access to {p.name}.</Notice>
              )}
            </section>
          )}
        </div>

        <aside className="space-y-5 lg:sticky lg:top-24 lg:self-start">
          <Card className="p-6">
            <div className="flex items-center gap-3">
              <Avatar src={avatarUrl(cfg.owner_discord_id, cfg.owner_avatar, 64)} name={cfg.owner_name} size={40} />
              <div className="min-w-0">
                <p className="flex items-center gap-1.5 truncate text-[15px] font-medium text-white"><Link href={`/u/${cfg.owner_discord_id}`} className="truncate hover:text-violet-200">{cfg.owner_name}</Link>{cfg.owner_verified && <VerifiedMark />}</p>
                <p className="muted text-xs">Creator</p>
              </div>
            </div>
            <div className="hairline my-5" />
            <ConfigActions
              slug={cfg.slug}
              signedIn={!!user}
              canUse={canUse}
              lockedReason={lockedReason}
              compatible={compat?.ok ?? true}
              incompatibleReason={reasonText[compat?.reason ?? ""] ?? "unknown"}
              liked={state?.liked ?? false}
              saved={state?.saved ?? false}
              likes={cfg.likes_count}
              mine={!!user && user.id === cfg.owner_id}
              loginHref={`/api/auth/login?next=/cloud/${p.slug}/${cfg.slug}`}
            />
          </Card>
          <Card className="divide-y divide-line text-sm">
            <Info label="Made for" value={p.name} />
            <Info label="Config version" value={`v${cfg.latest_version}`} />
            <Info label="Lua version" value={cfg.lua_version} />
            <Info label="Format" value={String(cfg.format_version)} />
            <Info label="Share code" value={cfg.slug} mono />
            <Info label="Downloads" value={String(cfg.downloads_count)} />
            <Info label="Imports" value={String(cfg.imports_count)} />
            <Info label="Updated" value={formatDate(cfg.updated_at)} />
          </Card>
          {compat?.outdated && compat.ok && <Notice tone="amber">Made with an older Lua version. It should import, but some options may be missing.</Notice>}
        </aside>
      </div>
    </div>
  );
}

function Info({ label, value, mono }: { label: string; value: string; mono?: boolean }) {
  return (
    <div className="flex items-center justify-between gap-4 px-5 py-3">
      <span className="muted">{label}</span>
      <span className={cx("text-white", mono && "font-mono text-xs")}>{value}</span>
    </div>
  );
}
