import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { ConfigCard } from "@/components/config-card";
import { VerifiedMark } from "@/components/config-card";
import { Avatar, Badge, Card, EmptyState, SectionTitle, Stat, formatDate } from "@/components/ui";
import { listConfigs } from "@/lib/configs";
import { avatarUrl } from "@/lib/discord";
import { one, query } from "@/lib/db";

export const dynamic = "force-dynamic";

type U = { id: string; discord_id: string; username: string; global_name: string | null; avatar: string | null; verified_creator: boolean; created_at: Date };

export async function generateMetadata({ params }: { params: Promise<{ id: string }> }): Promise<Metadata> {
  const u = await one<U>("select * from users where discord_id = $1", [(await params).id]);
  return { title: u ? (u.global_name || u.username) : "Profile" };
}

// Community profile: only public information (name, avatar, badges, public configs).
export default async function Profile({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  if (!/^\d{5,25}$/.test(id)) notFound();
  const u = await one<U>("select id, discord_id, username, global_name, avatar, verified_creator, created_at from users where discord_id = $1", [id]);
  if (!u) notFound();
  const [configs, wins, totals] = await Promise.all([
    listConfigs({ ownerId: u.id, sort: "popular", limit: 12 }),
    query<{ board_id: string; period: string; rank: number; is_demo: boolean }>("select board_id, period, rank, is_demo from monthly_results where user_id = $1 order by period desc, rank limit 24", [u.id]),
    one<{ likes: string; dl: string }>("select coalesce(sum(likes_count),0) as likes, coalesce(sum(downloads_count + imports_count),0) as dl from configs where owner_id = $1 and visibility = 'public' and not hidden", [u.id]),
  ]);
  const name = u.global_name || u.username;
  return (
    <div className="space-y-12">
      <Card className="flex flex-wrap items-center gap-6 p-8">
        <Avatar src={avatarUrl(u.discord_id, u.avatar, 128)} name={name} size={88} />
        <div>
          <h1 className="flex items-center gap-2 text-3xl font-semibold tracking-tight text-white">{name}{u.verified_creator && <VerifiedMark />}</h1>
          <div className="mt-3 flex flex-wrap gap-2">
            {u.verified_creator && <Badge tone="violet">Verified creator</Badge>}
            {wins.some((w) => w.rank === 1) && <Badge tone="amber">Leaderboard winner</Badge>}
            <Badge>Member since {formatDate(u.created_at)}</Badge>
          </div>
        </div>
      </Card>
      <div className="grid gap-4 sm:grid-cols-3">
        <Stat label="Public configs" value={configs.total} />
        <Stat label="Likes received" value={totals?.likes ?? 0} />
        <Stat label="Downloads and imports" value={totals?.dl ?? 0} />
      </div>
      <section>
        <SectionTitle title="Configs" />
        {configs.items.length ? <div className="grid gap-5 sm:grid-cols-2 lg:grid-cols-3">{configs.items.map((c) => <ConfigCard key={c.id} c={c} />)}</div> : <EmptyState title="No public configs yet" />}
      </section>
      {wins.length > 0 && (
        <section>
          <SectionTitle title="Leaderboard results" />
          <Card className="divide-y divide-line text-sm">
            {wins.map((w) => (
              <div key={`${w.board_id}${w.period}`} className="flex items-center justify-between px-5 py-3">
                <span>{w.period} · {w.board_id}</span>
                <span className="flex items-center gap-2"><Badge tone="violet">#{w.rank}</Badge>{w.is_demo && <Badge tone="amber" className="uppercase">Demo</Badge>}</span>
              </div>
            ))}
          </Card>
        </section>
      )}
    </div>
  );
}
