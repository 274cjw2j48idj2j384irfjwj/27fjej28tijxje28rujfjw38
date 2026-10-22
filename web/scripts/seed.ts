// Demo data for looking at the site. Everything it writes is marked as demo (is_demo, or a demo_ user) and shown with a
// "Demo data" label. Re-running it replaces the old demo data. Never run it on production without wanting the labels there.
import { closePool, one, pool, query } from "../src/lib/db";
import { periodOf, previousPeriod } from "../src/lib/leaderboard";

const demoSvg = (title: string, hue: number) =>
  `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1280 720"><defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="hsl(${hue},45%,13%)"/><stop offset="1" stop-color="hsl(${hue + 30},50%,7%)"/></linearGradient></defs>
<rect width="1280" height="720" fill="url(#g)"/><rect x="140" y="90" width="1000" height="540" rx="22" fill="#0e0c16" stroke="hsl(${hue},70%,70%)" stroke-opacity=".35"/>
<rect x="140" y="90" width="230" height="540" rx="22" fill="#12101c"/>${[0, 1, 2, 3, 4].map((i) => `<rect x="168" y="${130 + i * 56}" width="${150 - i * 8}" height="14" rx="7" fill="hsl(${hue},60%,75%)" fill-opacity="${i === 1 ? 0.85 : 0.22}"/>`).join("")}
${[0, 1, 2, 3, 4, 5].map((i) => `<rect x="420" y="${140 + i * 70}" width="${520 - (i % 3) * 90}" height="14" rx="7" fill="#fff" fill-opacity=".12"/><rect x="1020" y="${134 + i * 70}" width="64" height="26" rx="13" fill="hsl(${hue},75%,62%)" fill-opacity="${i % 2 ? 0.8 : 0.2}"/>`).join("")}
<text x="640" y="672" text-anchor="middle" font-family="sans-serif" font-size="26" letter-spacing="8" fill="#fff" fill-opacity=".3">${title}</text></svg>`;

async function main() {
  const db = pool();
  await query("delete from users where discord_id like '9000%'"); // cascades to the demo configs, scores and results
  await query("delete from product_media where is_demo");
  await query("delete from releases where is_demo");
  await query("delete from score_events where is_demo");

  const names = ["Nova", "Raven", "Echo", "Kestrel", "Onyx", "Lyra", "Vesper", "Atlas", "Mirage", "Zephyr", "Ember", "Quill"];
  const users: { id: string; name: string }[] = [];
  for (let i = 0; i < names.length; i++) {
    const row = await one<{ id: string }>(
      "insert into users (discord_id, username, global_name, verified_creator, created_at) values ($1,$2,$3,$4, now() - ($5 || ' days')::interval) returning id",
      [`9000000000000000${String(i + 10)}`, `demo_${names[i].toLowerCase()}`, `${names[i]} (demo)`, i < 3, 200 - i * 9],
    );
    users.push({ id: row!.id, name: names[i] });
  }

  await query(
    `update products set latest_version = '1.0.0', install_guide = $2, compat_notes = $3, features = $4::jsonb where id = $1`,
    [
      "gamesense",
      "Demo text, edit it in Admin > Products.\n1. Download the loader from the Downloads page.\n2. Put it into your gamesense lua folder.\n3. Load it in game and sign in.\n4. Import a config from the cloud with its share code.",
      "Demo text. Configs of format 1 are supported.",
      JSON.stringify([
        { category: "Ragebot", title: "Example ragebot option", text: "Demo feature, replace it in Admin.", demo: true },
        { category: "Ragebot", title: "Another example option", text: "Demo feature.", demo: true },
        { category: "Anti-Aim", title: "Example anti-aim option", text: "Demo feature.", demo: true },
        { category: "Visuals", title: "Example visual option", text: "Demo feature.", demo: true },
        { category: "Config", title: "Config cloud", text: "Share and import configs.", demo: true },
      ]),
    ],
  );
  await query(
    `update products set latest_version = '1.0.0', install_guide = $2, compat_notes = $3, features = $4::jsonb where id = $1`,
    [
      "primordial",
      "Demo text, edit it in Admin > Products.\n1. Download the loader from the Downloads page.\n2. Put it into the Primordial scripts folder.\n3. Load it and sign in.\n4. Import a config from the cloud with its share code.",
      "Demo text. Configs of format 1 are supported.",
      JSON.stringify([
        { category: "Ragebot", title: "Example ragebot option", text: "Demo feature.", demo: true },
        { category: "Anti-Aim", title: "Example anti-aim option", text: "Demo feature.", demo: true },
        { category: "Visuals", title: "Example visual option", text: "Demo feature.", demo: true },
        { category: "Misc", title: "Example misc option", text: "Demo feature.", demo: true },
      ]),
    ],
  );

  for (const [product, hue] of [["gamesense", 262], ["primordial", 285]] as const) {
    for (const [i, cat] of (["menu", "visuals", "configuration"] as const).entries()) {
      const blob = await one<{ id: string }>("insert into blobs (content_type, bytes) values ('image/svg+xml', $1) returning id", [Buffer.from(demoSvg(`${cat.toUpperCase()} - DEMO`, hue + i * 12))]);
      await query("insert into product_media (product_id, kind, category, blob_id, caption, sort, is_demo) values ($1,'screenshot',$2,$3,$4,$5,true)", [product, cat, blob!.id, `Demo ${cat} image`, i]);
    }
    await query("insert into releases (product_id, version, title, notes, released_at, is_demo) values ($1,'1.0.0','First release',$2,now() - interval '9 days',true), ($1,'1.0.1','Small fixes',$3,now() - interval '2 days',true)", [
      product,
      JSON.stringify(["Demo release note one", "Demo release note two"]),
      JSON.stringify(["Demo fix one", "Demo fix two"]),
    ]);
  }

  const mk = async (owner: number, product: "gamesense" | "primordial", name: string, tags: string[], opts: { official?: boolean; featured?: boolean; likes?: number; dl?: number } = {}) => {
    const slug = Math.random().toString(36).slice(2, 12).padEnd(10, "x");
    const c = await one<{ id: string }>(
      `insert into configs (slug, product_id, owner_id, name, description, tags, is_official, is_featured, is_demo, likes_count, downloads_count, imports_count, updated_at)
       values ($1,$2,$3,$4,$5,$6,$7,$8,true,$9,$10,$11, now() - ($12 || ' hours')::interval) returning id`,
      [slug, product, users[owner].id, name, "Demo config. Replace it with a real upload.", tags, !!opts.official, !!opts.featured, opts.likes ?? 0, opts.dl ?? 0, Math.floor((opts.dl ?? 0) / 3), Math.floor(Math.random() * 200)],
    );
    await query("insert into config_versions (config_id, version, payload, payload_bytes, format_version, lua_version) values ($1,1,$2,64,1,'1.0.0')", [c!.id, JSON.stringify({ meta: { product, format_version: 1, lua_version: "1.0.0" }, data: { demo: true } })]);
  };
  await mk(0, "gamesense", "Official starter", ["official", "starter"], { official: true, featured: true, likes: 48, dl: 210 });
  await mk(1, "gamesense", "Closet rage", ["rage"], { featured: true, likes: 21, dl: 90 });
  await mk(2, "gamesense", "Soft legit", ["legit"], { likes: 9, dl: 33 });
  await mk(3, "gamesense", "Hvh all rounder", ["hvh", "rage"], { likes: 14, dl: 61 });
  await mk(0, "primordial", "Official starter", ["official", "starter"], { official: true, featured: true, likes: 37, dl: 150 });
  await mk(4, "primordial", "Primordial rage", ["rage"], { likes: 12, dl: 44 });
  await mk(5, "primordial", "Quiet legit", ["legit"], { likes: 5, dl: 20 });

  const now = new Date();
  const cur = periodOf(now);
  const prev = previousPeriod(cur);
  const pts = [940, 870, 820, 610, 560, 430, 380, 290, 210, 150, 90, 40];
  for (const [bi, board] of ["gamesense", "primordial"].entries()) {
    for (const [i, u] of users.entries()) {
      const total = Math.max(10, pts[(i + bi * 3) % pts.length]);
      await query("insert into score_events (board_id, user_id, period, event_type, points, dedupe_key, is_demo, created_at) values ($1,$2,$3,'demo',$4,$5,true, now() - ($6 || ' hours')::interval)", [board, u.id, cur, total, `demo:${board}:${cur}:${u.id}`, i * 7]);
    }
    for (let r = 1; r <= 3; r++) {
      await query("insert into monthly_results (board_id, period, rank, user_id, points, is_demo) values ($1,$2,$3,$4,$5,true) on conflict do nothing", [board, prev, r, users[(r + bi * 2) % users.length].id, 1000 - r * 90]);
    }
  }
  for (let r = 1; r <= 3; r++) await query("insert into monthly_results (board_id, period, rank, user_id, points, is_demo) values ('overall',$1,$2,$3,$4,true) on conflict do nothing", [prev, r, users[r].id, 1800 - r * 160]);

  console.log("demo data written");
}

main().catch((e) => { console.error(e); process.exitCode = 1; }).finally(closePool);
