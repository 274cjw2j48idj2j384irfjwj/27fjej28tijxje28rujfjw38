import { describe, expect, it } from "vitest";
import { diffData } from "@/lib/config-diff";

describe("diffData", () => {
  it("finds added, removed and changed keys with their paths", () => {
    const r = diffData({ a: 1, b: { c: 2, d: [1, 2] }, gone: true }, { a: 1, b: { c: 3, d: [1, 2, 3] }, fresh: "x" });
    expect(r.entries).toEqual([
      { path: "b.c", kind: "changed", before: 2, after: 3 },
      { path: "b.d[2]", kind: "added", after: 3 },
      { path: "fresh", kind: "added", after: "x" },
      { path: "gone", kind: "removed", before: true },
    ]);
  });
  it("equal data gives no entries and strings are compared as values", () => {
    expect(diffData({ a: "x" }, { a: "x" }).entries).toEqual([]);
    expect(diffData("abc", "abd").entries).toEqual([{ path: "(root)", kind: "changed", before: "abc", after: "abd" }]);
  });
  it("is capped", () => {
    const big = Object.fromEntries(Array.from({ length: 1000 }, (_, i) => [`k${i}`, i]));
    const r = diffData({}, big);
    expect(r.entries.length).toBe(300);
    expect(r.truncated).toBe(true);
  });
});
