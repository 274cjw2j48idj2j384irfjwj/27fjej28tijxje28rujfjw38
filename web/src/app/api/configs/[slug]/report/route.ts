import { z } from "zod";
import { assertSameOrigin, isAdmin, requireUser } from "@/lib/authz";
import { reportConfig } from "@/lib/configs";
import { api, body, json } from "@/lib/http";
import { loadVisible } from "@/lib/config-api";
import { rateLimit } from "@/lib/rate-limit";

export const dynamic = "force-dynamic";

const schema = z.object({ reason: z.string().min(1).max(60), details: z.string().max(500).optional() });

export const POST = api<{ slug: string }>(async (req, { params }) => {
  assertSameOrigin(req);
  const user = await requireUser();
  await rateLimit(`report:${user.id}`, 20, 3600);
  const cfg = await loadVisible(params.slug, { id: user.id, isAdmin: isAdmin(user) });
  const input = await body(req, schema);
  await reportConfig(user.id, cfg.id, input.reason, input.details ?? "");
  return json({ reported: true });
});
