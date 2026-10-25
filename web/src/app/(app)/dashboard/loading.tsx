export default function Loading() {
  return (
    <div role="status" aria-label="Loading" className="animate-pulse space-y-6">
      <div className="space-y-3">
        <div className="h-3 w-24 rounded bg-white/[0.06]" />
        <div className="h-9 w-72 max-w-full rounded-lg bg-white/[0.07]" />
        <div className="h-4 w-96 max-w-full rounded bg-white/[0.04]" />
      </div>
      <div className="grid gap-4 sm:grid-cols-2">
        <div className="card h-44" />
        <div className="card h-44" />
      </div>
      <div className="grid grid-cols-2 gap-4 sm:grid-cols-4">
        {[0, 1, 2, 3].map((i) => <div key={i} className="card h-24" />)}
      </div>
      <span className="sr-only">Loading</span>
    </div>
  );
}
