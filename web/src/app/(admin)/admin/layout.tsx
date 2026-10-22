import { redirect } from "next/navigation";
import type { ReactNode } from "react";
import { AdminNav } from "@/components/admin/admin-nav";
import { SiteFooter, SiteHeader } from "@/components/header";
import { ButtonLink, EmptyState } from "@/components/ui";
import { currentUser, isAdmin } from "@/lib/authz";

export const dynamic = "force-dynamic";
export const metadata = { title: "Admin", robots: { index: false, follow: false } };

export default async function AdminLayout({ children }: { children: ReactNode }) {
  const user = await currentUser();
  if (!user) redirect("/api/auth/login?next=/admin");
  const allowed = isAdmin(user) && !user.suspended;
  return (
    <>
      <SiteHeader />
      <main id="main" className="mx-auto max-w-6xl px-4 pt-10 sm:px-6 sm:pt-12">
        {allowed ? (
          <div className="grid grid-cols-[minmax(0,1fr)] gap-8 lg:grid-cols-[220px_minmax(0,1fr)]">
            <AdminNav />
            <div className="min-w-0">{children}</div>
          </div>
        ) : (
          <div className="mx-auto max-w-lg py-10">
            <EmptyState title="Access denied" action={<ButtonLink href="/dashboard" variant="ghost" small>Go to your dashboard</ButtonLink>}>
              The admin area is only for the Specter team. You are signed in as {user.global_name || user.username}, which has no admin rights.
            </EmptyState>
          </div>
        )}
      </main>
      <SiteFooter />
    </>
  );
}
