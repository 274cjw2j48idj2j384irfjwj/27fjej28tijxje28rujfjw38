import { randomBytes } from "node:crypto";
import { LIMITS, type ProductId } from "@/config/site";
import { one, query, tx, type Db } from "./db";
import { checkCompat, cleanMultiline, cleanTags, cleanText, validatePayload, type Problem } from "./config-validate";

export class ApiError extends Error {
  constructor(public status: number, public code: string, message: string, public details?: unknown) {
    super(message);
  }
}

const ALPHABET = "0123456789abcdefghjkmnpqrstvwxyz"; // crockford base32: no look-alike letters

export function newSlug(len = 10): string {
  const bytes = randomBytes(len);
  let s = "";
  for (let i = 0; i < len; i++) s += ALPHABET[bytes[i] % 32];
  return s;
}

export type Visibility = "public" | "unlisted" | "private";
export const VISIBILITIES: Visibility[] = ["public", "unlisted", "private"];

export type ConfigRow = {
  id: string;
  slug: string;
  product_id: ProductId;
  owner_id: string;
  name: string;
  description: string;
  tags: string[];
  visibility: Visibility;
  is_official: boolean;
  is_featured: boolean;
  hidden: boolean;
  is_demo: boolean;
  latest_version: number;
  likes_count: number;
  downloads_count: number;
  imports_count: number;
  created_at: Date;
  updated_at: Date;
};

export type ConfigListItem = ConfigRow & {
  owner_name: string;
  owner_avatar: string | null;
  owner_discord_id: string;
  owner_verified: boolean;
  lua_version: string;
  format_version: number;
  image_id: string | null;
};

const LIST_SELECT = `
  c.*, u.global_name as owner_global, u.username as owner_username, u.avatar as owner_avatar, u.discord_id as owner_discord_id,
  u.verified_creator as owner_verified, v.lua_version, v.format_version,
  (select blob_id from config_images i where i.config_id = c.id order by sort, id limit 1) as image_id`;

type RawList = ConfigRow & { owner_global: string | null; owner_username: string; owner_avatar: string | null; owner_discord_id: string; owner_verified: boolean; lua_version: string; format_version: number; image_id: string | null };

function shape(r: RawList): ConfigListItem {
  const { owner_global, owner_username, ...rest } = r;
  return { ...rest, owner_name: owner_global || owner_username };
}

export function problemsError(problems: Problem[]): ApiError {
  return new ApiError(422, "invalid_config", problems[0]?.message ?? "Invalid config.", problems);
}

async function checkUploadQuota(userId: string, db: Db): Promise<void> {
  const row = await one<{ n: string }>(
    `select count(*) as n from config_versions v join configs c on c.id = v.config_id
      where c.owner_id = $1 and v.created_at > now() - interval '1 day'`,
    [userId],
    db,
  );
  if (Number(row?.n ?? 0) >= LIMITS.uploadsPerDay) throw new ApiError(429, "upload_quota", `At most ${LIMITS.uploadsPerDay} uploads per day.`);
}

export type NewConfig = {
  ownerId: string;
  productId: ProductId;
  name: string;
  description?: string;
  tags?: string[];
  visibility?: Visibility;
  payload: unknown;
  isOfficial?: boolean;
  isDemo?: boolean;
};

export async function createConfig(input: NewConfig): Promise<{ id: string; slug: string }> {
  const name = cleanText(input.name, LIMITS.configNameLen);
  if (name.length < 2) throw new ApiError(400, "bad_name", "The name needs at least 2 characters.");
  const visibility = input.visibility ?? "public";
  if (!VISIBILITIES.includes(visibility)) throw new ApiError(400, "bad_visibility", "Unknown visibility.");
  const checked = validatePayload(input.payload, input.productId);
  if (!checked.ok) throw problemsError(checked.problems);
  return tx(async (db) => {
    if (!input.isDemo) await checkUploadQuota(input.ownerId, db);
    const slug = newSlug();
    const cfg = await one<{ id: string }>(
      `insert into configs (slug, product_id, owner_id, name, description, tags, visibility, is_official, is_demo)
       values ($1,$2,$3,$4,$5,$6,$7,$8,$9) returning id`,
      [slug, input.productId, input.ownerId, name, cleanMultiline(input.description ?? "", LIMITS.configDescLen), cleanTags(input.tags ?? []), visibility, !!input.isOfficial, !!input.isDemo],
      db,
    );
    await query(
      `insert into config_versions (config_id, version, payload, payload_bytes, format_version, lua_version) values ($1,1,$2,$3,$4,$5)`,
      [cfg!.id, JSON.stringify(checked.payload), checked.bytes, checked.payload.meta.format_version, checked.payload.meta.lua_version],
      db,
    );
    return { id: cfg!.id, slug };
  });
}

export async function addVersion(configId: string, ownerId: string, payload: unknown, changelog = ""): Promise<{ version: number }> {
  const cfg = await one<ConfigRow>("select * from configs where id = $1", [configId]);
  if (!cfg || cfg.owner_id !== ownerId) throw new ApiError(404, "not_found", "Config not found.");
  const checked = validatePayload(payload, cfg.product_id);
  if (!checked.ok) throw problemsError(checked.problems);
  return tx(async (db) => {
    await checkUploadQuota(ownerId, db);
    const row = await one<{ latest_version: number }>("select latest_version from configs where id = $1 for update", [configId], db);
    const version = row!.latest_version + 1;
    await query(
      `insert into config_versions (config_id, version, payload, payload_bytes, format_version, lua_version, changelog) values ($1,$2,$3,$4,$5,$6,$7)`,
      [configId, version, JSON.stringify(checked.payload), checked.bytes, checked.payload.meta.format_version, checked.payload.meta.lua_version, cleanMultiline(changelog, 400)],
      db,
    );
    await query("update configs set latest_version = $2, updated_at = now() where id = $1", [configId, version], db);
    return { version };
  });
}

export async function updateConfigMeta(configId: string, ownerId: string, patch: { name?: string; description?: string; tags?: string[]; visibility?: Visibility }): Promise<void> {
  const cfg = await one<ConfigRow>("select * from configs where id = $1", [configId]);
  if (!cfg || cfg.owner_id !== ownerId) throw new ApiError(404, "not_found", "Config not found.");
  const name = patch.name === undefined ? cfg.name : cleanText(patch.name, LIMITS.configNameLen);
  if (name.length < 2) throw new ApiError(400, "bad_name", "The name needs at least 2 characters.");
  if (patch.visibility && !VISIBILITIES.includes(patch.visibility)) throw new ApiError(400, "bad_visibility", "Unknown visibility.");
  await query(
    "update configs set name = $2, description = $3, tags = $4, visibility = $5, updated_at = now() where id = $1",
    [
      configId,
      name,
      patch.description === undefined ? cfg.description : cleanMultiline(patch.description, LIMITS.configDescLen),
      patch.tags === undefined ? cfg.tags : cleanTags(patch.tags),
      patch.visibility ?? cfg.visibility,
    ],
  );
}

export async function deleteConfig(configId: string, ownerId: string): Promise<void> {
  const rows = await query("delete from configs where id = $1 and owner_id = $2 returning id", [configId, ownerId]);
  if (!rows.length) throw new ApiError(404, "not_found", "Config not found.");
}

export type Viewer = { id: string; isAdmin: boolean } | null;

// Who may see a config page: public and unlisted for everybody (a hidden one only for the owner and admins),
// private only for the owner.
export function canView(cfg: Pick<ConfigRow, "owner_id" | "visibility" | "hidden">, viewer: Viewer): boolean {
  if (viewer?.isAdmin) return true;
  if (viewer && viewer.id === cfg.owner_id) return true;
  return cfg.visibility !== "private" && !cfg.hidden;
}

export async function getConfigBySlug(slug: string, viewer: Viewer): Promise<ConfigListItem | null> {
  const row = await one<RawList>(
    `select ${LIST_SELECT} from configs c join users u on u.id = c.owner_id
       join config_versions v on v.config_id = c.id and v.version = c.latest_version where c.slug = $1`,
    [slug],
  );
  if (!row) return null;
  return canView(row, viewer) ? shape(row) : null;
}

export type Sort = "latest" | "popular" | "downloads" | "featured";

export type ListQuery = {
  productId?: ProductId;
  q?: string;
  tag?: string;
  luaVersion?: string;
  sort?: Sort;
  official?: boolean;
  featuredOnly?: boolean;
  ownerId?: string;          // list of one creator (public ones; with includeOwn also the private)
  includeOwn?: boolean;
  likedBy?: string;
  limit?: number;
  offset?: number;
};

export async function listConfigs(q: ListQuery): Promise<{ items: ConfigListItem[]; total: number }> {
  const where: string[] = [];
  const params: unknown[] = [];
  const p = (v: unknown) => {
    params.push(v);
    return `$${params.length}`;
  };
  if (q.ownerId && q.includeOwn) where.push(`c.owner_id = ${p(q.ownerId)}`);
  else {
    where.push("c.visibility = 'public' and not c.hidden");
    if (q.ownerId) where.push(`c.owner_id = ${p(q.ownerId)}`);
  }
  if (q.productId) where.push(`c.product_id = ${p(q.productId)}`);
  if (q.q) {
    const like = p(`%${q.q.replace(/[%_\\]/g, "\\$&").slice(0, 60)}%`);
    const tag = p(q.q.toLowerCase().slice(0, 24));
    where.push(`(c.name ilike ${like} or c.description ilike ${like} or ${tag} = any(c.tags))`);
  }
  if (q.tag) where.push(`${p(q.tag.toLowerCase())} = any(c.tags)`);
  if (q.luaVersion) where.push(`v.lua_version = ${p(q.luaVersion)}`);
  if (q.official) where.push("c.is_official");
  if (q.featuredOnly) where.push("c.is_featured");
  if (q.likedBy) where.push(`exists (select 1 from config_likes l where l.config_id = c.id and l.user_id = ${p(q.likedBy)})`);
  const order: Record<Sort, string> = {
    latest: "c.updated_at desc",
    popular: "c.likes_count desc, c.updated_at desc",
    downloads: "(c.downloads_count + c.imports_count) desc, c.updated_at desc",
    featured: "c.is_featured desc, c.is_official desc, c.likes_count desc, c.updated_at desc",
  };
  const limit = Math.min(Math.max(q.limit ?? 24, 1), 60);
  const offset = Math.max(q.offset ?? 0, 0);
  const from = `from configs c join users u on u.id = c.owner_id join config_versions v on v.config_id = c.id and v.version = c.latest_version where ${where.join(" and ")}`;
  const rows = await query<RawList>(`select ${LIST_SELECT} ${from} order by ${order[q.sort ?? "latest"]} limit ${limit} offset ${offset}`, params);
  const total = await one<{ n: string }>(`select count(*) as n ${from}`, params);
  return { items: rows.map(shape), total: Number(total?.n ?? 0) };
}

export async function myConfigs(userId: string): Promise<ConfigListItem[]> {
  const rows = await query<RawList>(
    `select ${LIST_SELECT} from configs c join users u on u.id = c.owner_id
       join config_versions v on v.config_id = c.id and v.version = c.latest_version where c.owner_id = $1 order by c.updated_at desc`,
    [userId],
  );
  return rows.map(shape);
}

export type VersionRow = { version: number; lua_version: string; format_version: number; payload_bytes: number; changelog: string; created_at: Date };

export async function listVersions(configId: string): Promise<VersionRow[]> {
  return query<VersionRow>(
    "select version, lua_version, format_version, payload_bytes, changelog, created_at from config_versions where config_id = $1 order by version desc",
    [configId],
  );
}

export async function getVersionPayload(configId: string, version?: number): Promise<{ version: number; payload: { meta: { product: string; format_version: number; lua_version: string }; data: unknown } } | null> {
  const row = version
    ? await one<{ version: number; payload: never }>("select version, payload from config_versions where config_id = $1 and version = $2", [configId, version])
    : await one<{ version: number; payload: never }>(
        "select v.version, v.payload from config_versions v join configs c on c.id = v.config_id and v.version = c.latest_version where c.id = $1",
        [configId],
      );
  return row ? { version: row.version, payload: row.payload } : null;
}

export async function compatFor(configId: string, version: number): Promise<ReturnType<typeof checkCompat> | null> {
  const row = await one<{ product_id: string; format_version: number; lua_version: string; min_format: number; max_format: number; latest_version: string }>(
    `select c.product_id, v.format_version, v.lua_version, p.min_format, p.max_format, p.latest_version
       from config_versions v join configs c on c.id = v.config_id join products p on p.id = c.product_id
      where v.config_id = $1 and v.version = $2`,
    [configId, version],
  );
  if (!row) return null;
  return checkCompat(
    { product: row.product_id, format_version: row.format_version, lua_version: row.lua_version },
    { id: row.product_id, min_format: row.min_format, max_format: row.max_format, latest_version: row.latest_version },
  );
}

export async function toggleLike(userId: string, configId: string): Promise<{ liked: boolean; likes: number }> {
  return tx(async (db) => {
    const removed = await query("delete from config_likes where user_id = $1 and config_id = $2 returning 1", [userId, configId], db);
    if (removed.length) {
      const r = await one<{ likes_count: number }>("update configs set likes_count = greatest(likes_count - 1, 0) where id = $1 returning likes_count", [configId], db);
      return { liked: false, likes: r!.likes_count };
    }
    await query("insert into config_likes (user_id, config_id) values ($1,$2)", [userId, configId], db);
    const r = await one<{ likes_count: number }>("update configs set likes_count = likes_count + 1 where id = $1 returning likes_count", [configId], db);
    return { liked: true, likes: r!.likes_count };
  });
}

export async function saveToLibrary(userId: string, configId: string): Promise<void> {
  await query(
    `insert into config_library (user_id, config_id, saved_version)
     select $1, c.id, c.latest_version from configs c where c.id = $2
     on conflict (user_id, config_id) do update set saved_version = excluded.saved_version, saved_at = now()`,
    [userId, configId],
  );
}

export async function removeFromLibrary(userId: string, configId: string): Promise<void> {
  await query("delete from config_library where user_id = $1 and config_id = $2", [userId, configId]);
}

export type LibraryItem = ConfigListItem & { saved_version: number; update_available: boolean };

export async function libraryOf(userId: string, productId?: ProductId): Promise<LibraryItem[]> {
  const rows = await query<RawList & { saved_version: number }>(
    `select ${LIST_SELECT}, l.saved_version from config_library l join configs c on c.id = l.config_id join users u on u.id = c.owner_id
       join config_versions v on v.config_id = c.id and v.version = c.latest_version
      where l.user_id = $1 and ($2::text is null or c.product_id = $2) and (c.visibility <> 'private' or c.owner_id = $1) and (not c.hidden or c.owner_id = $1)
      order by l.saved_at desc`,
    [userId, productId ?? null],
  );
  return rows.map((r) => ({ ...shape(r), saved_version: r.saved_version, update_available: r.latest_version > r.saved_version }));
}

// A counted event: one per user, config, kind and day.
export async function recordEvent(configId: string, userId: string, kind: "download" | "import_code" | "client_import"): Promise<boolean> {
  return tx(async (db) => {
    const ins = await query("insert into config_events (config_id, user_id, kind) values ($1,$2,$3) on conflict do nothing returning id", [configId, userId, kind], db);
    if (!ins.length) return false;
    const col = kind === "download" ? "downloads_count" : "imports_count";
    await query(`update configs set ${col} = ${col} + 1 where id = $1`, [configId], db);
    return true;
  });
}

export async function reportConfig(userId: string, configId: string, reason: string, details: string): Promise<void> {
  const r = cleanText(reason, 60);
  if (!r) throw new ApiError(400, "bad_reason", "A reason is needed.");
  await query(
    `insert into config_reports (config_id, reporter_id, reason, details) values ($1,$2,$3,$4)
     on conflict (config_id, reporter_id) do update set reason = excluded.reason, details = excluded.details, status = 'open', created_at = now()`,
    [configId, userId, r, cleanMultiline(details, 500)],
  );
}

export const IMAGE_TYPES: Record<string, { ext: string; magic: (b: Buffer) => boolean }> = {
  "image/png": { ext: "png", magic: (b) => b.length > 8 && b.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])) },
  "image/jpeg": { ext: "jpg", magic: (b) => b.length > 3 && b[0] === 0xff && b[1] === 0xd8 && b[2] === 0xff },
  "image/webp": { ext: "webp", magic: (b) => b.length > 12 && b.subarray(0, 4).toString() === "RIFF" && b.subarray(8, 12).toString() === "WEBP" },
};

export async function addConfigImage(configId: string, ownerId: string, contentType: string, bytes: Buffer): Promise<string> {
  const type = IMAGE_TYPES[contentType];
  if (!type || !type.magic(bytes)) throw new ApiError(415, "bad_image", "Only PNG, JPEG or WebP images are accepted.");
  if (bytes.length > LIMITS.imageBytes) throw new ApiError(413, "image_too_big", `An image can be at most ${LIMITS.imageBytes / 1024 / 1024} MB.`);
  return tx(async (db) => {
    const cfg = await one<{ owner_id: string }>("select owner_id from configs where id = $1 for update", [configId], db);
    if (!cfg || cfg.owner_id !== ownerId) throw new ApiError(404, "not_found", "Config not found.");
    const n = await one<{ n: string }>("select count(*) as n from config_images where config_id = $1", [configId], db);
    if (Number(n?.n) >= LIMITS.maxImagesPerConfig) throw new ApiError(409, "too_many_images", `At most ${LIMITS.maxImagesPerConfig} images per config.`);
    const blob = await one<{ id: string }>("insert into blobs (content_type, bytes) values ($1,$2) returning id", [contentType, bytes], db);
    await query("insert into config_images (config_id, blob_id, sort) values ($1,$2,$3)", [configId, blob!.id, Number(n?.n)], db);
    return blob!.id;
  });
}

export async function configImages(configId: string): Promise<string[]> {
  return (await query<{ blob_id: string }>("select blob_id from config_images where config_id = $1 order by sort, id", [configId])).map((r) => r.blob_id);
}

export async function removeConfigImage(configId: string, ownerId: string, blobId: string): Promise<void> {
  const r = await tx(async (db) => {
    const cfg = await one<{ owner_id: string }>("select owner_id from configs where id = $1", [configId], db);
    if (!cfg || cfg.owner_id !== ownerId) return null;
    const del = await query("delete from config_images where config_id = $1 and blob_id = $2 returning blob_id", [configId, blobId], db);
    if (del.length) await query("delete from blobs where id = $1", [blobId], db);
    return del.length;
  });
  if (!r) throw new ApiError(404, "not_found", "Image not found.");
}
