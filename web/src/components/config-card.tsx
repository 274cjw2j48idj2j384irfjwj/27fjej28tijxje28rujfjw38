import Link from "next/link";
import { getProduct } from "@/config/site";
import type { ConfigListItem } from "@/lib/configs";
import { avatarUrl } from "@/lib/discord";
import { Avatar, Badge, formatDate } from "./ui";

export function VerifiedMark() {
  return (
    <span title="Verified creator" className="inline-flex size-4 items-center justify-center rounded-full bg-violet-500/25 text-violet-200">
      <svg width="10" height="10" viewBox="0 0 10 10" aria-label="Verified creator"><path d="M2 5.2 4.1 7.3 8 3" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" /></svg>
    </span>
  );
}

export function ConfigCard({ c }: { c: ConfigListItem }) {
  const product = getProduct(c.product_id);
  return (
    <Link href={`/cloud/${product?.slug ?? c.product_id}/${c.slug}`} className="card card-hover group flex flex-col overflow-hidden">
      <div className="relative aspect-[16/8] border-b border-line bg-gradient-to-br from-ink-800 to-ink-900">
        {c.image_id ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img src={`/api/media/${c.image_id}`} alt="" loading="lazy" className="h-full w-full object-cover" />
        ) : (
          <div className="flex h-full items-center justify-center text-[11px] uppercase tracking-[0.2em] text-[color:var(--faint)]">No preview</div>
        )}
        <div className="absolute left-3 top-3 flex gap-1.5">
          {c.is_official && <Badge tone="violet">Official</Badge>}
          {c.is_featured && <Badge tone="amber">Featured</Badge>}
          {c.is_demo && <Badge tone="amber" className="uppercase">Demo</Badge>}
        </div>
      </div>
      <div className="flex flex-1 flex-col p-5">
        <div className="flex items-start justify-between gap-3">
          <h3 className="line-clamp-1 text-base font-semibold text-white">{c.name}</h3>
          <span className="shrink-0 text-[11px] text-[color:var(--faint)]">v{c.latest_version}</span>
        </div>
        <p className="muted mt-1.5 line-clamp-2 min-h-[2.5rem] text-[13px] leading-relaxed">{c.description || "No description."}</p>
        {c.tags.length > 0 && (
          <div className="mt-3 flex flex-wrap gap-1.5">
            {c.tags.slice(0, 3).map((t) => (
              <span key={t} className="rounded-md bg-white/[0.04] px-2 py-0.5 text-[11px] text-[color:var(--muted)]">#{t}</span>
            ))}
          </div>
        )}
        <div className="mt-auto flex items-center justify-between pt-4">
          <span className="flex min-w-0 items-center gap-2 text-xs text-[color:var(--muted)]">
            <Avatar src={avatarUrl(c.owner_discord_id, c.owner_avatar, 48)} name={c.owner_name} size={20} />
            <span className="truncate">{c.owner_name}</span>
            {c.owner_verified && <VerifiedMark />}
          </span>
          <span className="flex shrink-0 items-center gap-3 text-xs text-[color:var(--faint)]">
            <span title="Likes">♥ {c.likes_count}</span>
            <span title="Downloads and imports">↓ {c.downloads_count + c.imports_count}</span>
          </span>
        </div>
        <p className="mt-2 text-[11px] text-[color:var(--faint)]">{product?.platform} · updated {formatDate(c.updated_at)}</p>
      </div>
    </Link>
  );
}
