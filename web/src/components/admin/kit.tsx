"use client";

import { useRouter } from "next/navigation";
import { useCallback, useEffect, useId, useRef, useState, type ReactNode } from "react";
import { cx } from "@/components/ui";

export type ApiResult<T = Record<string, unknown>> = T;

// One place that talks to the admin API: a failed request throws the API's error.message, nothing is faked.
export async function callApi<T = Record<string, unknown>>(url: string, init: { method?: string; json?: unknown; raw?: BodyInit; contentType?: string } = {}): Promise<T> {
  const headers: Record<string, string> = {};
  let body: BodyInit | undefined;
  if (init.json !== undefined) {
    headers["content-type"] = "application/json";
    body = JSON.stringify(init.json);
  } else if (init.raw !== undefined) {
    body = init.raw;
    if (init.contentType) headers["content-type"] = init.contentType;
  }
  let res: Response;
  try {
    res = await fetch(url, { method: init.method ?? (body ? "POST" : "GET"), headers, body, cache: "no-store" });
  } catch {
    throw new Error("The server could not be reached. Check your connection and try again.");
  }
  let data: unknown = null;
  try {
    data = await res.json();
  } catch {
    /* empty body */
  }
  if (!res.ok) {
    const msg = (data as { error?: { message?: string } } | null)?.error?.message;
    throw new Error(msg || `Request failed (${res.status}).`);
  }
  return data as T;
}

export type Run = {
  busy: boolean;
  error: string | null;
  done: string | null;
  run: (fn: () => Promise<unknown>, success?: string, opts?: { refresh?: boolean }) => Promise<boolean>;
  reset: () => void;
};

// Runs an API action: busy flag, the API's error message on failure, router.refresh() on success.
export function useRun(): Run {
  const router = useRouter();
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [done, setDone] = useState<string | null>(null);
  const run = useCallback(
    async (fn: () => Promise<unknown>, success = "Saved.", opts: { refresh?: boolean } = {}) => {
      setBusy(true);
      setError(null);
      setDone(null);
      try {
        await fn();
        setDone(success);
        if (opts.refresh !== false) router.refresh();
        return true;
      } catch (e) {
        setError(e instanceof Error ? e.message : "Something went wrong.");
        return false;
      } finally {
        setBusy(false);
      }
    },
    [router],
  );
  const reset = useCallback(() => {
    setError(null);
    setDone(null);
  }, []);
  return { busy, error, done, run, reset };
}

export function Feedback({ run, className }: { run: Pick<Run, "error" | "done">; className?: string }) {
  if (run.error) return <p role="alert" className={cx("rounded-lg border border-red-400/25 bg-red-500/[0.07] px-3 py-2 text-sm text-red-200", className)}>{run.error}</p>;
  if (run.done) return <p role="status" className={cx("rounded-lg border border-emerald-400/25 bg-emerald-500/[0.07] px-3 py-2 text-sm text-emerald-200", className)}>{run.done}</p>;
  return null;
}

// A button that, when `confirm` is set, first turns into "Sure? Yes / Cancel" (keyboard friendly, no native dialog).
export function ActionButton({
  children, onRun, confirm, variant = "ghost", small = true, disabled, className, success, label,
}: {
  children: ReactNode; onRun: () => Promise<unknown>; confirm?: string; variant?: "ghost" | "danger" | "primary"; small?: boolean; disabled?: boolean; className?: string; success?: string; label?: string;
}) {
  const r = useRun();
  const [asking, setAsking] = useState(false);
  const yes = useRef<HTMLButtonElement>(null);
  useEffect(() => {
    if (asking) yes.current?.focus();
  }, [asking]);
  const cls = cx(variant === "primary" ? "btn-primary" : variant === "danger" ? "btn-danger" : "btn-ghost", small && "btn-sm");
  const go = async () => {
    setAsking(false);
    await r.run(onRun, success ?? "Done.");
  };
  return (
    <span className={cx("inline-flex flex-col items-start gap-1.5", className)}>
      {asking ? (
        <span className="inline-flex flex-wrap items-center gap-2 rounded-xl border border-red-400/25 bg-red-500/[0.06] px-2.5 py-1.5" role="group" aria-label="Confirm">
          <span className="text-xs text-red-100">{confirm}</span>
          <button ref={yes} type="button" onClick={go} className="btn-danger btn-sm">Yes, do it</button>
          <button type="button" onClick={() => setAsking(false)} onKeyDown={(e) => e.key === "Escape" && setAsking(false)} className="btn-ghost btn-sm">Cancel</button>
        </span>
      ) : (
        <button type="button" className={cls} disabled={disabled || r.busy} aria-label={label} onClick={() => (confirm ? setAsking(true) : go())}>
          {r.busy ? "Working..." : children}
        </button>
      )}
      {r.error && <span role="alert" className="max-w-xs text-xs text-red-300">{r.error}</span>}
    </span>
  );
}

export function Switch({ checked, onChange, label, disabled, hint }: { checked: boolean; onChange: (v: boolean) => void; label: string; disabled?: boolean; hint?: ReactNode }) {
  const id = useId();
  return (
    <div className="flex items-start gap-3">
      <button
        id={id}
        type="button"
        role="switch"
        aria-checked={checked}
        disabled={disabled}
        onClick={() => onChange(!checked)}
        className={cx("relative mt-0.5 h-6 w-11 shrink-0 rounded-full border transition disabled:opacity-50", checked ? "border-violet-400/60 bg-violet-600" : "border-line bg-white/[0.06]")}
      >
        <span className={cx("absolute top-0.5 size-4.5 rounded-full bg-white transition-all", checked ? "left-[22px]" : "left-0.5")} style={{ width: 18, height: 18 }} />
        <span className="sr-only">{label}</span>
      </button>
      <label htmlFor={id} className="cursor-pointer text-sm leading-snug text-[color:var(--text)]">
        {label}
        {hint && <span className="muted mt-0.5 block text-xs">{hint}</span>}
      </label>
    </div>
  );
}

export function Field({ label, children, hint, className }: { label: string; children: (id: string) => ReactNode; hint?: ReactNode; className?: string }) {
  const id = useId();
  return (
    <div className={className}>
      <label htmlFor={id} className="label">{label}</label>
      {children(id)}
      {hint && <p className="mt-1.5 text-xs text-[color:var(--faint)]">{hint}</p>}
    </div>
  );
}

export function TableWrap({ children, label }: { children: ReactNode; label: string }) {
  return (
    <div className="card overflow-hidden">
      <div className="scroll-thin overflow-x-auto" role="region" aria-label={label} tabIndex={0}>
        {children}
      </div>
    </div>
  );
}

export const th = "whitespace-nowrap px-4 py-3 text-left text-[11px] font-medium uppercase tracking-wider text-[color:var(--muted)]";
export const td = "px-4 py-3 align-middle text-sm";
