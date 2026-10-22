import { NextResponse, type NextRequest } from "next/server";

// Gives the server components the path (and query) of the request, so a signed out visitor of a deep link comes back to it after the sign in.
export function middleware(req: NextRequest) {
  const headers = new Headers(req.headers);
  headers.set("x-pathname", `${req.nextUrl.pathname}${req.nextUrl.search}`);
  return NextResponse.next({ request: { headers } });
}

export const config = { matcher: ["/dashboard/:path*", "/admin/:path*", "/link"] };
