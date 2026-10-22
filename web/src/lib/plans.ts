import { z } from "zod";
import { one, query } from "./db";
import { audit } from "./audit";
import { ApiError } from "./configs";
import { CURRENCIES, DURATION_RE, LICENSE_PLANS } from "./plan-format";

export type Plan = {
  id: string; slug: string; name: string; description: string; license_plan: string; duration: string;
  price_cents: number; currency: string; active: boolean; sort: number; card_enabled: boolean; crypto_enabled: boolean;
  created_at: Date; updated_at: Date;
};

const COLS = "id, slug, name, description, license_plan, duration, price_cents, currency, active, sort, card_enabled, crypto_enabled, created_at, updated_at";

export const planSchema = z.object({
  slug: z.string().trim().toLowerCase().regex(/^[a-z0-9][a-z0-9-]{1,39}$/, "Slug: 2 to 40 letters, digits or dashes."),
  name: z.string().trim().min(1, "Name is required.").max(80),
  description: z.string().trim().max(400).default(""),
  license_plan: z.enum(LICENSE_PLANS),
  duration: z.string().trim().toLowerCase().regex(DURATION_RE, "Duration: lifetime or a number with d, w or m (30d, 1w, 1m)."),
  price_cents: z.number().int("Price must be whole cents.").min(1, "Price must be above zero.").max(10_000_000),
  currency: z.enum(CURRENCIES).default("usd"),
  active: z.boolean().default(true),
  sort: z.number().int().min(-1000).max(1000).default(0),
  card_enabled: z.boolean().default(true),
  crypto_enabled: z.boolean().default(true),
});
export type PlanInput = z.infer<typeof planSchema>;

export async function listPlans(activeOnly = false): Promise<(Plan & { orders: number })[]> {
  return query(
    `select ${COLS.split(", ").map((c) => `p.${c}`).join(", ")}, (select count(*)::int from orders o where o.plan_id = p.id) as orders
       from plans p ${activeOnly ? "where p.active" : ""} order by p.sort, p.price_cents, p.name`,
  );
}

export async function findPlan(idOrSlug: string): Promise<Plan | null> {
  const isUuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(idOrSlug);
  return one<Plan>(`select ${COLS} from plans where ${isUuid ? "id = $1" : "slug = $1"}`, [idOrSlug.toLowerCase()]);
}

function dupMessage(err: unknown): never {
  if ((err as { code?: string })?.code === "23505") throw new ApiError(409, "slug_taken", "That slug is already used by another plan.");
  throw err;
}

export async function createPlan(actorId: string, input: PlanInput): Promise<Plan> {
  try {
    const row = await one<Plan>(
      `insert into plans (slug, name, description, license_plan, duration, price_cents, currency, active, sort, card_enabled, crypto_enabled)
       values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11) returning ${COLS}`,
      [input.slug, input.name, input.description, input.license_plan, input.duration, input.price_cents, input.currency, input.active, input.sort, input.card_enabled, input.crypto_enabled],
    );
    await audit(actorId, "plan.create", "plan", row!.id, { slug: input.slug, price_cents: input.price_cents, currency: input.currency });
    return row!;
  } catch (err) {
    return dupMessage(err);
  }
}

export async function updatePlan(actorId: string, id: string, input: PlanInput): Promise<Plan> {
  try {
    const row = await one<Plan>(
      `update plans set slug=$2, name=$3, description=$4, license_plan=$5, duration=$6, price_cents=$7, currency=$8, active=$9, sort=$10, card_enabled=$11, crypto_enabled=$12, updated_at=now()
        where id=$1 returning ${COLS}`,
      [id, input.slug, input.name, input.description, input.license_plan, input.duration, input.price_cents, input.currency, input.active, input.sort, input.card_enabled, input.crypto_enabled],
    );
    if (!row) throw new ApiError(404, "not_found", "Plan not found.");
    await audit(actorId, "plan.update", "plan", id, { slug: input.slug, price_cents: input.price_cents, currency: input.currency, active: input.active });
    return row;
  } catch (err) {
    return dupMessage(err);
  }
}

// A plan with orders is only deactivated (the orders keep pointing at it).
export async function deletePlan(actorId: string, id: string): Promise<{ deleted: boolean; deactivated: boolean }> {
  const used = await one<{ n: number }>("select count(*)::int as n from orders where plan_id = $1", [id]);
  if ((used?.n ?? 0) > 0) {
    const row = await one("update plans set active = false, updated_at = now() where id = $1 returning id", [id]);
    if (!row) throw new ApiError(404, "not_found", "Plan not found.");
    await audit(actorId, "plan.deactivate", "plan", id, { reason: "has orders" });
    return { deleted: false, deactivated: true };
  }
  const row = await one("delete from plans where id = $1 returning id", [id]);
  if (!row) throw new ApiError(404, "not_found", "Plan not found.");
  await audit(actorId, "plan.delete", "plan", id);
  return { deleted: true, deactivated: false };
}
