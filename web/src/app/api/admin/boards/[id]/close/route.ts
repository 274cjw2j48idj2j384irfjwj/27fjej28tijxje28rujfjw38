import { z } from "zod";
import { adminOnly } from "@/lib/admin-http";
import { closePeriod } from "@/lib/leaderboard";
import { api, body, json } from "@/lib/http";

export const dynamic = "force-dynamic";

// A finished month can be closed by hand (the cron does it by itself). Closing twice does nothing the second time.
export const POST = api<{ id: string }>(async (req, { params }) => {
  await adminOnly(req);
  const input = await body(req, z.object({ period: z.string() }), 1024);
  return json(await closePeriod(params.id, input.period));
});
