import { NextResponse } from "next/server";
import { currentUser, isAdmin } from "@/lib/authz";
import { one } from "@/lib/db";
import { ApiError } from "@/lib/configs";
import { api } from "@/lib/http";

export const dynamic = "force-dynamic";

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;

// Images are served from the database. A product image is public; a config image follows the visibility of its config.
export const GET = api<{ id: string }>(async (_req, { params }) => {
  if (!UUID.test(params.id)) throw new ApiError(404, "not_found", "Not found.");
  const row = await one<{ content_type: string; bytes: Buffer; public: boolean; owner_id: string | null; visibility: string | null; hidden: boolean | null }>(
    `select b.content_type, b.bytes,
            exists (select 1 from product_media m where m.blob_id = b.id) as public,
            c.owner_id, c.visibility, c.hidden
       from blobs b left join config_images i on i.blob_id = b.id left join configs c on c.id = i.config_id where b.id = $1`,
    [params.id],
  );
  if (!row) throw new ApiError(404, "not_found", "Not found.");
  let allowed = row.public;
  let cacheable = row.public;
  if (!allowed && row.owner_id) {
    if (row.visibility !== "private" && !row.hidden) {
      allowed = true;
      cacheable = row.visibility === "public";
    } else {
      const user = await currentUser();
      allowed = !!user && (user.id === row.owner_id || isAdmin(user));
    }
  }
  if (!allowed) throw new ApiError(404, "not_found", "Not found.");
  return new NextResponse(new Uint8Array(row.bytes), {
    headers: {
      "content-type": row.content_type,
      "cache-control": cacheable ? "public, max-age=86400, immutable" : "private, no-store",
      "x-content-type-options": "nosniff",
      "content-security-policy": "default-src 'none'; sandbox",
    },
  });
});
