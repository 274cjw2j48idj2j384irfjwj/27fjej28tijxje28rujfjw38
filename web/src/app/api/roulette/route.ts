import { z } from "zod";
import { assertSameOrigin, requireUser } from "@/lib/authz";
import { api, body, json } from "@/lib/http";
import { ApiError } from "@/lib/configs";
import { rateLimit } from "@/lib/rate-limit";
import { PRIZES, rouletteState, spin } from "@/lib/roulette";

export const dynamic = "force-dynamic";

const schema = z.object({ lua: z.enum(["gamesense", "primordial"]).optional() });

// Odds, the state of the signed in user (next spin, history).
export const GET = api(async () => {
  const user = await requireUser();
  return json({ prizes: PRIZES.map((p) => ({ id: p.id, label: p.label, chance: p.weight / 100 })), ...(await rouletteState(user.id)) });
});

// The spin. The prize is rolled here, never by the browser; one spin per user per 7 days.
export const POST = api(async (req) => {
  assertSameOrigin(req);
  const user = await requireUser();
  if (user.suspended) throw new ApiError(403, "suspended", "This account is suspended.");
  const input = await body(req, schema, 1024);
  await rateLimit(`roulette:user:${user.id}`, 20, 600);
  return json({ spin: await spin(user.id, user.discord_id, input.lua ?? null) });
});
