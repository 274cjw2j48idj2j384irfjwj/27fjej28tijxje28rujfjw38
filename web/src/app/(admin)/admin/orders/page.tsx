import Link from "next/link";
import { adminPageUser } from "@/components/admin/server";
import { OrderActions } from "@/components/admin/order-actions";
import { OrderStatusBadge } from "@/components/payments/status";
import { Card, EmptyState, PageHeader, formatDate } from "@/components/ui";
import { ORDER_STATUSES, searchOrders } from "@/lib/admin-orders";
import { PROVIDER_LABEL, formatMoney } from "@/lib/plan-format";

export const dynamic = "force-dynamic";

export default async function OrdersAdminPage({ searchParams }: { searchParams: Promise<{ q?: string; status?: string; page?: string }> }) {
  if (!(await adminPageUser())) return null;
  const sp = await searchParams;
  const q = (sp.q ?? "").slice(0, 100);
  const status = sp.status ?? "";
  const res = await searchOrders({ q, status, page: Number(sp.page ?? 1) });
  const href = (page: number) => `/admin/orders?${new URLSearchParams({ ...(q ? { q } : {}), ...(status ? { status } : {}), page: String(page) })}`;
  return (
    <div className="space-y-8 pb-4">
      <PageHeader eyebrow="Admin" title="Orders">{res.total} order{res.total === 1 ? "" : "s"}. Search by order reference, Invoice ID, e-mail or user.</PageHeader>

      <form method="get" className="card flex flex-wrap items-end gap-3 p-4" role="search">
        <div className="min-w-0 flex-1 basis-56"><label htmlFor="q" className="label">Search</label><input id="q" name="q" defaultValue={q} className="input" placeholder="Order id, key, e-mail, user" /></div>
        <div><label htmlFor="status" className="label">Status</label>
          <select id="status" name="status" defaultValue={status} className="input"><option value="">All</option>{ORDER_STATUSES.map((s) => <option key={s} value={s}>{s}</option>)}</select></div>
        <button className="btn-primary" type="submit">Filter</button>
        {(q || status) && <Link href="/admin/orders" className="btn-ghost">Clear</Link>}
      </form>

      {res.items.length === 0 ? <EmptyState title="No orders found">{q || status ? "Nothing matches this filter." : "Orders appear here after the first checkout."}</EmptyState> : (
        <ul className="space-y-3">
          {res.items.map((o) => (
            <li key={o.id}>
              <Card className="p-5">
                <div className="flex flex-wrap items-start justify-between gap-3">
                  <div className="min-w-0">
                    <p className="font-medium text-white">{o.plan_snapshot.name} <span className="muted font-normal">· {formatMoney(o.amount_cents, o.currency)} · {PROVIDER_LABEL[o.provider] ?? o.provider}</span></p>
                    <p className="mt-1 break-all font-mono text-xs text-[color:var(--faint)]">{o.id}</p>
                  </div>
                  <OrderStatusBadge status={o.status} />
                </div>
                <dl className="mt-3 grid gap-x-6 gap-y-1 text-sm sm:grid-cols-2">
                  <Row k="Created" v={formatDate(o.created_at, true)} />
                  <Row k="Paid" v={formatDate(o.paid_at, true)} />
                  <Row k="Issued" v={formatDate(o.issued_at, true)} />
                  <Row k="User" v={o.username ?? "guest"} />
                  <Row k="E-mail" v={o.email ?? "-"} />
                  <Row k="License" v={o.license_key ? `${o.plan_snapshot.license_plan} · ${o.plan_snapshot.duration}` : `${o.plan_snapshot.license_plan} · ${o.plan_snapshot.duration} (no key)`} />
                  {o.license_key && <Row k="Invoice ID" v={o.license_key} mono />}
                  {o.provider_ref && <Row k="Provider ref" v={o.provider_ref} mono />}
                  {o.provider_payment && <Row k="Payment" v={o.provider_payment} mono />}
                  {o.issue_attempts > 0 && <Row k="Issue attempts" v={String(o.issue_attempts)} />}
                </dl>
                {o.last_error && <p className="mt-3 rounded-lg border border-amber-400/25 bg-amber-500/[0.06] px-3 py-2 text-xs text-amber-200">{o.last_error}</p>}
                {o.admin_note && <p className="mt-2 text-xs text-[color:var(--muted)]">Note: {o.admin_note}</p>}
                <div className="mt-4 border-t border-line pt-4"><OrderActions id={o.id} status={o.status} hasKey={!!o.license_key} /></div>
              </Card>
            </li>
          ))}
        </ul>
      )}

      {res.pages > 1 && (
        <nav aria-label="Pages" className="flex items-center justify-between text-sm">
          {res.page > 1 ? <Link className="btn-ghost btn-sm" href={href(res.page - 1)}>Previous</Link> : <span />}
          <span className="muted">Page {res.page} of {res.pages}</span>
          {res.page < res.pages ? <Link className="btn-ghost btn-sm" href={href(res.page + 1)}>Next</Link> : <span />}
        </nav>
      )}
    </div>
  );
}

function Row({ k, v, mono }: { k: string; v: string; mono?: boolean }) {
  return <div className="flex gap-2"><dt className="w-28 shrink-0 text-[color:var(--faint)]">{k}</dt><dd className={`min-w-0 break-all text-[color:var(--text)] ${mono ? "font-mono text-xs" : ""}`}>{v}</dd></div>;
}
