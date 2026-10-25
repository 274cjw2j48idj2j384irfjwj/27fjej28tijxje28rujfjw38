import { assertSameOrigin, requireAdmin } from "./authz";
import type { SessionUser } from "./sessions";

// Every admin route starts here: signed in, admin, and (for writes) coming from our own pages.
export async function adminOnly(req: Request): Promise<SessionUser> {
  if (req.method !== "GET") assertSameOrigin(req);
  return requireAdmin();
}
