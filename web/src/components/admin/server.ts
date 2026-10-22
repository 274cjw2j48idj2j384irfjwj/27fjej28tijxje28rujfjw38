import { currentUser, isAdmin, isOwner } from "@/lib/authz";
import type { SessionUser } from "@/lib/sessions";

// The layout shows "Access denied" to non admins; pages call this too so they never query admin data for them.
export async function adminPageUser(): Promise<(SessionUser & { owner: boolean }) | null> {
  const u = await currentUser();
  if (!u || u.suspended || !isAdmin(u)) return null;
  return { ...u, owner: isOwner(u) };
}

export function metaText(meta: unknown): string {
  if (!meta || typeof meta !== "object") return "";
  return Object.entries(meta as Record<string, unknown>)
    .map(([k, v]) => `${k}: ${typeof v === "object" && v !== null ? JSON.stringify(v) : String(v)}`)
    .join(" · ");
}
