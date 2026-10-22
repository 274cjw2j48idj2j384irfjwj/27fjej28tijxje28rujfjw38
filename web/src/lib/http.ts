import { NextResponse } from "next/server";
import { ZodError, type ZodTypeAny, type z } from "zod";
import { ApiError } from "./configs";

export function json(data: unknown, status = 200, headers: Record<string, string> = {}): NextResponse {
  return NextResponse.json(data, { status, headers: { "cache-control": "no-store", ...headers } });
}

export function fail(err: unknown): NextResponse {
  if (err instanceof ApiError) return json({ error: { code: err.code, message: err.message, details: err.details } }, err.status);
  if (err instanceof ZodError) return json({ error: { code: "bad_request", message: err.issues[0]?.message ?? "Bad request", details: err.issues.map((i) => ({ path: i.path.join("."), message: i.message })) } }, 400);
  console.error("unhandled api error", err);
  return json({ error: { code: "server_error", message: "Something went wrong." } }, 500);
}

type Ctx<P> = { params: Promise<P> };

// Wraps a route handler: ApiError and validation errors become JSON answers, anything else a plain 500.
export function api<P = Record<string, never>>(fn: (req: Request, ctx: { params: P }) => Promise<NextResponse | Response>) {
  return async (req: Request, ctx: Ctx<P>): Promise<Response> => {
    try {
      return await fn(req, { params: await ctx.params });
    } catch (err) {
      return fail(err);
    }
  };
}

export async function body<S extends ZodTypeAny>(req: Request, schema: S, maxBytes = 400 * 1024): Promise<z.infer<S>> {
  const len = Number(req.headers.get("content-length") ?? 0);
  if (len > maxBytes) throw new ApiError(413, "too_big", "The request is too large.");
  const text = await req.text();
  if (Buffer.byteLength(text) > maxBytes) throw new ApiError(413, "too_big", "The request is too large.");
  let data: unknown;
  try {
    data = text ? JSON.parse(text) : {};
  } catch {
    throw new ApiError(400, "bad_json", "The body is not valid JSON.");
  }
  return schema.parse(data);
}
