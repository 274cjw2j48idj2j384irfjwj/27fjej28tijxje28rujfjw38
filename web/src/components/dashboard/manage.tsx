"use client";

import { useRouter } from "next/navigation";
import { useMemo, useRef, useState } from "react";
import { LIMITS } from "@/config/site";
import { Notice } from "@/components/ui";
import { call, formatBytes, sendJson, type ApiProblem } from "./api";
import { ContentInput, Problems, parseContent, type Template } from "./content-input";

export function DetailsForm({ slug, initial }: { slug: string; initial: { name: string; description: string; tags: string[]; visibility: string } }) {
  const router = useRouter();
  const [name, setName] = useState(initial.name);
  const [description, setDescription] = useState(initial.description);
  const [tags, setTags] = useState(initial.tags.join(", "));
  const [visibility, setVisibility] = useState(initial.visibility);
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState<{ ok: boolean; text: string } | null>(null);
  async function save(e: React.FormEvent) {
    e.preventDefault();
    setBusy(true);
    setMsg(null);
    const res = await sendJson(`/api/configs/${slug}`, "PATCH", { name: name.trim(), description: description.trim(), tags: tags.split(",").map((t) => t.trim()).filter(Boolean), visibility });
    setBusy(false);
    if (!res.ok) return setMsg({ ok: false, text: res.message });
    setMsg({ ok: true, text: "Saved." });
    router.refresh();
  }
  return (
    <form onSubmit={save} className="space-y-5">
      <div className="grid gap-5 sm:grid-cols-2">
        <div>
          <label htmlFor="d-name" className="label">Name</label>
          <input id="d-name" className="input" value={name} onChange={(e) => setName(e.target.value)} maxLength={LIMITS.configNameLen} required />
        </div>
        <div>
          <label htmlFor="d-vis" className="label">Visibility</label>
          <select id="d-vis" className="input" value={visibility} onChange={(e) => setVisibility(e.target.value)}>
            <option value="public">Public: listed in the cloud</option>
            <option value="unlisted">Unlisted: only with the link or code</option>
            <option value="private">Private: only you</option>
          </select>
        </div>
      </div>
      <div>
        <label htmlFor="d-tags" className="label">Tags</label>
        <input id="d-tags" className="input" value={tags} onChange={(e) => setTags(e.target.value)} placeholder="legit, hvh" />
      </div>
      <div>
        <label htmlFor="d-desc" className="label">Description</label>
        <textarea id="d-desc" className="input" rows={4} value={description} onChange={(e) => setDescription(e.target.value)} maxLength={LIMITS.configDescLen} />
      </div>
      <div className="flex flex-wrap items-center gap-3">
        <button type="submit" className="btn-primary" disabled={busy}>{busy ? "Saving..." : "Save changes"}</button>
        {msg && <p role={msg.ok ? "status" : "alert"} className={msg.ok ? "text-sm text-emerald-300" : "text-sm text-red-300"}>{msg.text}</p>}
      </div>
    </form>
  );
}

export function VersionForm({ slug, template, productName, canUpload, reason }: { slug: string; template: Template; productName: string; canUpload: boolean; reason: string }) {
  const router = useRouter();
  const [content, setContent] = useState("");
  const [changelog, setChangelog] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<{ message: string; problems: ApiProblem[] } | null>(null);
  const [okText, setOkText] = useState("");
  const parsed = useMemo(() => parseContent(content), [content]);
  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setOkText("");
    if (!parsed) return setError({ message: "Add the new config content first.", problems: [] });
    if (!parsed.ok) return setError({ message: parsed.message, problems: [] });
    setBusy(true);
    const res = await sendJson<{ version: number }>(`/api/configs/${slug}/versions`, "POST", { payload: parsed.value, changelog: changelog.trim() || undefined });
    setBusy(false);
    if (!res.ok) return setError({ message: res.message, problems: res.problems });
    setOkText(`Version ${res.data.version} published.`);
    setContent("");
    setChangelog("");
    router.refresh();
  }
  return (
    <form onSubmit={submit} className="space-y-5" noValidate>
      {!canUpload && <Notice tone="amber">{reason} Publishing a version needs access to {productName}.</Notice>}
      <div>
        <label htmlFor="v-log" className="label">Changelog</label>
        <input id="v-log" className="input" value={changelog} onChange={(e) => setChangelog(e.target.value)} maxLength={400} placeholder="What changed in this version?" />
      </div>
      <ContentInput value={content} onChange={setContent} parsed={parsed} template={template} productName={productName} />
      {error && <Problems message={error.message} problems={error.problems} />}
      <div className="flex flex-wrap items-center gap-3">
        <button type="submit" className="btn-primary" disabled={busy || !canUpload}>{busy ? "Publishing..." : "Publish new version"}</button>
        {okText && <p role="status" className="text-sm text-emerald-300">{okText}</p>}
      </div>
    </form>
  );
}

const IMAGE_TYPES = ["image/png", "image/jpeg", "image/webp"];

export function ImagesPanel({ slug, images }: { slug: string; images: string[] }) {
  const router = useRouter();
  const input = useRef<HTMLInputElement>(null);
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState<{ ok: boolean; text: string } | null>(null);
  const full = images.length >= LIMITS.maxImagesPerConfig;
  async function upload(f: File | undefined) {
    if (!f) return;
    setMsg(null);
    if (!IMAGE_TYPES.includes(f.type)) return setMsg({ ok: false, text: "Only PNG, JPEG or WebP images are accepted." });
    if (f.size > LIMITS.imageBytes) return setMsg({ ok: false, text: `That image is ${formatBytes(f.size)}. At most ${formatBytes(LIMITS.imageBytes)}.` });
    setBusy(true);
    const res = await call(`/api/configs/${slug}/images`, { method: "POST", headers: { "content-type": f.type }, body: f });
    setBusy(false);
    if (input.current) input.current.value = "";
    if (!res.ok) return setMsg({ ok: false, text: res.message });
    setMsg({ ok: true, text: "Image added." });
    router.refresh();
  }
  async function remove(src: string) {
    setMsg(null);
    setBusy(true);
    const res = await call(`/api/configs/${slug}/images`, { method: "DELETE", headers: { "content-type": "application/json" }, body: JSON.stringify({ id: src.split("/").pop() }) });
    setBusy(false);
    if (!res.ok) return setMsg({ ok: false, text: res.message });
    setMsg({ ok: true, text: "Image removed." });
    router.refresh();
  }
  return (
    <div>
      {images.length > 0 ? (
        <ul className="grid grid-cols-2 gap-3 sm:grid-cols-4">
          {images.map((src) => (
            <li key={src} className="group relative aspect-video overflow-hidden rounded-xl border border-line bg-ink-900">
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img src={src} alt="Config preview" loading="lazy" className="h-full w-full object-cover" />
              <button type="button" disabled={busy} onClick={() => remove(src)} aria-label="Remove this image" className="absolute right-2 top-2 rounded-lg border border-line bg-ink-950/85 px-2 py-1 text-xs text-red-200 opacity-100 transition hover:border-red-400/50 sm:opacity-0 sm:group-hover:opacity-100 sm:focus-visible:opacity-100">Remove</button>
            </li>
          ))}
        </ul>
      ) : (
        <p className="muted text-sm">No preview images yet. A config without one shows a plain placeholder in the cloud.</p>
      )}
      <div className="mt-4 flex flex-wrap items-center gap-3">
        <label htmlFor="img-file" className="sr-only">Preview image (PNG, JPEG or WebP)</label>
        <input ref={input} id="img-file" type="file" accept={IMAGE_TYPES.join(",")} className="sr-only" disabled={busy || full} onChange={(e) => upload(e.target.files?.[0])} />
        <button type="button" className="btn-ghost btn-sm" disabled={busy || full} onClick={() => input.current?.click()}>{busy ? "Uploading..." : "Add preview image"}</button>
        <span className="text-xs text-[color:var(--faint)]">{images.length} / {LIMITS.maxImagesPerConfig} images, PNG, JPEG or WebP, up to {formatBytes(LIMITS.imageBytes)}.</span>
        {msg && <p role={msg.ok ? "status" : "alert"} className={msg.ok ? "text-sm text-emerald-300" : "text-sm text-red-300"}>{msg.text}</p>}
      </div>
    </div>
  );
}

export function DeleteConfig({ slug, name }: { slug: string; name: string }) {
  const router = useRouter();
  const [confirm, setConfirm] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  async function remove() {
    setBusy(true);
    setError("");
    const res = await sendJson(`/api/configs/${slug}`, "DELETE");
    if (!res.ok) {
      setBusy(false);
      return setError(res.message);
    }
    router.push("/dashboard/configs");
    router.refresh();
  }
  return (
    <div>
      {!confirm ? (
        <button type="button" className="btn-danger btn-sm" onClick={() => setConfirm(true)}>Delete this config</button>
      ) : (
        <div role="alertdialog" aria-label="Confirm delete" className="rounded-xl border border-red-400/30 bg-red-500/[0.07] p-4">
          <p className="text-sm text-red-100">Delete <strong>{name}</strong> with all its versions, images, likes and saves? This cannot be undone.</p>
          <div className="mt-3 flex flex-wrap gap-2">
            <button type="button" className="btn-danger btn-sm" disabled={busy} onClick={remove}>{busy ? "Deleting..." : "Yes, delete it"}</button>
            <button type="button" className="btn-ghost btn-sm" disabled={busy} onClick={() => setConfirm(false)}>Cancel</button>
          </div>
        </div>
      )}
      {error && <p role="alert" className="mt-3 text-sm text-red-300">{error}</p>}
    </div>
  );
}
