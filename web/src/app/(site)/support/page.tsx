import type { Metadata } from "next";
import { ButtonLink, Card, Notice, PageHeader } from "@/components/ui";
import { site } from "@/config/site";

export const metadata: Metadata = { title: "Discord and support" };

export default function SupportPage() {
  return (
    <div className="max-w-3xl">
      <PageHeader eyebrow="Support" title="Discord and support">Support, announcements, config sharing and your access roles live on the Discord server.</PageHeader>
      <Card className="p-8">
        <h2 className="text-lg font-medium text-white">Join the server</h2>
        <p className="muted mt-2 text-sm leading-relaxed">Open a ticket there for access problems, billing questions or bug reports. When you write, include the Lua you use and what the dashboard shows for your access.</p>
        <div className="mt-6">
          {site.discordInvite ? <ButtonLink href={site.discordInvite} external>Join the Discord</ButtonLink> : <Notice tone="amber">The invite link is not set yet. Set DISCORD_INVITE in the environment of the site.</Notice>}
        </div>
      </Card>
      <div className="mt-6 grid gap-5 sm:grid-cols-2">
        <Card className="p-6">
          <h3 className="text-[15px] font-medium text-white">Before you ask</h3>
          <ul className="muted mt-3 space-y-2 text-sm"><li>Check the FAQ.</li><li>Check your access in the dashboard.</li><li>Check the status page.</li></ul>
        </Card>
        <Card className="p-6">
          <h3 className="text-[15px] font-medium text-white">Never share</h3>
          <p className="muted mt-3 text-sm leading-relaxed">Staff will never ask for your Discord password, your license key in public, or a config that contains secrets.</p>
        </Card>
      </div>
    </div>
  );
}
