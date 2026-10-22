import { NextResponse } from "next/server";
import { assertSameOrigin, currentUser } from "@/lib/authz";
import { ApiError } from "@/lib/configs";
import { api } from "@/lib/http";
import { audit } from "@/lib/audit";
import { destroyAllSessions, SESSION_COOKIE } from "@/lib/sessions";

export const dynamic = "force-dynamic";

// "Sign out everywhere": every session of the user ends, this browser's cookie goes with them.
export const DELETE = api(async (req) => {
  assertSameOrigin(req);
  const user = await currentUser(); // a suspended account may still sign out
  if (!user) throw new ApiError(401, "unauthenticated", "Sign in with Discord first.");
  await destroyAllSessions(user.id);
  await audit(user.id, "auth.logout_all", "user", user.id);
  const res = NextResponse.json({ ok: true }, { headers: { "cache-control": "no-store" } });
  res.cookies.delete(SESSION_COOKIE);
  return res;
});
