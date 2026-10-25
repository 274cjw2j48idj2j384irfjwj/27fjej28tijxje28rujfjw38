"use client";

import { ActionButton, callApi } from "./kit";

export function ConfigActions({ id, name, hidden, featured, official }: { id: string; name: string; hidden: boolean; featured: boolean; official: boolean }) {
  const act = (action: string) => () => callApi(`/api/admin/configs/${id}`, { method: "POST", json: { action } });
  return (
    <div className="flex flex-wrap items-start gap-1.5">
      {hidden
        ? <ActionButton onRun={act("unhide")} success="Config is visible again." label={`Unhide ${name}`}>Unhide</ActionButton>
        : <ActionButton confirm={`Hide "${name}"? The owner is notified.`} onRun={act("hide")} success="Config hidden." label={`Hide ${name}`}>Hide</ActionButton>}
      <ActionButton onRun={act(featured ? "unfeature" : "feature")} success={featured ? "Unfeatured." : "Featured."} label={`${featured ? "Unfeature" : "Feature"} ${name}`}>{featured ? "Unfeature" : "Feature"}</ActionButton>
      <ActionButton onRun={act(official ? "unofficial" : "official")} success={official ? "Official mark removed." : "Marked official."} label={`${official ? "Remove official from" : "Mark official"} ${name}`}>{official ? "Not official" : "Official"}</ActionButton>
      <ActionButton variant="danger" confirm={`Delete "${name}" for good? This cannot be undone.`} onRun={act("delete")} success="Config deleted." label={`Delete ${name}`}>Delete</ActionButton>
    </div>
  );
}

export function ReportActions({ id, configId, name, hidden }: { id: string; configId: string; name: string; hidden: boolean }) {
  const set = (status: "resolved" | "dismissed") => () => callApi(`/api/admin/reports/${id}`, { method: "POST", json: { status } });
  return (
    <div className="flex flex-wrap items-start gap-1.5">
      <ActionButton variant="primary" onRun={set("resolved")} success="Report resolved." label={`Resolve report on ${name}`}>Resolve</ActionButton>
      <ActionButton onRun={set("dismissed")} success="Report dismissed." label={`Dismiss report on ${name}`}>Dismiss</ActionButton>
      {!hidden && <ActionButton variant="danger" confirm={`Hide "${name}" now?`} onRun={() => callApi(`/api/admin/configs/${configId}`, { method: "POST", json: { action: "hide" } })} success="Config hidden." label={`Hide ${name}`}>Hide config</ActionButton>}
    </div>
  );
}
