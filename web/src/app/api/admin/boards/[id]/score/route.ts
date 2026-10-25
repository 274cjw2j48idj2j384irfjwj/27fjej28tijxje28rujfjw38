import { z } from "zod";
import { adminOnly } from "@/lib/admin-http";
import { manualScore } from "@/lib/leaderboard";
import { audit } from "@/lib/audit";
import { api, body, json } from "@/lib/http";

export const dynamic = "force-dynamic";

const schema = z.object({ user_id: z.string().uuid(), points: z.number().int(), reason: z.string().min(1).max(200) });

export const POST = api<{ id: string }>(async (req, { params }) => {
  const admin = await adminOnly(req);
  const input = await body(req, schema, 2048);
  await manualScore({ boardId: params.id, userId: input.user_id, points: input.points, reason: input.reason, actorId: admin.id });
  await audit(admin.id, "score.manual", "board", params.id, { user: input.user_id, points: input.points, reason: input.reason });
  return json({ ok: true }, 201);
});
