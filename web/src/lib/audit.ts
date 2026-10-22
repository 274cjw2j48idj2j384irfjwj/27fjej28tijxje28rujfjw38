import { query, type Db } from "./db";

export async function audit(actorId: string | null, action: string, targetType = "", targetId = "", meta: Record<string, unknown> = {}, db?: Db): Promise<void> {
  await query("insert into audit_log (actor_id, action, target_type, target_id, meta) values ($1,$2,$3,$4,$5)", [actorId, action, targetType, targetId, JSON.stringify(meta)], db);
}

export async function notify(userId: string, kind: string, title: string, body = "", link: string | null = null, db?: Db): Promise<void> {
  await query("insert into notifications (user_id, kind, title, body, link) values ($1,$2,$3,$4,$5)", [userId, kind, title, body, link], db);
}
