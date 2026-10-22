import { NextResponse } from "next/server";
import { cookies } from "next/headers";
import { site } from "@/config/site";
import { adminIds, safeNext } from "@/lib/authz";
import { safeEqual } from "@/lib/crypto";
import { exchangeCode, fetchUser } from "@/lib/discord";
import { rateLimit, clientIp } from "@/lib/rate-limit";
import { createSession, SESSION_COOKIE, SESSION_DAYS, upsertUser } from "@/lib/sessions";
import { audit } from "@/lib/audit";

export const dynamic = "force-dynamic";

function back(error: string): NextResponse {
  return NextResponse.redirect(`${site.url}/login?error=${error}`, 303);
}

export async function GET(req: Request) {
  const url = new URL(req.url);
  const jar = await cookies();
  const state = jar.get("specter_oauth_state")?.value ?? "";
  const next = safeNext(jar.get("specter_oauth_next")?.value);
  const code = url.searchParams.get("code");
  const given = url.searchParams.get("state") ?? "";
  if (url.searchParams.get("error")) return back("denied");
  if (!code || !state || !safeEqual(state, given)) return back("state");
  try {
    await rateLimit(`login:${clientIp(req.headers)}`, 30, 600);
    const token = await exchangeCode(code);
    const du = await fetchUser(token);
    const user = await upsertUser(du, adminIds());
    if (user.suspended) return back("suspended");
    const session = await createSession(user.id, req.headers.get("user-agent"));
    await audit(user.id, "auth.login", "user", user.id);
    const res = NextResponse.redirect(`${site.url}${next}`, 303);
    res.cookies.set(SESSION_COOKIE, session.token, {
      httpOnly: true,
      sameSite: "lax",
      secure: site.url.startsWith("https"),
      path: "/",
      maxAge: SESSION_DAYS * 86400,
    });
    res.cookies.delete("specter_oauth_state");
    res.cookies.delete("specter_oauth_next");
    return res;
  } catch (err) {
    console.error("discord login failed", (err as Error).message);
    return back("discord");
  }
}
