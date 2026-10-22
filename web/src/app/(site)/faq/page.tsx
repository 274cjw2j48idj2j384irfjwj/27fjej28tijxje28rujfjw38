import type { Metadata } from "next";
import Link from "next/link";
import { PageHeader } from "@/components/ui";

export const metadata: Metadata = { title: "FAQ" };

const FAQ: { q: string; a: string }[] = [
  { q: "How do I get access?", a: "Access comes from your Discord roles on the Specter server, or from time limited access the team or the leaderboard gave you. Sign in with Discord and the dashboard shows your status for each Lua." },
  { q: "Does one Lua unlock the other?", a: "No. Gamesense and Primordial are separate products with their own access, expiry and downloads." },
  { q: "What do the access states mean?", a: "Active: you can use the Lua. Expiring soon: access ends within 7 days. Expired: it ended. Suspended: the team paused it. No access: nothing was found for this Lua." },
  { q: "It says it could not check my Discord roles.", a: "That is a connection problem between this site and Discord, not a missing role. Wait a minute and refresh. If it stays, tell support on Discord." },
  { q: "How do I share a config from the Lua?", a: "Link your account once: the Lua shows a short code, you approve it at the link page while signed in. After that the Lua menu can upload a config to the cloud of its own Lua. This needs the Lua client to include the cloud integration." },
  { q: "Can a config run code?", a: "No. A config is stored and handed out as data only. Uploads with code, tokens, keys or personal paths are refused." },
  { q: "Can I use a Gamesense config in Primordial?", a: "No. Every config belongs to exactly one Lua and the other Lua will not import it." },
  { q: "How does the leaderboard work?", a: "The board runs per UTC month. When a month ends the final result is saved, rewards are paid once, and a new month starts from zero. The first three places get 30, 14 and 7 days of subscription when rewards are switched on for that board." },
  { q: "What happens to my reward if I already have access?", a: "Running access is extended from its end. Ended access restarts from the moment the reward is paid. An access that never expires stays as it is." },
  { q: "Which times are used?", a: "All month borders and countdowns are UTC." },
  { q: "How do I disconnect a device?", a: "Open Connected Devices in your dashboard and revoke it. The Lua loses access to the cloud at once." },
];

export default function FaqPage() {
  return (
    <div className="max-w-3xl">
      <PageHeader eyebrow="FAQ" title="Questions and answers" />
      <div className="space-y-3">
        {FAQ.map((f) => (
          <details key={f.q} className="card group px-6 py-5 open:border-violet-400/30">
            <summary className="flex cursor-pointer list-none items-center justify-between gap-4 text-[15px] font-medium text-white [&::-webkit-details-marker]:hidden">
              {f.q}
              <svg width="14" height="14" viewBox="0 0 14 14" className="shrink-0 text-violet-300 transition group-open:rotate-45" aria-hidden="true"><path d="M7 2v10M2 7h10" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" /></svg>
            </summary>
            <p className="muted mt-3 text-sm leading-relaxed">{f.a}</p>
          </details>
        ))}
      </div>
      <p className="muted mt-10 text-sm">Still stuck? <Link href="/support" className="text-violet-300 hover:text-violet-200">Ask on Discord</Link>.</p>
    </div>
  );
}
