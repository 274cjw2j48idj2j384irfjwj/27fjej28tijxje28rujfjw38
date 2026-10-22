import { afterAll, beforeEach, describe, expect, it } from "vitest";
import { applyReward, closeDuePeriods, closePeriod, ingestScore, manualScore, nextPeriodStart, periodOf, previousPeriod, rankOf, standings } from "@/lib/leaderboard";
import { resolveAccess } from "@/lib/access";
import { query } from "@/lib/db";
import { day, done, mkUser, resetDb } from "./helpers";

const oct = (d: number, h = 12) => new Date(Date.UTC(2026, 9, d, h));
const nov1 = new Date(Date.UTC(2026, 10, 1, 0, 5));
const noRoles = async () => ({ inGuild: true, roles: [] as string[] });

async function score(boardId: string, userId: string, points: number, at: Date, demo = false) {
  await query(
    `insert into score_events (board_id, user_id, period, event_type, points, dedupe_key, is_demo, created_at) values ($1,$2,$3,'t',$4,$5,$6,$7)`,
    [boardId, userId, periodOf(at), points, `k${Math.random()}`, demo, at],
  );
}

async function enableRewards(boardId = "gamesense", product = "gamesense") {
  await query("update boards set rewards_enabled = true, reward_product_id = $2 where id = $1", [boardId, product]);
}

describe("periods", () => {
  it("UTC month borders", () => {
    expect(periodOf(new Date("2026-10-31T23:59:59Z"))).toBe("2026-10");
    expect(periodOf(new Date("2026-11-01T00:00:00Z"))).toBe("2026-11");
    expect(nextPeriodStart("2026-12").toISOString()).toBe("2027-01-01T00:00:00.000Z");
    expect(previousPeriod("2027-01")).toBe("2026-12");
  });
});

describe("score ingestion", () => {
  beforeEach(resetDb);
  afterAll(done);

  it("production point collection is off until an admin enables it", async () => {
    const u = await mkUser();
    expect(await ingestScore({ boardId: "gamesense", userId: u.id, eventType: "kill", dedupeKey: "a" })).toEqual({ accepted: false, reason: "disabled" });
    expect(await query("select 1 from score_events")).toHaveLength(0);
  });

  it("only rules that the admin approved give points, and the client never sends points", async () => {
    const u = await mkUser();
    await query(`update boards set scoring_enabled = true, rules = '{"events":{"round_win":{"points":3}}}' where id = 'gamesense'`);
    expect(await ingestScore({ boardId: "gamesense", userId: u.id, eventType: "kill", dedupeKey: "a" })).toEqual({ accepted: false, reason: "unknown_event" });
    expect(await ingestScore({ boardId: "gamesense", userId: u.id, eventType: "round_win", dedupeKey: "a" })).toEqual({ accepted: true, points: 3 });
    expect(await ingestScore({ boardId: "gamesense", userId: u.id, eventType: "round_win", dedupeKey: "a" })).toEqual({ accepted: false, reason: "duplicate" });
    expect(await ingestScore({ boardId: "overall", userId: u.id, eventType: "round_win", dedupeKey: "b" })).toEqual({ accepted: false, reason: "bad_board" });
  });

  it("the daily cap holds", async () => {
    const u = await mkUser();
    await query(`update boards set scoring_enabled = true, rules = '{"events":{"x":{"points":4,"dailyCap":10}}}' where id = 'gamesense'`);
    const at = oct(5);
    const r = [];
    for (let i = 0; i < 4; i++) r.push((await ingestScore({ boardId: "gamesense", userId: u.id, eventType: "x", dedupeKey: `k${i}`, now: at })).accepted);
    expect(r).toEqual([true, true, false, false]);
    expect((await ingestScore({ boardId: "gamesense", userId: u.id, eventType: "x", dedupeKey: "next", now: oct(6) })).accepted).toBe(true);
  });

  it("two parallel identical events count once", async () => {
    const u = await mkUser();
    await query(`update boards set scoring_enabled = true, rules = '{"events":{"x":{"points":1}}}' where id = 'gamesense'`);
    const out = await Promise.all([1, 2, 3, 4, 5].map(() => ingestScore({ boardId: "gamesense", userId: u.id, eventType: "x", dedupeKey: "same" })));
    expect(out.filter((o) => o.accepted)).toHaveLength(1);
  });
});

describe("standings", () => {
  beforeEach(resetDb);

  it("orders by points, then who reached them first, then the older account", async () => {
    const a = await mkUser("a", { createdAt: new Date("2026-01-01") });
    const b = await mkUser("b", { createdAt: new Date("2026-01-02") });
    const c = await mkUser("c", { createdAt: new Date("2026-01-03") });
    const d = await mkUser("d", { createdAt: new Date("2026-01-04") });
    await score("gamesense", a.id, 50, oct(10));
    await score("gamesense", b.id, 50, oct(9));        // same points, earlier
    await score("gamesense", c.id, 80, oct(20));
    await score("gamesense", d.id, 50, oct(9));        // same points and same time as b, but a younger account
    const rows = await standings("gamesense", "2026-10");
    expect(rows.map((r) => r.name)).toEqual(["c", "b", "d", "a"]);
    expect(rows.map((r) => r.rank)).toEqual([1, 2, 3, 4]);
    expect(await rankOf("gamesense", "2026-10", a.id)).toMatchObject({ rank: 4, points: 50 });
  });

  it("zero and negative totals are not listed; months are separate", async () => {
    const a = await mkUser();
    await score("gamesense", a.id, 10, oct(1));
    await score("gamesense", a.id, -10, oct(2));
    await score("gamesense", a.id, 5, new Date(Date.UTC(2026, 10, 2)));
    expect(await standings("gamesense", "2026-10")).toHaveLength(0);
    expect((await standings("gamesense", "2026-11"))[0].points).toBe(5);
  });

  it("the overall board adds the product boards", async () => {
    const a = await mkUser("a");
    const b = await mkUser("b");
    await score("gamesense", a.id, 30, oct(3));
    await score("primordial", a.id, 30, oct(3));
    await score("gamesense", b.id, 50, oct(3));
    const rows = await standings("overall", "2026-10");
    expect(rows.map((r) => [r.name, r.points])).toEqual([["a", 60], ["b", 50]]);
  });

  it("manual points need a product board", async () => {
    const a = await mkUser();
    await manualScore({ boardId: "gamesense", userId: a.id, points: 7, reason: "x", actorId: a.id, now: oct(2) });
    expect((await standings("gamesense", "2026-10"))[0].points).toBe(7);
    await expect(manualScore({ boardId: "overall", userId: a.id, points: 7, reason: "x", actorId: a.id })).rejects.toMatchObject({ code: "bad_board" });
    await expect(manualScore({ boardId: "gamesense", userId: a.id, points: 0, reason: "x", actorId: a.id })).rejects.toMatchObject({ code: "bad_points" });
  });
});

describe("monthly close and rewards", () => {
  beforeEach(resetDb);

  async function season() {
    const [a, b, c, d] = await Promise.all(["a", "b", "c", "d"].map((n) => mkUser(n)));
    await score("gamesense", a.id, 90, oct(10));
    await score("gamesense", b.id, 70, oct(11));
    await score("gamesense", c.id, 40, oct(12));
    await score("gamesense", d.id, 10, oct(13));
    return { a, b, c, d };
  }

  it("the month cannot be closed before it is over", async () => {
    await expect(closePeriod("gamesense", "2026-10", oct(31, 23))).rejects.toMatchObject({ code: "period_open" });
    await expect(closePeriod("gamesense", "2026-1", nov1)).rejects.toMatchObject({ code: "bad_period" });
  });

  it("stores the top 3 and pays 30 / 14 / 7 days, nobody else", async () => {
    const { a, b, c, d } = await season();
    await enableRewards();
    const s = await closePeriod("gamesense", "2026-10", nov1);
    expect(s).toMatchObject({ alreadyClosed: false, results: 3, rewards: 3 });
    const res = await query<{ rank: number; user_id: string; points: number }>("select rank, user_id, points from monthly_results order by rank");
    expect(res.map((r) => [r.rank, r.user_id, r.points])).toEqual([[1, a.id, 90], [2, b.id, 70], [3, c.id, 40]]);
    const log = await query<{ days: number; user_id: string }>("select days, user_id from reward_log order by rank");
    expect(log.map((l) => l.days)).toEqual([30, 14, 7]);
    expect((await resolveAccess(a.id, "gamesense", noRoles, nov1)).status).toBe("active");
    expect((await resolveAccess(d.id, "gamesense", noRoles, nov1)).status).toBe("no_access");
    expect((await resolveAccess(a.id, "primordial", noRoles, nov1)).status).toBe("no_access"); // reward is for the configured product only
    const g = await query<{ expires_at: Date }>("select expires_at from access_grants where user_id = $1", [a.id]);
    expect(g[0].expires_at.getTime() - nov1.getTime()).toBe(30 * day);
    expect(await query("select 1 from notifications where user_id = $1 and kind = 'reward'", [a.id])).toHaveLength(1);
  });

  it("running it again, or twice at the same time, pays nothing twice", async () => {
    await season();
    await enableRewards();
    const runs = await Promise.allSettled([1, 2, 3, 4].map(() => closePeriod("gamesense", "2026-10", nov1)));
    const ok = runs.filter((r) => r.status === "fulfilled").map((r) => (r as PromiseFulfilledResult<{ alreadyClosed: boolean }>).value);
    expect(ok.filter((o) => !o.alreadyClosed)).toHaveLength(1);
    expect((await closePeriod("gamesense", "2026-10", nov1)).alreadyClosed).toBe(true);
    expect(await query("select 1 from reward_log")).toHaveLength(3);
    expect(await query("select 1 from access_grants")).toHaveLength(3);
    expect(await query("select 1 from monthly_results")).toHaveLength(3);
  });

  it("the month job closes every finished month once and leaves the running month alone", async () => {
    const { a } = await season();
    await score("gamesense", a.id, 5, new Date(Date.UTC(2026, 10, 3)));
    await enableRewards();
    const first = await closeDuePeriods(nov1);
    expect(first.map((s) => `${s.boardId}:${s.period}`).sort()).toEqual(["gamesense:2026-10", "overall:2026-10"]);
    expect(await closeDuePeriods(nov1)).toEqual([]);
    expect(await standings("gamesense", "2026-11")).toHaveLength(1); // the new month starts from zero and is still open
  });

  it("an active access is extended, an ended one starts now", async () => {
    const { a, b } = await season();
    await enableRewards();
    await query("insert into access_grants (user_id, product_id, source, starts_at, expires_at) values ($1,'gamesense','admin',$2,$3)", [a.id, oct(1), new Date(nov1.getTime() + 10 * day)]);
    await query("insert into access_grants (user_id, product_id, source, starts_at, expires_at) values ($1,'gamesense','admin',$2,$3)", [b.id, oct(1), oct(5)]);
    await closePeriod("gamesense", "2026-10", nov1);
    const ra = await resolveAccess(a.id, "gamesense", noRoles, nov1);
    expect(ra.expiresAt!.getTime()).toBe(nov1.getTime() + 10 * day + 30 * day);
    const rb = await resolveAccess(b.id, "gamesense", noRoles, nov1);
    expect(rb.expiresAt!.getTime()).toBe(nov1.getTime() + 14 * day);
    const log = await query<{ note: string }>("select note from reward_log order by rank");
    expect(log.map((l) => l.note)).toEqual(["extended", "started", "started"]);
  });

  it("an open ended access gets no grant but the result is logged and the user told", async () => {
    const { a } = await season();
    await enableRewards();
    await query("insert into access_grants (user_id, product_id, source, expires_at) values ($1,'gamesense','admin',null)", [a.id]);
    await closePeriod("gamesense", "2026-10", nov1);
    const log = await query<{ note: string; grant_id: string | null }>("select note, grant_id from reward_log where rank = 1");
    expect(log[0]).toEqual({ note: "permanent_access", grant_id: null });
    expect(await query("select 1 from access_grants where user_id = $1", [a.id])).toHaveLength(1);
  });

  it("the reward product and the board are independent settings", async () => {
    const { a } = await season();
    await enableRewards("gamesense", "primordial");
    await closePeriod("gamesense", "2026-10", nov1);
    expect((await resolveAccess(a.id, "primordial", noRoles, nov1)).status).toBe("active");
    expect((await resolveAccess(a.id, "gamesense", noRoles, nov1)).status).toBe("no_access");
  });

  it("with rewards switched off only the result is stored", async () => {
    await season();
    await closePeriod("gamesense", "2026-10", nov1);
    expect(await query("select 1 from monthly_results")).toHaveLength(3);
    expect(await query("select 1 from reward_log")).toHaveLength(0);
    expect(await query("select 1 from access_grants")).toHaveLength(0);
  });

  it("demo points are never rewarded", async () => {
    const a = await mkUser();
    await score("gamesense", a.id, 99, oct(5), true);
    await enableRewards();
    const s = await closePeriod("gamesense", "2026-10", nov1);
    expect(s).toMatchObject({ results: 0, rewards: 0 });
    expect(await query("select 1 from access_grants")).toHaveLength(0);
  });

  it("the overall board can pay its own reward", async () => {
    const a = await mkUser("a");
    await score("gamesense", a.id, 20, oct(3));
    await score("primordial", a.id, 20, oct(4));
    await query("update boards set rewards_enabled = true, reward_product_id = 'primordial', reward_days = '[10,5,2]' where id = 'overall'");
    await closePeriod("overall", "2026-10", nov1);
    const g = await query<{ expires_at: Date }>("select expires_at from access_grants");
    expect(g[0].expires_at.getTime() - nov1.getTime()).toBe(10 * day);
    expect((await query<{ points: number }>("select points from monthly_results"))[0].points).toBe(40);
  });

  it("applyReward starts from now when nothing runs", async () => {
    const a = await mkUser();
    const out = await applyReward((await import("@/lib/db")).pool(), a.id, "gamesense", 7, nov1, null, "t");
    expect(out.newExpiresAt!.getTime() - nov1.getTime()).toBe(7 * day);
  });
});
