import { afterAll, beforeEach, describe, expect, it, vi } from "vitest";

const jar = { value: "" as string | undefined };
const discord = { roles: [] as string[], down: false, inGuild: true };

vi.mock("next/headers", () => ({
  cookies: async () => ({ get: (name: string) => (name === "specter_session" && jar.value ? { value: jar.value } : undefined) }),
}));
vi.mock("@/lib/discord", async (orig) => {
  const real = await orig<typeof import("@/lib/discord")>();
  return {
    ...real,
    discordConfigured: () => true,
    fetchMember: async () => {
      if (discord.down) throw new Error("down");
      return { inGuild: discord.inGuild, roles: discord.roles };
    },
  };
});

import { GET as listGet, POST as createPost } from "@/app/api/configs/route";
import { GET as cfgGet, PATCH as cfgPatch } from "@/app/api/configs/[slug]/route";
import { GET as dlGet } from "@/app/api/configs/[slug]/download/route";
import { POST as likePost } from "@/app/api/configs/[slug]/like/route";
import { POST as importPost } from "@/app/api/configs/[slug]/import-code/route";
import { GET as mediaGet } from "@/app/api/media/[id]/route";
import { GET as adminUsers } from "@/app/api/admin/users/route";
import { POST as adminUserAction } from "@/app/api/admin/users/[id]/route";
import { POST as cronPost } from "@/app/api/cron/close-month/route";
import { POST as deviceCode } from "@/app/api/device/code/route";
import { POST as deviceToken } from "@/app/api/device/token/route";
import { POST as deviceApprove } from "@/app/api/device/approve/route";
import { GET as clientBrowse, POST as clientUpload } from "@/app/api/client/configs/route";
import { GET as clientInfo } from "@/app/api/client/configs/[slug]/route";
import { GET as clientPayload } from "@/app/api/client/configs/[slug]/payload/route";
import { POST as clientScore } from "@/app/api/client/score/route";
import { GET as clientMe } from "@/app/api/client/me/route";
import { createConfig } from "@/lib/configs";
import { createSession } from "@/lib/sessions";
import { query } from "@/lib/db";
import { done, mkUser, resetDb } from "./helpers";

process.env.PUBLIC_URL = "http://localhost:3000";
process.env.CRON_SECRET = "c".repeat(32);

const ORIGIN = "http://localhost:3000";
const ctx = <P>(params: P) => ({ params: Promise.resolve(params) });
const payload = (product: "gamesense" | "primordial" = "gamesense") => ({ meta: { product, format_version: 1, lua_version: "1.0.0" }, data: { a: 1 } });

function req(url: string, init: { method?: string; body?: unknown; headers?: Record<string, string>; origin?: string | null } = {}) {
  const headers: Record<string, string> = { "content-type": "application/json", ...(init.headers ?? {}) };
  if (init.origin !== null && init.method && init.method !== "GET") headers.origin = init.origin ?? ORIGIN;
  return new Request(`${ORIGIN}${url}`, { method: init.method ?? "GET", headers, body: init.body === undefined ? undefined : JSON.stringify(init.body) });
}

async function login(userId: string) {
  jar.value = (await createSession(userId, "test")).token;
}

async function body(res: Response) {
  return (await res.json()) as any;
}

async function giveRole(product: "gamesense" | "primordial", role = "ROLE_" + product) {
  await query("insert into role_mappings (product_id, discord_role_id) values ($1,$2) on conflict do nothing", [product, role]);
  return role;
}

beforeEach(async () => {
  await resetDb();
  jar.value = undefined;
  discord.roles = [];
  discord.down = false;
  discord.inGuild = true;
});
afterAll(done);

describe("sign in and access are checked by the backend", () => {
  it("a signed out visitor cannot create, download, like or import", async () => {
    const owner = await mkUser();
    const c = await createConfig({ ownerId: owner.id, productId: "gamesense", name: "Pub", payload: payload() });
    expect((await createPost(req("/api/configs", { method: "POST", body: { product: "gamesense", name: "x1", payload: payload() } }), ctx({}))).status).toBe(401);
    expect((await dlGet(req(`/api/configs/${c.slug}/download`), ctx({ slug: c.slug }))).status).toBe(401);
    expect((await likePost(req(`/api/configs/${c.slug}/like`, { method: "POST" }), ctx({ slug: c.slug }))).status).toBe(401);
    expect((await importPost(req(`/api/configs/${c.slug}/import-code`, { method: "POST" }), ctx({ slug: c.slug }))).status).toBe(401);
  });

  it("the catalog and a public config page are readable without signing in", async () => {
    const owner = await mkUser();
    const c = await createConfig({ ownerId: owner.id, productId: "gamesense", name: "Pub", payload: payload() });
    const list = await body(await listGet(req("/api/configs?product=gamesense"), ctx({})));
    expect(list.items).toHaveLength(1);
    expect(list.items[0].payload).toBeUndefined();
    const one = await body(await cfgGet(req(`/api/configs/${c.slug}`), ctx({ slug: c.slug })));
    expect(one.config.name).toBe("Pub");
    expect(JSON.stringify(one)).not.toContain('"data"');
  });

  it("without the role the download and the upload are refused, with the role they work", async () => {
    const owner = await mkUser();
    const c = await createConfig({ ownerId: owner.id, productId: "gamesense", name: "Pub", payload: payload() });
    const u = await mkUser("buyer");
    await login(u.id);
    await giveRole("gamesense");
    const denied = await dlGet(req(`/api/configs/${c.slug}/download`), ctx({ slug: c.slug }));
    expect(denied.status).toBe(403);
    expect((await body(denied)).error.code).toBe("no_access");
    expect((await createPost(req("/api/configs", { method: "POST", body: { product: "gamesense", name: "mine1", payload: payload() } }), ctx({}))).status).toBe(403);

    discord.roles = ["ROLE_gamesense"];
    await query("delete from member_cache");
    const ok = await dlGet(req(`/api/configs/${c.slug}/download`), ctx({ slug: c.slug }));
    expect(ok.status).toBe(200);
    expect(JSON.parse(await ok.text())).toEqual(payload());
    const made = await createPost(req("/api/configs", { method: "POST", body: { product: "gamesense", name: "mine1", payload: payload() } }), ctx({}));
    expect(made.status).toBe(201);
  });

  it("the Gamesense role gives nothing for Primordial", async () => {
    const owner = await mkUser();
    const c = await createConfig({ ownerId: owner.id, productId: "primordial", name: "PM", payload: payload("primordial") });
    const u = await mkUser();
    await login(u.id);
    await giveRole("gamesense");
    await giveRole("primordial");
    discord.roles = ["ROLE_gamesense"];
    expect((await dlGet(req(`/api/configs/${c.slug}/download`), ctx({ slug: c.slug }))).status).toBe(403);
    const created = await createPost(req("/api/configs", { method: "POST", body: { product: "primordial", name: "pm cfg", payload: payload("primordial") } }), ctx({}));
    expect(created.status).toBe(403);
  });

  it("a Discord outage answers 503, not 'no access'", async () => {
    const owner = await mkUser();
    const c = await createConfig({ ownerId: owner.id, productId: "gamesense", name: "Pub", payload: payload() });
    const u = await mkUser();
    await login(u.id);
    await giveRole("gamesense");
    discord.down = true;
    const res = await dlGet(req(`/api/configs/${c.slug}/download`), ctx({ slug: c.slug }));
    expect(res.status).toBe(503);
    expect((await body(res)).error.code).toBe("discord_unavailable");
  });

  it("an expired grant is refused with its own code, a suspended product too", async () => {
    const owner = await mkUser();
    const c = await createConfig({ ownerId: owner.id, productId: "gamesense", name: "Pub", payload: payload() });
    const u = await mkUser();
    await login(u.id);
    await query("insert into access_grants (user_id, product_id, source, starts_at, expires_at) values ($1,'gamesense','admin', now() - interval '10 days', now() - interval '1 day')", [u.id]);
    expect((await body(await dlGet(req(`/api/configs/${c.slug}/download`), ctx({ slug: c.slug })))).error.code).toBe("expired");
    await query("insert into access_grants (user_id, product_id, source, expires_at) values ($1,'gamesense','admin', now() + interval '10 days')", [u.id]);
    expect((await dlGet(req(`/api/configs/${c.slug}/download`), ctx({ slug: c.slug }))).status).toBe(200);
    await query("insert into suspensions (user_id, product_id) values ($1,'gamesense')", [u.id]);
    expect((await body(await dlGet(req(`/api/configs/${c.slug}/download`), ctx({ slug: c.slug })))).error.code).toBe("suspended");
  });

  it("a private config is a 404 for everybody but the owner", async () => {
    const owner = await mkUser();
    const c = await createConfig({ ownerId: owner.id, productId: "gamesense", name: "Secret", visibility: "private", payload: payload() });
    const u = await mkUser();
    await login(u.id);
    expect((await cfgGet(req(`/api/configs/${c.slug}`), ctx({ slug: c.slug }))).status).toBe(404);
    await login(owner.id);
    expect((await cfgGet(req(`/api/configs/${c.slug}`), ctx({ slug: c.slug }))).status).toBe(200);
  });

  it("only the owner can edit a config", async () => {
    const owner = await mkUser();
    const c = await createConfig({ ownerId: owner.id, productId: "gamesense", name: "Mine", payload: payload() });
    const u = await mkUser();
    await login(u.id);
    expect((await cfgPatch(req(`/api/configs/${c.slug}`, { method: "PATCH", body: { name: "Hacked" } }), ctx({ slug: c.slug }))).status).toBe(404);
  });

  it("a write from another site is refused", async () => {
    const u = await mkUser();
    await login(u.id);
    const res = await likePost(req("/api/configs/x/like", { method: "POST", origin: "https://evil.example" }), ctx({ slug: "x" }));
    expect(res.status).toBe(403);
    expect((await body(res)).error.code).toBe("bad_origin");
    expect((await likePost(req("/api/configs/x/like", { method: "POST", origin: null }), ctx({ slug: "x" }))).status).toBe(403);
  });

  it("a suspended account is locked out", async () => {
    const u = await mkUser();
    await login(u.id);
    await query("update users set suspended = true where id = $1", [u.id]);
    const res = await likePost(req("/api/configs/x/like", { method: "POST" }), ctx({ slug: "x" }));
    expect(res.status).toBe(403);
    expect((await body(res)).error.code).toBe("suspended");
  });
});

describe("admin routes", () => {
  it("are closed to normal users and open to admins", async () => {
    const u = await mkUser("normal");
    const a = await mkUser("boss", { admin: true });
    await login(u.id);
    expect((await adminUsers(req("/api/admin/users"), ctx({}))).status).toBe(403);
    expect((await adminUserAction(req(`/api/admin/users/${u.id}`, { method: "POST", body: { action: "ban" } }), ctx({ id: u.id }))).status).toBe(403);
    jar.value = undefined;
    expect((await adminUsers(req("/api/admin/users"), ctx({}))).status).toBe(401);
    await login(a.id);
    expect((await adminUsers(req("/api/admin/users"), ctx({}))).status).toBe(200);
  });

  it("an admin grant gives access and shows in the audit log; only owners make admins", async () => {
    const a = await mkUser("boss", { admin: true });
    const u = await mkUser("buyer");
    await login(a.id);
    const g = await adminUserAction(req(`/api/admin/users/${u.id}`, { method: "POST", body: { action: "grant", product: "gamesense", days: 30 } }), ctx({ id: u.id }));
    expect(g.status).toBe(200);
    expect(await query("select 1 from audit_log where action = 'access.grant'")).toHaveLength(1);
    const mk = await adminUserAction(req(`/api/admin/users/${u.id}`, { method: "POST", body: { action: "make_admin" } }), ctx({ id: u.id }));
    expect(mk.status).toBe(403);
    process.env.ADMIN_DISCORD_IDS = (await query<{ discord_id: string }>("select discord_id from users where id = $1", [a.id]))[0].discord_id;
    const ok = await adminUserAction(req(`/api/admin/users/${u.id}`, { method: "POST", body: { action: "make_admin" } }), ctx({ id: u.id }));
    expect(ok.status).toBe(200);
    delete process.env.ADMIN_DISCORD_IDS;
  });

  it("an admin cannot ban themselves", async () => {
    const a = await mkUser("boss", { admin: true });
    await login(a.id);
    expect((await adminUserAction(req(`/api/admin/users/${a.id}`, { method: "POST", body: { action: "ban" } }), ctx({ id: a.id }))).status).toBe(400);
  });
});

describe("media", () => {
  it("a private config image is only for its owner", async () => {
    const owner = await mkUser();
    const other = await mkUser();
    const c = await createConfig({ ownerId: owner.id, productId: "gamesense", name: "Imgs", visibility: "private", payload: payload() });
    const blob = (await query<{ id: string }>("insert into blobs (content_type, bytes) values ('image/png', $1) returning id", [Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 1, 2, 3, 4])]))[0];
    await query("insert into config_images (config_id, blob_id) values ($1,$2)", [c.id, blob.id]);
    await login(other.id);
    expect((await mediaGet(req(`/api/media/${blob.id}`), ctx({ id: blob.id }))).status).toBe(404);
    await login(owner.id);
    const ok = await mediaGet(req(`/api/media/${blob.id}`), ctx({ id: blob.id }));
    expect(ok.status).toBe(200);
    expect(ok.headers.get("content-type")).toBe("image/png");
    expect((await mediaGet(req("/api/media/not-a-uuid"), ctx({ id: "not-a-uuid" }))).status).toBe(404);
  });
});

describe("cron", () => {
  it("needs the secret", async () => {
    expect((await cronPost(req("/api/cron/close-month", { method: "POST" }), ctx({}))).status).toBe(401);
    expect((await cronPost(req("/api/cron/close-month", { method: "POST", headers: { authorization: "Bearer wrong" } }), ctx({}))).status).toBe(401);
    const ok = await cronPost(req("/api/cron/close-month", { method: "POST", headers: { authorization: `Bearer ${"c".repeat(32)}` } }), ctx({}));
    expect(ok.status).toBe(200);
    expect(await body(ok)).toEqual({ closed: [], releaseNotices: 0, expiryNotices: 0 });
  });
});

describe("Lua client flow", () => {
  async function linkedToken(userId: string, product: "gamesense" | "primordial") {
    const started = await body(await deviceCode(req("/api/device/code", { method: "POST", body: { product, client_name: "Lua" } }), ctx({})));
    await login(userId);
    const ok = await deviceApprove(req("/api/device/approve", { method: "POST", body: { user_code: started.user_code, approve: true } }), ctx({}));
    expect(ok.status).toBe(200);
    jar.value = undefined;
    await new Promise((r) => setTimeout(r, 10));
    const got = await body(await deviceToken(req("/api/device/token", { method: "POST", body: { device_code: started.device_code } }), ctx({})));
    expect(got.status).toBe("approved");
    return got.access_token as string;
  }
  const bearer = (t: string) => ({ authorization: `Bearer ${t}` });

  it("link, upload, browse, import: the token only works for its own Lua", async () => {
    const u = await mkUser("player");
    await giveRole("gamesense");
    await giveRole("primordial");
    discord.roles = ["ROLE_gamesense", "ROLE_primordial"];
    const gsToken = await linkedToken(u.id, "gamesense");

    const up = await clientUpload(req("/api/client/configs", { method: "POST", headers: bearer(gsToken), body: { name: "From Lua", payload: payload("gamesense") } }), ctx({}));
    expect(up.status).toBe(201);
    const made = await body(up);
    expect(made.share_code).toBe(made.slug);

    const wrong = await clientUpload(req("/api/client/configs", { method: "POST", headers: bearer(gsToken), body: { name: "Wrong lua", payload: payload("primordial") } }), ctx({}));
    expect(wrong.status).toBe(422);
    expect((await body(wrong)).error.code).toBe("invalid_config");

    const pmOwner = await mkUser();
    const pm = await createConfig({ ownerId: pmOwner.id, productId: "primordial", name: "PM only", payload: payload("primordial") });
    expect((await clientInfo(req(`/api/client/configs/${pm.slug}`, { headers: bearer(gsToken) }), ctx({ slug: pm.slug }))).status).toBe(404);
    expect((await clientPayload(req(`/api/client/configs/${pm.slug}/payload`, { headers: bearer(gsToken) }), ctx({ slug: pm.slug }))).status).toBe(404);

    const browse = await body(await clientBrowse(req("/api/client/configs", { headers: bearer(gsToken) }), ctx({})));
    expect(browse.items.map((i: any) => i.name)).toEqual(["From Lua"]);

    const info = await body(await clientInfo(req(`/api/client/configs/${made.slug}`, { headers: bearer(gsToken) }), ctx({ slug: made.slug })));
    expect(info.config.author.name).toBe("player");
    expect(info.compat.compatible).toBe(true);
    expect(info.payload).toBeUndefined();

    const data = await body(await clientPayload(req(`/api/client/configs/${made.slug}/payload`, { headers: bearer(gsToken) }), ctx({ slug: made.slug })));
    expect(data.payload).toEqual(payload("gamesense"));
  });

  it("an incompatible format is refused with 409 and the version info says so", async () => {
    const u = await mkUser();
    await giveRole("gamesense");
    discord.roles = ["ROLE_gamesense"];
    const t = await linkedToken(u.id, "gamesense");
    const owner = await mkUser();
    const c = await createConfig({ ownerId: owner.id, productId: "gamesense", name: "Old format", payload: payload() });
    await query("update products set min_format = 2, max_format = 3 where id = 'gamesense'");
    const info = await body(await clientInfo(req(`/api/client/configs/${c.slug}`, { headers: bearer(t) }), ctx({ slug: c.slug })));
    expect(info.compat).toMatchObject({ compatible: false, reason: "format_too_old" });
    const res = await clientPayload(req(`/api/client/configs/${c.slug}/payload`, { headers: bearer(t) }), ctx({ slug: c.slug }));
    expect(res.status).toBe(409);
  });

  it("a token without access gets 403 and without a token 401", async () => {
    const u = await mkUser();
    const t = await linkedToken(u.id, "gamesense");
    expect((await clientBrowse(req("/api/client/configs", { headers: bearer(t) }), ctx({}))).status).toBe(403);
    expect((await clientBrowse(req("/api/client/configs"), ctx({}))).status).toBe(401);
    expect((await clientBrowse(req("/api/client/configs", { headers: bearer("spt_fake") }), ctx({}))).status).toBe(401);
    const me = await body(await clientMe(req("/api/client/me", { headers: bearer(t) }), ctx({})));
    expect(me.access.status).toBe("no_access");
  });

  it("revoking the link stops the token", async () => {
    const u = await mkUser();
    await giveRole("gamesense");
    discord.roles = ["ROLE_gamesense"];
    const t = await linkedToken(u.id, "gamesense");
    expect((await clientBrowse(req("/api/client/configs", { headers: bearer(t) }), ctx({}))).status).toBe(200);
    await query("update client_tokens set revoked_at = now()");
    expect((await clientBrowse(req("/api/client/configs", { headers: bearer(t) }), ctx({}))).status).toBe(401);
  });

  it("score reports count nothing while collection is off", async () => {
    const u = await mkUser();
    await giveRole("gamesense");
    discord.roles = ["ROLE_gamesense"];
    const t = await linkedToken(u.id, "gamesense");
    const res = await clientScore(req("/api/client/score", { method: "POST", headers: bearer(t), body: { event_type: "round_win", dedupe_key: "m1:r1" } }), ctx({}));
    expect(await body(res)).toEqual({ accepted: false, reason: "disabled" });
    expect(await query("select 1 from score_events")).toHaveLength(0);
  });
});
