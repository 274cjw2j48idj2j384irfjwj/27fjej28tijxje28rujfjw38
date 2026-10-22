import type { ReactNode } from "react";
import { SiteFooter, SiteHeader } from "@/components/header";

export default function SiteLayout({ children }: { children: ReactNode }) {
  return (
    <>
      <SiteHeader />
      <main id="main" className="mx-auto max-w-6xl px-4 pt-12 sm:px-6 sm:pt-16">
        {children}
      </main>
      <SiteFooter />
    </>
  );
}
