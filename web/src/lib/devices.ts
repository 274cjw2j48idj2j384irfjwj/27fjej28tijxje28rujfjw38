import { LIMITS, type ProductId } from "@/config/site";
import { one, query, tx } from "./db";
import { normalizeUserCode, randomToken, sha256, userCode } from "./crypto";
import { ApiError } from "./configs";

export const CLIENT_SCOPES = ["configs:read", "configs:write", "library:read", "score:write"] as const;
export type ClientScope = (typeof CLIENT_SCOPES)[number];

export const POLL_INTERVAL_SEC = 5;

export async function startDeviceFlow(productId: ProductId, clientName: string, now = new Date()): Promise<{ deviceCode: string; userCode: string; expiresIn: number; interval: number }> {
  const deviceCode = randomToken("spd_");
  const code = userCode();
  const name = clientName.replace(/[^\w .-]/g, "").slice(0, 40);
  await query(
    `insert into device_codes (device_code_hash, user_code, product_id, client_name, expires_at) values ($1,$2,$3,$4,$5)`,
    [sha256(deviceCode), code, productId, name, new Date(now.getTime() + LIMITS.deviceCodeTtlSec * 1000)],
  );
  return { deviceCode, userCode: code, expiresIn: LIMITS.deviceCodeTtlSec, interval: POLL_INTERVAL_SEC };
}

export type PendingDevice = { product_id: ProductId; client_name: string; expires_at: Date };

export async function lookupUserCode(input: string, now = new Date()): Promise<PendingDevice | null> {
  const code = normalizeUserCode(input);
  if (!code) return null;
  return one<PendingDevice>("select product_id, client_name, expires_at from device_codes where user_code = $1 and status = 'pending' and expires_at > $2", [code, now]);
}

export async function decideDevice(input: string, userId: string, approve: boolean, now = new Date()): Promise<PendingDevice> {
  const code = normalizeUserCode(input);
  if (!code) throw new ApiError(400, "bad_code", "That code does not look right.");
  const row = await one<PendingDevice>(
    `update device_codes set status = $3, user_id = $2 where user_code = $1 and status = 'pending' and expires_at > $4
     returning product_id, client_name, expires_at`,
    [code, userId, approve ? "approved" : "denied", now],
  );
  if (!row) throw new ApiError(404, "code_not_found", "The code is wrong, used or expired.");
  return row;
}

export type PollResult =
  | { status: "pending" | "slow_down" | "denied" | "expired" | "invalid" }
  | { status: "approved"; token: string; scopes: ClientScope[]; productId: ProductId; expiresAt: Date };

// The Lua polls with its secret device code. The token is handed over once, the code is used up with it.
export async function pollDevice(deviceCode: string, now = new Date()): Promise<PollResult> {
  if (!deviceCode.startsWith("spd_")) return { status: "invalid" };
  return tx(async (db) => {
    const row = await one<{ id: string; status: string; user_id: string | null; product_id: ProductId; expires_at: Date; last_polled_at: Date | null; client_name: string }>(
      "select id, status, user_id, product_id, expires_at, last_polled_at, client_name from device_codes where device_code_hash = $1 for update",
      [sha256(deviceCode)],
      db,
    );
    if (!row || row.status === "consumed") return { status: "invalid" } as PollResult;
    if (row.expires_at <= now) return { status: "expired" } as PollResult;
    if (row.last_polled_at && now.getTime() - row.last_polled_at.getTime() < (POLL_INTERVAL_SEC - 1) * 1000) return { status: "slow_down" } as PollResult;
    await query("update device_codes set last_polled_at = $2 where id = $1", [row.id, now], db);
    if (row.status === "pending") return { status: "pending" } as PollResult;
    if (row.status === "denied") return { status: "denied" } as PollResult;

    const token = randomToken("spt_");
    const expiresAt = new Date(now.getTime() + LIMITS.deviceTokenTtlDays * 86_400_000);
    const scopes: ClientScope[] = [...CLIENT_SCOPES];
    await query(
      `insert into client_tokens (user_id, product_id, token_hash, scopes, name, expires_at) values ($1,$2,$3,$4,$5,$6)`,
      [row.user_id, row.product_id, sha256(token), scopes, row.client_name, expiresAt],
      db,
    );
    await query("update device_codes set status = 'consumed' where id = $1", [row.id], db);
    return { status: "approved", token, scopes, productId: row.product_id, expiresAt } as PollResult;
  });
}

export type TokenAuth = { tokenId: string; userId: string; productId: ProductId; scopes: ClientScope[] };

export async function authenticateToken(raw: string | null | undefined, now = new Date()): Promise<TokenAuth | null> {
  if (!raw || !raw.startsWith("spt_")) return null;
  const row = await one<{ id: string; user_id: string; product_id: ProductId; scopes: ClientScope[]; last_used_at: Date | null; suspended: boolean }>(
    `select t.id, t.user_id, t.product_id, t.scopes, t.last_used_at, u.suspended from client_tokens t join users u on u.id = t.user_id
      where t.token_hash = $1 and t.revoked_at is null and t.expires_at > $2`,
    [sha256(raw), now],
  );
  if (!row || row.suspended) return null;
  if (!row.last_used_at || now.getTime() - row.last_used_at.getTime() > 60_000) await query("update client_tokens set last_used_at = $2 where id = $1", [row.id, now]);
  return { tokenId: row.id, userId: row.user_id, productId: row.product_id, scopes: row.scopes };
}

export type DeviceRow = { id: string; product_id: ProductId; name: string; created_at: Date; last_used_at: Date | null; expires_at: Date };

export async function listDevices(userId: string): Promise<DeviceRow[]> {
  return query<DeviceRow>(
    "select id, product_id, name, created_at, last_used_at, expires_at from client_tokens where user_id = $1 and revoked_at is null and expires_at > now() order by created_at desc",
    [userId],
  );
}

export async function revokeDevice(userId: string, tokenId: string): Promise<void> {
  const r = await query("update client_tokens set revoked_at = now() where id = $1 and user_id = $2 and revoked_at is null returning id", [tokenId, userId]);
  if (!r.length) throw new ApiError(404, "not_found", "Device not found.");
}
