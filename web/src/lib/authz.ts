import { cookies } from "next/headers";
import { site, type ProductId } from "@/config/site";
import { hasAccess, resolveAccess, type AccessResult, type MemberFetcher } from "./access";
import { ApiError } from "./configs";
import { fetchMember, discordConfigured } from "./discord";
import { SESSION_COOKIE, userFromSession, type SessionUser } from "./sessions";
import { authenticateToken, type ClientScope, type TokenAuth } from "./devices";
import { clientIp, rateLimit } from "./rate-limit";

export function adminIds(): string[] {
  return (process.env.ADMIN_DISCORD_IDS ?? "").split(",").map((s) => s.trim()).filter(Boolean);
}

export function isOwner(user: Pick<SessionUser, "discord_id">): boolean {
  return adminIds().includes(user.discord_id);
}

export function isAdmin(user: Pick<SessionUser, "discord_id" | "is_admin">): boolean {
  return user.is_admin || isOwner(user);
}

export const discordFetcher: MemberFetcher = async (discordId) => {
  if (!discordConfigured()) throw new Error("Discord is not configured");
  return fetchMember(discordId);
};

export async function currentUser(): Promise<SessionUser | null> {
  const jar = await cookies();
  return userFromSession(jar.get(SESSION_COOKIE)?.value);
}

export async function requireUser(): Promise<SessionUser> {
  const user = await currentUser();
  if (!user) throw new ApiError(401, "unauthenticated", "Sign in with Discord first.");
  if (user.suspended) throw new ApiError(403, "suspended", "This account is suspended.");
  return user;
}

export async function requireAdmin(): Promise<SessionUser> {
  const user = await requireUser();
  if (!isAdmin(user)) throw new ApiError(403, "forbidden", "Admins only.");
  return user;
}

// Cookie authenticated writes must come from our own pages (the cookie is SameSite=Lax as well).
export function assertSameOrigin(req: Request): void {
  const origin = req.headers.get("origin");
  const fetchSite = req.headers.get("sec-fetch-site");
  const allowed = new URL(site.url).origin;
  if (origin) {
    if (origin !== allowed) throw new ApiError(403, "bad_origin", "Cross site request refused.");
    return;
  }
  if (fetchSite && fetchSite !== "same-origin" && fetchSite !== "none") throw new ApiError(403, "bad_origin", "Cross site request refused.");
  if (!fetchSite) throw new ApiError(403, "bad_origin", "Missing origin.");
}

export async function accessOf(userId: string, productId: ProductId): Promise<AccessResult> {
  return resolveAccess(userId, productId, discordFetcher);
}

// The backend check behind every protected action: a status that does not give access is refused here, whatever the page showed.
export async function requireProductAccess(userId: string, productId: ProductId): Promise<AccessResult> {
  const access = await accessOf(userId, productId);
  if (hasAccess(access.status)) return access;
  if (access.status === "suspended") throw new ApiError(403, "suspended", "Your access to this product is suspended.");
  if (access.integrationError) throw new ApiError(503, "discord_unavailable", "Could not check your Discord roles right now. Try again in a minute.");
  if (access.status === "expired") throw new ApiError(403, "expired", "Your access has expired.");
  throw new ApiError(403, "no_access", "You do not have access to this product.");
}

export async function requireToken(req: Request, scope: ClientScope): Promise<TokenAuth> {
  const h = req.headers.get("authorization") ?? "";
  const raw = h.toLowerCase().startsWith("bearer ") ? h.slice(7).trim() : "";
  await rateLimit(`tok:${clientIp(req.headers)}`, 600, 60);
  const auth = await authenticateToken(raw);
  if (!auth) throw new ApiError(401, "bad_token", "The token is missing, expired or revoked.");
  if (!auth.scopes.includes(scope)) throw new ApiError(403, "scope", `The token has no ${scope} scope.`);
  return auth;
}

export function safeNext(next: string | null | undefined): string {
  if (!next || !next.startsWith("/") || next.startsWith("//") || next.includes("\\")) return "/dashboard";
  return next;
}
