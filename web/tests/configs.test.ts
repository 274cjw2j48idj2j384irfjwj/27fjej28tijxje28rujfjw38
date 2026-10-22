import { afterAll, beforeEach, describe, expect, it } from "vitest";
import { checkCompat, cleanTags, cleanText, compareVersions, validatePayload } from "@/lib/config-validate";
import {
  addConfigImage, addVersion, canView, compatFor, createConfig, getConfigBySlug, getVersionPayload, libraryOf, listConfigs, recordEvent,
  removeFromLibrary, reportConfig, saveToLibrary, toggleLike, updateConfigMeta, ApiError,
} from "@/lib/configs";
import { query } from "@/lib/db";
import { done, mkUser, resetDb } from "./helpers";

const payload = (product: "gamesense" | "primordial" = "gamesense", extra: Record<string, unknown> = {}) => ({
  meta: { product, format_version: 1, lua_version: "1.4.0" },
  data: { aa: { yaw: 12, jitter: true }, ...extra },
});

describe("validatePayload", () => {
  it("accepts a normal config", () => {
    const r = validatePayload(payload(), "gamesense");
    expect(r.ok).toBe(true);
  });
  it("refuses a config of the other Lua", () => {
    const r = validatePayload(payload("primordial"), "gamesense");
    expect(r.ok === false && r.problems[0].code).toBe("wrong_product");
  });
  it("refuses a missing or broken meta", () => {
    expect(validatePayload({ data: {} }, "gamesense").ok).toBe(false);
    expect(validatePayload({ meta: { product: "gamesense", format_version: 0, lua_version: "x" }, data: {} }, "gamesense").ok).toBe(false);
    expect(validatePayload("nope", "gamesense").ok).toBe(false);
    expect(validatePayload([], "gamesense").ok).toBe(false);
  });
  it("accepts a string as data (an exported text) and refuses numbers or null", () => {
    expect(validatePayload({ meta: payload().meta, data: "eyJhIjoxfQ==" }, "gamesense").ok).toBe(true);
    expect(validatePayload({ meta: payload().meta, data: 5 }, "gamesense").ok).toBe(false);
    expect(validatePayload({ meta: payload().meta, data: null }, "gamesense").ok).toBe(false);
  });
  it("refuses unknown top level keys", () => {
    expect(validatePayload({ ...payload(), exec: "x" }, "gamesense").ok).toBe(false);
  });
  it("refuses secrets: key names and token like values", () => {
    expect(validatePayload(payload("gamesense", { token: "x" }), "gamesense").ok).toBe(false);
    expect(validatePayload(payload("gamesense", { license_key: "x" }), "gamesense").ok).toBe(false);
    expect(validatePayload(payload("gamesense", { note: "github_pat_11CQXD3BI0woVlikv3ta7m_1XPrn0CH4eUO2VocaZhEG18xnr62" }), "gamesense").ok).toBe(false);
    expect(validatePayload(payload("gamesense", { note: "https://discord.com/api/webhooks/1/abc" }), "gamesense").ok).toBe(false);
    expect(validatePayload(payload("gamesense", { note: "ABCDEF-GHJKMN-PQRSTU-VWXYZ2" }), "gamesense").ok).toBe(false);
    expect(validatePayload(payload("gamesense", { note: "me@example.com" }), "gamesense").ok).toBe(false);
    expect(validatePayload(payload("gamesense", { note: "C:\\Users\\Peter\\Desktop" }), "gamesense").ok).toBe(false);
  });
  it("a harmless key that only contains a word like author is fine", () => {
    expect(validatePayload(payload("gamesense", { author: "me", tokens_used: 3, passwordless: false }), "gamesense").ok).toBe(true);
  });
  it("refuses code in a config", () => {
    expect(validatePayload(payload("gamesense", { x: "os.execute('rm')" }), "gamesense").ok).toBe(false);
    expect(validatePayload(payload("gamesense", { x: "function() end" }), "gamesense").ok).toBe(false);
    expect(validatePayload(payload("gamesense", { x: "loadstring(a)()" }), "gamesense").ok).toBe(false);
  });
  it("refuses too big, too deep and prototype keys", () => {
    expect(validatePayload({ meta: payload().meta, data: "a".repeat(300 * 1024) }, "gamesense").ok).toBe(false);
    let deep: unknown = 1;
    for (let i = 0; i < 30; i++) deep = { a: deep };
    expect(validatePayload({ meta: payload().meta, data: deep }, "gamesense").ok).toBe(false);
    expect(validatePayload({ meta: payload().meta, data: JSON.parse('{"__proto__": {"x": 1}}') }, "gamesense").ok).toBe(false);
  });
});

describe("compat", () => {
  const target = { id: "gamesense", min_format: 2, max_format: 3, latest_version: "1.5.0" };
  it("wrong product is incompatible", () => {
    expect(checkCompat({ product: "primordial", format_version: 2, lua_version: "1.5.0" }, target)).toMatchObject({ ok: false, reason: "wrong_product" });
  });
  it("a format outside the supported range is incompatible", () => {
    expect(checkCompat({ product: "gamesense", format_version: 1, lua_version: "1.0.0" }, target)).toMatchObject({ ok: false, reason: "format_too_old" });
    expect(checkCompat({ product: "gamesense", format_version: 4, lua_version: "1.9.0" }, target)).toMatchObject({ ok: false, reason: "format_too_new" });
  });
  it("an older Lua version only makes it outdated", () => {
    expect(checkCompat({ product: "gamesense", format_version: 2, lua_version: "1.4.9" }, target)).toEqual({ ok: true, reason: null, outdated: true });
    expect(checkCompat({ product: "gamesense", format_version: 3, lua_version: "1.5.0" }, target)).toEqual({ ok: true, reason: null, outdated: false });
  });
  it("compares versions numerically", () => {
    expect(compareVersions("1.10.0", "1.9.0")).toBe(1);
    expect(compareVersions("1.4", "1.4.0")).toBe(0);
    expect(compareVersions("0.9", "1.0")).toBe(-1);
  });
});

describe("text cleaning", () => {
  it("cleans control characters and limits", () => {
    expect(cleanText("  a\u0000b\u202ec  ", 10)).toBe("a b c");
    expect(cleanText("x".repeat(100), 5)).toBe("xxxxx");
    expect(cleanTags(["Legit AA", "legit aa", "<script>", "ok_tag", "", "x".repeat(40)])).toEqual(["legit aa", "script", "ok_tag", "x".repeat(24)]);
  });
});

describe("config store", () => {
  beforeEach(resetDb);
  afterAll(done);

  it("creates a config with a first version and a share slug", async () => {
    const u = await mkUser("owner");
    const c = await createConfig({ ownerId: u.id, productId: "gamesense", name: "My legit", description: "hello", tags: ["legit"], payload: payload() });
    expect(c.slug).toMatch(/^[0-9a-hjkmnp-tv-z]{10}$/);
    const got = await getConfigBySlug(c.slug, null);
    expect(got).toMatchObject({ name: "My legit", product_id: "gamesense", latest_version: 1, lua_version: "1.4.0", owner_name: "owner" });
  });

  it("a config of the other Lua cannot be uploaded", async () => {
    const u = await mkUser();
    await expect(createConfig({ ownerId: u.id, productId: "primordial", name: "x1", payload: payload("gamesense") })).rejects.toMatchObject({ status: 422, code: "invalid_config" });
  });

  it("a new version keeps the old ones and only the owner may add one", async () => {
    const u = await mkUser();
    const other = await mkUser();
    const c = await createConfig({ ownerId: u.id, productId: "gamesense", name: "Cfg", payload: payload() });
    await expect(addVersion(c.id, other.id, payload())).rejects.toMatchObject({ status: 404 });
    expect(await addVersion(c.id, u.id, payload("gamesense", { x: 1 }), "tweaks")).toEqual({ version: 2 });
    expect((await getVersionPayload(c.id))!.version).toBe(2);
    expect((await getVersionPayload(c.id, 1))!.version).toBe(1);
    await expect(addVersion(c.id, u.id, payload("primordial"))).rejects.toMatchObject({ code: "invalid_config" });
  });

  it("visibility: public and unlisted are viewable by link, private only by the owner, hidden only by owner and admin", async () => {
    const owner = await mkUser();
    const stranger = await mkUser();
    const admin = await mkUser("adm", { admin: true });
    const pub = await createConfig({ ownerId: owner.id, productId: "gamesense", name: "Pub", visibility: "public", payload: payload() });
    const unl = await createConfig({ ownerId: owner.id, productId: "gamesense", name: "Unl", visibility: "unlisted", payload: payload() });
    const priv = await createConfig({ ownerId: owner.id, productId: "gamesense", name: "Priv", visibility: "private", payload: payload() });
    const s = { id: stranger.id, isAdmin: false };
    expect(await getConfigBySlug(pub.slug, s)).not.toBeNull();
    expect(await getConfigBySlug(unl.slug, null)).not.toBeNull();
    expect(await getConfigBySlug(priv.slug, s)).toBeNull();
    expect(await getConfigBySlug(priv.slug, { id: owner.id, isAdmin: false })).not.toBeNull();
    await query("update configs set hidden = true where id = $1", [pub.id]);
    expect(await getConfigBySlug(pub.slug, s)).toBeNull();
    expect(await getConfigBySlug(pub.slug, { id: admin.id, isAdmin: true })).not.toBeNull();
    expect(canView({ owner_id: owner.id, visibility: "public", hidden: false }, null)).toBe(true);
  });

  it("the catalog lists only public configs of the asked Lua", async () => {
    const u = await mkUser();
    await createConfig({ ownerId: u.id, productId: "gamesense", name: "GS one", visibility: "public", payload: payload() });
    await createConfig({ ownerId: u.id, productId: "gamesense", name: "GS unlisted", visibility: "unlisted", payload: payload() });
    await createConfig({ ownerId: u.id, productId: "gamesense", name: "GS private", visibility: "private", payload: payload() });
    await createConfig({ ownerId: u.id, productId: "primordial", name: "PM one", visibility: "public", payload: payload("primordial") });
    const gs = await listConfigs({ productId: "gamesense" });
    expect(gs.items.map((i) => i.name)).toEqual(["GS one"]);
    expect(gs.total).toBe(1);
    const pm = await listConfigs({ productId: "primordial" });
    expect(pm.items.map((i) => i.name)).toEqual(["PM one"]);
    const own = await listConfigs({ ownerId: u.id, includeOwn: true });
    expect(own.total).toBe(4);
  });

  it("search, tag filter, sorts", async () => {
    const u = await mkUser();
    const a = await createConfig({ ownerId: u.id, productId: "gamesense", name: "Alpha rage", tags: ["rage"], payload: payload() });
    const b = await createConfig({ ownerId: u.id, productId: "gamesense", name: "Beta legit", tags: ["legit"], payload: payload() });
    await query("update configs set likes_count = 5, is_featured = true where id = $1", [b.id]);
    expect((await listConfigs({ productId: "gamesense", q: "alpha" })).items.map((i) => i.id)).toEqual([a.id]);
    expect((await listConfigs({ productId: "gamesense", tag: "legit" })).items.map((i) => i.id)).toEqual([b.id]);
    expect((await listConfigs({ productId: "gamesense", sort: "popular" })).items[0].id).toBe(b.id);
    expect((await listConfigs({ productId: "gamesense", featuredOnly: true })).items).toHaveLength(1);
    expect((await listConfigs({ productId: "gamesense", q: "100%_" })).items).toHaveLength(0);
    expect((await listConfigs({ productId: "gamesense", luaVersion: "1.4.0" })).total).toBe(2);
  });

  it("likes toggle and the counter follows", async () => {
    const u = await mkUser();
    const v = await mkUser();
    const c = await createConfig({ ownerId: u.id, productId: "gamesense", name: "Likeme", payload: payload() });
    expect(await toggleLike(v.id, c.id)).toEqual({ liked: true, likes: 1 });
    expect(await toggleLike(u.id, c.id)).toEqual({ liked: true, likes: 2 });
    expect(await toggleLike(v.id, c.id)).toEqual({ liked: false, likes: 1 });
  });

  it("downloads and imports count once per user and day", async () => {
    const u = await mkUser();
    const v = await mkUser();
    const c = await createConfig({ ownerId: u.id, productId: "gamesense", name: "Count", payload: payload() });
    expect(await recordEvent(c.id, v.id, "download")).toBe(true);
    expect(await recordEvent(c.id, v.id, "download")).toBe(false);
    expect(await recordEvent(c.id, v.id, "import_code")).toBe(true);
    const row = (await getConfigBySlug(c.slug, null))!;
    expect(row.downloads_count).toBe(1);
    expect(row.imports_count).toBe(1);
  });

  it("the library flags a newer version", async () => {
    const u = await mkUser();
    const v = await mkUser();
    const c = await createConfig({ ownerId: u.id, productId: "gamesense", name: "Lib", payload: payload() });
    await saveToLibrary(v.id, c.id);
    expect((await libraryOf(v.id))[0]).toMatchObject({ saved_version: 1, update_available: false });
    await addVersion(c.id, u.id, payload("gamesense", { y: 2 }));
    expect((await libraryOf(v.id))[0]).toMatchObject({ saved_version: 1, update_available: true });
    await saveToLibrary(v.id, c.id);
    expect((await libraryOf(v.id))[0].update_available).toBe(false);
    await updateConfigMeta(c.id, u.id, { visibility: "private" });
    expect(await libraryOf(v.id)).toHaveLength(0);
    await removeFromLibrary(v.id, c.id);
  });

  it("compat of a stored version follows the product settings", async () => {
    const u = await mkUser();
    const c = await createConfig({ ownerId: u.id, productId: "gamesense", name: "Compat", payload: payload() });
    await query("update products set min_format = 2, max_format = 3, latest_version = '1.5.0' where id = 'gamesense'");
    expect(await compatFor(c.id, 1)).toMatchObject({ ok: false, reason: "format_too_old" });
    await query("update products set min_format = 1, max_format = 1 where id = 'gamesense'");
    expect(await compatFor(c.id, 1)).toMatchObject({ ok: true, outdated: true });
  });

  it("upload quota per day", async () => {
    const u = await mkUser();
    for (let i = 0; i < 20; i++) await createConfig({ ownerId: u.id, productId: "gamesense", name: `cfg ${i}`, payload: payload() });
    await expect(createConfig({ ownerId: u.id, productId: "gamesense", name: "one too many", payload: payload() })).rejects.toMatchObject({ status: 429, code: "upload_quota" });
  });

  it("images: only real PNG / JPEG / WebP, size and count limited, owner only", async () => {
    const u = await mkUser();
    const other = await mkUser();
    const c = await createConfig({ ownerId: u.id, productId: "gamesense", name: "Imgs", payload: payload() });
    const png = Buffer.concat([Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]), Buffer.alloc(32)]);
    await expect(addConfigImage(c.id, u.id, "image/png", Buffer.from("<script>alert(1)</script>"))).rejects.toMatchObject({ code: "bad_image" });
    await expect(addConfigImage(c.id, u.id, "image/svg+xml", png)).rejects.toMatchObject({ code: "bad_image" });
    await expect(addConfigImage(c.id, other.id, "image/png", png)).rejects.toMatchObject({ status: 404 });
    await expect(addConfigImage(c.id, u.id, "image/png", Buffer.concat([png, Buffer.alloc(3 * 1024 * 1024)]))).rejects.toMatchObject({ code: "image_too_big" });
    for (let i = 0; i < 4; i++) await addConfigImage(c.id, u.id, "image/png", png);
    await expect(addConfigImage(c.id, u.id, "image/png", png)).rejects.toMatchObject({ code: "too_many_images" });
  });

  it("a report is stored once per reporter", async () => {
    const u = await mkUser();
    const v = await mkUser();
    const c = await createConfig({ ownerId: u.id, productId: "gamesense", name: "Rep", payload: payload() });
    await reportConfig(v.id, c.id, "spam", "x");
    await reportConfig(v.id, c.id, "other", "y");
    const rows = await query("select * from config_reports");
    expect(rows).toHaveLength(1);
    await expect(reportConfig(v.id, c.id, "  ", "")).rejects.toBeInstanceOf(ApiError);
  });
});
