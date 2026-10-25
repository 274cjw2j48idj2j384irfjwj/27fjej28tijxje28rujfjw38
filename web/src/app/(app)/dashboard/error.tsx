"use client";

import { ErrorState } from "@/components/ui";

export default function DashboardError({ reset }: { error: Error; reset: () => void }) {
  return (
    <div className="space-y-4">
      <ErrorState title="This page could not be loaded">Something went wrong while reading your data. Nothing was changed.</ErrorState>
      <div className="text-center">
        <button type="button" className="btn-ghost btn-sm" onClick={reset}>Try again</button>
      </div>
    </div>
  );
}
