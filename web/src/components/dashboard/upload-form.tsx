"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useMemo, useState } from "react";
import { LIMITS } from "@/config/site";
import { Notice } from "@/components/ui";
import { sendJson, type ApiProblem } from "./api";
import { ContentInput, Problems, parseContent, type Template } from "./content-input";
import { CopyButton } from "./copy-button";

export type ProductOption = { id: string; name: string; slug: string; canUpload: boolean; reason: string; template: Template };

export function UploadForm({ products }: { products: ProductOption[] }) {
  const router = useRouter();
  const firstUsable = products.find((p) => p.canUpload) ?? products[0];
  const [product, setProduct] = useState(firstUsable?.id ?? "");
  const [name, setName] = useState("");
  const [description, setDescription] = useState("");
  const [tags, setTags] = useState("");
  const [visibility, setVisibility] = useState("public");
  const [content, setContent] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<{ message: string; problems: ApiProblem[] } | null>(null);
  const [done, setDone] = useState<{ slug: string; url: string; product: string } | null>(null);
  const chosen = products.find((p) => p.id === product);
  const parsed = useMemo(() => parseContent(content), [content]);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setDone(null);
    if (!parsed) return setError({ message: "Add the config content first: choose a .json file or paste it.", problems: [] });
    if (!parsed.ok) return setError({ message: parsed.message, problems: [] });
    setBusy(true);
    const res = await sendJson<{ slug: string; url: string }>("/api/configs", "POST", {
      product,
      name: name.trim(),
      description: description.trim() || undefined,
      tags: tags.split(",").map((t) => t.trim()).filter(Boolean),
      visibility,
      payload: parsed.value,
    });
    setBusy(false);
    if (!res.ok) return setError({ message: res.message, problems: res.problems });
    setDone({ slug: res.data.slug, url: res.data.url, product });
    setName("");
    setDescription("");
    setTags("");
    setContent("");
    router.refresh();
  }

  return (
    <form onSubmit={submit} className="card space-y-5 p-6" noValidate>
      <div className="grid gap-5 sm:grid-cols-2">
        <div>
          <label htmlFor="up-product" className="label">Lua</label>
          <select id="up-product" className="input" value={product} onChange={(e) => setProduct(e.target.value)}>
            {products.map((p) => <option key={p.id} value={p.id}>{p.name}{p.canUpload ? "" : " (no access)"}</option>)}
          </select>
        </div>
        <div>
          <label htmlFor="up-vis" className="label">Visibility</label>
          <select id="up-vis" className="input" value={visibility} onChange={(e) => setVisibility(e.target.value)}>
            <option value="public">Public: listed in the cloud</option>
            <option value="unlisted">Unlisted: only with the link or code</option>
            <option value="private">Private: only you</option>
          </select>
        </div>
      </div>
      {chosen && !chosen.canUpload && <Notice tone="amber">{chosen.reason} Uploading needs access to the Lua the config is made for.</Notice>}
      <div className="grid gap-5 sm:grid-cols-2">
        <div>
          <label htmlFor="up-name" className="label">Name</label>
          <input id="up-name" className="input" value={name} onChange={(e) => setName(e.target.value)} maxLength={LIMITS.configNameLen} placeholder="Legit mid-range" required autoComplete="off" />
        </div>
        <div>
          <label htmlFor="up-tags" className="label">Tags</label>
          <input id="up-tags" className="input" value={tags} onChange={(e) => setTags(e.target.value)} placeholder="legit, hvh, scout" autoComplete="off" aria-describedby="up-tags-help" />
          <p id="up-tags-help" className="mt-1.5 text-xs text-[color:var(--faint)]">Comma separated, up to {LIMITS.maxTags} tags.</p>
        </div>
      </div>
      <div>
        <label htmlFor="up-desc" className="label">Description</label>
        <textarea id="up-desc" className="input" rows={3} value={description} onChange={(e) => setDescription(e.target.value)} maxLength={LIMITS.configDescLen} placeholder="What is it good for?" />
      </div>
      <ContentInput value={content} onChange={setContent} parsed={parsed} template={chosen?.template ?? null} productName={chosen?.name ?? "the Lua"} />
      {error && <Problems message={error.message} problems={error.problems} />}
      {done && (
        <div role="status" className="rounded-xl border border-emerald-400/30 bg-emerald-500/10 px-4 py-3 text-sm text-emerald-100">
          <p className="font-medium">Config uploaded.</p>
          <p className="mt-1 text-emerald-200/80">Share code: <code className="font-mono">{done.slug}</code></p>
          <div className="mt-3 flex flex-wrap gap-2">
            <Link href={`/dashboard/configs/${done.slug}`} className="btn-ghost btn-sm">Manage it</Link>
            <CopyButton text={done.slug} label="Copy code" />
          </div>
        </div>
      )}
      <div className="flex flex-wrap items-center justify-between gap-3">
        <p className="text-xs text-[color:var(--faint)]">Up to {LIMITS.uploadsPerDay} uploads a day.</p>
        <button type="submit" className="btn-primary" disabled={busy || !chosen?.canUpload}>{busy ? "Uploading..." : "Upload config"}</button>
      </div>
    </form>
  );
}
