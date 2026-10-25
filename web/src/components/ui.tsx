import Link from "next/link";
import type { ReactNode } from "react";
import type { AccessStatus } from "@/lib/access";

export function cx(...parts: (string | false | null | undefined)[]): string {
  return parts.filter(Boolean).join(" ");
}

export function Card({ children, className, hover }: { children: ReactNode; className?: string; hover?: boolean }) {
  return <div className={cx("card", hover && "card-hover", className)}>{children}</div>;
}

export function ButtonLink({ href, children, variant = "primary", small, className, external }: { href: string; children: ReactNode; variant?: "primary" | "ghost"; small?: boolean; className?: string; external?: boolean }) {
  const cls = cx(variant === "primary" ? "btn-primary" : "btn-ghost", small && "btn-sm", className);
  if (external) return <a href={href} className={cls} target="_blank" rel="noopener noreferrer">{children}</a>;
  return <Link href={href} className={cls}>{children}</Link>;
}

export function PageHeader({ eyebrow, title, children, actions }: { eyebrow?: string; title: string; children?: ReactNode; actions?: ReactNode }) {
  return (
    <header className="mb-8 flex flex-wrap items-end justify-between gap-4">
      <div className="max-w-2xl">
        {eyebrow && <p className="eyebrow mb-2">{eyebrow}</p>}
        <h1 className="text-3xl font-semibold tracking-tight text-white sm:text-4xl">{title}</h1>
        {children && <p className="muted mt-3 text-[15px] leading-relaxed">{children}</p>}
      </div>
      {actions && <div className="flex flex-wrap gap-2">{actions}</div>}
    </header>
  );
}

export function SectionTitle({ eyebrow, title, children, action }: { eyebrow?: string; title: string; children?: ReactNode; action?: ReactNode }) {
  return (
    <div className="mb-6 flex flex-wrap items-end justify-between gap-3">
      <div>
        {eyebrow && <p className="eyebrow mb-1.5">{eyebrow}</p>}
        <h2 className="text-2xl font-semibold tracking-tight text-white">{title}</h2>
        {children && <p className="muted mt-2 max-w-xl text-sm leading-relaxed">{children}</p>}
      </div>
      {action}
    </div>
  );
}

type Tone = "violet" | "green" | "amber" | "red" | "gray";
const TONES: Record<Tone, string> = {
  violet: "border-violet-400/30 bg-violet-500/10 text-violet-200",
  green: "border-emerald-400/30 bg-emerald-500/10 text-emerald-200",
  amber: "border-amber-400/30 bg-amber-500/10 text-amber-200",
  red: "border-red-400/30 bg-red-500/10 text-red-200",
  gray: "border-white/10 bg-white/[0.03] text-[color:var(--muted)]",
};

export function Badge({ children, tone = "gray", className }: { children: ReactNode; tone?: Tone; className?: string }) {
  return <span className={cx("inline-flex items-center gap-1 rounded-full border px-2.5 py-0.5 text-[11px] font-medium tracking-wide", TONES[tone], className)}>{children}</span>;
}

export function DemoTag() {
  return <Badge tone="amber" className="uppercase">Demo data</Badge>;
}

const STATUS: Record<AccessStatus, { label: string; tone: Tone }> = {
  active: { label: "Active", tone: "green" },
  expiring_soon: { label: "Expiring soon", tone: "amber" },
  expired: { label: "Expired", tone: "red" },
  suspended: { label: "Suspended", tone: "red" },
  no_access: { label: "No access", tone: "gray" },
};

export function StatusBadge({ status }: { status: AccessStatus }) {
  const s = STATUS[status];
  return <Badge tone={s.tone}><span className="size-1.5 rounded-full bg-current" />{s.label}</Badge>;
}

export function EmptyState({ title, children, action, icon }: { title: string; children?: ReactNode; action?: ReactNode; icon?: ReactNode }) {
  return (
    <div className="card flex flex-col items-center px-6 py-14 text-center">
      {icon && <div className="mb-4 text-violet-300/70">{icon}</div>}
      <p className="text-base font-medium text-white">{title}</p>
      {children && <p className="muted mt-2 max-w-md text-sm leading-relaxed">{children}</p>}
      {action && <div className="mt-5">{action}</div>}
    </div>
  );
}

export function ErrorState({ title = "Something went wrong", children }: { title?: string; children?: ReactNode }) {
  return (
    <div role="alert" className="rounded-2xl border border-red-400/25 bg-red-500/[0.06] px-6 py-8 text-center">
      <p className="text-base font-medium text-red-100">{title}</p>
      {children && <p className="mt-2 text-sm text-red-200/80">{children}</p>}
    </div>
  );
}

export function Avatar({ src, name, size = 36 }: { src: string; name: string; size?: number }) {
  // eslint-disable-next-line @next/next/no-img-element
  return <img src={src} alt="" aria-hidden="true" width={size} height={size} loading="lazy" referrerPolicy="no-referrer" className="rounded-full border border-line bg-ink-800 object-cover" style={{ width: size, height: size }} />;
}

export function Stat({ label, value, hint }: { label: string; value: ReactNode; hint?: ReactNode }) {
  return (
    <div className="card px-5 py-4">
      <p className="text-xs uppercase tracking-wider text-[color:var(--muted)]">{label}</p>
      <p className="mt-1.5 text-2xl font-semibold tracking-tight text-white">{value}</p>
      {hint && <p className="mt-1 text-xs text-[color:var(--faint)]">{hint}</p>}
    </div>
  );
}

export function Kbd({ children }: { children: ReactNode }) {
  return <kbd className="rounded-md border border-line bg-white/[0.04] px-1.5 py-0.5 font-mono text-[11px] text-[color:var(--muted)]">{children}</kbd>;
}

export function Notice({ tone = "violet", children }: { tone?: Tone; children: ReactNode }) {
  return <div className={cx("rounded-xl border px-4 py-3 text-sm leading-relaxed", TONES[tone])}>{children}</div>;
}

export function formatDate(d: Date | string | null | undefined, withTime = false): string {
  if (!d) return "-";
  const date = typeof d === "string" ? new Date(d) : d;
  return date.toLocaleString("en-GB", { timeZone: "UTC", year: "numeric", month: "short", day: "2-digit", ...(withTime ? { hour: "2-digit", minute: "2-digit" } : {}) }) + (withTime ? " UTC" : "");
}

export function daysLeft(d: Date | null | undefined, now = new Date()): string {
  if (!d) return "No expiry";
  const ms = d.getTime() - now.getTime();
  if (ms <= 0) return "Ended";
  const days = Math.ceil(ms / 86_400_000);
  return days === 1 ? "1 day left" : `${days} days left`;
}
