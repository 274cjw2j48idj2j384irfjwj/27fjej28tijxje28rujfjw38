import { ConfigCard } from "@/components/config-card";
import { Logo } from "@/components/logo";
import { Podium } from "@/components/podium";
import { ProductCard } from "@/components/product-card";
import { Badge, ButtonLink, Card, EmptyState, SectionTitle, formatDate } from "@/components/ui";
import { site } from "@/config/site";
import { currentUser } from "@/lib/authz";
import { getBoard, nextPeriodStart, periodOf } from "@/lib/leaderboard";
import { featuredConfigs, getAllProducts, latestReleases, topThree } from "@/lib/site-data";

export const dynamic = "force-dynamic";

const PILLARS = [
  { title: "Discord sign-in", text: "One click, no new password. Your Discord roles decide what you can use." },
  { title: "Separate access per Lua", text: "Each Lua has its own access, expiry and downloads. One never unlocks the other." },
  { title: "Config cloud", text: "Publish a config from the Lua menu, browse the catalog and save what you like." },
  { title: "Monthly leaderboard", text: "A fresh race every month. The top three win subscription days." },
];

export default async function Home() {
  const [user, products, featured, releases, board, top] = await Promise.all([currentUser(), getAllProducts(), featuredConfigs(3), latestReleases(4), getBoard("overall"), topThree("overall")]);
  const resets = nextPeriodStart(periodOf(new Date()));
  return (
    <div className="space-y-28 pb-4">
      <section className="relative -mt-4 pb-4 pt-6 text-center sm:pt-12">
        <div aria-hidden="true" className="pointer-events-none absolute left-1/2 top-0 -z-10 h-[420px] w-[720px] -translate-x-1/2 rounded-full bg-violet-600/20 blur-[120px]" />
        <div className="reveal mx-auto mb-8 flex size-20 items-center justify-center rounded-3xl border border-line bg-ink-850/80 glow-ring">
          <Logo size={44} />
        </div>
        <p className="reveal eyebrow">Exclusive scripts, one platform</p>
        <h1 className="reveal-2 wordmark mt-4 text-5xl font-semibold tracking-[0.28em] sm:text-7xl">SPECTER</h1>
        <p className="reveal-3 muted mx-auto mt-6 max-w-xl text-[17px] leading-relaxed">
          Two scripts, built apart and run apart. Manage your access with Discord, share configs through the cloud and take part in the monthly leaderboard.
        </p>
        <div className="reveal-3 mt-9 flex flex-wrap justify-center gap-3">
          <ButtonLink href="#luas">Explore the Luas</ButtonLink>
          {user ? <ButtonLink href="/dashboard" variant="ghost">Open dashboard</ButtonLink> : <a href="/api/auth/login" className="btn-ghost">Sign in with Discord</a>}
        </div>
      </section>

      <section id="luas" className="scroll-mt-24">
        <SectionTitle eyebrow="Products" title="Choose your Lua">Each Lua has its own page, its own access and its own config cloud.</SectionTitle>
        <div className="grid gap-6 md:grid-cols-2">
          {products.map((p) => <ProductCard key={p.id} p={p} />)}
        </div>
      </section>

      <section>
        <SectionTitle eyebrow="Platform" title="What the platform gives you" />
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
          {PILLARS.map((x, i) => (
            <Card key={x.title} className="p-6">
              <span className="mb-4 flex size-9 items-center justify-center rounded-xl border border-line bg-violet-500/10 text-sm font-semibold text-violet-300">{i + 1}</span>
              <h3 className="text-[15px] font-medium text-white">{x.title}</h3>
              <p className="muted mt-2 text-sm leading-relaxed">{x.text}</p>
            </Card>
          ))}
        </div>
      </section>

      <section>
        <SectionTitle eyebrow="Cloud" title="Featured configs" action={<ButtonLink href="/cloud" variant="ghost" small>Browse all</ButtonLink>}>
          Picked by the team from both Luas.
        </SectionTitle>
        {featured.length ? (
          <div className="grid gap-5 sm:grid-cols-2 lg:grid-cols-3">{featured.map((c) => <ConfigCard key={c.id} c={c} />)}</div>
        ) : (
          <EmptyState title="No featured configs yet" action={<ButtonLink href="/cloud" variant="ghost" small>Open the cloud</ButtonLink>}>
            When the team features a config it shows up here.
          </EmptyState>
        )}
      </section>

      <section>
        <SectionTitle eyebrow="This month" title="Leaderboard" action={<ButtonLink href="/leaderboard" variant="ghost" small>Full ranking</ButtonLink>}>
          Month ends {formatDate(resets)} (UTC). {board?.rewards_enabled ? "The top three win subscription days." : ""}
        </SectionTitle>
        {top.rows.length ? (
          <Podium rows={top.rows} rewardDays={board?.reward_days ?? [30, 14, 7]} rewardsOn={!!board?.rewards_enabled} />
        ) : (
          <EmptyState title="No points yet this month">
            {board?.scoring_enabled ? "Be the first on the board." : "Point collection starts when the team approves the scoring rules."}
          </EmptyState>
        )}
      </section>

      <section>
        <SectionTitle eyebrow="Updates" title="Latest releases" action={<ButtonLink href="/changelog" variant="ghost" small>Full changelog</ButtonLink>} />
        {releases.length ? (
          <div className="grid gap-4 md:grid-cols-2">
            {releases.map((r) => (
              <Card key={r.id} className="p-6">
                <div className="flex items-center justify-between gap-3">
                  <Badge tone="violet">{r.product}</Badge>
                  <span className="text-xs text-[color:var(--faint)]">{formatDate(r.released_at)}</span>
                </div>
                <h3 className="mt-4 text-lg font-medium text-white">{r.title} <span className="text-sm font-normal text-[color:var(--muted)]">v{r.version}</span></h3>
                <ul className="muted mt-3 space-y-1.5 text-sm">
                  {r.notes.slice(0, 3).map((n, i) => <li key={i} className="flex gap-2"><span className="text-violet-400">·</span>{n}</li>)}
                </ul>
                {r.is_demo && <Badge tone="amber" className="mt-4 uppercase">Demo data</Badge>}
              </Card>
            ))}
          </div>
        ) : (
          <EmptyState title="No releases yet">The changelog fills up with the first release.</EmptyState>
        )}
      </section>

      <section>
        <Card className="relative overflow-hidden px-8 py-12 text-center sm:px-14">
          <div aria-hidden="true" className="pointer-events-none absolute -right-10 -top-20 size-72 rounded-full bg-violet-600/20 blur-[90px]" />
          <p className="eyebrow">Community</p>
          <h2 className="mt-3 text-3xl font-semibold tracking-tight text-white">Join the Discord</h2>
          <p className="muted mx-auto mt-4 max-w-lg text-[15px] leading-relaxed">Support, announcements, config sharing and the roles that unlock your access all live on the Discord server.</p>
          <div className="mt-7 flex justify-center gap-3">
            <ButtonLink href="/support">Discord and support</ButtonLink>
            {!user && <a href="/api/auth/login" className="btn-ghost">Sign in with Discord</a>}
          </div>
          {!site.discordInvite && <p className="mt-5 text-xs text-[color:var(--faint)]">The invite link is set with DISCORD_INVITE.</p>}
        </Card>
      </section>
    </div>
  );
}
