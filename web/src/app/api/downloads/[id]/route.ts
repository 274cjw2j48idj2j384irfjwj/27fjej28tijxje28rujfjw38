import { NextResponse } from "next/server";
import { requireProductAccess, requireUser } from "@/lib/authz";
import { ApiError } from "@/lib/configs";
import { getDownloadFile } from "@/lib/downloads";
import { api } from "@/lib/http";
import { audit } from "@/lib/audit";

export const dynamic = "force-dynamic";

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;

// The Lua file itself. The backend checks the access of the signed in user to that Lua before it sends a byte.
export const GET = api<{ id: string }>(async (_req, { params }) => {
  const user = await requireUser();
  if (!UUID.test(params.id)) throw new ApiError(404, "not_found", "File not found.");
  const file = await getDownloadFile(params.id);
  if (!file) throw new ApiError(404, "not_found", "File not found.");
  await requireProductAccess(user.id, file.product_id);
  await audit(user.id, "download.get", "product", file.product_id, { file: file.filename });
  return new NextResponse(new Uint8Array(file.bytes), {
    headers: {
      "content-type": "text/plain; charset=utf-8",
      "content-disposition": `attachment; filename="${file.filename}"`,
      "cache-control": "private, no-store",
      "x-content-type-options": "nosniff",
    },
  });
});
