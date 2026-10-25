import { requireUser } from "@/lib/authz";
import { query } from "@/lib/db";
import { api, json } from "@/lib/http";

export const dynamic = "force-dynamic";

export const GET = api(async () => {
  const user = await requireUser();
  const rows = await query<{ id: string; kind: string; title: string; body: string; link: string | null; read_at: Date | null; created_at: Date }>(
    "select id, kind, title, body, link, read_at, created_at from notifications where user_id = $1 order by created_at desc limit 50",
    [user.id],
  );
  return json({ items: rows, unread: rows.filter((r) => !r.read_at).length });
});
