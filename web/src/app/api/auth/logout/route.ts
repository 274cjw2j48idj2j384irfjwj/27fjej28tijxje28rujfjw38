import { NextResponse } from "next/server";
import { cookies } from "next/headers";
import { api } from "@/lib/http";
import { assertSameOrigin } from "@/lib/authz";
import { destroySession, SESSION_COOKIE } from "@/lib/sessions";

export const dynamic = "force-dynamic";

export const POST = api(async (req) => {
  assertSameOrigin(req);
  const jar = await cookies();
  await destroySession(jar.get(SESSION_COOKIE)?.value);
  const res = NextResponse.json({ ok: true });
  res.cookies.delete(SESSION_COOKIE);
  return res;
});
