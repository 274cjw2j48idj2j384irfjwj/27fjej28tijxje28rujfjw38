import { afterAll, beforeEach, describe, expect, it } from "vitest";
import { adminOverview, boardOverviews, closedPeriods, monthlyResults, rewardPreview, unclosedPeriods } from "@/lib/admin-boards";
import { closePeriod } from "@/lib/leaderboard";
import { query } from "@/lib/db";
import { done, mkUser, resetDb } from "./helpers";

beforeEach(resetDb);
afterAll(done);

async function score(user: string, board: string, period: string, points: number, key: string) {
  await query("insert into score_events (board_id, user_id, period, event_type, points, dedupe_key) values ($1,$2,$3,'x',$4,$5)", [board, user, period, points, key]);
}

describe("admin board helpers", () => {
  it("lists unclosed finished months, then closed periods and results after closing", async () => {
    const now = new Date(Date.UTC(2026, 10, 5));
    const a = await mkUser("a");
    const b = await mkUser("b");
    await score(a.id, "gamesense", "2026-10", 50, "k1");
    await score(b.id, "gamesense", "2026-10", 30, "k2");
    await score(a.id, "gamesense", "2026-11", 5, "k3"); // running month: not due
    expect(await unclosedPeriods(now)).toEqual([{ board_id: "gamesense", period: "2026-10" }]);
    await closePeriod("gamesense", "2026-10", now);
    expect(await unclosedPeriods(now)).toEqual([]);
    const closed = await closedPeriods();
    expect(closed).toMatchObject([{ board_id: "gamesense", period: "2026-10", results: 2, rewards: 0 }]);
    const res = await monthlyResults();
    expect(res.map((r) => [r.rank, r.name, r.points])).toEqual([[1, "a", 50], [2, "b", 30]]);
  });

  it("previews the payout from standings and board settings", async () => {
    const now = new Date(Date.UTC(2026, 10, 5));
    const a = await mkUser("a");
    await score(a.id, "gamesense", "2026-11", 40, "k1");
    await query("update boards set rewards_enabled = true, reward_product_id = 'primordial', reward_days = '[20,10,5]' where id = 'gamesense'");
    const prev = await rewardPreview(now);
    const gs = prev.find((p) => p.board.id === "gamesense")!;
    expect(gs.enabled).toBe(true);
    expect(gs.rows).toEqual([{ rank: 1, name: "a", points: 40, days: 20, demo: false }]);
    expect(gs.closesAt.toISOString()).toBe("2026-12-01T00:00:00.000Z");
    expect(prev.find((p) => p.board.id === "primordial")!.enabled).toBe(false);
    const ov = await boardOverviews(now);
    expect(ov.find((o) => o.board.id === "overall")!.events).toBe(1);
  });

  it("overview counters", async () => {
    await mkUser("a", { admin: true });
    await mkUser("b");
    const o = await adminOverview();
    expect(o).toMatchObject({ users: 2, admins: 1, reportsOpen: 0, configs: 0 });
  });
});
