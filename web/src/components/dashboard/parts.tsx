import { Badge, StatusBadge } from "@/components/ui";
import type { AccessResult } from "@/lib/access";
import type { BoardStanding } from "@/lib/dashboard-data";

// "No access" when Discord could not be asked would be a lie: it gets its own label.
export function StatusPill({ access }: { access: AccessResult }) {
  if (access.integrationError && access.status === "no_access") return <Badge tone="amber"><span className="size-1.5 rounded-full bg-current" />Roles not checked</Badge>;
  return <StatusBadge status={access.status} />;
}

export function rankText(b: BoardStanding): string {
  if (!b.me) return b.board.scoring_enabled ? "No points yet" : "Scoring is off";
  return `#${b.me.rank} with ${b.me.points} pts`;
}

export function Row({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div className="flex items-baseline justify-between gap-4 border-b border-line/60 py-2.5 text-sm last:border-0">
      <dt className="muted shrink-0">{label}</dt>
      <dd className="min-w-0 text-right text-white">{children}</dd>
    </div>
  );
}
