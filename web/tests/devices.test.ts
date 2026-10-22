import { afterAll, beforeEach, describe, expect, it } from "vitest";
import { authenticateToken, decideDevice, listDevices, lookupUserCode, pollDevice, revokeDevice, startDeviceFlow } from "@/lib/devices";
import { query } from "@/lib/db";
import { done, mkUser, resetDb } from "./helpers";

const t0 = new Date("2026-10-22T12:00:00Z");
const plus = (s: number) => new Date(t0.getTime() + s * 1000);

describe("device link", () => {
  beforeEach(resetDb);
  afterAll(done);

  it("the full flow: start, approve, poll once, use the token", async () => {
    const u = await mkUser();
    const f = await startDeviceFlow("gamesense", "Specter menu", t0);
    expect(f.userCode).toMatch(/^[A-Z2-9]{4}-[A-Z2-9]{4}$/);
    expect(await pollDevice(f.deviceCode, plus(1))).toEqual({ status: "pending" });
    expect(await lookupUserCode(f.userCode, plus(2))).toMatchObject({ product_id: "gamesense", client_name: "Specter menu" });
    await decideDevice(f.userCode.toLowerCase().replace("-", " "), u.id, true, plus(3));
    const r = await pollDevice(f.deviceCode, plus(10));
    expect(r.status).toBe("approved");
    if (r.status !== "approved") return;
    expect(r.token.startsWith("spt_")).toBe(true);
    expect(r.productId).toBe("gamesense");
    expect(await pollDevice(f.deviceCode, plus(20))).toEqual({ status: "invalid" }); // used up
    const auth = await authenticateToken(r.token, plus(30));
    expect(auth).toMatchObject({ userId: u.id, productId: "gamesense" });
    expect(auth!.scopes).toContain("configs:write");
  });

  it("only the hash of the token is stored", async () => {
    const u = await mkUser();
    const f = await startDeviceFlow("primordial", "x", t0);
    await decideDevice(f.userCode, u.id, true, t0);
    const r = await pollDevice(f.deviceCode, plus(10));
    if (r.status !== "approved") throw new Error("not approved");
    const rows = await query<{ token_hash: string }>("select token_hash from client_tokens");
    expect(rows[0].token_hash).not.toContain(r.token);
    const codes = await query<{ device_code_hash: string }>("select device_code_hash from device_codes");
    expect(codes[0].device_code_hash).not.toContain(f.deviceCode);
  });

  it("a denied code never gives a token", async () => {
    const u = await mkUser();
    const f = await startDeviceFlow("gamesense", "x", t0);
    await decideDevice(f.userCode, u.id, false, t0);
    expect(await pollDevice(f.deviceCode, plus(10))).toEqual({ status: "denied" });
  });

  it("an expired code cannot be approved or polled", async () => {
    const u = await mkUser();
    const f = await startDeviceFlow("gamesense", "x", t0);
    await expect(decideDevice(f.userCode, u.id, true, plus(601))).rejects.toMatchObject({ status: 404 });
    expect(await pollDevice(f.deviceCode, plus(601))).toEqual({ status: "expired" });
    expect(await lookupUserCode(f.userCode, plus(601))).toBeNull();
  });

  it("a wrong code or a code used twice is refused", async () => {
    const u = await mkUser();
    const v = await mkUser();
    const f = await startDeviceFlow("gamesense", "x", t0);
    await expect(decideDevice("nope", u.id, true, t0)).rejects.toMatchObject({ code: "bad_code" });
    await expect(decideDevice("AAAA-AAAA", u.id, true, t0)).rejects.toMatchObject({ status: 404 });
    await decideDevice(f.userCode, u.id, true, t0);
    await expect(decideDevice(f.userCode, v.id, true, t0)).rejects.toMatchObject({ status: 404 }); // cannot be taken over
  });

  it("polling too fast is told to slow down", async () => {
    const f = await startDeviceFlow("gamesense", "x", t0);
    expect(await pollDevice(f.deviceCode, plus(1))).toEqual({ status: "pending" });
    expect(await pollDevice(f.deviceCode, plus(2))).toEqual({ status: "slow_down" });
  });

  it("garbage device codes are invalid", async () => {
    expect(await pollDevice("nope")).toEqual({ status: "invalid" });
    expect(await pollDevice("spd_" + "x".repeat(40))).toEqual({ status: "invalid" });
  });

  it("a revoked, expired or suspended-user token stops working", async () => {
    const u = await mkUser();
    const f = await startDeviceFlow("gamesense", "Laptop", t0);
    await decideDevice(f.userCode, u.id, true, t0);
    const r = await pollDevice(f.deviceCode, plus(10));
    if (r.status !== "approved") throw new Error("x");
    expect(await listDevices(u.id)).toHaveLength(1);
    expect(await authenticateToken(r.token, plus(60))).not.toBeNull();
    expect(await authenticateToken(r.token, new Date(t0.getTime() + 91 * 86_400_000))).toBeNull();
    await query("update users set suspended = true where id = $1", [u.id]);
    expect(await authenticateToken(r.token, plus(60))).toBeNull();
    await query("update users set suspended = false where id = $1", [u.id]);
    const [dev] = await listDevices(u.id);
    await revokeDevice(u.id, dev.id);
    expect(await authenticateToken(r.token, plus(60))).toBeNull();
    expect(await listDevices(u.id)).toHaveLength(0);
  });

  it("a user cannot revoke the token of another user", async () => {
    const u = await mkUser();
    const v = await mkUser();
    const f = await startDeviceFlow("gamesense", "x", t0);
    await decideDevice(f.userCode, u.id, true, t0);
    await pollDevice(f.deviceCode, plus(10));
    const [dev] = await listDevices(u.id);
    await expect(revokeDevice(v.id, dev.id)).rejects.toMatchObject({ status: 404 });
  });

  it("tokens of a wrong shape are not accepted", async () => {
    expect(await authenticateToken(null)).toBeNull();
    expect(await authenticateToken("Bearer x")).toBeNull();
    expect(await authenticateToken("spt_notreal")).toBeNull();
  });
});
