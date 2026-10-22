import { afterAll, beforeEach, describe, expect, it, vi } from "vitest";

process.env.LICENSE_SERVER_URL = "https://license.test";
process.env.LICENSE_ADMIN_SECRET = "admin-secret";

import { PRIZES, roll, rouletteState, spin, WEEK_MS } from "@/lib/roulette";
import { one, query } from "@/lib/db";
import { done, mkUser, resetDb } from "./helpers";

const world = { keys: [] as any[], extends: [] as any[], down: false, refs: new Map<string, number>(), reject: false };
beforeEach(async () => {
  await resetDb();
  world.keys = []; world.extends = []; world.down = false; world.refs.clear(); world.reject = false;
  vi.stubGlobal("fetch", async (input: any, init: any = {}) => {
    const url = String(input);
    const reply = (status: number, data: unknown) => new Response(JSON.stringify(data), { status, headers: { "content-type": "application/json" } });
    if (world.down) throw new Error("ECONNREFUSED");
    if (url.includes("/admin/by_discord")) return reply(200, world.keys);
    if (url.endsWith("/admin/extend")) {
      if (world.reject) return reply(403, { ok: false, reason: "expired" });
      const b = JSON.parse(init.body);
      world.extends.push(b);
      if (!world.refs.has(b.ref)) world.refs.set(b.ref, Date.now() + b.hours * 3600000);
      return reply(200, { ok: true, already: false, expires_at: world.refs.get(b.ref) });
    }
    throw new Error("unexpected fetch " + url);
  });
});
afterAll(done);

const key = (lua: string, over: Record<string, unknown> = {}) => ({ key: `K-${lua}`, plan: lua === "primordial" ? "pm_nightly" : "specter", lua, expires_at: Date.now() + 5 * 86400000, expired: false, revoked: false, ...over });

describe("odds", () => {
  it("add up to 100 % and the 30 day prize is exactly 1 %", () => {
    expect(PRIZES.reduce((n, p) => n + p.weight, 0)).toBe(10000);
    expect(PRIZES.find((p) => p.id === "30d")!.weight).toBe(100);
    expect(PRIZES.some((p) => p.id === "nothing")).toBe(true);
  });
  it("rolls by the weights", () => {
    expect(roll(() => 0).id).toBe("nothing");
    expect(roll(() => 3999).id).toBe("nothing");
    expect(roll(() => 4000).id).toBe("5h");
    expect(roll(() => 9899).id).toBe("14d");
    expect(roll(() => 9900).id).toBe("30d");
    expect(roll(() => 9999).id).toBe("30d");
  });
});

describe("spin", () => {
  it("needs a running registered key and keeps the spin when there is none", async () => {
    const u = await mkUser();
    await expect(spin(u.id, u.discord_id, null)).rejects.toMatchObject({ code: "no_key" });
    world.keys = [key("gamesense", { expires_at: null })];
    await expect(spin(u.id, u.discord_id, null)).rejects.toMatchObject({ code: "no_key" });
    expect((await rouletteState(u.id)).canSpin).toBe(true);
  });

  it("pays a prize once and allows one spin a week", async () => {
    const u = await mkUser();
    world.keys = [key("gamesense")];
    const r = await spin(u.id, u.discord_id, null);
    expect(r.status).toBe("done");
    if (r.hours > 0) {
      expect(world.extends).toHaveLength(1);
      expect(world.extends[0]).toMatchObject({ key: "K-gamesense", hours: r.hours, ref: r.id, discord_id: u.discord_id });
      expect(r.newExpiresAt).not.toBeNull();
    } else expect(world.extends).toHaveLength(0);
    await expect(spin(u.id, u.discord_id, null)).rejects.toMatchObject({ code: "already_spun", status: 429 });
    // a week later it is allowed again
    await query("update roulette_spins set created_at = now() - interval '8 days' where user_id = $1", [u.id]);
    expect((await rouletteState(u.id)).canSpin).toBe(true);
    await expect(spin(u.id, u.discord_id, null)).resolves.toMatchObject({ status: "done" });
  });

  it("stores the roll and waits the full 7 days", async () => {
    const u = await mkUser();
    world.keys = [key("gamesense")];
    const t0 = new Date(Date.now() - 1000);
    await spin(u.id, u.discord_id, null, t0);
    const s = await rouletteState(u.id, new Date(t0.getTime() + WEEK_MS - 1000));
    expect(s.canSpin).toBe(false);
    expect(s.nextSpinAt).toBe(new Date(t0.getTime() + WEEK_MS).toISOString());
    expect((await rouletteState(u.id, new Date(t0.getTime() + WEEK_MS))).canSpin).toBe(true);
  });

  it("asks which Lua when the account has keys for both", async () => {
    const u = await mkUser();
    world.keys = [key("gamesense"), key("primordial")];
    await expect(spin(u.id, u.discord_id, null)).rejects.toMatchObject({ code: "choose_lua" });
    expect((await rouletteState(u.id)).history).toHaveLength(0);
    const r = await spin(u.id, u.discord_id, "primordial");
    expect(r.status).toBe("done");
    if (r.hours > 0) expect(world.extends[0].key).toBe("K-primordial");
  });

  it("keeps an unpaid prize when the license server is down and finishes it later without a new roll", async () => {
    const u = await mkUser();
    world.keys = [key("gamesense")];
    // force a prize with hours
    await spin(u.id, u.discord_id, null).catch(() => undefined);
    await query("delete from roulette_spins where user_id = $1", [u.id]);
    world.extends = [];
    const row = await one<{ id: string }>("insert into roulette_spins (user_id, prize, hours, lua, license_key) values ($1,'1d',24,'gamesense','K-gamesense') returning id", [u.id]);
    world.down = true;
    await expect(spin(u.id, u.discord_id, null)).rejects.toMatchObject({ code: "license_unavailable" });
    expect((await rouletteState(u.id)).pending?.id).toBe(row!.id);
    world.down = false;
    const r = await spin(u.id, u.discord_id, null);
    expect(r).toMatchObject({ id: row!.id, prize: "1d", status: "done" });
    expect(world.extends).toHaveLength(1);
    expect(await query("select 1 from roulette_spins where user_id = $1", [u.id])).toHaveLength(1);
  });

  it("a key that ended between the roll and the payment keeps the spin and says so", async () => {
    const u = await mkUser();
    world.keys = [key("gamesense")];
    await query("insert into roulette_spins (user_id, prize, hours, lua, license_key) values ($1,'7d',168,'gamesense','K-gamesense')", [u.id]);
    world.reject = true;
    await expect(spin(u.id, u.discord_id, null)).rejects.toMatchObject({ code: "key_unavailable", status: 409 });
    expect((await rouletteState(u.id)).pending).not.toBeNull();
  });

  it("two parallel spins make one", async () => {
    const u = await mkUser();
    world.keys = [key("gamesense")];
    const out = await Promise.allSettled([spin(u.id, u.discord_id, null), spin(u.id, u.discord_id, null), spin(u.id, u.discord_id, null)]);
    expect(await query("select 1 from roulette_spins where user_id = $1", [u.id])).toHaveLength(1);
    expect(out.filter((o) => o.status === "fulfilled").length).toBeGreaterThanOrEqual(1);
    // a parallel call may repeat the payment of the same spin: the ref makes the license server count it once
    expect(new Set(world.extends.map((e) => e.ref)).size).toBeLessThanOrEqual(1);
  });
});
