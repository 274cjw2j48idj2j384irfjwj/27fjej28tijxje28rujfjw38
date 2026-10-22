import { closeDuePeriods } from "@/lib/leaderboard";
import { fanoutReleases, warnExpiring } from "@/lib/notices";
import { purgeRateLimits } from "@/lib/rate-limit";
import { purgeSessions } from "@/lib/sessions";
import { safeEqual } from "@/lib/crypto";
import { ApiError } from "@/lib/configs";
import { api, json } from "@/lib/http";

export const dynamic = "force-dynamic";

// Called by a scheduler (Railway cron, GitHub Actions, any cron service) with `Authorization: Bearer $CRON_SECRET`.
// Idempotent: calling it every hour is fine, a closed month is never paid twice.
export const POST = api(async (req) => {
  const secret = process.env.CRON_SECRET ?? "";
  const given = (req.headers.get("authorization") ?? "").replace(/^Bearer\s+/i, "");
  if (secret.length < 24 || !safeEqual(secret, given)) throw new ApiError(401, "unauthorized", "Bad cron secret.");
  const closed = await closeDuePeriods();
  const releaseNotices = await fanoutReleases();
  const expiryNotices = await warnExpiring();
  await purgeRateLimits();
  await purgeSessions();
  return json({ closed, releaseNotices, expiryNotices });
});
