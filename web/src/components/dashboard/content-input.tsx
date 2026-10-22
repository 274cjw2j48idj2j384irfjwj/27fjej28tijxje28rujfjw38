"use client";

import { useId, useRef, useState } from "react";
import { FileJson } from "lucide-react";
import { LIMITS } from "@/config/site";
import { formatBytes } from "./api";

export type Template = { product: string; format: number; lua: string };

export type Parsed = { ok: true; value: unknown; bytes: number } | { ok: false; message: string } | null;

export function parseContent(text: string): Parsed {
  if (!text.trim()) return null;
  const bytes = new TextEncoder().encode(text).length;
  if (bytes > LIMITS.configBytes) return { ok: false, message: `That is ${formatBytes(bytes)}. A config can be at most ${LIMITS.configBytes / 1024} KB.` };
  try {
    return { ok: true, value: JSON.parse(text), bytes };
  } catch (e) {
    return { ok: false, message: `Not valid JSON: ${(e as Error).message}` };
  }
}

export function templateText(t: Template): string {
  return JSON.stringify({ meta: { product: t.product, format_version: t.format, lua_version: t.lua }, data: {} }, null, 2);
}

// The content of a config: a .json file or pasted text, parsed in the browser before it is sent. The server still validates everything.
export function ContentInput({ value, onChange, parsed, template, productName }: { value: string; onChange: (v: string) => void; parsed: Parsed; template: Template | null; productName: string }) {
  const id = useId();
  const file = useRef<HTMLInputElement>(null);
  const [fileError, setFileError] = useState("");
  async function pick(f: File | undefined) {
    if (!f) return;
    if (f.size > LIMITS.configBytes * 2) {
      setFileError(`${f.name} is ${formatBytes(f.size)}. A config can be at most ${LIMITS.configBytes / 1024} KB.`);
    } else {
      setFileError("");
      onChange(await f.text());
    }
    if (file.current) file.current.value = "";
  }
  const meta = parsed?.ok && parsed.value && typeof parsed.value === "object" ? (parsed.value as { meta?: { product?: unknown } }).meta : undefined;
  const mismatch = parsed?.ok && typeof meta?.product === "string" && template && meta.product !== template.product;
  return (
    <div>
      <div className="mb-1.5 flex flex-wrap items-center justify-between gap-2">
        <label htmlFor={id} className="label !mb-0">Config content (JSON)</label>
        <div className="flex gap-2">
          <button type="button" className="btn-ghost btn-sm" onClick={() => file.current?.click()}><FileJson size={14} aria-hidden="true" />Choose .json file</button>
          <button type="button" className="btn-ghost btn-sm" disabled={!template} onClick={() => template && onChange(templateText(template))}>Insert template</button>
        </div>
        <input ref={file} type="file" accept=".json,application/json" className="sr-only" tabIndex={-1} aria-label="Choose a .json config file" onChange={(e) => pick(e.target.files?.[0])} />
      </div>
      <textarea
        id={id}
        value={value}
        onChange={(e) => onChange(e.target.value)}
        rows={9}
        spellCheck={false}
        placeholder={`{ "meta": { "product": "...", "format_version": 1, "lua_version": "1.0.0" }, "data": { } }`}
        className="input scroll-thin font-mono text-[12px] leading-relaxed"
        aria-describedby={`${id}-help`}
        aria-invalid={parsed?.ok === false}
      />
      <div id={`${id}-help`} className="mt-2 space-y-1 text-xs leading-relaxed text-[color:var(--faint)]">
        <p>
          Format: <code className="rounded bg-white/[0.05] px-1 font-mono">{`{"meta":{"product","format_version","lua_version"},"data":...}`}</code>. <code className="font-mono">product</code> must match the Lua you pick ({productName}),
          <code className="font-mono"> data</code> is an object or a string. Maximum {LIMITS.configBytes / 1024} KB. Secrets, e-mails and code are refused.
        </p>
        {fileError && <p role="alert" className="text-red-300">{fileError}</p>}
        {parsed?.ok && <p className="text-emerald-300/90">Valid JSON, {formatBytes(parsed.bytes)}.</p>}
        {parsed?.ok === false && <p role="alert" className="text-red-300">{parsed.message}</p>}
        {mismatch && <p className="text-amber-200">The meta.product in this text is {String(meta?.product)}, but you picked {productName}. The server will refuse it.</p>}
      </div>
    </div>
  );
}

export function Problems({ message, problems }: { message: string; problems: { message: string }[] }) {
  const extra = problems.filter((p) => p.message !== message);
  return (
    <div role="alert" className="rounded-xl border border-red-400/30 bg-red-500/10 px-4 py-3 text-sm text-red-100">
      <p className="font-medium">{message}</p>
      {extra.length > 0 && (
        <ul className="mt-2 list-disc space-y-1 pl-5 text-red-200/90">
          {extra.slice(0, 12).map((p, i) => <li key={i}>{p.message}</li>)}
        </ul>
      )}
      {extra.length > 12 && <p className="mt-2 text-xs text-red-200/70">and {extra.length - 12} more.</p>}
    </div>
  );
}
