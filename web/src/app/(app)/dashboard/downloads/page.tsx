import type { Metadata } from "next";
import { Download, Lock } from "lucide-react";
import { Badge, Card, EmptyState, Notice, PageHeader, formatDate } from "@/components/ui";
import { canUse, reasonFor } from "@/components/dashboard/access";
import { StatusPill } from "@/components/dashboard/parts";
import { formatBytes } from "@/components/dashboard/api";
import { accessAll, requireDashboardUser } from "@/lib/dashboard-data";
import { listDownloads } from "@/lib/downloads";
import { getProductContent } from "@/lib/site-data";

export const dynamic = "force-dynamic";
export const metadata: Metadata = { title: "Downloads" };

export default async function DownloadsPage() {
  const user = await requireDashboardUser("/dashboard/downloads");
  const access = await accessAll(user.id);
  const blocks = await Promise.all(
    access.map(async (a) => ({ ...a, files: await listDownloads(a.product.id), content: await getProductContent(a.product.id) })),
  );
  return (
    <div className="space-y-12">
      <PageHeader eyebrow="Dashboard" title="Downloads">The loader file of each Lua. The server checks your access again before it sends a file.</PageHeader>

      {blocks.map(({ product, access: a, files, content }) => {
        const r = reasonFor(a, product.name);
        const allowed = canUse(a);
        return (
          <section key={product.id} aria-labelledby={`dl-${product.id}`}>
            <div className="mb-5 flex flex-wrap items-center justify-between gap-3">
              <div>
                <p className="eyebrow mb-1.5">{product.platform}</p>
                <h2 id={`dl-${product.id}`} className="text-2xl font-semibold tracking-tight text-white">{product.name}</h2>
              </div>
              <StatusPill access={a} />
            </div>

            {a.status === "expiring_soon" && <div className="mb-4"><Notice tone="amber">{r.text}</Notice></div>}
            {!allowed && (
              <div className="mb-4">
                <Notice tone={r.tone === "red" ? "red" : r.tone === "amber" ? "amber" : "gray"}>
                  <span className="flex items-start gap-2"><Lock size={15} className="mt-0.5 shrink-0" aria-hidden="true" /><span><span className="font-medium">{r.title}.</span> {r.text} Downloads stay locked until then.</span></span>
                </Notice>
              </div>
            )}

            {files.length === 0 ? (
              <EmptyState title="No file uploaded yet">The team has not uploaded a loader for {product.name}. It shows up here as soon as they do.</EmptyState>
            ) : (
              <ul className="space-y-3">
                {files.map((f, i) => (
                  <li key={f.id}>
                    <Card className="flex flex-wrap items-center justify-between gap-4 p-5">
                      <div className="min-w-0">
                        <p className="flex flex-wrap items-center gap-2">
                          <span className="break-all font-medium text-white">{f.filename}</span>
                          {f.version && <Badge tone="violet">v{f.version}</Badge>}
                          {i === 0 && <Badge tone="green">Latest</Badge>}
                        </p>
                        {f.note && <p className="muted mt-1 text-sm">{f.note}</p>}
                        <p className="mt-1 text-xs text-[color:var(--faint)]">{formatBytes(f.bytes)} · uploaded {formatDate(f.created_at)}</p>
                      </div>
                      {allowed ? (
                        <a href={`/api/downloads/${f.id}`} download={f.filename} className="btn-primary btn-sm"><Download size={14} aria-hidden="true" />Download</a>
                      ) : (
                        <button type="button" className="btn-ghost btn-sm" disabled title={r.text}><Lock size={14} aria-hidden="true" />Locked</button>
                      )}
                    </Card>
                  </li>
                ))}
              </ul>
            )}

            <div className="mt-6">
              <h3 className="mb-3 text-sm font-medium uppercase tracking-wider text-[color:var(--muted)]">How to install</h3>
              <Card className="p-5">
                {content?.installGuide.trim() ? (
                  <div className="space-y-2 text-sm leading-relaxed">
                    {content.installGuide.split("\n").filter((l) => l.trim()).map((line, i) => <p key={i} className="text-[color:var(--text)]/90">{line.trim()}</p>)}
                  </div>
                ) : (
                  <p className="muted text-sm">The team has not written the install steps for this Lua yet.</p>
                )}
              </Card>
            </div>
          </section>
        );
      })}
    </div>
  );
}
