import type { ProductId } from "@/config/site";
import { one, query, tx } from "./db";
import { ApiError } from "./configs";
import { audit } from "./audit";
import { cleanText } from "./config-validate";

export type DownloadRow = { id: string; product_id: ProductId; filename: string; version: string; note: string; bytes: number; created_at: Date };

export const DOWNLOAD_MAX_BYTES = 2 * 1024 * 1024;

export async function listDownloads(productId?: ProductId): Promise<DownloadRow[]> {
  return query<DownloadRow>(
    "select id, product_id, filename, version, note, bytes, created_at from product_downloads where ($1::text is null or product_id = $1) order by created_at desc",
    [productId ?? null],
  );
}

export function safeFilename(name: string): string {
  const base = name.split(/[\\/]/).pop() ?? "";
  const clean = base.replace(/[^\w.\- ]/g, "_").replace(/^\.+/, "").slice(0, 80);
  return clean;
}

// A download is a Lua file (the loader). Anything else is refused, and the bytes must be text.
export async function addDownload(actorId: string, productId: ProductId, filename: string, version: string, note: string, bytes: Buffer): Promise<string> {
  const name = safeFilename(filename);
  if (!/\.lua$/i.test(name)) throw new ApiError(415, "bad_file", "Only .lua files can be offered.");
  if (bytes.length === 0 || bytes.length > DOWNLOAD_MAX_BYTES) throw new ApiError(413, "bad_size", "The file must be between 1 byte and 2 MB.");
  if (bytes.includes(0)) throw new ApiError(415, "bad_file", "That does not look like a text file.");
  return tx(async (db) => {
    const blob = await one<{ id: string }>("insert into blobs (content_type, bytes) values ('text/plain; charset=utf-8', $1) returning id", [bytes], db);
    const row = await one<{ id: string }>(
      "insert into product_downloads (product_id, filename, version, note, blob_id, bytes, created_by) values ($1,$2,$3,$4,$5,$6,$7) returning id",
      [productId, name, cleanText(version, 32), cleanText(note, 200), blob!.id, bytes.length, actorId],
      db,
    );
    await audit(actorId, "download.add", "product", productId, { file: name, bytes: bytes.length }, db);
    return row!.id;
  });
}

export async function removeDownload(actorId: string, id: string): Promise<void> {
  const r = await one<{ product_id: string; filename: string; blob_id: string }>("delete from product_downloads where id = $1 returning product_id, filename, blob_id", [id]);
  if (!r) throw new ApiError(404, "not_found", "File not found.");
  await query("delete from blobs where id = $1", [r.blob_id]);
  await audit(actorId, "download.remove", "product", r.product_id, { file: r.filename });
}

export async function getDownloadFile(id: string): Promise<{ product_id: ProductId; filename: string; bytes: Buffer } | null> {
  return one<{ product_id: ProductId; filename: string; bytes: Buffer }>(
    "select d.product_id, d.filename, b.bytes from product_downloads d join blobs b on b.id = d.blob_id where d.id = $1",
    [id],
  );
}
