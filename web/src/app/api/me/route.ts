import { getProducts } from "@/config/site";
import { accessOf, isAdmin, requireUser } from "@/lib/authz";
import { api, json } from "@/lib/http";
import { avatarUrl } from "@/lib/discord";

export const dynamic = "force-dynamic";

export const GET = api(async () => {
  const user = await requireUser();
  const access = Object.fromEntries(await Promise.all(getProducts().map(async (p) => [p.id, await accessOf(user.id, p.id)])));
  return json({
    user: { id: user.id, discordId: user.discord_id, name: user.global_name || user.username, avatar: avatarUrl(user.discord_id, user.avatar), isAdmin: isAdmin(user), verifiedCreator: user.verified_creator },
    access,
  });
});
