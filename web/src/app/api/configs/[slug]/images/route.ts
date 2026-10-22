import { assertSameOrigin, requireUser } from "@/lib/authz";
import { ApiError, addConfigImage } from "@/lib/configs";
import { api, json } from "@/lib/http";
import { loadVisible } from "@/lib/config-api";
import { LIMITS } from "@/config/site";
import { rateLimit } from "@/lib/rate-limit";

export const dynamic = "force-dynamic";

// The image is sent as the raw request body (Content-Type: image/png | image/jpeg | image/webp).
export const POST = api<{ slug: string }>(async (req, { params }) => {
  assertSameOrigin(req);
  const user = await requireUser();
  await rateLimit(`img:${user.id}`, 30, 3600);
  const cfg = await loadVisible(params.slug, { id: user.id, isAdmin: false });
  if (cfg.owner_id !== user.id) throw new ApiError(404, "not_found", "Config not found.");
  const len = Number(req.headers.get("content-length") ?? 0);
  if (len > LIMITS.imageBytes + 1024) throw new ApiError(413, "image_too_big", "The image is too large.");
  const type = (req.headers.get("content-type") ?? "").split(";")[0].trim().toLowerCase();
  const bytes = Buffer.from(await req.arrayBuffer());
  const id = await addConfigImage(cfg.id, user.id, type, bytes);
  return json({ url: `/api/media/${id}` }, 201);
});
