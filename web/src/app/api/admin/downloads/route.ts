import { adminOnly } from "@/lib/admin-http";
import { addDownload, listDownloads } from "@/lib/downloads";
import { api, json } from "@/lib/http";
import { productParam } from "@/lib/config-api";
import { ApiError } from "@/lib/configs";

export const dynamic = "force-dynamic";

export const GET = api(async (req) => {
  await adminOnly(req);
  return json({ files: await listDownloads() });
});

// Raw file as the body; product, filename, version and note in the query string.
export const POST = api(async (req) => {
  const admin = await adminOnly(req);
  const sp = new URL(req.url).searchParams;
  const product = productParam.parse(sp.get("product"));
  if (Number(req.headers.get("content-length") ?? 0) > 2.5 * 1024 * 1024) throw new ApiError(413, "bad_size", "The file must be at most 2 MB.");
  const bytes = Buffer.from(await req.arrayBuffer());
  const id = await addDownload(admin.id, product, sp.get("filename") ?? "", sp.get("version") ?? "", sp.get("note") ?? "", bytes);
  return json({ id }, 201);
});
