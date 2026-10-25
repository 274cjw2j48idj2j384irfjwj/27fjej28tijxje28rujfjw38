import type { Metadata } from "next";
import Link from "next/link";
import { MonitorSmartphone } from "lucide-react";
import { Card, EmptyState, PageHeader, SectionTitle, formatDate } from "@/components/ui";
import { RevokeDevice } from "@/components/dashboard/small-actions";
import { getProduct } from "@/config/site";
import { requireDashboardUser } from "@/lib/dashboard-data";
import { listDevices } from "@/lib/devices";

export const dynamic = "force-dynamic";
export const metadata: Metadata = { title: "Connected Devices" };

export default async function DevicesPage() {
  const user = await requireDashboardUser("/dashboard/devices");
  const devices = await listDevices(user.id);
  return (
    <div className="space-y-12">
      <PageHeader eyebrow="Dashboard" title="Connected Devices">Luas linked to your account. A linked Lua can read your configs and library and upload configs and score for you.</PageHeader>

      <section>
        <SectionTitle eyebrow="Linked" title="Your devices" />
        {devices.length === 0 ? (
          <EmptyState title="No device linked" icon={<MonitorSmartphone size={28} aria-hidden="true" />}>Link a Lua from its menu to use the cloud in game. The steps are below.</EmptyState>
        ) : (
          <ul className="space-y-3">
            {devices.map((d) => (
              <li key={d.id}>
                <Card className="flex flex-wrap items-center justify-between gap-4 p-5">
                  <div className="min-w-0">
                    <p className="break-all font-medium text-white">{d.name || "Unnamed client"}</p>
                    <p className="muted text-sm">{getProduct(d.product_id)?.name ?? d.product_id}</p>
                    <p className="mt-1 text-xs text-[color:var(--faint)]">Linked {formatDate(d.created_at, true)} · {d.last_used_at ? `last used ${formatDate(d.last_used_at, true)}` : "never used"} · link ends {formatDate(d.expires_at)}</p>
                  </div>
                  <RevokeDevice id={d.id} name={d.name || "device"} />
                </Card>
              </li>
            ))}
          </ul>
        )}
      </section>

      <section>
        <SectionTitle eyebrow="How to" title="Link a Lua" />
        <Card className="p-6">
          <ol className="space-y-3 text-sm leading-relaxed">
            {[
              "Load the Lua in game and open its menu.",
              "Choose Link account. The menu shows a code like ABCD-EFGH.",
              <>Open <Link href="/link" className="text-violet-300 underline-offset-2 hover:underline">the link page</Link> in your browser, sign in, and enter the code.</>,
              "Check which Lua is asking, then approve. The Lua picks the link up within a few seconds.",
            ].map((step, i) => (
              <li key={i} className="flex gap-3">
                <span className="flex size-6 shrink-0 items-center justify-center rounded-full border border-line bg-violet-500/10 text-xs font-semibold text-violet-300">{i + 1}</span>
                <span className="pt-0.5">{step}</span>
              </li>
            ))}
          </ol>
          <p className="muted mt-5 text-xs">Revoking a device ends its link at once. The Lua has to be linked again to use the cloud.</p>
        </Card>
      </section>
    </div>
  );
}
