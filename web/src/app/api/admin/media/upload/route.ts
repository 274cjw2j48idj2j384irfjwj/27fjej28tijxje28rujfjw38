import { adminOnly } from "@/lib/admin-http";
import { ApiError, IMAGE_TYPES } from "@/lib/configs";
import { audit } from "@/lib/audit";
import { tx, one } from "@/lib/db";
import { cleanText } from "@/lib/config-validate";
import { api, json } from "@/lib/http";
import { productParam } from "@/lib/config-api";
import { z } from "zod";

export const dynamic = "force-dynamic";

const MAX = 6 * 1024 * 1024;

// Product screenshots uploaded by an admin: the raw image is the request body, the rest is in the query string.
export const POST = api(async (req) => {
  const admin = await adminOnly(req);
  const sp = new URL(req.url).searchParams;
  const product = productParam.parse(sp.get("product"));
  const category = z.enum(["menu", "visuals", "configuration"]).parse(sp.get("category"));
  const caption = cleanText(sp.get("caption") ?? "", 160);
  const type = (req.headers.get("content-type") ?? "").split(";")[0].trim().toLowerCase();
  const rule = IMAGE_TYPES[type];
  if (Number(req.headers.get("content-length") ?? 0) > MAX) throw new ApiError(413, "image_too_big", "The image is too large (6 MB at most).");
  const bytes = Buffer.from(await req.arrayBuffer());
  if (!rule || !rule.magic(bytes)) throw new ApiError(415, "bad_image", "Only PNG, JPEG or WebP images are accepted.");
  if (bytes.length > MAX) throw new ApiError(413, "image_too_big", "The image is too large (6 MB at most).");
  const id = await tx(async (db) => {
    const blob = await one<{ id: string }>("insert into blobs (content_type, bytes) values ($1,$2) returning id", [type, bytes], db);
    const m = await one<{ id: string }>(
      "insert into product_media (product_id, kind, category, blob_id, caption, sort) values ($1,'screenshot',$2,$3,$4,(select coalesce(max(sort),0)+1 from product_media where product_id = $1)) returning id",
      [product, category, blob!.id, caption],
      db,
    );
    await audit(admin.id, "media.upload", "product", product, { id: m!.id }, db);
    return m!.id;
  });
  return json({ id }, 201);
});
