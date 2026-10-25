import { z } from "zod";
import type { ProductId } from "@/config/site";
import { one, query, tx } from "./db";
import { ApiError, deleteConfig } from "./configs";
import { audit, notify } from "./audit";
import { cleanMultiline, cleanText } from "./config-validate";
import { destroyAllSessions } from "./sessions";

export type AdminUser = {
  id: string; discord_id: string; username: string; global_name: string | null; avatar: string | null;
  is_admin: boolean; suspended: boolean; verified_creator: boolean; created_at: Date; last_login_at: Date;
};

export async function searchUsers(q: string, limit = 30): Promise<AdminUser[]> {
  const like = `%${q.replace(/[%_\\]/g, "\\$&").slice(0, 40)}%`;
  return query<AdminUser>(
    `select id, discord_id, username, global_name, avatar, is_admin, suspended, verified_creator, created_at, last_login_at
       from users where $1 = '' or discord_id = $2 or username ilike $3 or global_name ilike $3 order by last_login_at desc limit ${Math.min(limit, 100)}`,
    [q, q, like],
  );
}

export async function userDetail(id: string) {
  const user = await one<AdminUser>("select id, discord_id, username, global_name, avatar, is_admin, suspended, verified_creator, created_at, last_login_at from users where id = $1", [id]);
  if (!user) return null;
  const grants = await query("select id, product_id, source, starts_at, expires_at, revoked_at, note from access_grants where user_id = $1 order by created_at desc", [id]);
  const suspensions = await query("select id, product_id, reason, created_at, lifted_at from suspensions where user_id = $1 order by created_at desc", [id]);
  return { user, grants, suspensions };
}

export const grantSchema = z.object({ product: z.enum(["gamesense", "primordial"]), days: z.number().int().min(1).max(3650).nullable(), note: z.string().max(200).optional() });

export async function grantAccess(actorId: string, userId: string, productId: ProductId, days: number | null, note = "", now = new Date()): Promise<string> {
  return tx(async (db) => {
    const exists = await one("select 1 as x from users where id = $1", [userId], db);
    if (!exists) throw new ApiError(404, "not_found", "User not found.");
    const expires = days === null ? null : new Date(now.getTime() + days * 86_400_000);
    const g = await one<{ id: string }>(
      "insert into access_grants (user_id, product_id, source, starts_at, expires_at, note, created_by) values ($1,$2,'admin',$3,$4,$5,$6) returning id",
      [userId, productId, now, expires, cleanText(note, 200), actorId],
      db,
    );
    await audit(actorId, "access.grant", "user", userId, { product: productId, days, grant: g!.id }, db);
    await notify(userId, "access", `Access added: ${productId}`, days === null ? "Your access does not expire." : `${days} days were added.`, "/dashboard/access", db);
    return g!.id;
  });
}

export async function revokeGrant(actorId: string, grantId: string): Promise<void> {
  const r = await one<{ user_id: string; product_id: string }>("update access_grants set revoked_at = now() where id = $1 and revoked_at is null returning user_id, product_id", [grantId]);
  if (!r) throw new ApiError(404, "not_found", "Grant not found.");
  await audit(actorId, "access.revoke", "user", r.user_id, { product: r.product_id, grant: grantId });
}

export async function setProductSuspension(actorId: string, userId: string, productId: ProductId, suspend: boolean, reason = ""): Promise<void> {
  if (suspend) {
    await query(
      "insert into suspensions (user_id, product_id, reason, created_by) values ($1,$2,$3,$4) on conflict (user_id, product_id) where lifted_at is null do nothing",
      [userId, productId, cleanText(reason, 200), actorId],
    );
  } else {
    await query("update suspensions set lifted_at = now() where user_id = $1 and product_id = $2 and lifted_at is null", [userId, productId]);
  }
  await audit(actorId, suspend ? "access.suspend" : "access.unsuspend", "user", userId, { product: productId, reason });
}

export async function setPlatformBan(actorId: string, userId: string, banned: boolean): Promise<void> {
  const r = await one("update users set suspended = $2 where id = $1 returning id", [userId, banned]);
  if (!r) throw new ApiError(404, "not_found", "User not found.");
  if (banned) await destroyAllSessions(userId);
  await audit(actorId, banned ? "user.ban" : "user.unban", "user", userId);
}

export async function setVerifiedCreator(actorId: string, userId: string, value: boolean): Promise<void> {
  const r = await one("update users set verified_creator = $2 where id = $1 returning id", [userId, value]);
  if (!r) throw new ApiError(404, "not_found", "User not found.");
  await audit(actorId, value ? "creator.verify" : "creator.unverify", "user", userId);
}

export async function setAdminFlag(actorId: string, userId: string, value: boolean): Promise<void> {
  const r = await one("update users set is_admin = $2 where id = $1 returning id", [userId, value]);
  if (!r) throw new ApiError(404, "not_found", "User not found.");
  await audit(actorId, value ? "admin.add" : "admin.remove", "user", userId);
}

// ---- Discord role mapping
export const roleSchema = z.object({ product: z.enum(["gamesense", "primordial"]), role_id: z.string().regex(/^\d{15,22}$/, "A Discord role id is 15-22 digits."), label: z.string().max(60).optional() });

export async function listRoleMappings() {
  return query<{ id: string; product_id: ProductId; discord_role_id: string; label: string }>("select id, product_id, discord_role_id, label from role_mappings order by product_id, label");
}

export async function addRoleMapping(actorId: string, product: ProductId, roleId: string, label = ""): Promise<void> {
  await query("insert into role_mappings (product_id, discord_role_id, label) values ($1,$2,$3) on conflict (product_id, discord_role_id) do update set label = excluded.label", [product, roleId, cleanText(label, 60)]);
  await audit(actorId, "role.map", "product", product, { role: roleId });
}

export async function removeRoleMapping(actorId: string, id: string): Promise<void> {
  const r = await one<{ product_id: string; discord_role_id: string }>("delete from role_mappings where id = $1 returning product_id, discord_role_id", [id]);
  if (!r) throw new ApiError(404, "not_found", "Mapping not found.");
  await audit(actorId, "role.unmap", "product", r.product_id, { role: r.discord_role_id });
}

// ---- Products and releases
export const featureSchema = z.object({ category: z.string().min(1).max(40), title: z.string().min(1).max(80), text: z.string().max(400).default("") });

export const productSchema = z.object({
  features: z.array(featureSchema).max(80).optional(),
  install_guide: z.string().max(6000).optional(),
  compat_notes: z.string().max(2000).optional(),
  latest_version: z.string().regex(/^\d+(\.\d+){0,3}([-+][0-9A-Za-z.-]+)?$/).or(z.literal("")).optional(),
  min_format: z.number().int().min(1).max(1000).optional(),
  max_format: z.number().int().min(1).max(1000).optional(),
});

export async function updateProduct(actorId: string, id: ProductId, p: z.infer<typeof productSchema>): Promise<void> {
  const cur = await one<{ min_format: number; max_format: number }>("select min_format, max_format from products where id = $1", [id]);
  if (!cur) throw new ApiError(404, "not_found", "Product not found.");
  const min = p.min_format ?? cur.min_format;
  const max = p.max_format ?? cur.max_format;
  if (min > max) throw new ApiError(400, "bad_formats", "The lowest format cannot be above the highest.");
  await query(
    `update products set features = coalesce($2::jsonb, features), install_guide = coalesce($3, install_guide), compat_notes = coalesce($4, compat_notes),
            latest_version = coalesce($5, latest_version), min_format = $6, max_format = $7, updated_at = now() where id = $1`,
    [
      id,
      p.features ? JSON.stringify(p.features.map((f) => ({ category: cleanText(f.category, 40), title: cleanText(f.title, 80), text: cleanMultiline(f.text, 400) }))) : null,
      p.install_guide === undefined ? null : cleanMultiline(p.install_guide, 6000),
      p.compat_notes === undefined ? null : cleanMultiline(p.compat_notes, 2000),
      p.latest_version ?? null,
      min,
      max,
    ],
  );
  await audit(actorId, "product.update", "product", id);
}

export const releaseSchema = z.object({
  product: z.enum(["gamesense", "primordial"]),
  version: z.string().regex(/^\d+(\.\d+){0,3}([-+][0-9A-Za-z.-]+)?$/),
  title: z.string().min(1).max(120),
  notes: z.array(z.string().min(1).max(300)).max(30),
  set_latest: z.boolean().optional(),
});

export async function addRelease(actorId: string, r: z.infer<typeof releaseSchema>): Promise<string> {
  return tx(async (db) => {
    const row = await one<{ id: string }>(
      "insert into releases (product_id, version, title, notes) values ($1,$2,$3,$4) returning id",
      [r.product, r.version, cleanText(r.title, 120), JSON.stringify(r.notes.map((n) => cleanText(n, 300)))],
      db,
    );
    if (r.set_latest) await query("update products set latest_version = $2, updated_at = now() where id = $1", [r.product, r.version], db);
    await audit(actorId, "release.add", "product", r.product, { version: r.version }, db);
    return row!.id;
  });
}

export async function deleteRelease(actorId: string, id: string): Promise<void> {
  const r = await one<{ product_id: string; version: string }>("delete from releases where id = $1 returning product_id, version", [id]);
  if (!r) throw new ApiError(404, "not_found", "Release not found.");
  await audit(actorId, "release.delete", "product", r.product_id, { version: r.version });
}

export const mediaSchema = z.object({
  product: z.enum(["gamesense", "primordial"]),
  kind: z.enum(["screenshot", "video"]),
  category: z.enum(["menu", "visuals", "configuration"]),
  url: z.string().url().max(500).refine((u) => u.startsWith("https://"), "Only https links."),
  caption: z.string().max(160).optional(),
});

export async function addMediaUrl(actorId: string, m: z.infer<typeof mediaSchema>): Promise<string> {
  const row = await one<{ id: string }>(
    "insert into product_media (product_id, kind, category, url, caption, sort) values ($1,$2,$3,$4,$5,(select coalesce(max(sort),0)+1 from product_media where product_id = $1)) returning id",
    [m.product, m.kind, m.category, m.url, cleanText(m.caption ?? "", 160)],
  );
  await audit(actorId, "media.add", "product", m.product, { id: row!.id });
  return row!.id;
}

export async function removeMedia(actorId: string, id: string): Promise<void> {
  const r = await one<{ product_id: string }>("delete from product_media where id = $1 returning product_id", [id]);
  if (!r) throw new ApiError(404, "not_found", "Media not found.");
  await audit(actorId, "media.remove", "product", r.product_id, { id });
}

// ---- Config moderation
export const moderationSchema = z.object({ action: z.enum(["hide", "unhide", "feature", "unfeature", "official", "unofficial", "delete"]) });

export async function moderateConfig(actorId: string, configId: string, action: z.infer<typeof moderationSchema>["action"]): Promise<void> {
  const cfg = await one<{ id: string; owner_id: string; name: string }>("select id, owner_id, name from configs where id = $1", [configId]);
  if (!cfg) throw new ApiError(404, "not_found", "Config not found.");
  const sets: Record<string, string> = {
    hide: "hidden = true", unhide: "hidden = false", feature: "is_featured = true", unfeature: "is_featured = false", official: "is_official = true", unofficial: "is_official = false",
  };
  if (action === "delete") await deleteConfig(configId, cfg.owner_id);
  else await query(`update configs set ${sets[action]} where id = $1`, [configId]);
  if (action === "hide") await notify(cfg.owner_id, "moderation", `Your config "${cfg.name}" was hidden`, "A moderator hid it from the cloud. Contact support on Discord if you think it was a mistake.");
  await audit(actorId, `config.${action}`, "config", configId, { name: cfg.name });
}

export async function listOpenReports() {
  return query(
    `select r.id, r.reason, r.details, r.created_at, c.id as config_id, c.slug, c.name, c.product_id, c.hidden,
            coalesce(rep.global_name, rep.username) as reporter, coalesce(o.global_name, o.username) as owner
       from config_reports r join configs c on c.id = r.config_id join users rep on rep.id = r.reporter_id join users o on o.id = c.owner_id
      where r.status = 'open' order by r.created_at`,
  );
}

export async function resolveReport(actorId: string, reportId: string, status: "resolved" | "dismissed"): Promise<void> {
  const r = await one("update config_reports set status = $2, resolved_by = $3, resolved_at = now() where id = $1 and status = 'open' returning id", [reportId, status, actorId]);
  if (!r) throw new ApiError(404, "not_found", "Report not found.");
  await audit(actorId, `report.${status}`, "report", reportId);
}

// ---- Leaderboard settings
export const boardSchema = z.object({
  scoring_enabled: z.boolean().optional(),
  rules: z
    .object({ events: z.record(z.string().regex(/^[a-z0-9_]{1,40}$/), z.object({ points: z.number().int().min(1).max(1000), dailyCap: z.number().int().min(1).max(100000).optional() })) })
    .optional(),
  rewards_enabled: z.boolean().optional(),
  reward_product_id: z.enum(["gamesense", "primordial"]).nullable().optional(),
  reward_days: z.array(z.number().int().min(1).max(365)).length(3).optional(),
});

export async function updateBoard(actorId: string, id: string, b: z.infer<typeof boardSchema>): Promise<void> {
  const cur = await one<{ kind: string; reward_product_id: string | null; rewards_enabled: boolean; scoring_enabled: boolean }>("select kind, reward_product_id, rewards_enabled, scoring_enabled from boards where id = $1", [id]);
  if (!cur) throw new ApiError(404, "not_found", "Board not found.");
  const rewardProduct = b.reward_product_id === undefined ? cur.reward_product_id : b.reward_product_id;
  const rewardsOn = b.rewards_enabled ?? cur.rewards_enabled;
  if (rewardsOn && !rewardProduct) throw new ApiError(400, "no_reward_product", "Choose the product the reward gives access to.");
  if (b.scoring_enabled && cur.kind === "overall") throw new ApiError(400, "bad_board", "The overall board adds the product boards, it does not collect points itself.");
  await query(
    `update boards set scoring_enabled = coalesce($2, scoring_enabled), rules = coalesce($3::jsonb, rules), rewards_enabled = $4, reward_product_id = $5,
            reward_days = coalesce($6::jsonb, reward_days) where id = $1`,
    [id, b.scoring_enabled ?? null, b.rules ? JSON.stringify(b.rules) : null, rewardsOn, rewardProduct, b.reward_days ? JSON.stringify(b.reward_days) : null],
  );
  await audit(actorId, "board.update", "board", id, b as Record<string, unknown>);
}

export async function recentAudit(limit = 100) {
  return query(
    `select a.id, a.action, a.target_type, a.target_id, a.meta, a.created_at, coalesce(u.global_name, u.username) as actor
       from audit_log a left join users u on u.id = a.actor_id order by a.id desc limit ${Math.min(limit, 500)}`,
  );
}

export async function recentRewards(limit = 100) {
  return query(
    `select r.id, r.board_id, r.period, r.rank, r.product_id, r.days, r.note, r.previous_expires_at, r.new_expires_at, r.created_at, coalesce(u.global_name, u.username) as winner
       from reward_log r join users u on u.id = r.user_id order by r.id desc limit ${Math.min(limit, 500)}`,
  );
}
