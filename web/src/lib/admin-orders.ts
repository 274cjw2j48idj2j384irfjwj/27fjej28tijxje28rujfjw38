import { audit } from "./audit";
import { ApiError } from "./configs";
import { one, query } from "./db";
import { getOrder, refundOrder, settleOrder, type Order } from "./orders";

export const ORDER_STATUSES = ["pending", "paid", "issued", "expired", "failed", "review", "refunded"] as const;
const PAGE = 25;

export type AdminOrderRow = Order & { username: string | null };

export async function searchOrders(opts: { q: string; status: string; page: number }): Promise<{ items: AdminOrderRow[]; total: number; page: number; pages: number }> {
  const where: string[] = [];
  const params: unknown[] = [];
  const q = opts.q.trim().slice(0, 100);
  if (q) {
    params.push(`%${q.replace(/[%_\\]/g, "\\$&")}%`);
    const p = `$${params.length}`;
    where.push(`(o.id::text ilike ${p} or o.license_key ilike ${p} or o.email ilike ${p} or u.username ilike ${p} or u.global_name ilike ${p} or u.discord_id ilike ${p})`);
  }
  if ((ORDER_STATUSES as readonly string[]).includes(opts.status)) {
    params.push(opts.status);
    where.push(`o.status = $${params.length}`);
  }
  const w = where.length ? `where ${where.join(" and ")}` : "";
  const total = (await one<{ n: number }>(`select count(*)::int as n from orders o left join users u on u.id = o.user_id ${w}`, params))!.n;
  const pages = Math.max(1, Math.ceil(total / PAGE));
  const page = Math.min(Math.max(1, Math.floor(opts.page) || 1), pages);
  const items = await query<AdminOrderRow>(
    `select o.*, coalesce(u.global_name, u.username) as username from orders o left join users u on u.id = o.user_id ${w}
      order by o.created_at desc limit ${PAGE} offset ${(page - 1) * PAGE}`,
    params,
  );
  return { items, total, page, pages };
}

export async function runOrderAction(actorId: string, orderId: string, action: "issue" | "mark_paid" | "refund" | "note", reason: string): Promise<Order> {
  const o = await getOrder(orderId);
  if (!o) throw new ApiError(404, "order_not_found", "Order not found.");
  const meta = { action, from: o.status, reason };
  switch (action) {
    case "issue": {
      if (o.status !== "paid") throw new ApiError(409, "bad_state", "Only a paid order without a key can be issued again.");
      await audit(actorId, "order.issue", "order", orderId, meta);
      return settleOrder(orderId);
    }
    case "mark_paid": {
      if (reason.length < 5) throw new ApiError(400, "reason_required", "Write a reason (at least 5 characters).");
      if (!["pending", "review", "expired", "failed"].includes(o.status)) throw new ApiError(409, "bad_state", `An order that is ${o.status} cannot be marked paid.`);
      await audit(actorId, "order.mark_paid", "order", orderId, meta);
      await query("update orders set admin_note = $2 where id = $1", [orderId, `Marked paid: ${reason}`]);
      return settleOrder(orderId, { manual: true });
    }
    case "refund": {
      await audit(actorId, "order.refund", "order", orderId, meta);
      return refundOrder(orderId);
    }
    case "note": {
      if (!reason) throw new ApiError(400, "reason_required", "Write the note.");
      await audit(actorId, "order.note", "order", orderId, meta);
      return (await one<Order>("update orders set admin_note = $2 where id = $1 returning *", [orderId, reason]))!;
    }
  }
}
