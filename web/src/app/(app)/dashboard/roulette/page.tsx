import type { Metadata } from "next";
import { Badge, Card, PageHeader, SectionTitle, formatDate } from "@/components/ui";
import { RouletteWheel } from "@/components/dashboard/roulette-wheel";
import { requireDashboardUser } from "@/lib/dashboard-data";
import { PRIZES, rouletteState } from "@/lib/roulette";

export const dynamic = "force-dynamic";
export const metadata: Metadata = { title: "Roulette" };

export default async function RoulettePage() {
  const user = await requireDashboardUser("/dashboard/roulette");
  const state = await rouletteState(user.id);
  return (
    <div className="space-y-12">
      <PageHeader eyebrow="Dashboard" title="Weekly roulette">One spin every 7 days. Won time is added to your registered key. You can also win nothing.</PageHeader>

      <Card className="p-6 sm:p-10">
        <RouletteWheel
          prizes={PRIZES.map((p) => ({ id: p.id, label: p.label }))}
          canSpin={state.canSpin}
          luas={[{ id: "gamesense", name: "Gamesense" }, { id: "primordial", name: "Primordial" }]}
          nextSpinAt={state.nextSpinAt}
        />
        {state.pending && <p role="status" className="mt-6 text-center text-sm text-amber-300">Your last prize is not paid yet. Press Spin to finish it.</p>}
      </Card>

      <section>
        <SectionTitle eyebrow="Odds" title="Chances" />
        <ul className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
          {PRIZES.map((p) => (
            <li key={p.id} className="card flex items-center justify-between px-4 py-3 text-sm">
              <span className="text-white">{p.label}</span>
              <span className="muted">{p.weight / 100}%</span>
            </li>
          ))}
        </ul>
      </section>

      <section>
        <SectionTitle eyebrow="History" title="Your spins" />
        {state.history.length === 0 ? (
          <p className="muted text-sm">No spins yet.</p>
        ) : (
          <ul className="space-y-2">
            {state.history.map((h) => (
              <li key={h.id} className="card flex items-center justify-between gap-3 px-4 py-3 text-sm">
                <span className="text-white">{h.hours === 0 ? "Nothing" : h.label}</span>
                <span className="muted">{formatDate(new Date(h.createdAt))}</span>
                {h.status === "pending" && <Badge>unpaid</Badge>}
              </li>
            ))}
          </ul>
        )}
      </section>
    </div>
  );
}
