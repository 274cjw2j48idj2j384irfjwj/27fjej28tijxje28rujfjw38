"use client";

import { useState } from "react";
import { ActionButton, Feedback, Field, Switch, callApi, td, th, useRun } from "./kit";
import { Avatar, Badge, Card, Notice } from "@/components/ui";

type Rule = { key: string; points: string; cap: string };
export type BoardData = {
  id: string; name: string; kind: "product" | "overall"; scoring: boolean; rewards: boolean; rewardProduct: string | null; rewardDays: number[];
  rules: { key: string; points: number; cap?: number }[];
  period: string; events: number;
  standings: { rank: number; name: string; avatar: string; points: number; demo: boolean }[];
};

export function BoardPanel({ b, products }: { b: BoardData; products: { id: string; name: string }[] }) {
  const r = useRun();
  const isProduct = b.kind === "product";
  const [scoring, setScoring] = useState(b.scoring);
  const [rules, setRules] = useState<Rule[]>(b.rules.map((x) => ({ key: x.key, points: String(x.points), cap: x.cap ? String(x.cap) : "" })));
  const [rewards, setRewards] = useState(b.rewards);
  const [rp, setRp] = useState(b.rewardProduct ?? "");
  const [days, setDays] = useState(b.rewardDays.map(String));
  const [askScoring, setAskScoring] = useState(false);

  const setRule = (i: number, patch: Partial<Rule>) => setRules((a) => a.map((x, j) => (j === i ? { ...x, ...patch } : x)));
  const keys = rules.map((x) => x.key.trim());
  const ruleErr = isProduct
    ? rules.some((x) => !/^[a-z0-9_]{1,40}$/.test(x.key.trim()) || !Number.isInteger(Number(x.points)) || Number(x.points) < 1 || Number(x.points) > 1000 || (x.cap !== "" && (!Number.isInteger(Number(x.cap)) || Number(x.cap) < 1 || Number(x.cap) > 100000)))
      ? "Each event needs a key of a-z, 0-9 and _, points from 1 to 1000 and an optional daily cap."
      : new Set(keys).size !== keys.length ? "Two events have the same key." : ""
    : "";
  const dayErr = days.some((d) => !Number.isInteger(Number(d)) || Number(d) < 1 || Number(d) > 365) ? "Reward days must be whole numbers from 1 to 365." : "";
  const rewardErr = rewards && !rp ? "Choose the product the reward gives access to." : "";
  const err = ruleErr || dayErr || rewardErr;

  const save = async () => {
    setAskScoring(false);
    const payload: Record<string, unknown> = { rewards_enabled: rewards, reward_product_id: rp || null, reward_days: days.map(Number) };
    if (isProduct) {
      payload.scoring_enabled = scoring;
      payload.rules = { events: Object.fromEntries(rules.map((x) => [x.key.trim(), { points: Number(x.points), ...(x.cap !== "" ? { dailyCap: Number(x.cap) } : {}) }])) };
    }
    await r.run(() => callApi(`/api/admin/boards/${b.id}`, { method: "PUT", json: payload }), "Board settings saved.");
  };
  const onSave = () => (isProduct && scoring && !b.scoring ? setAskScoring(true) : void save());

  return (
    <Card className="p-5 sm:p-6">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <h2 className="text-xl font-semibold text-white">{b.name}</h2>
        <div className="flex gap-2">
          <Badge tone={b.kind === "overall" ? "gray" : b.scoring ? "green" : "amber"}>{b.kind === "overall" ? "Adds the product boards" : b.scoring ? "Collecting points" : "Scoring off"}</Badge>
          <Badge tone={b.rewards ? "green" : "gray"}>Rewards {b.rewards ? "on" : "off"}</Badge>
        </div>
      </div>

      <form onSubmit={(e) => { e.preventDefault(); onSave(); }} className="mt-6 space-y-7">
        {isProduct ? (
          <section className="space-y-4">
            <Switch checked={scoring} onChange={setScoring} label="Scoring enabled" hint="When off, the Lua can report events but no point is stored." />
            <Notice tone="amber"><strong>Warning:</strong> production point collection must only be enabled once the scoring rules below are approved. Points that were collected cannot be recalculated, and the top three win real subscription days.</Notice>
            <div>
              <div className="mb-2 flex items-center justify-between gap-3">
                <p className="label !mb-0">Scoring rules</p>
                <button type="button" className="btn-ghost btn-sm" onClick={() => setRules((a) => [...a, { key: "", points: "1", cap: "" }])}>Add event</button>
              </div>
              {rules.length === 0 ? <p className="muted text-sm">No events yet: nothing can score on this board.</p> : (
                <ul className="space-y-2">
                  {rules.map((x, i) => (
                    <li key={i} className="grid grid-cols-[1fr_90px] items-end gap-2 sm:grid-cols-[1fr_110px_130px_auto]">
                      <Field label={i === 0 ? "Event type" : "Event"}>{(id) => <input id={id} className="input font-mono" value={x.key} maxLength={40} onChange={(e) => setRule(i, { key: e.target.value })} placeholder="kill_streak" />}</Field>
                      <Field label="Points">{(id) => <input id={id} type="number" min={1} max={1000} className="input" value={x.points} onChange={(e) => setRule(i, { points: e.target.value })} />}</Field>
                      <Field label="Daily cap" className="col-span-1">{(id) => <input id={id} type="number" min={1} className="input" placeholder="None" value={x.cap} onChange={(e) => setRule(i, { cap: e.target.value })} />}</Field>
                      <button type="button" className="btn-danger btn-sm col-span-1 self-end justify-self-start sm:mb-1" onClick={() => setRules((a) => a.filter((_, j) => j !== i))} aria-label={`Remove event ${x.key || i + 1}`}>Remove</button>
                    </li>
                  ))}
                </ul>
              )}
              <p className="mt-2 text-xs text-[color:var(--faint)]">The daily cap is the most points one player can earn from this event per UTC day.</p>
            </div>
          </section>
        ) : (
          <Notice>The overall board adds up both product boards of the month. It collects no points itself, so it has no scoring switch or rules.</Notice>
        )}

        <section className="space-y-4 border-t border-line pt-6">
          <Switch checked={rewards} onChange={setRewards} label="Rewards enabled" hint="When the month closes, the top three get subscription days added to their access." />
          <div className="grid gap-4 sm:grid-cols-4">
            <Field label="Reward product" className="sm:col-span-1">{(id) => <select id={id} className="input" value={rp} onChange={(e) => setRp(e.target.value)}><option value="">Not set</option>{products.map((p) => <option key={p.id} value={p.id}>{p.name}</option>)}</select>}</Field>
            {["1st", "2nd", "3rd"].map((l, i) => (
              <Field key={l} label={`Days for ${l}`}>{(id) => <input id={id} type="number" min={1} max={365} className="input" value={days[i]} onChange={(e) => setDays((d) => d.map((x, j) => (j === i ? e.target.value : x)))} />}</Field>
            ))}
          </div>
        </section>

        <div className="flex flex-wrap items-center gap-3">
          {askScoring ? (
            <>
              <Notice tone="red">Enable production point collection? Only do this when the scoring rules are approved.</Notice>
              <button type="button" className="btn-danger btn-sm" autoFocus onClick={() => void save()}>Yes, enable scoring</button>
              <button type="button" className="btn-ghost btn-sm" onClick={() => setAskScoring(false)}>Cancel</button>
            </>
          ) : (
            <button className="btn-primary" type="submit" disabled={r.busy || !!err}>{r.busy ? "Saving..." : "Save board settings"}</button>
          )}
          {err && <span className="text-sm text-amber-300">{err}</span>}
          <Feedback run={r} />
        </div>
      </form>

      <section className="mt-8 border-t border-line pt-6">
        <h3 className="text-base font-medium text-white">Standings {b.period}</h3>
        <p className="muted mt-1 text-sm">{b.events} score events this month. Top 10 shown.</p>
        {b.standings.length === 0 ? <p className="muted mt-3 text-sm">No points this month yet.</p> : (
          <div className="mt-3 overflow-x-auto scroll-thin" role="region" aria-label={`${b.name} standings`} tabIndex={0}>
            <table className="w-full min-w-[360px]">
              <thead className="border-b border-line"><tr><th className={th}>#</th><th className={th}>Player</th><th className={`${th} text-right`}>Points</th></tr></thead>
              <tbody className="divide-y divide-[color:var(--line)]">
                {b.standings.map((s) => (
                  <tr key={s.rank}><td className={`${td} w-12 font-mono`}>{s.rank}</td><td className={td}><span className="flex items-center gap-2.5"><Avatar src={s.avatar} name="" size={24} />{s.name}{s.demo && <Badge tone="amber">Demo</Badge>}</span></td><td className={`${td} text-right font-mono`}>{s.points}</td></tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>

      {isProduct && <ManualPoints boardId={b.id} />}
    </Card>
  );
}

type U = { id: string; username: string; global_name: string | null; discord_id: string };

function ManualPoints({ boardId }: { boardId: string }) {
  const r = useRun();
  const [q, setQ] = useState("");
  const [found, setFound] = useState<U[] | null>(null);
  const [searchErr, setSearchErr] = useState("");
  const [pick, setPick] = useState<U | null>(null);
  const [points, setPoints] = useState("");
  const [reason, setReason] = useState("");
  const n = Number(points);
  const valid = !!pick && Number.isInteger(n) && n !== 0 && Math.abs(n) <= 100000 && reason.trim().length > 0;
  const search = async () => {
    setSearchErr("");
    try {
      const res = await callApi<{ users: U[] }>(`/api/admin/users?q=${encodeURIComponent(q.trim())}`);
      setFound(res.users.slice(0, 8));
    } catch (e) {
      setFound(null);
      setSearchErr(e instanceof Error ? e.message : "Search failed.");
    }
  };
  const give = async () => {
    const ok = await r.run(() => callApi(`/api/admin/boards/${boardId}/score`, { method: "POST", json: { user_id: pick!.id, points: n, reason: reason.trim() } }), `${n > 0 ? "+" : ""}${n} points recorded for ${pick!.global_name || pick!.username}.`);
    if (ok) { setPoints(""); setReason(""); }
  };
  return (
    <section className="mt-8 border-t border-line pt-6">
      <h3 className="text-base font-medium text-white">Manual points</h3>
      <p className="muted mt-1 text-sm">Add or remove points for a player this month (a negative number removes). Every entry is kept with its reason and written to the audit log.</p>
      <div className="mt-4 grid gap-6 lg:grid-cols-2">
        <div>
          <form onSubmit={(e) => { e.preventDefault(); void search(); }} className="flex gap-2" role="search">
            <label htmlFor={`mp-${boardId}`} className="sr-only">Find a player</label>
            <input id={`mp-${boardId}`} className="input" value={q} onChange={(e) => setQ(e.target.value)} placeholder="Find player by name or Discord id" maxLength={40} />
            <button className="btn-ghost" type="submit">Find</button>
          </form>
          {searchErr && <p role="alert" className="mt-2 text-sm text-red-300">{searchErr}</p>}
          {found && (found.length === 0 ? <p className="muted mt-2 text-sm">Nobody found.</p> : (
            <ul className="mt-2 divide-y divide-[color:var(--line)] rounded-xl border border-line">
              {found.map((u) => (
                <li key={u.id}>
                  <button type="button" onClick={() => setPick(u)} aria-pressed={pick?.id === u.id} className={`flex w-full items-center justify-between gap-3 px-3 py-2 text-left text-sm hover:bg-white/[0.04] ${pick?.id === u.id ? "bg-violet-500/15" : ""}`}>
                    <span className="truncate">{u.global_name || u.username}</span><span className="font-mono text-xs text-[color:var(--faint)]">{u.discord_id}</span>
                  </button>
                </li>
              ))}
            </ul>
          ))}
        </div>
        <form onSubmit={(e) => { e.preventDefault(); void give(); }} className="space-y-3">
          <p className="text-sm">{pick ? <>Player: <strong className="text-white">{pick.global_name || pick.username}</strong></> : <span className="muted">Pick a player from the search first.</span>}</p>
          <div className="grid grid-cols-[110px_1fr] gap-3">
            <Field label="Points">{(id) => <input id={id} type="number" className="input" value={points} onChange={(e) => setPoints(e.target.value)} placeholder="50" />}</Field>
            <Field label="Reason">{(id) => <input id={id} className="input" maxLength={200} value={reason} onChange={(e) => setReason(e.target.value)} placeholder="e.g. event winner" />}</Field>
          </div>
          <div className="flex flex-wrap items-center gap-3"><button className="btn-primary btn-sm" type="submit" disabled={r.busy || !valid}>{r.busy ? "Saving..." : "Record points"}</button><Feedback run={r} /></div>
        </form>
      </div>
    </section>
  );
}

type Summary = { boardId: string; period: string; alreadyClosed: boolean; results: number; rewards: number };

export function CloseMonth({ boards, suggestions, defaultPeriod }: { boards: { id: string; name: string }[]; suggestions: { board_id: string; period: string }[]; defaultPeriod: string }) {
  const [board, setBoard] = useState(suggestions[0]?.board_id ?? boards[0]?.id ?? "");
  const [period, setPeriod] = useState(suggestions[0]?.period ?? defaultPeriod);
  const [summary, setSummary] = useState<Summary | null>(null);
  const valid = /^\d{4}-(0[1-9]|1[0-2])$/.test(period);
  return (
    <Card className="p-5 sm:p-6">
      <h2 className="text-lg font-medium text-white">Close a finished month</h2>
      <p className="muted mt-1 text-sm">Stores the final top three and pays the rewards. The monthly job does this by itself; use this if you want it now. Closing a month twice does nothing the second time, and a month that is not over yet is refused.</p>
      {suggestions.length > 0 && (
        <div className="mt-4"><p className="label">Waiting to be closed</p>
          <ul className="flex flex-wrap gap-2">{suggestions.map((s) => <li key={s.board_id + s.period}><button type="button" className="btn-ghost btn-sm" onClick={() => { setBoard(s.board_id); setPeriod(s.period); }}>{boards.find((b) => b.id === s.board_id)?.name ?? s.board_id} {s.period}</button></li>)}</ul>
        </div>
      )}
      <div className="mt-4 grid gap-3 sm:grid-cols-[1fr_1fr_auto] sm:items-end">
        <Field label="Board">{(id) => <select id={id} className="input" value={board} onChange={(e) => setBoard(e.target.value)}>{boards.map((b) => <option key={b.id} value={b.id}>{b.name}</option>)}</select>}</Field>
        <Field label="Month (UTC)" hint="Format 2026-09">{(id) => <input id={id} className="input font-mono" value={period} onChange={(e) => setPeriod(e.target.value)} placeholder="2026-09" maxLength={7} />}</Field>
        <div className="pb-6 sm:pb-[26px]">
          <ActionButton variant="primary" small={false} disabled={!valid} confirm={`Close ${period} on the ${boards.find((b) => b.id === board)?.name} board and pay its rewards?`} success="Month closed."
            onRun={async () => setSummary(await callApi<Summary>(`/api/admin/boards/${board}/close`, { method: "POST", json: { period } }))}>Close month</ActionButton>
        </div>
      </div>
      {summary && (
        <div role="status" className="mt-2"><Notice tone={summary.alreadyClosed ? "gray" : "green"}>
          {summary.alreadyClosed ? `${summary.period} was already closed on this board. Nothing changed.` : `${summary.period} closed: ${summary.results} result${summary.results === 1 ? "" : "s"} stored, ${summary.rewards} reward${summary.rewards === 1 ? "" : "s"} paid.`}
        </Notice></div>
      )}
    </Card>
  );
}
