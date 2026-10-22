import Link from "next/link";
import type { ProductContent } from "@/lib/site-data";
import { Badge } from "./ui";
import { Logo } from "./logo";

export function ProductCard({ p }: { p: ProductContent }) {
  const shot = p.media.find((m) => m.kind === "screenshot");
  const top = p.features.slice(0, 4);
  return (
    <Link href={`/luas/${p.slug}`} className="card card-hover group flex flex-col overflow-hidden">
      <div className="relative aspect-[16/9] overflow-hidden border-b border-line bg-gradient-to-br from-ink-800 to-ink-900">
        {shot ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img src={shot.src} alt={shot.caption || `${p.name} preview`} loading="lazy" className="h-full w-full object-cover transition duration-500 group-hover:scale-[1.03]" referrerPolicy="no-referrer" />
        ) : (
          <div className="flex h-full w-full flex-col items-center justify-center gap-3 text-center">
            <Logo size={44} className="opacity-90" />
            <span className="text-[11px] uppercase tracking-[0.2em] text-[color:var(--faint)]">Preview coming soon</span>
          </div>
        )}
        <div className="absolute left-4 top-4"><Badge tone="violet">{p.platform}</Badge></div>
        {shot?.is_demo && <div className="absolute right-4 top-4"><Badge tone="amber" className="uppercase">Demo image</Badge></div>}
      </div>
      <div className="flex flex-1 flex-col p-6">
        <h3 className="text-xl font-semibold tracking-tight text-white">{p.name}</h3>
        <p className="muted mt-2 text-sm leading-relaxed">{p.description}</p>
        {top.length > 0 ? (
          <ul className="mt-5 grid gap-2 text-sm">
            {top.map((f) => (
              <li key={f.title} className="flex items-start gap-2.5 text-[color:var(--text)]/90">
                <span className="mt-[7px] size-1.5 shrink-0 rounded-full bg-violet-400" />
                <span>{f.title}{f.demo && <span className="ml-2 text-[10px] uppercase tracking-wider text-amber-200/80">demo</span>}</span>
              </li>
            ))}
          </ul>
        ) : (
          <p className="mt-5 text-xs text-[color:var(--faint)]">The feature list is added by the team.</p>
        )}
        <div className="mt-auto flex items-center justify-between pt-6 text-sm">
          <span className="muted text-xs">{p.latestVersion ? `Version ${p.latestVersion}` : "Version not set"}</span>
          <span className="text-violet-300 transition group-hover:translate-x-0.5">View details →</span>
        </div>
      </div>
    </Link>
  );
}
