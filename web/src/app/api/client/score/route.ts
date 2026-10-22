import { z } from "zod";
import { requireProductAccess, requireToken } from "@/lib/authz";
import { ingestScore } from "@/lib/leaderboard";
import { api, body, json } from "@/lib/http";
import { rateLimit } from "@/lib/rate-limit";

export const dynamic = "force-dynamic";

const schema = z.object({ event_type: z.string().regex(/^[a-z0-9_]{1,40}$/), dedupe_key: z.string().regex(/^[\w:.-]{1,80}$/) });

// The Lua reports that something happened. The points come from the admin rules, and nothing is counted while point
// collection is switched off (the default).
export const POST = api(async (req) => {
  const auth = await requireToken(req, "score:write");
  await rateLimit(`score:${auth.userId}`, 120, 60);
  await requireProductAccess(auth.userId, auth.productId);
  const input = await body(req, schema, 1024);
  const r = await ingestScore({ boardId: auth.productId, userId: auth.userId, eventType: input.event_type, dedupeKey: input.dedupe_key });
  return json(r.accepted ? { accepted: true, points: r.points } : { accepted: false, reason: r.reason }, r.accepted || r.reason === "duplicate" ? 200 : 202);
});
