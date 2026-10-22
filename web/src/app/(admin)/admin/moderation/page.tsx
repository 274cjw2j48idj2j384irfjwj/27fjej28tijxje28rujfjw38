import Link from "next/link";
import { ConfigActions, ReportActions } from "@/components/admin/moderation";
import { td, th } from "@/components/admin/styles";
import { adminPageUser } from "@/components/admin/server";
import { Badge, Card, EmptyState, PageHeader, SectionTitle, formatDate } from "@/components/ui";
import { getProduct } from "@/config/site";
import { listOpenReports } from "@/lib/admin";
import { listAdminConfigs } from "@/lib/admin-configs";

export const dynamic = "force-dynamic";

type Report = { id: string; reason: string; details: string; created_at: Date; config_id: string; slug: string; name: string; product_id: string; hidden: boolean; reporter: string; owner: string };

export default async function ModerationPage({ searchParams }: { searchParams: Promise<{ q?: string; product?: string; page?: string }> }) {
  if (!(await adminPageUser())) return null;
  const sp = await searchParams;
  const q = (sp.q ?? "").trim().slice(0, 60);
  const product = sp.product === "gamesense" || sp.product === "primordial" ? sp.product : "";
  const [reports, list] = await Promise.all([listOpenReports() as Promise<Report[]>, listAdminConfigs({ q, product, page: Number(sp.page ?? 1) })]);
  const pname = (id: string) => getProduct(id)?.platform ?? id;
  const pslug = (id: string) => getProduct(id)?.slug ?? id;
  const href = (page: number) => `/admin/moderation?${new URLSearchParams({ ...(q && { q }), ...(product && { product }), page: String(page) })}`;
  return (
    <div className="space-y-12 pb-4">
      <PageHeader eyebrow="Admin" title="Config Moderation">Decide on reports and manage any config in the cloud, including hidden and private ones.</PageHeader>

      <section>
        <SectionTitle eyebrow="Queue" title={`Open reports (${reports.length})`} />
        {reports.length === 0 ? <EmptyState title="No open reports">When someone reports a config it shows up here.</EmptyState> : (
          <ul className="space-y-3">
            {reports.map((r) => (
              <li key={r.id}>
                <Card className="p-5">
                  <div className="flex flex-wrap items-start justify-between gap-4">
                    <div className="min-w-0 max-w-2xl">
                      <p className="flex flex-wrap items-center gap-2 font-medium text-white">
                        {r.name} <Badge>{pname(r.product_id)}</Badge> {r.hidden && <Badge tone="red">Hidden</Badge>}
                        <Link href={`/cloud/${pslug(r.product_id)}/${r.slug}`} className="text-xs font-normal text-violet-300 hover:text-white" target="_blank">View</Link>
                      </p>
                      <p className="mt-2 text-sm"><span className="muted">Reason:</span> <span className="text-amber-200">{r.reason}</span></p>
                      {r.details && <p className="muted mt-1 whitespace-pre-wrap break-words text-sm">{r.details}</p>}
                      <p className="mt-2 text-xs text-[color:var(--faint)]">Reported by {r.reporter} · owner {r.owner} · {formatDate(r.created_at, true)}</p>
                    </div>
                    <ReportActions id={r.id} configId={r.config_id} name={r.name} hidden={r.hidden} />
                  </div>
                </Card>
              </li>
            ))}
          </ul>
        )}
      </section>

      <section>
        <SectionTitle eyebrow="Catalog" title="All configs"><span>{list.total} config{list.total === 1 ? "" : "s"} match. Ones with open reports come first.</span></SectionTitle>
        <form method="get" role="search" className="mb-5 flex flex-col gap-2 sm:flex-row">
          <label htmlFor="mq" className="sr-only">Search configs</label>
          <input id="mq" name="q" defaultValue={q} className="input sm:max-w-sm" placeholder="Config, slug, owner name or Discord id" maxLength={60} />
          <label htmlFor="mp" className="sr-only">Lua</label>
          <select id="mp" name="product" defaultValue={product} className="input sm:w-48"><option value="">Both Luas</option><option value="gamesense">Gamesense</option><option value="primordial">Primordial</option></select>
          <button className="btn-primary" type="submit">Filter</button>
          {(q || product) && <Link href="/admin/moderation" className="btn-ghost">Clear</Link>}
        </form>

        {list.items.length === 0 ? <EmptyState title="No configs match">Change the search or the Lua filter.</EmptyState> : (
          <div className="card overflow-hidden">
            <div className="scroll-thin overflow-x-auto" role="region" aria-label="Configs" tabIndex={0}>
              <table className="w-full min-w-[900px]">
                <thead className="border-b border-line"><tr><th className={th}>Config</th><th className={th}>Owner</th><th className={th}>Status</th><th className={th}>Stats</th><th className={th}>Updated</th><th className={th}>Actions</th></tr></thead>
                <tbody className="divide-y divide-[color:var(--line)]">
                  {list.items.map((c) => (
                    <tr key={c.id} className="align-top">
                      <td className={td}>
                        <Link href={`/cloud/${pslug(c.product_id)}/${c.slug}`} target="_blank" className="font-medium text-white hover:text-violet-200">{c.name}</Link>
                        <p className="mt-0.5 text-xs text-[color:var(--faint)]">{pname(c.product_id)} · <span className="font-mono">{c.slug}</span></p>
                      </td>
                      <td className={`${td} muted`}>{c.owner_name}</td>
                      <td className={td}>
                        <span className="flex flex-wrap gap-1.5">
                          <Badge tone={c.visibility === "public" ? "gray" : "amber"}>{c.visibility}</Badge>
                          {c.hidden && <Badge tone="red">Hidden</Badge>}
                          {c.is_featured && <Badge tone="violet">Featured</Badge>}
                          {c.is_official && <Badge tone="green">Official</Badge>}
                          {c.is_demo && <Badge tone="amber">Demo</Badge>}
                          {c.reports_open > 0 && <Badge tone="red">{c.reports_open} open report{c.reports_open === 1 ? "" : "s"}</Badge>}
                        </span>
                      </td>
                      <td className={`${td} whitespace-nowrap muted`}>{c.likes_count} likes · {c.downloads_count} dl{c.reports_total ? ` · ${c.reports_total} reports` : ""}</td>
                      <td className={`${td} whitespace-nowrap muted`}>{formatDate(c.updated_at)}</td>
                      <td className={td}><ConfigActions id={c.id} name={c.name} hidden={c.hidden} featured={c.is_featured} official={c.is_official} /></td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        )}
        {list.pages > 1 && (
          <nav aria-label="Pages" className="mt-5 flex items-center justify-between gap-3 text-sm">
            {list.page > 1 ? <Link className="btn-ghost btn-sm" href={href(list.page - 1)}>Previous</Link> : <span />}
            <span className="muted">Page {list.page} of {list.pages}</span>
            {list.page < list.pages ? <Link className="btn-ghost btn-sm" href={href(list.page + 1)}>Next</Link> : <span />}
          </nav>
        )}
      </section>
    </div>
  );
}
