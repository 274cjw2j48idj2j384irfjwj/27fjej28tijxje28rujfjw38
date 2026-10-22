import { afterAll, beforeEach, describe, expect, it, vi } from "vitest";

const jar = { value: "" as string | undefined };
vi.mock("next/headers", () => ({
  cookies: async () => ({ get: (name: string) => (name === "specter_session" && jar.value ? { value: jar.value } : undefined) }),
}));

import { GET as adminConfigs } from "@/app/api/admin/configs/route";
import { createConfig } from "@/lib/configs";
import { listAdminConfigs } from "@/lib/admin-configs";
import { createSession } from "@/lib/sessions";
import { query } from "@/lib/db";
import { done, mkUser, resetDb } from "./helpers";

process.env.PUBLIC_URL = "http://localhost:3000";
const payload = (product: "gamesense" | "primordial" = "gamesense") => ({ meta: { product, format_version: 1, lua_version: "1.0.0" }, data: { a: 1 } });
const ctx = { params: Promise.resolve({}) };

beforeEach(async () => {
  await resetDb();
  jar.value = undefined;
});
afterAll(done);

describe("admin config moderation list", () => {
  it("lists hidden and private configs with owner and report counts, open reports first", async () => {
    const a = await mkUser("alice");
    const b = await mkUser("bob");
    const pub = await createConfig({ ownerId: a.id, productId: "gamesense", name: "Public one", payload: payload() });
    const priv = await createConfig({ ownerId: b.id, productId: "primordial", name: "Secret one", visibility: "private", payload: payload("primordial") });
    await query("update configs set hidden = true where id = $1", [priv.id]);
    await query("update configs set updated_at = now() - interval '1 day' where id = $1", [pub.id]);
    const rep = await mkUser("reporter");
    await query("insert into config_reports (config_id, reporter_id, reason) values ($1,$2,'spam')", [pub.id, rep.id]);

    const all = await listAdminConfigs();
    expect(all.total).toBe(2);
    expect(all.items[0].name).toBe("Public one"); // the open report sorts first although it is older
    expect(all.items[0].reports_open).toBe(1);
    const hidden = all.items.find((c) => c.name === "Secret one")!;
    expect(hidden.hidden).toBe(true);
    expect(hidden.visibility).toBe("private");
    expect(hidden.owner_name).toBe("bob");
  });

  it("filters by name, owner, discord id and product, and pages", async () => {
    const a = await mkUser("alice");
    const b = await mkUser("bobby");
    await createConfig({ ownerId: a.id, productId: "gamesense", name: "Alpha cfg", payload: payload() });
    await createConfig({ ownerId: b.id, productId: "primordial", name: "Beta cfg", payload: payload("primordial") });
    expect((await listAdminConfigs({ q: "alpha" })).items.map((c) => c.name)).toEqual(["Alpha cfg"]);
    expect((await listAdminConfigs({ q: "bobby" })).items.map((c) => c.name)).toEqual(["Beta cfg"]);
    expect((await listAdminConfigs({ q: a.discord_id })).items.map((c) => c.name)).toEqual(["Alpha cfg"]);
    expect((await listAdminConfigs({ product: "primordial" })).total).toBe(1);
    expect((await listAdminConfigs({ q: "100%_" })).total).toBe(0); // wildcards are escaped
    const p = await listAdminConfigs({ pageSize: 1, page: 9 });
    expect(p.pages).toBe(2);
    expect(p.page).toBe(2);
    expect(p.items).toHaveLength(1);
  });

  it("the route is admin only", async () => {
    const user = await mkUser("plain");
    const admin = await mkUser("boss", { admin: true });
    const req = () => new Request("http://localhost:3000/api/admin/configs?q=x");
    expect((await adminConfigs(req(), ctx)).status).toBe(401);
    jar.value = (await createSession(user.id, "t")).token;
    expect((await adminConfigs(req(), ctx)).status).toBe(403);
    jar.value = (await createSession(admin.id, "t")).token;
    const ok = await adminConfigs(req(), ctx);
    expect(ok.status).toBe(200);
    expect((await ok.json()).items).toEqual([]);
  });
});
