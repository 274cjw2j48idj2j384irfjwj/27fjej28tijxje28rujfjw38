import type { Metadata } from "next";
import { Badge, Card, PageHeader } from "@/components/ui";
import { one } from "@/lib/db";
import { discordConfigured } from "@/lib/discord";

export const dynamic = "force-dynamic";
export const metadata: Metadata = { title: "Status" };

type Check = { name: string; ok: boolean | null; note: string };

async function checks(): Promise<Check[]> {
  const out: Check[] = [{ name: "Website", ok: true, note: "Serving this page." }];
  try {
    await one("select 1 as ok");
    out.push({ name: "Database", ok: true, note: "Reachable." });
  } catch {
    out.push({ name: "Database", ok: false, note: "Not reachable. Config cloud and sign in are down." });
  }
  out.push(discordConfigured() ? { name: "Discord integration", ok: true, note: "Configured. Role checks run live." } : { name: "Discord integration", ok: false, note: "Not configured on this server." });
  const license = (process.env.LICENSE_SERVER_URL ?? "").replace(/\/+$/, "");
  if (license) {
    try {
      const r = await fetch(`${license}/presence`, { signal: AbortSignal.timeout(4000), cache: "no-store" });
      out.push({ name: "License server", ok: r.ok, note: r.ok ? "Reachable." : `Answered ${r.status}.` });
    } catch {
      out.push({ name: "License server", ok: false, note: "Not reachable." });
    }
  } else {
    out.push({ name: "License server", ok: null, note: "Not checked (LICENSE_SERVER_URL is not set)." });
  }
  return out;
}

export default async function StatusPage() {
  const list = await checks();
  const allOk = list.every((c) => c.ok !== false);
  return (
    <div className="max-w-3xl">
      <PageHeader eyebrow="Status" title={allOk ? "All systems running" : "Some services have problems"}>Live checks of the web app and the services it depends on.</PageHeader>
      <Card className="divide-y divide-line">
        {list.map((c) => (
          <div key={c.name} className="flex items-center justify-between gap-4 px-6 py-5">
            <div>
              <p className="text-[15px] font-medium text-white">{c.name}</p>
              <p className="muted mt-0.5 text-sm">{c.note}</p>
            </div>
            <Badge tone={c.ok === null ? "gray" : c.ok ? "green" : "red"}>{c.ok === null ? "Unknown" : c.ok ? "Operational" : "Down"}</Badge>
          </div>
        ))}
      </Card>
    </div>
  );
}
