import { RoleManager } from "@/components/admin/role-manager";
import { adminPageUser } from "@/components/admin/server";
import { Badge, Notice, PageHeader } from "@/components/ui";
import { getProducts } from "@/config/site";
import { listRoleMappings } from "@/lib/admin";
import { discordConfigured } from "@/lib/discord";

export const dynamic = "force-dynamic";

export default async function RolesPage() {
  if (!(await adminPageUser())) return null;
  const mappings = await listRoleMappings();
  const products = getProducts();
  const configured = discordConfigured();
  return (
    <div className="space-y-8">
      <PageHeader eyebrow="Admin" title="Discord Role Mapping" actions={<Badge tone={configured ? "green" : "amber"}>Discord {configured ? "configured" : "not configured"}</Badge>}>
        A member who has any mapped role in the Specter server gets access to that Lua. Each Lua has its own list; one never unlocks the other.
      </PageHeader>
      {!configured && <Notice tone="amber">The Discord integration is not configured on this server (DISCORD_CLIENT_ID, DISCORD_CLIENT_SECRET, DISCORD_BOT_TOKEN or DISCORD_GUILD_ID is missing). Mappings are stored, but roles cannot be checked until it is set up: only admin grants and rewards give access.</Notice>}
      <Notice>
        Fallback: while a Lua has no rows here, the environment variables <code className="font-mono text-violet-200">LUA1_ROLE_IDS</code> (Gamesense) and <code className="font-mono text-violet-200">LUA2_ROLE_IDS</code> (Primordial) are used. The first row you add for a Lua replaces its environment list.
      </Notice>
      <RoleManager
        products={products.map((p) => ({ id: p.id, name: p.name, envIds: p.discordRoleIds }))}
        mappings={mappings.map((m) => ({ id: m.id, product: m.product_id, roleId: m.discord_role_id, label: m.label }))}
      />
    </div>
  );
}
