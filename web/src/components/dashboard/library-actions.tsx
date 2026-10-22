"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { Download } from "lucide-react";
import { call, copyText, sendJson } from "./api";

type Msg = { ok: boolean; text: string } | null;

export function LibraryActions({ slug, updateAvailable, locked, lockedReason }: { slug: string; updateAvailable: boolean; locked: boolean; lockedReason: string }) {
  const router = useRouter();
  const [busy, setBusy] = useState("");
  const [msg, setMsg] = useState<Msg>(null);
  const [confirmRemove, setConfirmRemove] = useState(false);

  async function download() {
    setBusy("download");
    setMsg(null);
    const res = await call(`/api/configs/${slug}/download`);
    if (!res.ok) {
      setBusy("");
      return setMsg({ ok: false, text: res.message });
    }
    const blob = await res.response.blob();
    const disp = res.response.headers.get("content-disposition") ?? "";
    const file = /filename="([^"]+)"/.exec(disp)?.[1] ?? `${slug}.specter.json`;
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = file;
    document.body.appendChild(a);
    a.click();
    a.remove();
    setTimeout(() => URL.revokeObjectURL(url), 2000);
    setBusy("");
    setMsg({ ok: true, text: `Downloaded ${file}.` });
  }

  async function importCode() {
    setBusy("code");
    setMsg(null);
    const res = await sendJson<{ code: string }>(`/api/configs/${slug}/import-code`, "POST");
    if (!res.ok) {
      setBusy("");
      return setMsg({ ok: false, text: res.message });
    }
    const copied = await copyText(res.data.code);
    setBusy("");
    setMsg({ ok: copied, text: copied ? `Import code ${res.data.code} copied. Paste it in the Lua menu.` : `Your import code is ${res.data.code}. Copy it by hand.` });
  }

  async function resave() {
    setBusy("resave");
    setMsg(null);
    const res = await sendJson(`/api/configs/${slug}/library`, "POST");
    setBusy("");
    if (!res.ok) return setMsg({ ok: false, text: res.message });
    setMsg({ ok: true, text: "Saved the latest version." });
    router.refresh();
  }

  async function remove() {
    setBusy("remove");
    setMsg(null);
    const res = await sendJson(`/api/configs/${slug}/library`, "DELETE");
    if (!res.ok) {
      setBusy("");
      setConfirmRemove(false);
      return setMsg({ ok: false, text: res.message });
    }
    router.refresh();
  }

  const off = !!busy || locked;
  return (
    <div>
      <div className="flex flex-wrap gap-2">
        <button type="button" className="btn-primary btn-sm" disabled={off} onClick={download} title={locked ? lockedReason : undefined}><Download size={14} aria-hidden="true" />{busy === "download" ? "Downloading..." : "Download"}</button>
        <button type="button" className="btn-ghost btn-sm" disabled={off} onClick={importCode} title={locked ? lockedReason : undefined}>{busy === "code" ? "Working..." : "Copy import code"}</button>
        {updateAvailable && <button type="button" className="btn-ghost btn-sm" disabled={off} onClick={resave} title={locked ? lockedReason : undefined}>{busy === "resave" ? "Saving..." : "Re-save latest"}</button>}
        {!confirmRemove ? (
          <button type="button" className="btn-ghost btn-sm" disabled={!!busy} onClick={() => setConfirmRemove(true)}>Remove</button>
        ) : (
          <>
            <button type="button" className="btn-danger btn-sm" disabled={!!busy} onClick={remove}>{busy === "remove" ? "Removing..." : "Confirm remove"}</button>
            <button type="button" className="btn-ghost btn-sm" disabled={!!busy} onClick={() => setConfirmRemove(false)}>Cancel</button>
          </>
        )}
      </div>
      {locked && <p className="mt-2 text-xs text-amber-200/80">{lockedReason}</p>}
      {msg && <p role={msg.ok ? "status" : "alert"} className={`mt-2 text-xs ${msg.ok ? "text-emerald-300" : "text-red-300"}`}>{msg.text}</p>}
    </div>
  );
}
