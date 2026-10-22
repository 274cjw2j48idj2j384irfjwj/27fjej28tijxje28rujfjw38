import type { ProductId } from "@/config/site";

// Pure helpers (no database): safe for client components too.

export const LICENSE_PLANS = ["beta", "nightly", "specter", "debug", "pm_dev", "pm_nightly", "pm_beta"] as const;
export type LicensePlan = (typeof LICENSE_PLANS)[number];
export const CURRENCIES = ["usd", "eur", "gbp"] as const;
export const DURATION_RE = /^(lifetime|\d+[dwm])$/;

export function luaOfLicensePlan(p: string): ProductId {
  return p.startsWith("pm_") ? "primordial" : "gamesense";
}

export function durationLabel(d: string): string {
  if (d === "lifetime") return "Lifetime";
  const m = /^(\d+)([dwm])$/.exec(d);
  if (!m) return d;
  const n = Number(m[1]);
  const unit = { d: "day", w: "week", m: "month" }[m[2] as "d" | "w" | "m"];
  return `${n} ${unit}${n === 1 ? "" : "s"}`;
}

export function formatMoney(cents: number, currency: string, locale = "en-US"): string {
  try {
    return new Intl.NumberFormat(locale, { style: "currency", currency: currency.toUpperCase() }).format(cents / 100);
  } catch {
    return `${(cents / 100).toFixed(2)} ${currency.toUpperCase()}`;
  }
}

export const STATUS_LABEL: Record<string, string> = {
  pending: "Waiting for payment",
  paid: "Paid, creating key",
  issued: "Complete",
  expired: "Expired",
  failed: "Failed",
  review: "Under review",
  refunded: "Refunded",
};
export const PROVIDER_LABEL: Record<string, string> = { stripe: "Card", nowpayments: "Crypto", manual: "Manual" };
