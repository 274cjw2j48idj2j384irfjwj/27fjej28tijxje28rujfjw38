import type { Metadata, Viewport } from "next";
import type { ReactNode } from "react";
import "./globals.css";
import { site } from "@/config/site";
import { CommandPalette } from "@/components/command-palette";

export const metadata: Metadata = {
  metadataBase: new URL(site.url),
  title: { default: "SPECTER", template: "%s | SPECTER" },
  description: "Two Luas, one cloud. Manage your access with Discord, share configs and climb the monthly leaderboard.",
  robots: { index: true, follow: true },
};

export const viewport: Viewport = { themeColor: "#07060b", colorScheme: "dark" };

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="en">
      <body>
        <a href="#main" className="sr-only focus:not-sr-only focus:fixed focus:left-4 focus:top-4 focus:z-[100] focus:rounded-lg focus:bg-violet-600 focus:px-4 focus:py-2">
          Skip to content
        </a>
        <div className="relative z-10">{children}</div>
        <CommandPalette />
      </body>
    </html>
  );
}
