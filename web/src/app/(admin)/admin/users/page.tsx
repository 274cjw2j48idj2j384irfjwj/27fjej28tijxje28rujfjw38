import Link from "next/link";
import { adminPageUser } from "@/components/admin/server";
import { Avatar, Badge, EmptyState, PageHeader, formatDate } from "@/components/ui";
import { td, th } from "@/components/admin/kit";
import { searchUsers } from "@/lib/admin";
import { avatarUrl } from "@/lib/discord";

export const dynamic = "force-dynamic";

export default async function UsersPage({ searchParams }: { searchParams: Promise<{ q?: string }> }) {
  if (!(await adminPageUser())) return null;
  const q = ((await searchParams).q ?? "").trim().slice(0, 40);
  const users = await searchUsers(q, 50);
  return (
    <div className="space-y-6">
      <PageHeader eyebrow="Admin" title="Users & Access">Find a member by name or Discord id, then open them to see their live access for each Lua and manage it.</PageHeader>
      <form method="get" role="search" className="flex flex-col gap-2 sm:flex-row">
        <label htmlFor="q" className="sr-only">Search users</label>
        <input id="q" name="q" defaultValue={q} className="input sm:max-w-md" placeholder="Name or Discord id" maxLength={40} autoComplete="off" />
        <button className="btn-primary" type="submit">Search</button>
        {q && <Link href="/admin/users" className="btn-ghost">Clear</Link>}
      </form>
      <p className="muted text-sm" aria-live="polite">{q ? `${users.length} result${users.length === 1 ? "" : "s"} for "${q}"` : `Latest ${users.length} sign-ins`}</p>

      {users.length === 0 ? (
        <EmptyState title="No users found">Try another name, or paste the full Discord id.</EmptyState>
      ) : (
        <>
          <ul className="space-y-3 md:hidden">
            {users.map((u) => (
              <li key={u.id}>
                <Link href={`/admin/users/${u.id}`} className="card card-hover flex items-center gap-3 p-4">
                  <Avatar src={avatarUrl(u.discord_id, u.avatar, 64)} name={u.global_name || u.username} size={40} />
                  <span className="min-w-0 flex-1">
                    <span className="block truncate font-medium text-white">{u.global_name || u.username}</span>
                    <span className="block truncate font-mono text-xs text-[color:var(--faint)]">{u.discord_id}</span>
                    <span className="mt-1.5 flex flex-wrap gap-1.5"><Flags u={u} /></span>
                  </span>
                </Link>
              </li>
            ))}
          </ul>
          <div className="card hidden overflow-hidden md:block">
            <table className="w-full">
              <caption className="sr-only">Users</caption>
              <thead className="border-b border-line"><tr><th className={th}>User</th><th className={th}>Discord id</th><th className={th}>Flags</th><th className={th}>Last sign-in</th><th className={th}><span className="sr-only">Open</span></th></tr></thead>
              <tbody className="divide-y divide-[color:var(--line)]">
                {users.map((u) => (
                  <tr key={u.id} className="hover:bg-white/[0.02]">
                    <td className={td}>
                      <span className="flex items-center gap-3">
                        <Avatar src={avatarUrl(u.discord_id, u.avatar, 64)} name="" size={32} />
                        <span className="font-medium text-white">{u.global_name || u.username}</span>
                      </span>
                    </td>
                    <td className={`${td} font-mono text-xs text-[color:var(--muted)]`}>{u.discord_id}</td>
                    <td className={td}><span className="flex flex-wrap gap-1.5"><Flags u={u} /></span></td>
                    <td className={`${td} text-[color:var(--muted)]`}>{formatDate(u.last_login_at, true)}</td>
                    <td className={`${td} text-right`}><Link href={`/admin/users/${u.id}`} className="btn-ghost btn-sm">Manage</Link></td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </>
      )}
    </div>
  );
}

function Flags({ u }: { u: { is_admin: boolean; suspended: boolean; verified_creator: boolean } }) {
  if (!u.is_admin && !u.suspended && !u.verified_creator) return <span className="text-xs text-[color:var(--faint)]">-</span>;
  return (
    <>
      {u.is_admin && <Badge tone="violet">Admin</Badge>}
      {u.verified_creator && <Badge tone="green">Verified</Badge>}
      {u.suspended && <Badge tone="red">Banned</Badge>}
    </>
  );
}
