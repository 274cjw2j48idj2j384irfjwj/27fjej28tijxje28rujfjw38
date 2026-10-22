import { z } from "zod";
import { adminOnly } from "@/lib/admin-http";
import { isOwner, accessOf } from "@/lib/authz";
import { ApiError } from "@/lib/configs";
import { grantAccess, grantSchema, revokeGrant, setAdminFlag, setPlatformBan, setProductSuspension, setVerifiedCreator, userDetail } from "@/lib/admin";
import { api, body, json } from "@/lib/http";
import { getProducts } from "@/config/site";

export const dynamic = "force-dynamic";

export const GET = api<{ id: string }>(async (req, { params }) => {
  await adminOnly(req);
  const d = await userDetail(params.id);
  if (!d) throw new ApiError(404, "not_found", "User not found.");
  const access = Object.fromEntries(await Promise.all(getProducts().map(async (p) => [p.id, await accessOf(params.id, p.id)])));
  return json({ ...d, access });
});

const actionSchema = z.discriminatedUnion("action", [
  z.object({ action: z.literal("grant") }).merge(grantSchema),
  z.object({ action: z.literal("revoke_grant"), grant_id: z.string().uuid() }),
  z.object({ action: z.literal("suspend"), product: z.enum(["gamesense", "primordial"]), reason: z.string().max(200).optional() }),
  z.object({ action: z.literal("unsuspend"), product: z.enum(["gamesense", "primordial"]) }),
  z.object({ action: z.literal("ban") }),
  z.object({ action: z.literal("unban") }),
  z.object({ action: z.literal("verify") }),
  z.object({ action: z.literal("unverify") }),
  z.object({ action: z.literal("make_admin") }),
  z.object({ action: z.literal("remove_admin") }),
]);

export const POST = api<{ id: string }>(async (req, { params }) => {
  const admin = await adminOnly(req);
  const input = await body(req, actionSchema, 4096);
  switch (input.action) {
    case "grant":
      return json({ grant: await grantAccess(admin.id, params.id, input.product, input.days, input.note), ok: true });
    case "revoke_grant":
      await revokeGrant(admin.id, input.grant_id);
      break;
    case "suspend":
      await setProductSuspension(admin.id, params.id, input.product, true, input.reason);
      break;
    case "unsuspend":
      await setProductSuspension(admin.id, params.id, input.product, false);
      break;
    case "ban":
    case "unban":
      if (params.id === admin.id) throw new ApiError(400, "self", "You cannot ban yourself.");
      await setPlatformBan(admin.id, params.id, input.action === "ban");
      break;
    case "verify":
    case "unverify":
      await setVerifiedCreator(admin.id, params.id, input.action === "verify");
      break;
    case "make_admin":
    case "remove_admin":
      if (!isOwner(admin)) throw new ApiError(403, "owner_only", "Only the owners can change admin rights.");
      await setAdminFlag(admin.id, params.id, input.action === "make_admin");
      break;
  }
  return json({ ok: true });
});
