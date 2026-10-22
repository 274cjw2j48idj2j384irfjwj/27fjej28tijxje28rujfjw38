import { NextResponse } from "next/server";
import { randomBytes } from "node:crypto";
import { authorizeUrl, discordConfigured } from "@/lib/discord";
import { safeNext } from "@/lib/authz";
import { site } from "@/config/site";

export const dynamic = "force-dynamic";

export async function GET(req: Request) {
  if (!discordConfigured()) return NextResponse.redirect(`${site.url}/login?error=not_configured`, 303);
  const state = randomBytes(24).toString("base64url");
  const next = safeNext(new URL(req.url).searchParams.get("next"));
  const res = NextResponse.redirect(authorizeUrl(state), 303);
  const opts = { httpOnly: true, sameSite: "lax" as const, secure: site.url.startsWith("https"), path: "/", maxAge: 600 };
  res.cookies.set("specter_oauth_state", state, opts);
  res.cookies.set("specter_oauth_next", next, opts);
  return res;
}
