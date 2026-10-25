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
| Fizetés (Stripe, NOWPayments) -> license kulcs | A szerveroldal kész, **mockokkal tesztelt**, valódi test kulccsal még nem próbált (lásd Fizetés) |
| Demó adatok | Csak a `npm run seed` írja be őket, mindenhol **Demo data** címkével. Éles adatbázison ne futtasd |
| Képek / Lua fájlok tárolása | Az adatbázisban (`blobs`). Nagyobb forgalomhoz külső objektumtár kell (nincs megírva) |

## Oldalak

* Publikus: `/`, `/pricing`, `/order/[id]`, `/luas/[slug]` (két termékoldal), `/features`, `/previews`, `/cloud`, `/cloud/[lua]`, `/cloud/[lua]/[kód]`, `/leaderboard`, `/changelog`, `/faq`, `/support`, `/status`, `/u/[discord id]`, `/login`, `/link`.
* Bejelentkezve (`/dashboard/...`): Overview, My Access, Downloads, My Configs (+ kezelés), Saved Configs, Leaderboard, Rewards, Connected Devices, Orders, Account Settings, Notifications.
* Admin (`/admin/...`): Users & Access, Discord Role Mapping, Products & Releases (funkciók, letöltések, képek, kiadások), Plans, Orders, Config Moderation, Leaderboard Management, Monthly Rewards, Audit Log.
* Ctrl+K: gyorskereső (parancspaletta).

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

## Fizetés (Stripe kártya + NOWPayments crypto)

A vásárlás a `/pricing` oldalon történik, a státusz a `/order/<id>` oldalon látszik. **Fontos: a Stripe és a NOWPayments hívások csak mockokkal
lettek tesztelve (36 teszt, `tests/payments.test.ts`), valódi test kulccsal / sandboxszal még nem futottak. Élesítés előtt végig kell próbálni.**

### Hogyan megy

1. Az admin a `/admin/plans` oldalon létrehozza a csomagokat (ár, időtartam, melyik license plan, kártya / crypto kapcsoló). **Nincs beégetett ár**, üres adatbázisnál a `/pricing` üres állapotot mutat.
2. A vevő a `/pricing` oldalon a csomagra kattint: `POST /api/checkout {plan, provider: card|crypto, email?}`. Az összeget a szerver az adatbázisból veszi, a kliens nem küldhet árat. A válasz a fizetési oldal URL-je (Stripe Checkout / NOWPayments invoice). Rate limit: 10 / 10 perc IP-nként és felhasználónként.
3. A rendelés (`orders`) `pending`. A csomag adatai a rendelésbe másolódnak (`plan_snapshot`), a későbbi ár- vagy névmódosítás nem érinti.
4. Fizetés után a provider webhookot hív (Stripe: `/api/webhooks/stripe`, NOWPayments: `/api/webhooks/nowpayments`, csak az aláírás számít). A szerver ellenőrzi az összeget, a pénznemet, a session / invoice azonosítót, majd `paid` állapotot ír, és **a tranzakción kívül** meghívja a license szerver `POST /admin/create` végpontját `ref = order id` értékkel (idempotens, párhuzamos kézbesítésnél is egy kulcs). A kulcs az **Invoice ID**, az `issued` rendelésnél jelenik meg az order oldalon (előbb soha).
5. A vevő Discordban `/register key:<Invoice ID>`, `/download`, majd a loaderben ugyanazt a kulcsot adja meg.

Állapotok: `pending` -> `paid` -> `issued`; `expired` (24 óra fizetés nélkül, vagy a provider lejárt), `failed`, `review` (eltérő összeg / pénznem / session, alulfizetés, lejárt rendelésre érkező fizetés: **nem készül kulcs**, admin dönt), `refunded` (a kulcs visszavonva).
Ha a license szerver nem elérhető: a rendelés `paid` marad, a webhook 500-at ad (a provider újrapróbálja), a cron (`/api/cron/close-month`, óránként érdemes hívni) 1 perc után 20 alkalomig újrapróbálja (`issued` a válaszban). Az admin a `/admin/orders` oldalon kézzel is kiadhatja (`Issue key`).

### Környezeti változók (`.env.example`)

`LICENSE_SERVER_URL`, `LICENSE_ADMIN_SECRET` (kell mindkét módhoz), `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`, `NOWPAYMENTS_API_KEY`, `NOWPAYMENTS_IPN_SECRET`,
opcionális `STRIPE_API_BASE`, `NOWPAYMENTS_API_BASE` (sandbox: `https://api-sandbox.nowpayments.io/v1`). Amelyik hiányzik, annak a gombja a `/pricing` oldalon le van tiltva, a checkout 503 `provider_not_configured`.

### Stripe beállítás

1. Teszt módban: Developers -> API keys -> `sk_test_...` a `STRIPE_SECRET_KEY`.
2. Developers -> Webhooks -> endpoint: `PUBLIC_URL/api/webhooks/stripe`, események: `checkout.session.completed`, `checkout.session.async_payment_succeeded`, `checkout.session.async_payment_failed`, `checkout.session.expired`, `charge.refunded`, `charge.dispute.created`. A `whsec_...` a `STRIPE_WEBHOOK_SECRET`.
3. Helyi próba: `stripe listen --forward-to localhost:3000/api/webhooks/stripe` (a CLI kiírja a helyi `whsec_`-et), kártya `4242 4242 4242 4242`.
4. Részleges visszatérítés nem vonja vissza a kulcsot, a teljes és a vita (`dispute`) igen. A pénzt a Stripe felületén kell visszautalni, az admin `Refund` gomb csak a kulcsot vonja vissza.

### NOWPayments beállítás

1. Sandbox fiók (https://sandbox.nowpayments.io): API key -> `NOWPAYMENTS_API_KEY`, Store settings -> IPN secret key -> `NOWPAYMENTS_IPN_SECRET`, `NOWPAYMENTS_API_BASE=https://api-sandbox.nowpayments.io/v1`.
2. Az IPN URL-t a szerver minden invoice-nál megadja: `PUBLIC_URL/api/webhooks/nowpayments`. Az aláírás (`x-nowpayments-sig`) a kulcs szerint rekurzívan rendezett JSON HMAC-SHA512-je.
3. `finished` = fizetve (az összeg, pénznem és `actually_paid >= pay_amount` ellenőrizve), `partially_paid` -> `review`, `failed` / `expired` -> lezárt, `refunded` -> visszavonás. A többi státuszt (waiting, confirming ...) figyelmen kívül hagyja.

### Amit valódi teszt kulccsal még ki kell próbálni

* Stripe: a Checkout session létrehozása (a `expires_at` 31 perc, a Stripe minimuma 30), a webhook aláírás a valódi `whsec_`-kel, a `payment_intent` mező megérkezése, `charge.refunded` / `dispute` mezők, aszinkron fizetési módok.
* NOWPayments: az invoice válasz mezői (`id`, `invoice_url`), hogy az IPN-ben jön-e `invoice_id`, az aláírás pontos előállítása a valódi test IPN-nel, alulfizetés / újrapróbált fizetés viselkedése (egy invoice-hoz több payment is tartozhat, itt csak az első `finished` számít).
* A license szerver `/admin/create` és `/admin/revoke` szerződés (ref idempotencia, 409 busy) a valódi szerverrel.
* A vevő nem bejelentkezve is vásárolhat; a rendelés azonosítója (uuid) a titok: aki ismeri, látja a kulcsot, ezért az order linket nem szabad megosztani.

## Biztonság

* A jogosultságot minden védett API hívás a **szerveren** ellenőrzi (`requireProductAccess`), a gombok elrejtése csak kényelem.
* Session: véletlen token, az adatbázisban csak a SHA-256 hash, `HttpOnly`, `SameSite=Lax`, `Secure` https alatt. A cookie-s írások `Origin` ellenőrzést kapnak.
* Kliens token: visszavonható, 90 napos, scope-os, csak a hash van tárolva; az eszközkód és a felhasználói kód lejár (10 perc), a jóváhagyás rate limitelt.
* Rate limit az adatbázisban (több példányon is közös): belépés, eszközkód, feltöltés, jelentés, kedvelés, pont.
* Feltöltési korlátok: config 256 KB, kép 2 MB (PNG/JPEG/WebP, a fájl eleje ellenőrizve, SVG tiltva), napi 20 feltöltés / felhasználó.
* Minden admin művelet és minden kiosztás az audit naplóba kerül.
* A titkok (`DISCORD_*`, `CRON_SECRET`) csak a szerveren vannak, a böngészőbe nem kerülnek.

## Heti rulett

`/dashboard/roulette`: heti 1 pörgetés (az utolsótól számított 7 nap). Esélyek: semmi 40 %, 5 óra 25 %, 12 óra 15 %, 1 nap 10 %, 7 nap 6 %, 14 nap 3 %, 30 nap 1 %.
A nyeremény a Discordon regisztrált (`/register`) futó, nem lifetime kulcs lejáratát hosszabbítja a license serveren (`POST /admin/extend`), ezért **előbb a `server.js`-t kell frissíteni**, utána a webet.
Az esélyeket a `src/lib/roulette.ts` `PRIZES` listája tartalmazza (ezrelék, az összeg 10000).
