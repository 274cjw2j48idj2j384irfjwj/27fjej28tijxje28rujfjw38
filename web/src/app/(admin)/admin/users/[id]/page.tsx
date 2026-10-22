import Link from "next/link";
import { notFound } from "next/navigation";
import { UserActions } from "@/components/admin/user-actions";
import { adminPageUser } from "@/components/admin/server";
import { Avatar, Badge, Card, PageHeader, SectionTitle, StatusBadge, daysLeft, formatDate } from "@/components/ui";
import { td, th } from "@/components/admin/styles";
import { getProducts } from "@/config/site";
import { userDetail } from "@/lib/admin";
import { accessOf } from "@/lib/authz";
import { avatarUrl } from "@/lib/discord";

export const dynamic = "force-dynamic";

type Grant = { id: string; product_id: string; source: string; starts_at: Date; expires_at: Date | null; revoked_at: Date | null; note: string };
type Susp = { id: string; product_id: string; reason: string; created_at: Date; lifted_at: Date | null };

export default async function UserPage({ params }: { params: Promise<{ id: string }> }) {
  const me = await adminPageUser();
  if (!me) return null;
  const { id } = await params;
  if (!/^[0-9a-f-]{36}$/i.test(id)) notFound();
  const d = await userDetail(id);
  if (!d) notFound();
  const products = getProducts();
  const access = await Promise.all(products.map(async (p) => ({ p, a: await accessOf(id, p.id) })));
  const grants = d.grants as Grant[];
  const susp = d.suspensions as Susp[];
  const now = new Date();
  const u = d.user;
  const name = u.global_name || u.username;
  const productName = (pid: string) => products.find((p) => p.id === pid)?.name ?? pid;
  return (
    <div className="space-y-10 pb-4">
      <p className="text-sm"><Link href="/admin/users" className="text-violet-300 hover:text-white">&larr; All users</Link></p>
      <PageHeader eyebrow="User" title={name}>
        <span className="font-mono text-xs">Discord id {u.discord_id}</span> · joined {formatDate(u.created_at)} · last sign-in {formatDate(u.last_login_at, true)}
      </PageHeader>
      <div className="-mt-4 flex flex-wrap items-center gap-2">
        <Avatar src={avatarUrl(u.discord_id, u.avatar, 64)} name="" size={40} />
        {u.is_admin && <Badge tone="violet">Admin</Badge>}
        {u.verified_creator && <Badge tone="green">Verified creator</Badge>}
        {u.suspended && <Badge tone="red">Banned from the platform</Badge>}
        {id === me.id && <Badge>This is you</Badge>}
      </div>

      <section>
        <SectionTitle eyebrow="Live status" title="Access per Lua">The result the backend computes right now from Discord roles, grants and suspensions.</SectionTitle>
        <div className="grid gap-4 md:grid-cols-2">
          {access.map(({ p, a }) => (
            <Card key={p.id} className="p-5">
              <div className="flex items-center justify-between gap-3">
                <h3 className="font-medium text-white">{p.name}</h3>
                <StatusBadge status={a.status} />
              </div>
              <dl className="mt-4 grid grid-cols-[auto_1fr] gap-x-4 gap-y-1.5 text-sm">
                <dt className="muted">Source</dt><dd>{a.via === "discord_role" ? "Discord role" : a.via === "admin" ? "Admin grant" : a.via === "reward" ? "Leaderboard reward" : "-"}</dd>
                <dt className="muted">Ends</dt><dd>{a.status === "no_access" || a.status === "suspended" ? "-" : a.expiresAt ? `${formatDate(a.expiresAt, true)} (${daysLeft(a.expiresAt, now)})` : "Never"}</dd>
              </dl>
              {a.integrationError && <p className="mt-3 text-xs text-amber-300">Discord could not be asked, so this only counts grants.</p>}
            </Card>
          ))}
        </div>
      </section>

      <UserActions
        userId={id}
        name={name}
        isSelf={id === me.id}
        owner={me.owner}
        flags={{ admin: u.is_admin, banned: u.suspended, verified: u.verified_creator }}
        products={products.map((p) => ({ id: p.id, name: p.name, suspended: susp.some((s) => s.product_id === p.id && !s.lifted_at) }))}
        grants={grants.map((g) => ({ id: g.id, product: productName(g.product_id), source: g.source, starts: formatDate(g.starts_at, true), ends: g.expires_at ? formatDate(g.expires_at, true) : "Open ended", note: g.note, state: g.revoked_at ? "revoked" : g.expires_at && g.expires_at <= now ? "ended" : g.starts_at > now ? "scheduled" : "live" }))}
      />

      <section>
        <SectionTitle eyebrow="History" title="Suspensions" />
        {susp.length === 0 ? <p className="muted text-sm">No product suspension was ever set for this user.</p> : (
          <div className="card overflow-hidden"><div className="scroll-thin overflow-x-auto" role="region" aria-label="Suspensions" tabIndex={0}>
            <table className="w-full min-w-[520px]">
              <thead className="border-b border-line"><tr><th className={th}>Lua</th><th className={th}>Reason</th><th className={th}>Since</th><th className={th}>State</th></tr></thead>
              <tbody className="divide-y divide-[color:var(--line)]">
                {susp.map((s) => (
                  <tr key={s.id}><td className={td}>{productName(s.product_id)}</td><td className={`${td} muted`}>{s.reason || "-"}</td><td className={td}>{formatDate(s.created_at, true)}</td><td className={td}>{s.lifted_at ? <Badge>Lifted {formatDate(s.lifted_at)}</Badge> : <Badge tone="red">Active</Badge>}</td></tr>
                ))}
              </tbody>
            </table>
          </div></div>
        )}
      </section>
    </div>
  );
}
