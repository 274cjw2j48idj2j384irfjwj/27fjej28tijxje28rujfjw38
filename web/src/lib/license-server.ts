// The only place that talks to the license server (create / revoke a key). Secrets come from the environment.

export type LicenseErrorKind = "not_configured" | "timeout" | "network" | "busy" | "rejected" | "server";

export class LicenseServerError extends Error {
  constructor(public kind: LicenseErrorKind, message: string, public status?: number) {
    super(message);
  }
}

export type LicenseCreate = { key: string; plan: string; expires_at: number | string | null; note: string; existing?: boolean };

const TIMEOUT_MS = 10_000;

export function licenseServerConfigured(): boolean {
  return !!(process.env.LICENSE_SERVER_URL?.trim() && process.env.LICENSE_ADMIN_SECRET?.trim());
}

async function call(path: string, payload: unknown, method: "POST" | "GET" = "POST"): Promise<unknown> {
  const base = (process.env.LICENSE_SERVER_URL ?? "").trim().replace(/\/+$/, "");
  const secret = process.env.LICENSE_ADMIN_SECRET ?? "";
  if (!base || !secret.trim()) throw new LicenseServerError("not_configured", "The license server is not configured.");
  const ctl = new AbortController();
  const timer = setTimeout(() => ctl.abort(), TIMEOUT_MS);
  let res: Response;
  try {
    res = await fetch(`${base}${path}`, {
      method,
      headers: { "content-type": "application/json", "x-admin-secret": secret },
      body: method === "POST" ? JSON.stringify(payload) : undefined,
      signal: ctl.signal,
      cache: "no-store",
    });
  } catch (err) {
    if ((err as Error)?.name === "AbortError") throw new LicenseServerError("timeout", "The license server did not answer in time.");
    throw new LicenseServerError("network", "The license server could not be reached.");
  } finally {
    clearTimeout(timer);
  }
  let data: unknown = null;
  try {
    data = await res.json();
  } catch {
    /* no json body */
  }
  if (res.status === 409 && (data as { error?: string } | null)?.error === "busy") throw new LicenseServerError("busy", "The license server is busy with this order.", 409);
  if (!res.ok) {
    const msg = (data as { error?: string } | null)?.error;
    throw new LicenseServerError(res.status >= 500 ? "server" : "rejected", `The license server answered ${res.status}${msg ? `: ${String(msg).slice(0, 120)}` : ""}.`, res.status);
  }
  return data;
}

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

// `ref` makes the call idempotent: the same ref always gives the same key. A "busy" answer (another call with that ref runs) is retried a few times.
export async function createLicense(input: { plan: string; duration: string; note: string; ref: string }, opts: { busyRetries?: number; busyDelayMs?: number } = {}): Promise<LicenseCreate> {
  const retries = opts.busyRetries ?? 4;
  for (let i = 0; ; i++) {
    try {
      const data = (await call("/admin/create", input)) as Partial<LicenseCreate> | null;
      if (!data || typeof data.key !== "string" || !data.key) throw new LicenseServerError("server", "The license server answered without a key.");
      return data as LicenseCreate;
    } catch (err) {
      if (err instanceof LicenseServerError && err.kind === "busy" && i < retries) {
        await sleep(opts.busyDelayMs ?? 300 * (i + 1));
        continue;
      }
      throw err;
    }
  }
}

export async function revokeLicense(key: string): Promise<void> {
  await call("/admin/revoke", { key });
}

export type LicenseOfDiscord = { key: string; plan: string; lua: "gamesense" | "primordial"; expires_at: number | null; expired: boolean; revoked: boolean };

// The keys registered to one Discord account (the bot's /register binds them).
export async function licensesOfDiscord(discordId: string): Promise<LicenseOfDiscord[]> {
  const data = await call(`/admin/by_discord?discord_id=${encodeURIComponent(discordId)}`, null, "GET");
  if (!Array.isArray(data)) throw new LicenseServerError("server", "The license server answered with something unexpected.");
  return data as LicenseOfDiscord[];
}

// Adds hours to a running key; the same `ref` is never paid twice.
export async function extendLicense(input: { key: string; discordId: string; hours: number; ref: string }): Promise<{ expires_at: number; already: boolean }> {
  const data = (await call("/admin/extend", { key: input.key, discord_id: input.discordId, hours: input.hours, ref: input.ref })) as { expires_at?: number; already?: boolean } | null;
  if (!data || typeof data.expires_at !== "number") throw new LicenseServerError("server", "The license server answered without an expiry.");
  return { expires_at: data.expires_at, already: !!data.already };
}

// Never log a whole key.
export function maskKey(key: string | null | undefined): string {
  return key ? `${key.slice(0, 4)}...` : "";
}
