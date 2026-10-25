import type { Metadata } from "next";
import { redirect } from "next/navigation";
import { LinkForm } from "@/components/dashboard/link-form";
import { canUse } from "@/components/dashboard/access";
import { PageHeader } from "@/components/ui";
import { accessAll } from "@/lib/dashboard-data";
import { currentUser } from "@/lib/authz";

export const dynamic = "force-dynamic";
export const metadata: Metadata = { title: "Link a Lua" };

export default async function LinkPage({ searchParams }: { searchParams: Promise<{ code?: string }> }) {
  const sp = await searchParams;
  const code = (sp.code ?? "").toUpperCase().replace(/[^A-Z0-9-]/g, "").slice(0, 12);
  const user = await currentUser();
  if (!user) redirect(`/api/auth/login?next=${encodeURIComponent(code ? `/link?code=${code}` : "/link")}`);
  const access = await accessAll(user.id);
  const products = Object.fromEntries(access.map((a) => [a.product.id, { name: a.product.name, platform: a.product.platform, canUse: canUse(a.access) }]));
  return (
    <div className="mx-auto max-w-lg pb-6">
      <PageHeader eyebrow="Device link" title="Link a Lua to your account">Enter the code your Lua menu shows. You see which Lua is asking before you approve it.</PageHeader>
      <LinkForm initialCode={code} products={products} />
    </div>
  );
}
