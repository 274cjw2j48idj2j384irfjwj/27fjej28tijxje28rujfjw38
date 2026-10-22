import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { OrderView } from "@/components/payments/order-view";
import { getOrderPublic } from "@/lib/orders";

export const dynamic = "force-dynamic";
export const metadata: Metadata = { title: "Your order", robots: { index: false, follow: false } };

export default async function OrderPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const o = await getOrderPublic(id);
  if (!o) notFound();
  const iso = (d: Date | null) => (d ? d.toISOString() : null);
  return <OrderView initial={{ ...o, created_at: o.created_at.toISOString(), paid_at: iso(o.paid_at), issued_at: iso(o.issued_at) }} />;
}
