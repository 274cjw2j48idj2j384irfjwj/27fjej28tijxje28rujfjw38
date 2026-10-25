import { afterAll, beforeEach, describe, expect, it } from "vitest";
import { computeAccess, hasAccess, resolveAccess, rolesGrantAccess, type GrantRow } from "@/lib/access";
import { query } from "@/lib/db";
import { day, done, mkUser, resetDb } from "./helpers";

const now = new Date("2026-10-22T12:00:00Z");
const grant = (over: Partial<GrantRow> = {}): GrantRow => ({ starts_at: new Date(now.getTime() - day), expires_at: new Date(now.getTime() + 30 * day), revoked_at: null, source: "admin", ...over });
const base = { now, suspended: false, roleAccess: false, grants: [] as GrantRow[] };

describe("computeAccess", () => {
  it("no role, no grant: no access", () => {
    expect(computeAccess(base).status).toBe("no_access");
  });
  it("a mapped Discord role is active access without an end", () => {
    const r = computeAccess({ ...base, roleAccess: true });
    expect(r).toMatchObject({ status: "active", expiresAt: null, via: "discord_role" });
  });
  it("a grant that runs for a long time is active, with its end", () => {
    const g = grant();
    expect(computeAccess({ ...base, grants: [g] })).toMatchObject({ status: "active", expiresAt: g.expires_at });
  });
  it("a grant ending within 7 days is expiring soon", () => {
    const g = grant({ expires_at: new Date(now.getTime() + 3 * day) });
    expect(computeAccess({ ...base, grants: [g] }).status).toBe("expiring_soon");
    expect(hasAccess("expiring_soon")).toBe(true);
  });
  it("a grant that ended is expired, and the last end is reported", () => {
    const a = grant({ expires_at: new Date(now.getTime() - 10 * day) });
    const b = grant({ expires_at: new Date(now.getTime() - 2 * day) });
    const r = computeAccess({ ...base, grants: [a, b] });
    expect(r.status).toBe("expired");
    expect(r.expiresAt).toEqual(b.expires_at);
    expect(hasAccess(r.status)).toBe(false);
  });
  it("a revoked grant never counts", () => {
    expect(computeAccess({ ...base, grants: [grant({ revoked_at: new Date(now.getTime() - 1000) })] }).status).toBe("no_access");
  });
  it("a grant that did not start yet does not count", () => {
    expect(computeAccess({ ...base, grants: [grant({ starts_at: new Date(now.getTime() + day) })] }).status).toBe("no_access");
  });
  it("an open ended grant is active forever", () => {
    expect(computeAccess({ ...base, grants: [grant({ expires_at: null })] })).toMatchObject({ status: "active", expiresAt: null });
  });
  it("suspended beats every kind of access", () => {
    expect(computeAccess({ ...base, suspended: true, roleAccess: true, grants: [grant()] }).status).toBe("suspended");
  });
  it("a Discord failure is told apart from no access, and grants still work", () => {
    const failed = computeAccess({ ...base, roleAccess: null });
    expect(failed).toMatchObject({ status: "no_access", integrationError: true });
    const withGrant = computeAccess({ ...base, roleAccess: null, grants: [grant()] });
    expect(withGrant).toMatchObject({ status: "active", integrationError: true });
    expect(computeAccess(base).integrationError).toBe(false);
  });
  it("rolesGrantAccess needs a mapped role", () => {
    expect(rolesGrantAccess(["1", "2"], ["2"])).toBe(true);
    expect(rolesGrantAccess(["1"], ["2"])).toBe(false);
    expect(rolesGrantAccess(["1"], [])).toBe(false);
  });
});

describe("resolveAccess (database)", () => {
  beforeEach(resetDb);
  afterAll(done);

  it("the two products are independent", async () => {
    const u = await mkUser();
    await query("insert into role_mappings (product_id, discord_role_id) values ('gamesense','R_GS'), ('primordial','R_PM')");
    const fetcher = async () => ({ inGuild: true, roles: ["R_GS"] });
    expect((await resolveAccess(u.id, "gamesense", fetcher, now)).status).toBe("active");
    expect((await resolveAccess(u.id, "primordial", fetcher, now)).status).toBe("no_access");
  });

  it("a user who is not in the server has no role access", async () => {
    const u = await mkUser();
    await query("insert into role_mappings (product_id, discord_role_id) values ('gamesense','R_GS')");
    const r = await resolveAccess(u.id, "gamesense", async () => ({ inGuild: false, roles: [] }), now);
    expect(r).toMatchObject({ status: "no_access", integrationError: false });
  });

  it("a Discord outage is an integration error, not a missing role", async () => {
    const u = await mkUser();
    await query("insert into role_mappings (product_id, discord_role_id) values ('gamesense','R_GS')");
    const down = async () => {
      throw new Error("discord down");
    };
    const r = await resolveAccess(u.id, "gamesense", down, now);
    expect(r).toMatchObject({ status: "no_access", integrationError: true });
  });

  it("during an outage a recent answer is still used, an old one is not", async () => {
    const u = await mkUser();
    await query("insert into role_mappings (product_id, discord_role_id) values ('gamesense','R_GS')");
    await resolveAccess(u.id, "gamesense", async () => ({ inGuild: true, roles: ["R_GS"] }), now);
    const down = async () => {
      throw new Error("down");
    };
    const soon = new Date(now.getTime() + 10 * 60_000); // cache is stale (> 5 min) but within 15 min
    expect((await resolveAccess(u.id, "gamesense", down, soon)).status).toBe("active");
    const later = new Date(now.getTime() + 60 * 60_000);
    expect(await resolveAccess(u.id, "gamesense", down, later)).toMatchObject({ status: "no_access", integrationError: true });
  });

  it("a removed role takes the access away after the cache runs out", async () => {
    const u = await mkUser();
    await query("insert into role_mappings (product_id, discord_role_id) values ('gamesense','R_GS')");
    await resolveAccess(u.id, "gamesense", async () => ({ inGuild: true, roles: ["R_GS"] }), now);
    const later = new Date(now.getTime() + 6 * 60_000);
    expect((await resolveAccess(u.id, "gamesense", async () => ({ inGuild: true, roles: [] }), later)).status).toBe("no_access");
  });

  it("a product suspension only hits that product", async () => {
    const u = await mkUser();
    await query("insert into access_grants (user_id, product_id, source, starts_at, expires_at) values ($1,'gamesense','admin',$3,$2), ($1,'primordial','admin',$3,$2)", [u.id, new Date(now.getTime() + 20 * day), new Date(now.getTime() - day)]);
    await query("insert into suspensions (user_id, product_id) values ($1,'gamesense')", [u.id]);
    const f = async () => ({ inGuild: true, roles: [] });
    expect((await resolveAccess(u.id, "gamesense", f, now)).status).toBe("suspended");
    expect((await resolveAccess(u.id, "primordial", f, now)).status).toBe("active");
  });

  it("a platform ban suspends both products", async () => {
    const u = await mkUser();
    await query("update users set suspended = true where id = $1", [u.id]);
    const f = async () => ({ inGuild: true, roles: ["x"] });
    expect((await resolveAccess(u.id, "gamesense", f, now)).status).toBe("suspended");
    expect((await resolveAccess(u.id, "primordial", f, now)).status).toBe("suspended");
  });
});
