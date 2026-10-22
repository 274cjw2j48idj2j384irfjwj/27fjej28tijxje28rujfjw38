import { requireProductAccess, requireToken } from "@/lib/authz";
import { libraryOf } from "@/lib/configs";
import { api, json } from "@/lib/http";
import { publicConfig } from "@/lib/config-api";

export const dynamic = "force-dynamic";

// "Saved Configs": the library of the user for the Lua of the token, with a flag when the author has a newer version.
export const GET = api(async (req) => {
  const auth = await requireToken(req, "library:read");
  await requireProductAccess(auth.userId, auth.productId);
  const items = await libraryOf(auth.userId, auth.productId);
  return json({ items: items.map((c) => ({ ...publicConfig(c), savedVersion: c.saved_version, updateAvailable: c.update_available })) });
});
