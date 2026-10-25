// Compares two config payloads (their `data`) and lists what changed, key by key. Pure, used by the version compare view.
export type DiffEntry = { path: string; kind: "added" | "removed" | "changed"; before?: unknown; after?: unknown };

const MAX_ENTRIES = 300;

function isObj(v: unknown): v is Record<string, unknown> {
  return !!v && typeof v === "object" && !Array.isArray(v);
}

function walk(a: unknown, b: unknown, path: string, out: DiffEntry[]): void {
  if (out.length >= MAX_ENTRIES) return;
  if (isObj(a) && isObj(b)) {
    const keys = new Set([...Object.keys(a), ...Object.keys(b)]);
    for (const k of [...keys].sort()) {
      if (out.length >= MAX_ENTRIES) return;
      const p = path ? `${path}.${k}` : k;
      if (!(k in a)) out.push({ path: p, kind: "added", after: b[k] });
      else if (!(k in b)) out.push({ path: p, kind: "removed", before: a[k] });
      else walk(a[k], b[k], p, out);
    }
    return;
  }
  if (Array.isArray(a) && Array.isArray(b)) {
    const n = Math.max(a.length, b.length);
    for (let i = 0; i < n; i++) {
      if (out.length >= MAX_ENTRIES) return;
      const p = `${path}[${i}]`;
      if (i >= a.length) out.push({ path: p, kind: "added", after: b[i] });
      else if (i >= b.length) out.push({ path: p, kind: "removed", before: a[i] });
      else walk(a[i], b[i], p, out);
    }
    return;
  }
  if (JSON.stringify(a) !== JSON.stringify(b)) out.push({ path: path || "(root)", kind: "changed", before: a, after: b });
}

export function diffData(before: unknown, after: unknown): { entries: DiffEntry[]; truncated: boolean } {
  const entries: DiffEntry[] = [];
  walk(before, after, "", entries);
  return { entries, truncated: entries.length >= MAX_ENTRIES };
}

export function shortValue(v: unknown, max = 60): string {
  const s = typeof v === "string" ? v : JSON.stringify(v);
  return s.length > max ? `${s.slice(0, max)}...` : s;
}
