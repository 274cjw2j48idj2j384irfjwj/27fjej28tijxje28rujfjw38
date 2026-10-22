import type { Metadata } from "next";
import Link from "next/link";
import { Bookmark, Heart } from "lucide-react";
import { Avatar, Badge, Card, EmptyState, Notice, PageHeader, formatDate } from "@/components/ui";
import { canUse, reasonFor } from "@/components/dashboard/access";
import { LibraryActions } from "@/components/dashboard/library-actions";
import { getProduct } from "@/config/site";
import { libraryOf } from "@/lib/configs";
import { accessAll, requireDashboardUser } from "@/lib/dashboard-data";
import { avatarUrl } from "@/lib/discord";

export const dynamic = "force-dynamic";
export const metadata: Metadata = { title: "Saved Configs" };

export default async function SavedPage() {
  const user = await requireDashboardUser("/dashboard/saved");
  const [items, access] = await Promise.all([libraryOf(user.id), accessAll(user.id)]);
  const byProduct = new Map(access.map((a) => [a.product.id as string, a]));
  const locked = access.filter((a) => !canUse(a.access) && items.some((i) => i.product_id === a.product.id));
  return (
    <div className="space-y-8">
      <PageHeader eyebrow="Dashboard" title="Saved Configs">Configs you saved from the cloud. Download them, copy the import code for the Lua menu, or pick up a new version.</PageHeader>

      {locked.map((a) => (
        <Notice key={a.product.id} tone="amber"><span className="font-medium">{a.product.name}:</span> {reasonFor(a.access, a.product.name).text} Download, import code and re-save are locked until it works again.</Notice>
      ))}

      {items.length === 0 ? (
        <EmptyState title="Nothing saved yet" icon={<Bookmark size={28} aria-hidden="true" />} action={<Link href="/cloud" className="btn-primary btn-sm">Browse the cloud</Link>}>
          Save a config from the cloud and it shows up here with its version and update status.
        </EmptyState>
      ) : (
        <ul className="grid gap-4 lg:grid-cols-2">
          {items.map((c) => {
            const a = byProduct.get(c.product_id);
            const product = getProduct(c.product_id);
            const lockedHere = !!a && !canUse(a.access);
            return (
              <li key={c.id}>
                <Card className="flex h-full flex-col p-5">
                  <div className="flex items-start justify-between gap-3">
                    <div className="min-w-0">
                      <Link href={`/cloud/${product?.slug ?? c.product_id}/${c.slug}`} className="line-clamp-1 font-semibold text-white hover:text-violet-200">{c.name}</Link>
                      <p className="muted mt-0.5 text-xs">{product?.name ?? c.product_id}</p>
                    </div>
                    {c.update_available ? <Badge tone="amber">Update available</Badge> : <Badge tone="green">Up to date</Badge>}
                  </div>
                  <div className="mt-3 flex flex-wrap gap-1.5">
                    {c.visibility !== "public" && <Badge tone="gray">{c.visibility}</Badge>}
                    {c.hidden && <Badge tone="red">Hidden by moderation</Badge>}
                    {c.is_official && <Badge tone="violet">Official</Badge>}
                  </div>
                  <p className="muted mt-3 line-clamp-2 text-[13px] leading-relaxed">{c.description || "No description."}</p>
                  <div className="mt-4 flex flex-wrap items-center gap-x-4 gap-y-1 text-xs text-[color:var(--faint)]">
                    <span className="flex min-w-0 items-center gap-1.5"><Avatar src={avatarUrl(c.owner_discord_id, c.owner_avatar, 48)} name={c.owner_name} size={18} /><span className="truncate">{c.owner_name}</span></span>
                    <span>Saved v{c.saved_version}{c.update_available ? `, latest v${c.latest_version}` : ""}</span>
                    <span className="flex items-center gap-1"><Heart size={12} aria-hidden="true" />{c.likes_count}</span>
                    <span>updated {formatDate(c.updated_at)}</span>
                  </div>
                  <div className="mt-auto pt-5">
                    <LibraryActions slug={c.slug} updateAvailable={c.update_available} locked={lockedHere} lockedReason={a ? reasonFor(a.access, a.product.name).title : ""} />
                  </div>
                </Card>
              </li>
            );
          })}
        </ul>
      )}
    </div>
  );
}
