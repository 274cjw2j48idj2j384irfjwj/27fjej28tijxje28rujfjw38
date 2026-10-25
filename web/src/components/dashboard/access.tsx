import { hasAccess, type AccessResult } from "@/lib/access";
import { daysLeft, formatDate } from "@/components/ui";

export function viaLabel(via: AccessResult["via"]): string {
  if (via === "discord_role") return "Discord role";
  if (via === "admin") return "Admin grant";
  if (via === "reward") return "Leaderboard reward";
  return "-";
}

export function expiryLine(a: AccessResult): string {
  if (a.status === "no_access" || a.status === "suspended") return "-";
  if (a.status === "expired") return `Ended ${formatDate(a.expiresAt)}`;
  if (!a.expiresAt) return "No expiry";
  return `${formatDate(a.expiresAt)} (${daysLeft(a.expiresAt)})`;
}

export type Reason = { tone: "green" | "amber" | "red" | "gray" | "violet"; title: string; text: string };

// Why a status does or does not unlock something. A Discord check that failed is NOT "no access".
export function reasonFor(a: AccessResult, lua: string): Reason {
  switch (a.status) {
    case "active":
      return { tone: "green", title: "Access active", text: a.via === "discord_role" ? `Your Discord role unlocks ${lua}.` : `${viaLabel(a.via)} unlocks ${lua}.` };
    case "expiring_soon":
      return { tone: "amber", title: "Expiring soon", text: `Your access to ${lua} ends ${formatDate(a.expiresAt)} (${daysLeft(a.expiresAt)}). It still works until then.` };
    case "expired":
      return { tone: "red", title: "Access expired", text: `Your access to ${lua} ended ${formatDate(a.expiresAt)}. Get a new role or grant on Discord to unlock it again.` };
    case "suspended":
      return { tone: "red", title: "Access suspended", text: `Your access to ${lua} is suspended. Ask the team on Discord if you think this is a mistake.` };
    default:
      if (a.integrationError) return { tone: "amber", title: "Could not check your Discord roles right now", text: `We could not ask Discord, so the role part of your access to ${lua} is unknown. Reload in a minute; this is not the same as having no access.` };
      return { tone: "gray", title: "No access", text: `You do not have access to ${lua}. Access comes from a Discord role or a grant from the team.` };
  }
}

export function canUse(a: AccessResult): boolean {
  return hasAccess(a.status);
}
