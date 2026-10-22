// Browser side calls to the real API. Nothing here pretends: a failed request returns the API's own message.
export type ApiProblem = { code?: string; message: string; path?: string };

export type ApiResult<T = unknown> =
  | { ok: true; status: number; data: T; response: Response }
  | { ok: false; status: number; code: string; message: string; problems: ApiProblem[] };

function fallbackMessage(status: number): string {
  if (status === 401) return "Your session has ended. Sign in again.";
  if (status === 403) return "You are not allowed to do this.";
  if (status === 404) return "Not found.";
  if (status === 413) return "That is too large.";
  if (status === 429) return "Too many requests. Wait a moment and try again.";
  if (status >= 500) return "The server had a problem. Try again in a moment.";
  return "The request failed.";
}

export async function call<T = unknown>(url: string, init: RequestInit = {}): Promise<ApiResult<T>> {
  let res: Response;
  try {
    res = await fetch(url, { credentials: "same-origin", cache: "no-store", ...init });
  } catch {
    return { ok: false, status: 0, code: "network", message: "Could not reach the server. Check your connection and try again.", problems: [] };
  }
  if (res.ok) {
    let data: unknown = null;
    if ((res.headers.get("content-type") ?? "").includes("application/json")) {
      try {
        data = await res.clone().json();
      } catch {
        data = null;
      }
    }
    return { ok: true, status: res.status, data: data as T, response: res };
  }
  let err: { code?: string; message?: string; details?: unknown } | undefined;
  try {
    err = (await res.json())?.error;
  } catch {
    err = undefined;
  }
  const problems: ApiProblem[] = Array.isArray(err?.details)
    ? (err!.details as { code?: string; message?: string; path?: string }[]).filter((d) => d && typeof d.message === "string").map((d) => ({ code: d.code, message: d.message as string, path: d.path }))
    : [];
  return { ok: false, status: res.status, code: err?.code ?? "error", message: err?.message ?? fallbackMessage(res.status), problems };
}

export function sendJson<T = unknown>(url: string, method: "POST" | "PATCH" | "DELETE" | "PUT", body?: unknown): Promise<ApiResult<T>> {
  return call<T>(url, {
    method,
    headers: body === undefined ? undefined : { "content-type": "application/json" },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
}

export async function copyText(text: string): Promise<boolean> {
  try {
    await navigator.clipboard.writeText(text);
    return true;
  } catch {
    try {
      const area = document.createElement("textarea");
      area.value = text;
      area.setAttribute("readonly", "");
      area.style.position = "fixed";
      area.style.opacity = "0";
      document.body.appendChild(area);
      area.select();
      const ok = document.execCommand("copy");
      area.remove();
      return ok;
    } catch {
      return false;
    }
  }
}

export function formatBytes(n: number): string {
  if (n < 1024) return `${n} B`;
  if (n < 1024 * 1024) return `${(n / 1024).toFixed(n < 10240 ? 1 : 0)} KB`;
  return `${(n / 1024 / 1024).toFixed(1)} MB`;
}
