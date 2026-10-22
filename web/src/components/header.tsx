import Link from "next/link";
import { getProducts } from "@/config/site";
import { currentUser, isAdmin } from "@/lib/authz";
import { avatarUrl } from "@/lib/discord";
import { Logo, Wordmark } from "./logo";
import { Avatar } from "./ui";
import { MobileMenu, SignOutButton } from "./header-client";

export type NavLink = { href: string; label: string };

export function navLinks(): NavLink[] {
  return [
    { href: "/features", label: "Features" },
    { href: "/previews", label: "Previews" },
    { href: "/cloud", label: "Cloud Configs" },
    { href: "/leaderboard", label: "Leaderboard" },
    { href: "/changelog", label: "Changelog" },
    { href: "/faq", label: "FAQ" },
    { href: "/support", label: "Support" },
  ];
}

export async function SiteHeader() {
  const user = await currentUser();
  const products = getProducts();
  const links = navLinks();
  const admin = user ? isAdmin(user) : false;
  return (
    <header className="sticky top-0 z-40 border-b border-line bg-ink-950/75 backdrop-blur-xl">
      <div className="mx-auto flex h-16 max-w-6xl items-center gap-6 px-4 sm:px-6">
        <Link href="/" className="flex items-center gap-2.5" aria-label="SPECTER home">
          <Logo />
          <Wordmark className="hidden sm:inline" />
        </Link>

        <nav className="hidden items-center gap-1 lg:flex" aria-label="Main">
          <details className="group relative">
            <summary className="flex cursor-pointer list-none items-center gap-1 rounded-lg px-3 py-2 text-sm text-[color:var(--muted)] transition hover:text-white [&::-webkit-details-marker]:hidden">
              Luas
              <svg width="12" height="12" viewBox="0 0 12 12" className="transition group-open:rotate-180" aria-hidden="true"><path d="M2.5 4.5 6 8l3.5-3.5" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" /></svg>
            </summary>
            <div className="card absolute left-0 top-full mt-2 w-72 p-2">
              {products.map((p) => (
                <Link key={p.id} href={`/luas/${p.slug}`} className="block rounded-xl px-3 py-2.5 transition hover:bg-white/[0.05]">
                  <span className="block text-sm font-medium text-white">{p.name}</span>
                  <span className="muted block text-xs">{p.platform}</span>
                </Link>
              ))}
            </div>
          </details>
          {links.map((l) => (
            <Link key={l.href} href={l.href} className="rounded-lg px-3 py-2 text-sm text-[color:var(--muted)] transition hover:text-white">
              {l.label}
            </Link>
          ))}
        </nav>

        <div className="ml-auto flex items-center gap-2">
          {user ? (
            <details className="relative">
              <summary className="flex cursor-pointer list-none items-center gap-2 rounded-xl border border-line bg-white/[0.03] py-1.5 pl-1.5 pr-3 transition hover:border-violet-400/40 [&::-webkit-details-marker]:hidden">
                <Avatar src={avatarUrl(user.discord_id, user.avatar, 64)} name={user.global_name || user.username} size={28} />
                <span className="hidden max-w-[120px] truncate text-sm sm:inline">{user.global_name || user.username}</span>
              </summary>
              <div className="card absolute right-0 top-full mt-2 w-56 p-2">
                <Link href="/dashboard" className="block rounded-lg px-3 py-2 text-sm hover:bg-white/[0.05]">Dashboard</Link>
                <Link href="/dashboard/configs" className="block rounded-lg px-3 py-2 text-sm hover:bg-white/[0.05]">My Configs</Link>
                <Link href="/dashboard/settings" className="block rounded-lg px-3 py-2 text-sm hover:bg-white/[0.05]">Account Settings</Link>
                {admin && <Link href="/admin" className="block rounded-lg px-3 py-2 text-sm text-violet-300 hover:bg-white/[0.05]">Admin</Link>}
                <div className="hairline my-1" />
                <SignOutButton />
              </div>
            </details>
          ) : (
            <a href="/api/auth/login" className="btn-primary btn-sm">
              Sign in with Discord
            </a>
          )}
          <MobileMenu
            links={[...products.map((p) => ({ href: `/luas/${p.slug}`, label: p.name })), ...links]}
            signedIn={!!user}
            admin={admin}
          />
        </div>
      </div>
    </header>
  );
}

export function SiteFooter() {
  const products = getProducts();
  return (
    <footer className="mt-24 border-t border-line">
      <div className="mx-auto grid max-w-6xl gap-10 px-4 py-12 sm:px-6 md:grid-cols-[1.4fr_1fr_1fr_1fr]">
        <div>
          <div className="flex items-center gap-2.5">
            <Logo size={24} />
            <Wordmark className="text-[15px]" />
          </div>
          <p className="muted mt-4 max-w-xs text-sm leading-relaxed">Two Luas, one cloud. Sign in with Discord to manage your access and share configs.</p>
        </div>
        <FooterCol title="Products" links={products.map((p) => ({ href: `/luas/${p.slug}`, label: p.name }))} />
        <FooterCol title="Platform" links={[{ href: "/cloud", label: "Cloud Configs" }, { href: "/leaderboard", label: "Leaderboard" }, { href: "/changelog", label: "Changelog" }, { href: "/status", label: "Status" }]} />
        <FooterCol title="Help" links={[{ href: "/faq", label: "FAQ" }, { href: "/support", label: "Discord / Support" }]} />
      </div>
      <div className="border-t border-line py-5 text-center text-xs text-[color:var(--faint)]">© {new Date().getFullYear()} Specter. All rights reserved.</div>
    </footer>
  );
}

function FooterCol({ title, links }: { title: string; links: NavLink[] }) {
  return (
    <div>
      <p className="eyebrow mb-3">{title}</p>
      <ul className="space-y-2">
        {links.map((l) => (
          <li key={l.href}>
            <Link href={l.href} className="muted text-sm transition hover:text-white">{l.label}</Link>
          </li>
        ))}
      </ul>
    </div>
  );
}
