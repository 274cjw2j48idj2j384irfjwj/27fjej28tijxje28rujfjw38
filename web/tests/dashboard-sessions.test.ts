import { afterAll, beforeEach, describe, expect, it } from "vitest";
import { vi } from "vitest";

const jar = { value: "" as string | undefined };
vi.mock("next/headers", () => ({
  cookies: async () => ({ get: (name: string) => (name === "specter_session" && jar.value ? { value: jar.value } : undefined) }),
}));

import { DELETE as logoutAll } from "@/app/api/me/sessions/route";
import { createSession, userFromSession } from "@/lib/sessions";
import { query } from "@/lib/db";
import { done, mkUser, resetDb } from "./helpers";

process.env.PUBLIC_URL = "http://localhost:3000";
const ORIGIN = "http://localhost:3000";
const call = (origin: string | null = ORIGIN) =>
  logoutAll(new Request(`${ORIGIN}/api/me/sessions`, { method: "DELETE", headers: origin ? { origin } : {} }), { params: Promise.resolve({}) as never });

beforeEach(async () => {
  await resetDb();
  jar.value = undefined;
});
afterAll(done);

describe("sign out everywhere", () => {
  it("needs a session", async () => {
    expect((await call()).status).toBe(401);
  });

  it("refuses a cross site request and keeps the sessions", async () => {
    const u = await mkUser();
    const s = await createSession(u.id, "a");
    jar.value = s.token;
    expect((await call("https://evil.example")).status).toBe(403);
    expect(await userFromSession(s.token)).not.toBeNull();
  });

  it("ends every session of the user, and only of that user", async () => {
    const u = await mkUser();
    const other = await mkUser("other");
    const a = await createSession(u.id, "a");
    const b = await createSession(u.id, "b");
    const o = await createSession(other.id, "o");
    jar.value = a.token;
    const res = await call();
    expect(res.status).toBe(200);
    expect(await userFromSession(a.token)).toBeNull();
    expect(await userFromSession(b.token)).toBeNull();
    expect(await userFromSession(o.token)).not.toBeNull();
    expect(res.headers.get("set-cookie")).toContain("specter_session=");
    const log = await query("select 1 from audit_log where action = 'auth.logout_all' and actor_id = $1", [u.id]);
    expect(log).toHaveLength(1);
  });
});
