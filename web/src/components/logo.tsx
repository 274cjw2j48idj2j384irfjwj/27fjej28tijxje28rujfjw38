// The crescent of the Specter watermark: an accent disc with a smaller disc cut out of it.
export function Logo({ size = 28, className }: { size?: number; className?: string }) {
  return (
    <svg width={size} height={size} viewBox="0 0 32 32" className={className} aria-hidden="true">
      <defs>
        <linearGradient id="sg" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0" stopColor="#ddd6fe" />
          <stop offset="1" stopColor="#8b5cf6" />
        </linearGradient>
        <mask id="sm">
          <rect width="32" height="32" fill="#fff" />
          <circle cx="21.2" cy="12.4" r="10.8" fill="#000" />
        </mask>
      </defs>
      <circle cx="16" cy="16" r="12.8" fill="url(#sg)" mask="url(#sm)" />
    </svg>
  );
}

export function Wordmark({ className }: { className?: string }) {
  return <span className={`wordmark text-[17px] font-semibold tracking-[0.32em] ${className ?? ""}`}>SPECTER</span>;
}
