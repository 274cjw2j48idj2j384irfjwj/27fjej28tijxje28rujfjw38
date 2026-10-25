import { NextResponse } from "next/server";
import { isAdmin, requireProductAccess, requireUser } from "@/lib/authz";
import { ApiError, compatFor, getVersionPayload, recordEvent } from "@/lib/configs";
import { api } from "@/lib/http";
import { loadVisible } from "@/lib/config-api";

export const dynamic = "force-dynamic";

// The config file itself: only for a signed in user with access to the Lua the config is made for.
export const GET = api<{ slug: string }>(async (req, { params }) => {
  const user = await requireUser();
  const cfg = await loadVisible(params.slug, { id: user.id, isAdmin: isAdmin(user) });
  await requireProductAccess(user.id, cfg.product_id);
  const asked = Number(new URL(req.url).searchParams.get("version") ?? cfg.latest_version);
  const found = await getVersionPayload(cfg.id, Number.isInteger(asked) && asked > 0 ? asked : cfg.latest_version);
  if (!found) throw new ApiError(404, "no_version", "That version does not exist.");
  const compat = await compatFor(cfg.id, found.version);
  if (compat && !compat.ok) throw new ApiError(409, "incompatible", `This config version is not compatible (${compat.reason}).`);
  await recordEvent(cfg.id, user.id, "download");
  const file = `${cfg.slug}-v${found.version}.specter.json`;
  return new NextResponse(JSON.stringify(found.payload), {
    headers: {
      "content-type": "application/json; charset=utf-8",
      "content-disposition": `attachment; filename="${file}"`,
      "cache-control": "private, no-store",
      "x-content-type-options": "nosniff",
    },
  });
});
