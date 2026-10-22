import { AuditTable } from "@/components/admin/audit-table";
import { adminPageUser, metaText } from "@/components/admin/server";
import { PageHeader, formatDate } from "@/components/ui";
import { recentAudit } from "@/lib/admin";

export const dynamic = "force-dynamic";

type Row = { id: string; action: string; target_type: string; target_id: string; meta: unknown; created_at: Date; actor: string | null };

export default async function AuditPage() {
  if (!(await adminPageUser())) return null;
  const rows = (await recentAudit(500)) as Row[];
  return (
    <div className="space-y-6">
      <PageHeader eyebrow="Admin" title="Audit Log">Every admin action and every month close, newest first. The latest 500 entries are loaded; filter them here.</PageHeader>
      <AuditTable rows={rows.map((r) => ({ id: String(r.id), action: r.action, actor: r.actor ?? "system", target: r.target_type ? `${r.target_type} ${r.target_id}` : "", meta: metaText(r.meta), at: formatDate(r.created_at, true) }))} />
    </div>
  );
}
