import { assertSameOrigin, requireUser } from "@/lib/authz";
import { revokeDevice } from "@/lib/devices";
import { api, json } from "@/lib/http";
import { audit } from "@/lib/audit";

export const dynamic = "force-dynamic";

export const DELETE = api<{ id: string }>(async (req, { params }) => {
  assertSameOrigin(req);
  const user = await requireUser();
  await revokeDevice(user.id, params.id);
  await audit(user.id, "device.revoke", "device", params.id);
  return json({ ok: true });
});
