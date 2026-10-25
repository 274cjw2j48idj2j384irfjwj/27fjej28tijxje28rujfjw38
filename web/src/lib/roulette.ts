import { randomInt } from "node:crypto";
import { one, query, tx } from "./db";
import { ApiError } from "./configs";
import { audit, notify } from "./audit";
import { extendLicense, LicenseServerError, licensesOfDiscord, maskKey, type LicenseOfDiscord } from "./license-server";

export type PrizeId = "nothing" | "5h" | "12h" | "1d" | "7d" | "14d" | "30d";
export type Prize = { id: PrizeId; label: string; hours: number; weight: number };

// Odds in basis points (10 000 = 100 %). The 30 day prize is fixed at 1 %.
export const PRIZES: readonly Prize[] = [
  { id: "nothing", label: "Nothing", hours: 0, weight: 4000 },
  { id: "5h", label: "5 hours", hours: 5, weight: 2500 },
  { id: "12h", label: "12 hours", hours: 12, weight: 1500 },
  { id: "1d", label: "1 day", hours: 24, weight: 1000 },
  { id: "7d", label: "7 days", hours: 7 * 24, weight: 600 },
  { id: "14d", label: "14 days", hours: 14 * 24, weight: 300 },
  { id: "30d", label: "30 days", hours: 30 * 24, weight: 100 },
];
export const WEEK_MS = 7 * 86_400_000;
const TOTAL = PRIZES.reduce((n, p) => n + p.weight, 0);

export function roll(rnd: (max: number) => number = randomInt): Prize {
  let n = rnd(TOTAL);
  for (const p of PRIZES) {
    if (n < p.weight) return p;
    n -= p.weight;
  }
  return PRIZES[0];
}

type Lua = "gamesense" | "primordial";
type SpinRow = { id: string; prize: PrizeId; hours: number; lua: Lua | null; license_key: string | null; status: "pending" | "done"; new_expires_at: Date | null; created_at: Date; applied_at: Date | null };

export type SpinResult = { id: string; prize: PrizeId; label: string; hours: number; lua: Lua | null; status: "pending" | "done"; newExpiresAt: string | null; createdAt: string };

const COLS = "id, prize, hours, lua, license_key, status, new_expires_at, created_at, applied_at";

function result(r: SpinRow): SpinResult {
  const p = PRIZES.find((x) => x.id === r.prize) ?? PRIZES[0];
  return { id: r.id, prize: r.prize, label: p.label, hours: r.hours, lua: r.lua, status: r.status, newExpiresAt: r.new_expires_at ? r.new_expires_at.toISOString() : null, createdAt: r.created_at.toISOString() };
}

export type RouletteState = { nextSpinAt: string | null; canSpin: boolean; pending: SpinResult | null; history: SpinResult[] };

export async function rouletteState(userId: string, now = new Date()): Promise<RouletteState> {
  const rows = await query<SpinRow>(`select ${COLS} from roulette_spins where user_id = $1 order by created_at desc limit 12`, [userId]);
  const last = rows[0];
  const next = last ? new Date(last.created_at.getTime() + WEEK_MS) : null;
  const waiting = !!next && next > now;
  const pending = rows.find((r) => r.status === "pending");
  return { nextSpinAt: waiting ? next!.toISOString() : null, canSpin: !waiting && !pending, pending: pending ? result(pending) : null, history: rows.map(result) };
}

// A key the hours can go to: running, not revoked, not lifetime (nothing to add to).
function extendable(k: LicenseOfDiscord, now: number): boolean {
  return !k.revoked && !k.expired && typeof k.expires_at === "number" && k.expires_at > now;
}

function licenseProblem(err: unknown): never {
  if (err instanceof LicenseServerError) {
    if (err.kind === "not_configured") throw new ApiError(503, "license_unavailable", "The roulette is not available right now.");
    throw new ApiError(503, "license_unavailable", "The license server did not answer. Try again in a moment, your spin is kept.");
  }
  throw err;
}

// Pays a spin: adds the hours to its key. Safe to repeat (the spin id is the license server ref).
async function pay(userId: string, discordId: string, spin: SpinRow): Promise<SpinRow> {
  if (spin.status === "done") return spin;
  if (spin.hours === 0) {
    const done = await one<SpinRow>(`update roulette_spins set status = 'done', applied_at = now() where id = $1 and status = 'pending' returning ${COLS}`, [spin.id]);
    return done ?? spin;
  }
  let ext: { expires_at: number };
  try {
    ext = await extendLicense({ key: spin.license_key!, discordId, hours: spin.hours, ref: spin.id });
  } catch (err) {
    if (err instanceof LicenseServerError && err.kind === "rejected") {
      // The key ended / was revoked / moved between the roll and the payment: the spin stays, an admin can look at it.
      await audit(userId, "roulette.unpaid", "spin", spin.id, { key: maskKey(spin.license_key), status: err.status ?? 0 });
      throw new ApiError(409, "key_unavailable", "Your key can no longer be extended. Contact support, your prize is kept.");
    }
    return licenseProblem(err);
  }
  const done = await one<SpinRow>(
    `update roulette_spins set status = 'done', applied_at = now(), new_expires_at = to_timestamp($2 / 1000.0) where id = $1 and status = 'pending' returning ${COLS}`,
    [spin.id, ext.expires_at],
  );
  const row = done ?? { ...spin, status: "done" as const };
  const p = PRIZES.find((x) => x.id === spin.prize)!;
  if (done) {
    await audit(userId, "roulette.paid", "spin", spin.id, { prize: spin.prize, key: maskKey(spin.license_key) });
    await notify(userId, "reward", `Roulette: ${p.label} won`, `${p.label} were added to your ${spin.lua === "primordial" ? "Primordial" : "Gamesense"} key.`, "/dashboard/roulette");
  }
  return row;
}

export async function spin(userId: string, discordId: string, lua: Lua | null, now = new Date()): Promise<SpinResult> {
  // A paid-for-but-unconfirmed spin from before (the license server was down) is finished first, never rolled again.
  const open = await one<SpinRow>(`select ${COLS} from roulette_spins where user_id = $1 and status = 'pending' order by created_at limit 1`, [userId]);
  if (open) return result(await pay(userId, discordId, open));

  const state = await rouletteState(userId, now);
  if (!state.canSpin) throw new ApiError(429, "already_spun", "You already spun this week.", { nextSpinAt: state.nextSpinAt });

  let keys: LicenseOfDiscord[];
  try {
    keys = await licensesOfDiscord(discordId);
  } catch (err) {
    return licenseProblem(err);
  }
  const usable = keys.filter((k) => extendable(k, now.getTime()));
  const luas = [...new Set(usable.map((k) => k.lua))];
  if (luas.length === 0) throw new ApiError(422, "no_key", "You need a registered key that is still running (not lifetime). Use /register in Discord first.");
  if (!lua && luas.length > 1) throw new ApiError(422, "choose_lua", "Choose which Lua the prize goes to.", { options: luas });
  const target = lua ?? luas[0];
  const key = usable.filter((k) => k.lua === target).sort((a, b) => (b.expires_at ?? 0) - (a.expires_at ?? 0))[0];
  if (!key) throw new ApiError(422, "no_key", "You have no running key for that Lua.");

  const prize = roll();
  const row = await tx(async (db) => {
    await db.query("select pg_advisory_xact_lock(hashtext($1))", [`roulette:${userId}`]);
    const last = await one<{ created_at: Date }>("select created_at from roulette_spins where user_id = $1 order by created_at desc limit 1", [userId], db);
    if (last && last.created_at.getTime() + WEEK_MS > now.getTime()) throw new ApiError(429, "already_spun", "You already spun this week.", { nextSpinAt: new Date(last.created_at.getTime() + WEEK_MS).toISOString() });
    const r = await one<SpinRow>(
      `insert into roulette_spins (user_id, prize, hours, lua, license_key, created_at) values ($1,$2,$3,$4,$5,$6) returning ${COLS}`,
      [userId, prize.id, prize.hours, prize.hours ? target : null, prize.hours ? key.key : null, now],
      db,
    );
    await audit(userId, "roulette.spin", "spin", r!.id, { prize: prize.id }, db);
    return r!;
  });
  return result(await pay(userId, discordId, row));
}
