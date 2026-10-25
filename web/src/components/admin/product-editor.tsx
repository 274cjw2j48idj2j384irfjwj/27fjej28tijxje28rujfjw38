"use client";

import { useRef, useState } from "react";
import { ActionButton, Feedback, Field, callApi, useRun } from "./kit";
import { Badge, Card, Notice, cx } from "@/components/ui";

type Feature = { category: string; title: string; text: string };
type Initial = { features: Feature[]; installGuide: string; compatNotes: string; latestVersion: string; minFormat: number; maxFormat: number };
type Release = { id: string; version: string; title: string; notes: string[]; date: string; demo: boolean };
type Media = { id: string; kind: "screenshot" | "video"; category: string; src: string; caption: string; demo: boolean };
type Download = { id: string; filename: string; version: string; note: string; bytes: number; date: string };
type Props = { product: { id: string; name: string; slug: string }; initial: Initial; releases: Release[]; media: Media[]; downloads: Download[] };

const TABS = [["content", "Content"], ["releases", "Releases"], ["media", "Screenshots & videos"], ["downloads", "Downloads"]] as const;
type Tab = (typeof TABS)[number][0];

export function ProductEditor(p: Props) {
  const [tab, setTab] = useState<Tab>("content");
  const refs = useRef<(HTMLButtonElement | null)[]>([]);
  const onKey = (e: React.KeyboardEvent, i: number) => {
    const d = e.key === "ArrowRight" ? 1 : e.key === "ArrowLeft" ? -1 : 0;
    if (!d) return;
    const n = (i + d + TABS.length) % TABS.length;
    setTab(TABS[n][0]);
    refs.current[n]?.focus();
  };
  return (
    <div className="space-y-6">
      <div role="tablist" aria-label="Sections" className="scroll-thin flex gap-1 overflow-x-auto border-b border-line">
        {TABS.map(([k, label], i) => (
          <button key={k} ref={(el) => { refs.current[i] = el; }} role="tab" id={`tab-${k}`} aria-selected={tab === k} aria-controls={`panel-${k}`} tabIndex={tab === k ? 0 : -1} onClick={() => setTab(k)} onKeyDown={(e) => onKey(e, i)}
            className={cx("-mb-px whitespace-nowrap border-b-2 px-4 py-2.5 text-sm transition", tab === k ? "border-violet-400 text-white" : "border-transparent text-[color:var(--muted)] hover:text-white")}>
            {label}
          </button>
        ))}
      </div>
      {TABS.map(([k]) => (
        <div key={k} role="tabpanel" id={`panel-${k}`} aria-labelledby={`tab-${k}`} hidden={tab !== k}>
          {k === "content" && <ContentForm key={p.initial.latestVersion} id={p.product.id} initial={p.initial} />}
          {k === "releases" && <Releases id={p.product.id} releases={p.releases} latest={p.initial.latestVersion} />}
          {k === "media" && <MediaTab id={p.product.id} media={p.media} />}
          {k === "downloads" && <Downloads id={p.product.id} files={p.downloads} />}
        </div>
      ))}
    </div>
  );
}

function ContentForm({ id, initial }: { id: string; initial: Initial }) {
  const r = useRun();
  const [features, setFeatures] = useState<Feature[]>(initial.features);
  const [guide, setGuide] = useState(initial.installGuide);
  const [compat, setCompat] = useState(initial.compatNotes);
  const [version, setVersion] = useState(initial.latestVersion);
  const [min, setMin] = useState(String(initial.minFormat));
  const [max, setMax] = useState(String(initial.maxFormat));
  const set = (i: number, patch: Partial<Feature>) => setFeatures((f) => f.map((x, j) => (j === i ? { ...x, ...patch } : x)));
  const move = (i: number, d: number) => setFeatures((f) => { const n = [...f]; const j = i + d; if (j < 0 || j >= n.length) return f; [n[i], n[j]] = [n[j], n[i]]; return n; });
  const incomplete = features.some((f) => !f.category.trim() || !f.title.trim());
  const save = () => r.run(() => callApi(`/api/admin/products/${id}`, { method: "PUT", json: { features: features.map((f) => ({ category: f.category.trim(), title: f.title.trim(), text: f.text })), install_guide: guide, compat_notes: compat, latest_version: version.trim(), min_format: Number(min), max_format: Number(max) } }), "Product content saved.");
  return (
    <form onSubmit={(e) => { e.preventDefault(); void save(); }} className="space-y-8">
      <Card className="p-5">
        <h2 className="text-lg font-medium text-white">Version and config format</h2>
        <div className="mt-4 grid gap-4 sm:grid-cols-3">
          <Field label="Latest version" hint="Like 2.4.1. Empty clears it.">{(i) => <input id={i} className="input font-mono" value={version} onChange={(e) => setVersion(e.target.value)} placeholder="1.0.0" />}</Field>
          <Field label="Lowest config format" hint="Oldest config format the Lua imports.">{(i) => <input id={i} type="number" min={1} max={1000} className="input" value={min} onChange={(e) => setMin(e.target.value)} />}</Field>
          <Field label="Highest config format">{(i) => <input id={i} type="number" min={1} max={1000} className="input" value={max} onChange={(e) => setMax(e.target.value)} />}</Field>
        </div>
      </Card>

      <section>
        <div className="mb-4 flex flex-wrap items-center justify-between gap-3">
          <div><h2 className="text-lg font-medium text-white">Features</h2><p className="muted text-sm">Shown on the features page, grouped by category. {features.length} of 80.</p></div>
          <button type="button" className="btn-ghost btn-sm" disabled={features.length >= 80} onClick={() => setFeatures((f) => [...f, { category: f[f.length - 1]?.category ?? "", title: "", text: "" }])}>Add feature</button>
        </div>
        {features.length === 0 && <p className="muted text-sm">No features yet.</p>}
        <ol className="space-y-3">
          {features.map((f, i) => (
            <li key={i} className="card p-4">
              <div className="grid gap-3 md:grid-cols-[180px_1fr]">
                <Field label="Category">{(x) => <input id={x} className="input" maxLength={40} value={f.category} onChange={(e) => set(i, { category: e.target.value })} />}</Field>
                <Field label="Title">{(x) => <input id={x} className="input" maxLength={80} value={f.title} onChange={(e) => set(i, { title: e.target.value })} />}</Field>
                <Field label="Text" className="md:col-span-2">{(x) => <textarea id={x} rows={2} className="input" maxLength={400} value={f.text} onChange={(e) => set(i, { text: e.target.value })} />}</Field>
              </div>
              <div className="mt-3 flex flex-wrap gap-2">
                <button type="button" className="btn-ghost btn-sm" disabled={i === 0} onClick={() => move(i, -1)} aria-label={`Move feature ${i + 1} up`}>Up</button>
                <button type="button" className="btn-ghost btn-sm" disabled={i === features.length - 1} onClick={() => move(i, 1)} aria-label={`Move feature ${i + 1} down`}>Down</button>
                <button type="button" className="btn-danger btn-sm" onClick={() => setFeatures((a) => a.filter((_, j) => j !== i))} aria-label={`Remove feature ${i + 1}`}>Remove</button>
              </div>
            </li>
          ))}
        </ol>
      </section>

      <div className="grid gap-4 lg:grid-cols-2">
        <Field label="Install guide" hint="Plain text. A blank line starts a new paragraph. Up to 6000 characters.">{(x) => <textarea id={x} rows={10} className="input" maxLength={6000} value={guide} onChange={(e) => setGuide(e.target.value)} />}</Field>
        <Field label="Compatibility notes" hint="Up to 2000 characters.">{(x) => <textarea id={x} rows={10} className="input" maxLength={2000} value={compat} onChange={(e) => setCompat(e.target.value)} />}</Field>
      </div>
      <div className="sticky bottom-4 z-10 flex flex-wrap items-center gap-3 rounded-2xl border border-line bg-ink-900/90 p-3 backdrop-blur">
        <button className="btn-primary" type="submit" disabled={r.busy || incomplete}>{r.busy ? "Saving..." : "Save content"}</button>
        {incomplete && <span className="text-sm text-amber-300">Every feature needs a category and a title.</span>}
        <Feedback run={r} />
      </div>
    </form>
  );
}

function Releases({ id, releases, latest }: { id: string; releases: Release[]; latest: string }) {
  const r = useRun();
  const [version, setVersion] = useState("");
  const [title, setTitle] = useState("");
  const [notes, setNotes] = useState("");
  const [setLatest, setSetLatest] = useState(true);
  const lines = notes.split("\n").map((s) => s.trim()).filter(Boolean);
  const valid = /^\d+(\.\d+){0,3}([-+][0-9A-Za-z.-]+)?$/.test(version.trim()) && title.trim().length > 0 && lines.length <= 30 && lines.every((l) => l.length <= 300);
  const add = async () => {
    const ok = await r.run(() => callApi("/api/admin/releases", { method: "POST", json: { product: id, version: version.trim(), title: title.trim(), notes: lines, set_latest: setLatest } }), "Release added.");
    if (ok) { setVersion(""); setTitle(""); setNotes(""); }
  };
  return (
    <div className="space-y-8">
      <Card className="p-5">
        <h2 className="text-lg font-medium text-white">Add a release</h2>
        <form onSubmit={(e) => { e.preventDefault(); void add(); }} className="mt-4 grid gap-4 md:grid-cols-2">
          <Field label="Version" hint="Like 2.5.0">{(x) => <input id={x} className="input font-mono" value={version} onChange={(e) => setVersion(e.target.value)} placeholder="2.5.0" />}</Field>
          <Field label="Title">{(x) => <input id={x} className="input" maxLength={120} value={title} onChange={(e) => setTitle(e.target.value)} placeholder="Short headline" />}</Field>
          <Field label="Notes" className="md:col-span-2" hint={`One note per line, up to 30 lines of 300 characters. ${lines.length} now.`}>{(x) => <textarea id={x} rows={5} className="input" value={notes} onChange={(e) => setNotes(e.target.value)} placeholder={"Added ...\nFixed ..."} />}</Field>
          <label className="flex items-center gap-2 text-sm md:col-span-2"><input type="checkbox" className="accent-violet-500" checked={setLatest} onChange={(e) => setSetLatest(e.target.checked)} /> Set as the latest version (now {latest || "not set"})</label>
          <div className="flex flex-wrap items-center gap-3 md:col-span-2"><button className="btn-primary btn-sm" type="submit" disabled={r.busy || !valid}>{r.busy ? "Adding..." : "Add release"}</button><Feedback run={r} /></div>
        </form>
      </Card>
      <section>
        <h2 className="mb-4 text-lg font-medium text-white">Releases</h2>
        {releases.length === 0 ? <p className="muted text-sm">No releases yet.</p> : (
          <ul className="space-y-3">
            {releases.map((x) => (
              <li key={x.id} className="card p-4">
                <div className="flex flex-wrap items-start justify-between gap-3">
                  <div className="min-w-0">
                    <p className="flex flex-wrap items-center gap-2 font-medium text-white"><span className="font-mono">{x.version}</span> {x.title} {x.version === latest && <Badge tone="green">Latest</Badge>} {x.demo && <Badge tone="amber">Demo</Badge>}</p>
                    <p className="mt-1 text-xs text-[color:var(--faint)]">{x.date}</p>
                    {x.notes.length > 0 && <ul className="muted mt-2 list-disc space-y-0.5 pl-5 text-sm">{x.notes.map((n, i) => <li key={i}>{n}</li>)}</ul>}
                  </div>
                  <ActionButton variant="danger" confirm={`Delete release ${x.version}?`} onRun={() => callApi(`/api/admin/releases/${x.id}`, { method: "DELETE" })} success="Release deleted." label={`Delete release ${x.version}`}>Delete</ActionButton>
                </div>
              </li>
            ))}
          </ul>
        )}
      </section>
    </div>
  );
}

const CATS = ["menu", "visuals", "configuration"] as const;

function MediaTab({ id, media }: { id: string; media: Media[] }) {
  const link = useRun();
  const up = useRun();
  const [kind, setKind] = useState<"screenshot" | "video">("screenshot");
  const [cat, setCat] = useState<string>("menu");
  const [url, setUrl] = useState("");
  const [cap, setCap] = useState("");
  const [ucat, setUcat] = useState<string>("menu");
  const [ucap, setUcap] = useState("");
  const [file, setFile] = useState<File | null>(null);
  const fileRef = useRef<HTMLInputElement>(null);
  const urlOk = /^https:\/\/\S+$/.test(url.trim());
  const addLink = async () => {
    const ok = await link.run(() => callApi("/api/admin/media", { method: "POST", json: { product: id, kind, category: cat, url: url.trim(), caption: cap || undefined } }), "Link added.");
    if (ok) { setUrl(""); setCap(""); }
  };
  const upload = async () => {
    if (!file) return;
    const ok = await up.run(() => callApi(`/api/admin/media/upload?product=${id}&category=${ucat}&caption=${encodeURIComponent(ucap)}`, { method: "POST", raw: file, contentType: file.type }), "Image uploaded.");
    if (ok) { setFile(null); setUcap(""); if (fileRef.current) fileRef.current.value = ""; }
  };
  const tooBig = !!file && file.size > 6 * 1024 * 1024;
  return (
    <div className="space-y-8">
      <div className="grid gap-6 lg:grid-cols-2">
        <Card className="p-5">
          <h2 className="text-lg font-medium text-white">Upload an image</h2>
          <form onSubmit={(e) => { e.preventDefault(); void upload(); }} className="mt-4 space-y-3">
            <Field label="Image file" hint="PNG, JPEG or WebP, 6 MB at most.">{(x) => <input ref={fileRef} id={x} type="file" accept="image/png,image/jpeg,image/webp" className="input file:mr-3 file:rounded-lg file:border-0 file:bg-violet-600 file:px-3 file:py-1 file:text-white" onChange={(e) => setFile(e.target.files?.[0] ?? null)} />}</Field>
            <Field label="Category">{(x) => <select id={x} className="input" value={ucat} onChange={(e) => setUcat(e.target.value)}>{CATS.map((c) => <option key={c}>{c}</option>)}</select>}</Field>
            <Field label="Caption (optional)">{(x) => <input id={x} className="input" maxLength={160} value={ucap} onChange={(e) => setUcap(e.target.value)} />}</Field>
            <div className="flex flex-wrap items-center gap-3"><button className="btn-primary btn-sm" type="submit" disabled={up.busy || !file || tooBig}>{up.busy ? "Uploading..." : "Upload"}</button>{tooBig && <span className="text-sm text-amber-300">That file is over 6 MB.</span>}<Feedback run={up} /></div>
          </form>
        </Card>
        <Card className="p-5">
          <h2 className="text-lg font-medium text-white">Add a link</h2>
          <form onSubmit={(e) => { e.preventDefault(); void addLink(); }} className="mt-4 space-y-3">
            <Field label="https link">{(x) => <input id={x} type="url" className="input" value={url} onChange={(e) => setUrl(e.target.value)} placeholder="https://..." />}</Field>
            <div className="grid grid-cols-2 gap-3">
              <Field label="Type">{(x) => <select id={x} className="input" value={kind} onChange={(e) => setKind(e.target.value as "screenshot" | "video")}><option value="screenshot">Screenshot</option><option value="video">Video</option></select>}</Field>
              <Field label="Category">{(x) => <select id={x} className="input" value={cat} onChange={(e) => setCat(e.target.value)}>{CATS.map((c) => <option key={c}>{c}</option>)}</select>}</Field>
            </div>
            <Field label="Caption (optional)">{(x) => <input id={x} className="input" maxLength={160} value={cap} onChange={(e) => setCap(e.target.value)} />}</Field>
            <div className="flex flex-wrap items-center gap-3"><button className="btn-primary btn-sm" type="submit" disabled={link.busy || !urlOk}>{link.busy ? "Adding..." : "Add link"}</button><Feedback run={link} /></div>
          </form>
        </Card>
      </div>
      <section>
        <h2 className="mb-4 text-lg font-medium text-white">Current media ({media.length})</h2>
        {media.length === 0 ? <p className="muted text-sm">Nothing added yet.</p> : (
          <ul className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {media.map((m) => (
              <li key={m.id} className="card overflow-hidden">
                <div className="flex aspect-video items-center justify-center bg-ink-800">
                  {m.kind === "screenshot" && m.src ? /* eslint-disable-next-line @next/next/no-img-element */ <img src={m.src} alt={m.caption || "Screenshot"} loading="lazy" className="size-full object-cover" /> : <span className="muted text-sm">Video link</span>}
                </div>
                <div className="space-y-2 p-3">
                  <p className="flex flex-wrap gap-1.5"><Badge>{m.kind}</Badge><Badge tone="violet">{m.category}</Badge>{m.demo && <Badge tone="amber">Demo</Badge>}</p>
                  <p className="truncate text-sm text-white">{m.caption || <span className="muted">No caption</span>}</p>
                  <ActionButton variant="danger" confirm="Delete this media?" onRun={() => callApi(`/api/admin/media/${m.id}`, { method: "DELETE" })} success="Media deleted." label={`Delete ${m.kind} ${m.caption}`}>Delete</ActionButton>
                </div>
              </li>
            ))}
          </ul>
        )}
      </section>
    </div>
  );
}

function size(b: number) { return b > 1024 * 1024 ? `${(b / 1048576).toFixed(1)} MB` : `${Math.max(1, Math.round(b / 1024))} KB`; }

function Downloads({ id, files }: { id: string; files: Download[] }) {
  const r = useRun();
  const [file, setFile] = useState<File | null>(null);
  const [version, setVersion] = useState("");
  const [note, setNote] = useState("");
  const ref = useRef<HTMLInputElement>(null);
  const bad = !!file && (!/\.lua$/i.test(file.name) || file.size > 2 * 1024 * 1024 || file.size === 0);
  const upload = async () => {
    if (!file) return;
    const ok = await r.run(() => callApi(`/api/admin/downloads?product=${id}&filename=${encodeURIComponent(file.name)}&version=${encodeURIComponent(version)}&note=${encodeURIComponent(note)}`, { method: "POST", raw: file, contentType: "application/octet-stream" }), "File uploaded.");
    if (ok) { setFile(null); setVersion(""); setNote(""); if (ref.current) ref.current.value = ""; }
  };
  return (
    <div className="space-y-8">
      <Notice>Users with access to this Lua download these files from their dashboard. Only <code className="font-mono">.lua</code> files up to 2 MB are accepted. The newest file is the one offered first.</Notice>
      <Card className="p-5">
        <h2 className="text-lg font-medium text-white">Upload the loader</h2>
        <form onSubmit={(e) => { e.preventDefault(); void upload(); }} className="mt-4 grid gap-4 md:grid-cols-2">
          <Field label="Lua file" className="md:col-span-2">{(x) => <input ref={ref} id={x} type="file" accept=".lua,text/plain" className="input file:mr-3 file:rounded-lg file:border-0 file:bg-violet-600 file:px-3 file:py-1 file:text-white" onChange={(e) => setFile(e.target.files?.[0] ?? null)} />}</Field>
          <Field label="Version (optional)">{(x) => <input id={x} className="input font-mono" maxLength={32} value={version} onChange={(e) => setVersion(e.target.value)} />}</Field>
          <Field label="Note (optional)">{(x) => <input id={x} className="input" maxLength={200} value={note} onChange={(e) => setNote(e.target.value)} />}</Field>
          <div className="flex flex-wrap items-center gap-3 md:col-span-2"><button className="btn-primary btn-sm" type="submit" disabled={r.busy || !file || bad}>{r.busy ? "Uploading..." : "Upload file"}</button>{bad && <span className="text-sm text-amber-300">Choose a non empty .lua file of at most 2 MB.</span>}<Feedback run={r} /></div>
        </form>
      </Card>
      <section>
        <h2 className="mb-4 text-lg font-medium text-white">Files ({files.length})</h2>
        {files.length === 0 ? <p className="muted text-sm">No file uploaded yet. Users see no download button until you add one.</p> : (
          <ul className="space-y-3">
            {files.map((f, i) => (
              <li key={f.id} className="card flex flex-wrap items-center justify-between gap-3 p-4">
                <div className="min-w-0">
                  <p className="flex flex-wrap items-center gap-2 font-medium text-white"><span className="font-mono">{f.filename}</span>{f.version && <Badge>{f.version}</Badge>}{i === 0 && <Badge tone="green">Offered</Badge>}</p>
                  <p className="muted mt-1 text-xs">{size(f.bytes)} · {f.date}{f.note ? ` · ${f.note}` : ""}</p>
                </div>
                <ActionButton variant="danger" confirm={`Delete ${f.filename}?`} onRun={() => callApi(`/api/admin/downloads/${f.id}`, { method: "DELETE" })} success="File deleted." label={`Delete ${f.filename}`}>Delete</ActionButton>
              </li>
            ))}
          </ul>
        )}
      </section>
    </div>
  );
}
