import { avatarUrl } from "@/lib/discord";
import type { StandingRow } from "@/lib/leaderboard";
import { Avatar, Badge, DemoTag, cx } from "./ui";
import { VerifiedMark } from "./config-card";

const PLACE = [
  { label: "1st", ring: "border-violet-300/60 shadow-glow", height: "sm:pt-0" },
  { label: "2nd", ring: "border-violet-400/30", height: "sm:mt-8" },
  { label: "3rd", ring: "border-violet-400/20", height: "sm:mt-14" },
];

export function Podium({ rows, rewardDays, rewardsOn }: { rows: StandingRow[]; rewardDays: number[]; rewardsOn: boolean }) {
  // visual order on a wide screen: 2nd, 1st, 3rd
  const order = [1, 0, 2];
  const demo = rows.some((r) => r.demo);
  return (
    <div>
      {demo && <div className="mb-3"><DemoTag /></div>}
      <div className="grid gap-4 sm:grid-cols-3">
        {order.map((idx) => {
          const r = rows[idx];
          const place = PLACE[idx];
          if (!r) {
            return (
              <div key={idx} className={cx("card flex min-h-[170px] flex-col items-center justify-center border-dashed px-4 text-center", place.height, idx === 0 ? "sm:order-2" : idx === 1 ? "sm:order-1" : "sm:order-3")}>
                <span className="text-xs uppercase tracking-widest text-[color:var(--faint)]">{place.label}</span>
                <span className="muted mt-2 text-sm">Open place</span>
              </div>
            );
          }
          return (
            <div key={r.user_id} className={cx("card flex flex-col items-center px-4 py-6 text-center", place.height, idx === 0 ? "border-violet-300/40 sm:order-2" : idx === 1 ? "sm:order-1" : "sm:order-3")}>
              <span className="text-xs font-medium uppercase tracking-widest text-violet-300">{place.label}</span>
              <div className={cx("mt-3 rounded-full border-2 p-0.5", place.ring)}>
                <Avatar src={avatarUrl(r.discord_id, r.avatar, 128)} name={r.name} size={idx === 0 ? 72 : 60} />
              </div>
              <p className="mt-3 flex max-w-full items-center gap-1.5 truncate text-[15px] font-medium text-white">
                <span className="truncate">{r.name}</span>
                {r.verified && <VerifiedMark />}
              </p>
              <p className="mt-1 text-2xl font-semibold tabular-nums text-white">{r.points.toLocaleString("en-US")}</p>
              <p className="text-[11px] uppercase tracking-wider text-[color:var(--faint)]">points</p>
              {rewardsOn && rewardDays[idx] && <Badge tone="violet" className="mt-3">+{rewardDays[idx]} days</Badge>}
            </div>
          );
        })}
      </div>
    </div>
  );
}
