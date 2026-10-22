# SPECTER web platform

Next.js 15 (App Router), TypeScript, Tailwind, PostgreSQL. Discord login, két külön Lua (Gamesense / Primordial) külön
termékoldallal, hozzáférés-kezelés, config-cloud, havi ranglista jutalmakkal, admin felület.

A Lua nevek, azonosítók, a Discord szerver és a role ID-k egy helyen vannak: `src/config/site.ts` (env-ből felülírható),
a role-ok az admin felületen is (Discord Role Mapping).

## Mi működik, mi demó, mihez kell beállítás

| Terület | Állapot |
|---|---|
| Publikus oldalak (home, termékoldalak, features, previews, cloud, leaderboard, changelog, FAQ, support, status, profil) | **Működik**, valódi adatbázisból |
| Discord belépés, session, jogosultság (role -> Lua hozzáférés) | **Működik, ha** a Discord app + bot be van állítva (lásd lent). Nélküle a belépés kikapcsolva, a hozzáférés csak adminról adott (grant) lehet |
| Hozzáférési állapotok (No access / Active / Expiring soon / Expired / Suspended) + Discord-hiba külön jelzése | **Működik**, tesztelve |
| Config-cloud (feltöltés weben, verziók, képek, like, mentés, jelentés, moderáció, láthatóság, kompatibilitás) | **Működik** |
| Lua -> web -> Lua kapcsolat (eszközkód, token, feltöltés, böngészés, import, mentett könyvtár) | **A szerveroldal kész és tesztelt.** A Lua kliensekbe be kell építeni a hívásokat (lásd lent) |
| Havi ranglista, lezárás, 30 / 14 / 7 napos jutalom, dupla kiosztás elleni védelem | **Működik**, tesztelve. A pontgyűjtés **alapból ki van kapcsolva** |
| Pontozási szabály | **Nincs kitalálva.** Az admin adja meg (Leaderboard Management), addig a Luáktól jövő pont nem számít |
| Demó adatok | Csak a `npm run seed` írja be őket, mindenhol **Demo data** címkével. Éles adatbázison ne futtasd |
| Képek / Lua fájlok tárolása | Az adatbázisban (`blobs`). Nagyobb forgalomhoz külső objektumtár kell (nincs megírva) |

## Helyi futtatás

```
cd web
cp .env.example .env.local        # DATABASE_URL és PUBLIC_URL kell hozzá
npm install
npm run migrate                   # táblák
npm run seed                      # (opcionális) demó adatok
npm run dev
```

Teszt: `npm test` (valódi PostgreSQL kell, `TEST_DATABASE_URL`, alapból `postgres://pgrun@localhost:5433/specter_test`;
a tesztek **törlik** annak az adatbázisnak a tartalmát). Típusellenőrzés: `npm run typecheck`.

## Discord beállítás

1. https://discord.com/developers/applications: a meglévő Specter app (vagy új) -> **OAuth2**: Redirects: `PUBLIC_URL/api/auth/callback`.
   `DISCORD_CLIENT_ID`, `DISCORD_CLIENT_SECRET`.
2. **Bot**: ugyanaz a bot, ami a Discord szerveren van, elég; a tokenje a `DISCORD_BOT_TOKEN`. Csak a tagok role-jainak olvasására kell
   (REST `GET /guilds/{id}/members/{id}`), nincs szükség Server Members Intentre.
3. `DISCORD_GUILD_ID` = a szerver ID-je (Developer Mode -> jobb klikk -> Copy Server ID).
4. Role-ok: `LUA1_ROLE_IDS` / `LUA2_ROLE_IDS`, vagy az admin felület Discord Role Mapping oldalán. Egy role-nak csak az adott Luához van jogosultsága.
5. `ADMIN_DISCORD_IDS` = az owner(ek) Discord user ID-ja. Ők tudnak további adminokat kinevezni.

A role-ellenőrzés élő (5 perc cache). Ha a Discord nem elérhető, az oldal **nem** azt mondja, hogy nincs hozzáférés: külön hibaüzenet
és a letöltés/feltöltés 503 `discord_unavailable` (zárva marad, de a hiba oka látszik). Az admin által adott és a jutalom-hozzáférés
Discord nélkül is működik.

## Railway

Új service ugyanabból a repóból, **Root Directory = `web`** (a `web/Dockerfile` épít, indításkor lefuttatja a migrációt). Kell hozzá egy
PostgreSQL plugin (`DATABASE_URL`), és a `.env.example` változói. A meglévő license szerver és a bot érintetlen.

### Havi lezárás (cron)

A hónap végi eredményt és a jutalmakat az `POST /api/cron/close-month` adja ki, `Authorization: Bearer $CRON_SECRET` fejléccel.
Hívhatod óránként is (Railway cron, GitHub Actions, bármi): idempotens, egy lezárt hónapot soha nem fizet ki kétszer
(`period_closures` + `reward_log` egyedi kulcsok, advisory lock). Példa:

```
curl -X POST https://specter.example.com/api/cron/close-month -H "Authorization: Bearer $CRON_SECRET"
```

A hónaphatárok UTC-ben vannak. Holtverseny: több pont, majd aki előbb érte el (korábbi utolsó pont), majd a régebbi fiók, majd az ID.
Jutalom: aktív hozzáférést a lejáratától meghosszabbítja, lejárt/nincs hozzáférésnél a kiosztástól indul, a lejárat nélküli hozzáférést nem
bántja (naplózza). A jutalom a ranglistán beállított termékre szól (Leaderboard Management), a felhasználó értesítést kap.

## Lua kliens integráció (mit kell beépíteni a két Luába)

A weboldal a szerver oldalt adja, a Lua menübe a következő hívások kellenek (`Authorization: Bearer <token>`, JSON). Az alap URL a site `PUBLIC_URL`-je.

1. **Összekapcsolás** (egyszer):
   * `POST /api/device/code` `{"product":"gamesense"|"primordial","client_name":"Specter"}` -> `device_code`, `user_code`, `verification_uri`, `interval`
   * a Lua kiírja a `user_code`-ot (+ megnyitja a `verification_uri_complete` linket), a felhasználó belépve jóváhagyja a `/link` oldalon
   * `POST /api/device/token` `{"device_code":"..."}` az `interval` másodpercenként -> `{"status":"pending"}` ... `{"status":"approved","access_token":"spt_..."}`
     (a token egyszer jön meg; `slow_down`, `denied`, `expired` is lehet). A tokent a Lua a saját mappájába menti, a Connected Devices oldalon visszavonható.
2. **Upload to Cloud**: `POST /api/client/configs` `{"name","description","tags":[],"visibility":"public|unlisted|private","payload":{"meta":{"product","format_version","lua_version"},"data":...}}`
   -> `{slug, share_code, url}`. Új verzió: `PUT /api/client/configs/{slug}` `{"payload":...,"changelog":"..."}`.
3. **Browse Cloud**: `GET /api/client/configs?q=&sort=latest|popular|downloads|featured&page=` (csak a token Luájának configjai).
4. **Import**: `GET /api/client/configs/{code}` (név, szerző, kompatibilitás, **adat nélkül**: ezt kell megmutatni importálás előtt), majd
   `GET /api/client/configs/{code}/payload`. Nem kompatibilis configra 409.
5. **My Uploads**: `GET /api/client/uploads`. **Saved Configs**: `GET /api/client/library` (`updateAvailable` jelzővel).
6. **Pont** (alapból kikapcsolva): `POST /api/client/score` `{"event_type","dedupe_key"}`. A pontot a szerver adja az admin szabály szerint, a kliens nem küldhet pontot.

A config **adat**: `meta` + `data`. A `data` lehet objektum vagy szöveg (pl. az exportált base64). A szerver nem futtat belőle semmit, és visszautasítja a
tokent / kulcsot / webhookot / e-mailt / Windows user útvonalat / kódot tartalmazó configot, a túl nagyot (256 KB) és túl mélyet. A két Lua mostani
exportja (gamesense: pui export, primordial: eui export) ebbe a borítékba csomagolható, a `format_version`-t az admin a Products oldalon állítja.

## Biztonság

* A jogosultságot minden védett API hívás a **szerveren** ellenőrzi (`requireProductAccess`), a gombok elrejtése csak kényelem.
* Session: véletlen token, az adatbázisban csak a SHA-256 hash, `HttpOnly`, `SameSite=Lax`, `Secure` https alatt. A cookie-s írások `Origin` ellenőrzést kapnak.
* Kliens token: visszavonható, 90 napos, scope-os, csak a hash van tárolva; az eszközkód és a felhasználói kód lejár (10 perc), a jóváhagyás rate limitelt.
* Rate limit az adatbázisban (több példányon is közös): belépés, eszközkód, feltöltés, jelentés, kedvelés, pont.
* Feltöltési korlátok: config 256 KB, kép 2 MB (PNG/JPEG/WebP, a fájl eleje ellenőrizve, SVG tiltva), napi 20 feltöltés / felhasználó.
* Minden admin művelet és minden kiosztás az audit naplóba kerül.
* A titkok (`DISCORD_*`, `CRON_SECRET`) csak a szerveren vannak, a böngészőbe nem kerülnek.
