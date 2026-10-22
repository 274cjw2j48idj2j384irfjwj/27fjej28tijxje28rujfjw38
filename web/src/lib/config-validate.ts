import { z } from "zod";
import { LIMITS, type ProductId } from "@/config/site";

// A config is DATA: {meta, data}. It is stored and handed back as JSON, never executed, and these checks keep tokens,
// personal data and code out of public configs.

export const PRODUCT_IDS = ["gamesense", "primordial"] as const;

const versionRe = /^\d+(\.\d+){0,3}([-+][0-9A-Za-z.-]+)?$/;

export const metaSchema = z.object({
  product: z.enum(PRODUCT_IDS),
  format_version: z.number().int().min(1).max(1000),
  lua_version: z.string().regex(versionRe).max(32),
});

export type ConfigPayload = { meta: z.infer<typeof metaSchema>; data: unknown };

const SECRET_KEY = /(^|[_\-. ])(token|secret|password|passwd|license|licence|hwid|webhook|apikey|api_key|cookie|session)([_\-. ]|$)/i;
const SECRET_VALUE: { name: string; re: RegExp }[] = [
  { name: "GitHub token", re: /\b(github_pat_[A-Za-z0-9_]{20,}|gh[pousr]_[A-Za-z0-9]{20,})/ },
  { name: "Discord token", re: /[A-Za-z0-9_-]{23,28}\.[A-Za-z0-9_-]{6,7}\.[A-Za-z0-9_-]{27,}/ },
  { name: "Discord webhook", re: /discord(app)?\.com\/api\/webhooks\//i },
  { name: "license key", re: /\b[A-Z0-9]{6}-[A-Z0-9]{6}-[A-Z0-9]{6}-[A-Z0-9]{6}\b/ },
  { name: "email address", re: /[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/ },
  { name: "Windows user path", re: /[A-Za-z]:\\Users\\[^\\"]+/i },
];
const CODE_LIKE = /\b(loadstring|dofile|os\.execute|io\.popen|ffi\.cdef|ffi\.load|require\s*\()|function\s*\(/;

const MAX_DEPTH = 16;
const MAX_NODES = 40_000;
const MAX_STRING = 200_000;

export type Problem = { code: string; message: string };

function walk(value: unknown, depth: number, state: { nodes: number }, path: string, out: Problem[]): void {
  if (out.length >= 5) return;
  state.nodes++;
  if (state.nodes > MAX_NODES) {
    out.push({ code: "too_many_values", message: "The config has too many values." });
    return;
  }
  if (depth > MAX_DEPTH) {
    out.push({ code: "too_deep", message: `The config is nested too deep at ${path}.` });
    return;
  }
  if (typeof value === "string") {
    if (value.length > MAX_STRING) out.push({ code: "string_too_long", message: `A value is too long at ${path}.` });
    for (const s of SECRET_VALUE) if (s.re.test(value)) out.push({ code: "secret", message: `The config contains a ${s.name} at ${path}.` });
    if (CODE_LIKE.test(value)) out.push({ code: "code", message: `The config contains code at ${path}. A config is data only.` });
  } else if (Array.isArray(value)) {
    value.forEach((v, i) => walk(v, depth + 1, state, `${path}[${i}]`, out));
  } else if (value && typeof value === "object") {
    for (const [k, v] of Object.entries(value as Record<string, unknown>)) {
      if (SECRET_KEY.test(k)) out.push({ code: "secret_key", message: `The key "${k}" is not allowed in a config.` });
      if (k === "__proto__" || k === "constructor" || k === "prototype") out.push({ code: "bad_key", message: `The key "${k}" is not allowed.` });
      walk(v, depth + 1, state, `${path}.${k}`, out);
    }
  } else if (typeof value === "number" && !Number.isFinite(value)) {
    out.push({ code: "bad_number", message: `A number is not finite at ${path}.` });
  }
}

export type ValidateResult = { ok: true; payload: ConfigPayload; bytes: number } | { ok: false; problems: Problem[] };

export function validatePayload(raw: unknown, expectedProduct: ProductId): ValidateResult {
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) return { ok: false, problems: [{ code: "shape", message: "The config must be an object with meta and data." }] };
  const obj = raw as Record<string, unknown>;
  const meta = metaSchema.safeParse(obj.meta);
  if (!meta.success) return { ok: false, problems: [{ code: "meta", message: "meta needs product, format_version and lua_version." }] };
  if (meta.data.product !== expectedProduct) {
    return { ok: false, problems: [{ code: "wrong_product", message: `This config is for ${meta.data.product}, not for ${expectedProduct}.` }] };
  }
  if (!("data" in obj) || obj.data === null || obj.data === undefined || (typeof obj.data !== "object" && typeof obj.data !== "string")) {
    return { ok: false, problems: [{ code: "data", message: "data must be an object or a string." }] };
  }
  const extra = Object.keys(obj).filter((k) => k !== "meta" && k !== "data");
  if (extra.length) return { ok: false, problems: [{ code: "extra_keys", message: `Unknown top level keys: ${extra.join(", ")}.` }] };

  let text: string;
  try {
    text = JSON.stringify(obj);
  } catch {
    return { ok: false, problems: [{ code: "json", message: "The config is not valid JSON." }] };
  }
  const bytes = Buffer.byteLength(text, "utf8");
  if (bytes > LIMITS.configBytes) return { ok: false, problems: [{ code: "too_big", message: `The config is larger than ${LIMITS.configBytes / 1024} KB.` }] };

  const problems: Problem[] = [];
  walk(obj.data, 0, { nodes: 0 }, "data", problems);
  if (problems.length) return { ok: false, problems };
  return { ok: true, payload: { meta: meta.data, data: obj.data }, bytes };
}

export function compareVersions(a: string, b: string): number {
  const pa = a.split(/[-+]/)[0].split(".").map((n) => parseInt(n, 10) || 0);
  const pb = b.split(/[-+]/)[0].split(".").map((n) => parseInt(n, 10) || 0);
  for (let i = 0; i < Math.max(pa.length, pb.length); i++) {
    const d = (pa[i] ?? 0) - (pb[i] ?? 0);
    if (d) return d < 0 ? -1 : 1;
  }
  return 0;
}

export type CompatResult = { ok: boolean; reason: "wrong_product" | "format_too_old" | "format_too_new" | null; outdated: boolean };

// Can the Lua of `productId` import this config version? Wrong product and an unsupported format are hard stops;
// a config made with an older Lua version is only marked outdated.
export function checkCompat(
  meta: { product: string; format_version: number; lua_version: string },
  target: { id: string; min_format: number; max_format: number; latest_version: string },
): CompatResult {
  if (meta.product !== target.id) return { ok: false, reason: "wrong_product", outdated: false };
  if (meta.format_version < target.min_format) return { ok: false, reason: "format_too_old", outdated: true };
  if (meta.format_version > target.max_format) return { ok: false, reason: "format_too_new", outdated: false };
  const outdated = !!target.latest_version && compareVersions(meta.lua_version, target.latest_version) < 0;
  return { ok: true, reason: null, outdated };
}

const CONTROL = /[\u0000-\u001f\u007f\u200b-\u200f\u2028-\u202e\u2060-\u206f\ufeff]/g;
const CONTROL_KEEP_NEWLINE = /[\u0000-\u0009\u000b-\u001f\u007f\u200b-\u200f\u2028-\u202e\u2060-\u206f\ufeff]/g;

export function cleanText(s: string, max: number): string {
  return s.replace(CONTROL, " ").replace(/\s+/g, " ").trim().slice(0, max);
}

export function cleanMultiline(s: string, max: number): string {
  return s.replace(/\r\n?/g, "\n").replace(CONTROL_KEEP_NEWLINE, "").replace(/\n{3,}/g, "\n\n").trim().slice(0, max);
}

export function cleanTags(tags: string[]): string[] {
  const out = new Set<string>();
  for (const t of tags) {
    const c = cleanText(t, LIMITS.tagLen).toLowerCase().replace(/[^a-z0-9 _-]/g, "").trim();
    if (c) out.add(c);
    if (out.size >= LIMITS.maxTags) break;
  }
  return [...out];
}
