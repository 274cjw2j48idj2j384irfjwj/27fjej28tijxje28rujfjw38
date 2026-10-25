import { afterAll, beforeEach, describe, expect, it, vi } from "vitest";
import { announce, fanoutReleases, warnExpiring } from "@/lib/notices";
import { query } from "@/lib/db";
import { day, done, mkUser, resetDb } from "./helpers";

const now = new Date("2026-10-22T12:00:00Z");

describe("notices", () => {
  beforeEach(resetDb);
  afterAll(done);

  it("a new release notifies the users of that Lua once", async () => {
    const a = await mkUser("has-access");
    const b = await mkUser("other-lua");
    const c = await mkUser("nothing");
    await query("insert into access_grants (user_id, product_id, source, expires_at) values ($1,'gamesense','admin', $2), ($3,'primordial','admin', $2)", [a.id, new Date(now.getTime() + 20 * day), b.id]);
    await query("insert into releases (product_id, version, title, released_at) values ('gamesense','1.2.0','Fixes',$1)", [new Date(now.getTime() - day)]);
    expect(await fanoutReleases(now)).toBe(1);
    expect(await fanoutReleases(now)).toBe(0); // the same release is not announced again
    expect((await query("select user_id from notifications where kind = 'release'")).map((r: any) => r.user_id)).toEqual([a.id]);
    void c;
  });

  it("demo and old releases are skipped", async () => {
    await query("insert into releases (product_id, version, title, released_at, is_demo) values ('gamesense','1.0.0','Demo',$1,true), ('gamesense','0.9.0','Old',$2,false)", [new Date(now.getTime() - day), new Date(now.getTime() - 30 * day)]);
    expect(await fanoutReleases(now)).toBe(0);
    expect(await query("select 1 from release_notices")).toHaveLength(0);
  });

  it("an access that ends within 3 days is warned about once", async () => {
    const a = await mkUser();
    await query("insert into access_grants (user_id, product_id, source, starts_at, expires_at) values ($1,'gamesense','reward',$3,$2)", [a.id, new Date(now.getTime() + 2 * day), new Date(now.getTime() - day)]);
    expect(await warnExpiring(now)).toBe(1);
    expect(await warnExpiring(now)).toBe(0);
    expect(await query("select 1 from notifications where kind = 'expiry'")).toHaveLength(1);
  });

  it("no warning when another grant keeps the access running", async () => {
    const a = await mkUser();
    await query("insert into access_grants (user_id, product_id, source, starts_at, expires_at) values ($1,'gamesense','reward',$4,$2), ($1,'gamesense','admin',$4,$3)", [a.id, new Date(now.getTime() + 2 * day), new Date(now.getTime() + 40 * day), new Date(now.getTime() - day)]);
    expect(await warnExpiring(now)).toBe(0);
  });

  it("no warning for far away or revoked grants", async () => {
    const a = await mkUser();
    await query("insert into access_grants (user_id, product_id, source, expires_at) values ($1,'gamesense','admin',$2)", [a.id, new Date(now.getTime() + 30 * day)]);
    await query("insert into access_grants (user_id, product_id, source, expires_at, revoked_at) values ($1,'primordial','admin',$2, now())", [a.id, new Date(now.getTime() + 1 * day)]);
    expect(await warnExpiring(now)).toBe(0);
  });

  it("the announcement webhook is optional and only posts to Discord", async () => {
    delete process.env.DISCORD_ANNOUNCE_WEBHOOK;
    expect(await announce("x")).toBe(false);
    process.env.DISCORD_ANNOUNCE_WEBHOOK = "https://evil.example/hook";
    expect(await announce("x")).toBe(false);
    const fetchMock = vi.fn(async () => new Response(null, { status: 204 }));
    vi.stubGlobal("fetch", fetchMock);
    process.env.DISCORD_ANNOUNCE_WEBHOOK = "https://discord.com/api/webhooks/1/abc";
    expect(await announce("hello")).toBe(true);
    expect(fetchMock).toHaveBeenCalledTimes(1);
    vi.unstubAllGlobals();
    delete process.env.DISCORD_ANNOUNCE_WEBHOOK;
  });
});
