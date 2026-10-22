import { adminPageUser } from "@/components/admin/server";
import { PlanManager } from "@/components/admin/plan-manager";
import { Notice, PageHeader } from "@/components/ui";
import { providerConfigured } from "@/lib/orders";
import { licenseServerConfigured } from "@/lib/license-server";
import { listPlans } from "@/lib/plans";

export const dynamic = "force-dynamic";

export default async function PlansPage() {
  if (!(await adminPageUser())) return null;
  const plans = await listPlans();
  const card = providerConfigured("stripe");
  const crypto = providerConfigured("nowpayments");
  return (
    <div className="space-y-8 pb-4">
      <PageHeader eyebrow="Admin" title="Plans">What is on sale. Prices and plans are edited here; an order keeps the price it was bought with.</PageHeader>
      {(!card || !crypto || !licenseServerConfigured()) && (
        <Notice tone="amber">
          Not configured on this server: {[!licenseServerConfigured() && "license server (LICENSE_SERVER_URL, LICENSE_ADMIN_SECRET)", !providerConfigured("stripe") && "card payments (STRIPE_*)", !providerConfigured("nowpayments") && "crypto payments (NOWPAYMENTS_*)"].filter(Boolean).join(", ")}. The matching buttons on the pricing page stay disabled.
        </Notice>
      )}
      <PlanManager plans={plans.map(({ created_at: _c, updated_at: _u, ...p }) => p)} />
    </div>
  );
}
