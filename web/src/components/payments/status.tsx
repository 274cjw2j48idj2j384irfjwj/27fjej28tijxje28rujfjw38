import { Badge } from "@/components/ui";
import { STATUS_LABEL } from "@/lib/plan-format";

const TONE: Record<string, "violet" | "green" | "amber" | "red" | "gray"> = {
  pending: "amber", paid: "violet", issued: "green", expired: "gray", failed: "red", review: "amber", refunded: "gray",
};

export function OrderStatusBadge({ status }: { status: string }) {
  return <Badge tone={TONE[status] ?? "gray"}><span className="size-1.5 rounded-full bg-current" />{STATUS_LABEL[status] ?? status}</Badge>;
}
