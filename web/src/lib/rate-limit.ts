import { one } from "./db";
import { ApiError } from "./configs";

// Fixed window counter in the database, so every server instance shares it.
export async function rateLimit(key: string, limit: number, windowSec: number, now = new Date()): Promise<void> {
  const start = new Date(Math.floor(now.getTime() / (windowSec * 1000)) * windowSec * 1000);
  const row = await one<{ count: number }>(
    `insert into rate_limits (key, window_start, count) values ($1,$2,1)
     on conflict (key, window_start) do update set count = rate_limits.count + 1 returning count`,
    [key, start],
  );
  if (row && row.count > limit) throw new ApiError(429, "rate_limited", "Too many requests, try again in a moment.");
}

export async function purgeRateLimits(): Promise<void> {
  await one("delete from rate_limits where window_start < now() - interval '1 day'");
}

export function clientIp(headers: Headers): string {
  return headers.get("x-real-ip") || headers.get("x-forwarded-for")?.split(",")[0]?.trim() || "unknown";
}
