import type { Metadata } from "next";
import { redirect } from "next/navigation";
import { Logo } from "@/components/logo";
import { ButtonLink, Notice } from "@/components/ui";
import { currentUser, safeNext } from "@/lib/authz";

export const dynamic = "force-dynamic";
export const metadata: Metadata = { title: "Sign in" };

const ERRORS: Record<string, { tone: "red" | "amber"; title: string; text: string }> = {
  not_configured: { tone: "amber", title: "Sign in is not set up yet", text: "Discord sign in is not configured on this server, so nobody can sign in right now. If you run this site, set the Discord client id, secret, bot token and server id." },
  denied: { tone: "amber", title: "Sign in was cancelled", text: "Discord did not give us permission to see who you are. Try again and press Authorize." },
  state: { tone: "red", title: "The sign in could not be verified", text: "The sign in expired or was opened in another browser. Start again from this page." },
  discord: { tone: "red", title: "Discord did not answer", text: "We could not finish the sign in with Discord. Wait a minute and try again." },
  suspended: { tone: "red", title: "This account is suspended", text: "You cannot sign in with this Discord account. Ask the team on Discord if you think this is a mistake." },
};

export default async function LoginPage({ searchParams }: { searchParams: Promise<{ error?: string; next?: string }> }) {
  const sp = await searchParams;
  const next = safeNext(sp.next);
  const user = await currentUser();
  if (user && !sp.error) redirect(next);
  const err = sp.error ? (ERRORS[sp.error] ?? { tone: "red" as const, title: "Sign in failed", text: "Something went wrong while signing in. Try again." }) : null;
  const href = `/api/auth/login?next=${encodeURIComponent(next)}`;
  return (
    <div className="mx-auto max-w-md pb-6 text-center">
      <div className="mx-auto mb-7 flex size-16 items-center justify-center rounded-2xl border border-line bg-ink-850/80 glow-ring">
        <Logo size={34} />
      </div>
      <p className="eyebrow">Welcome</p>
      <h1 className="mt-3 text-3xl font-semibold tracking-tight text-white">Sign in to SPECTER</h1>
      <p className="muted mx-auto mt-3 max-w-sm text-[15px] leading-relaxed">One click with Discord. Your Discord roles decide which Luas you can use. We only ask who you are, never for a password.</p>

      {err && (
        <div className="mt-7 text-left" role="alert">
          <Notice tone={err.tone}><span className="font-medium">{err.title}.</span> {err.text}</Notice>
        </div>
      )}

      <div className="card mt-8 p-6">
        <a href={href} className="btn-primary w-full">{err ? "Try again with Discord" : "Sign in with Discord"}</a>
        {next !== "/dashboard" && <p className="mt-3 text-xs text-[color:var(--faint)]">After signing in you continue to {next.split("?")[0]}.</p>}
      </div>
      <div className="mt-6 flex justify-center gap-3">
        <ButtonLink href="/" variant="ghost" small>Back to the home page</ButtonLink>
        <ButtonLink href="/support" variant="ghost" small>Need help?</ButtonLink>
      </div>
    </div>
  );
}
