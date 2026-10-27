# Staging — a safe copy of LYO for testing

**In one sentence:** staging is a second, private copy of LYO (server,
database and website) where we try changes before real users see them.

## Why we need it

Today every app — the website, the iPhone app and the Android app, even
test builds — talks to the **real** server at `https://api.lyoai.app`, with
real users' data. A mistake in a test build can change real accounts. A
staging copy has its own empty database, so testing there cannot hurt
anyone.

## What we want (the target)

**One** staging environment, inside the Railway project that already runs
production:

| | Production (today) | Staging (to create) |
|---|---|---|
| Railway project | `caring-cat` | `caring-cat` (same project) |
| Railway environment | `Lyo` | `staging` (new) |
| Backend service | LyoBackendJune → `https://api.lyoai.app` | copy → its own address, e.g. `https://api-staging.lyoai.app` |
| Website service | lyo-web → `https://lyoai.app` | copy → e.g. `https://staging.lyoai.app` |
| Postgres database | production data | **its own, separate, empty** database |
| Redis | production | **its own** Redis |
| Variable **names** | e.g. `DATABASE_URL`, `CORS_ORIGINS`, `SECRET_KEY` … | **the same names**, with staging values |

Railway "environments" are made for exactly this: one project, several
isolated copies of the same set of services.

### How to create it (owner, in the Railway dashboard)

> These are instructions for you to follow when you are ready. Nobody has
> changed anything on Railway as part of this work.

1. **First turn on database backups for production** (see the cleanup
   checklist below, item 1). Do this before anything else.
2. Open Railway → project **caring-cat**. At the top, open the environment
   menu (it says **Lyo**) → **New Environment** → **Duplicate environment**
   → choose **Lyo** → name it **`staging`**.
   Railway copies the services and their settings. Databases are created
   **new and empty** — production data is not copied. That is what we want.
3. In the new **staging** environment, check every service's **Variables**:
   - `DATABASE_URL` and `REDIS_URL` must point at the **staging** Postgres
     and Redis. If they are written as references like
     `${{Postgres.DATABASE_URL}}`, Railway already does this for you. If you
     see a pasted address that matches production's, replace it with the
     reference. **Never point staging at the production database.**
   - Secrets such as `SECRET_KEY` / JWT secrets: give staging **different**
     values from production, so a staging login can never work on production.
   - `CORS_ORIGINS` on the staging backend: the staging website's address,
     as a JSON list, e.g. `["https://staging.lyoai.app"]`.
   - Outside services (email, AI providers, storage, push): staging may use
     the same AI keys; use separate/test settings for anything that contacts
     real people (email, push). Payment settings are out of scope for now —
     do not copy live payment keys into staging.
4. Give each staging service an address: **Settings → Networking →
   Generate Domain** (a free `….up.railway.app` address), or add a custom
   one like `api-staging.lyoai.app` and `staging.lyoai.app`.
5. Choose which code staging runs: in each staging service's **Settings →
   Source**, set the branch to **`staging`** (production keeps `main`).
   Then the flow is: work on a branch → merge into `staging` → test on
   staging → merge into `main` → production.
6. Deploy and check `https://<staging-backend>/health` and
   `https://<staging-website>/api/health` both answer.

## How each app points at staging

### Website (`web/`)

Every place in the website code that calls the server reads one setting:
**`NEXT_PUBLIC_API_URL`** (`src/lib/api.ts`, `src/lib/sync.ts`,
`src/lib/stack.ts`, `src/lib/learning-progress.ts`,
`src/stores/classroom-store.ts`). When it is not set, the site falls back to
production.

For the **staging website service**, set these Variables in Railway:

```text
NODE_ENV=production
NEXT_PUBLIC_API_URL=https://<your staging backend address>
```

Plus the same `NEXT_PUBLIC_FIREBASE_*` variables production has, if you want
*Continue with Google* on staging.

Important details:

- `NEXT_PUBLIC_API_URL` is baked into the website **when it is built**. After
  changing it, **redeploy** the service — a restart is not enough.
- The `Dockerfile` already accepts it as a build setting, so Railway passes
  it through automatically.
- For *Continue with Google* on the staging website, add the staging
  website's address in Firebase → **Authentication → Settings → Authorized
  domains**.
- The staging backend's `CORS_ORIGINS` must include the staging website's
  address (see step 3 above), or the browser will block requests.

### Android (`android/`)

The app has three build types, and the server address is chosen when the
app is built:

| Build type | Who it is for | Server |
|---|---|---|
| `debug` | developers | staging, once `LYO_STAGING_API_BASE_URL` is set; production until then |
| `staging` | testers (release-like, installable by anyone) | staging, once `LYO_STAGING_API_BASE_URL` is set; production until then |
| `release` | Google Play | production (`https://api.lyoai.app`), or `LYO_API_BASE_URL` if set |

Set the staging address once, in the file `~/.gradle/gradle.properties` on
the computer that builds (create it if missing):

```text
LYO_STAGING_API_BASE_URL=https://<your staging backend address>
```

or per build: `gradle :app:assembleStaging -PLYO_STAGING_API_BASE_URL=https://…`.
An environment variable with the same name works too (handy for CI).

The installed test app shows which server it uses in **Settings → About →
Server** (the Play Store build shows nothing extra there).

Note: the `staging` build has the same app ID as the Play Store app, so it
replaces the Play version on a phone rather than sitting next to it.

### iPhone (`Sources/`, owned by the iPhone group)

The iPhone app already reads a server address, in this order: the
`LYO_API_BASE_URL` setting in the Xcode scheme, then `LyoAPIBaseURL` in
Info.plist, then production. A staging TestFlight build would set
`LyoAPIBaseURL` to the staging backend address. Coordinate with the iPhone
group before changing it.

## Cleanup checklist (owner)

The audit found several duplicate copies of LYO on Railway. They cost money
and make it unclear which copy is "real". Clean up **after** the new staging
works, one item at a time. Before deleting anything: open it, check
**Settings → Networking** for attached domains, and check whether it has a
database with data you might need. **Deleting on Railway cannot be undone.**

- [ ] **1. Turn on Postgres backups for production — do this first.**
      caring-cat → environment **Lyo** → the **Postgres** service →
      **Backups** tab → turn on scheduled backups (daily, keep at least 7).
      Then click **Backup now** once and confirm it appears in the list.
      Do the same for the new staging Postgres if you want (optional).
- [ ] **2. Old, failing `production` environment in caring-cat.** Production
      actually runs in the environment named **Lyo**. Confirm the old
      `production` environment has no custom domains and no database you
      need, then delete it (environment menu → environment settings →
      Delete).
- [ ] **3. Second website copy in project `zonal-wisdom`, serving
      `www.lyoai.app`.** ⚠️ Careful: this one is live. First add
      `www.lyoai.app` to the website service in caring-cat → **Lyo**,
      update the DNS record Railway shows you at your domain provider, and
      wait until `https://www.lyoai.app/api/health` answers from the
      caring-cat service. Only then remove the domain from zonal-wisdom and
      delete the project.
- [ ] **4. Extra backend copy in project `intuitive-truth`.** Confirm it has
      no custom domain (especially not `api.lyoai.app`) and that no app uses
      its `….up.railway.app` address. If it has its own database, take a
      backup first in case it holds real data. Then delete the project.
- [ ] **5. Validation/staging services inside the production `Lyo`
      environment.** Test services should not live next to production —
      they may share production's variables or database. Once the new
      `staging` environment works, delete them from **Lyo** (recreate in
      `staging` only if still needed).
- [ ] **6. Separate staging projects.** Once the new staging environment
      works, check each of these for domains and data, then delete them:
      - [ ] `LyoOne-Journey-Staging`
      - [ ] `LYO-Community-Staging`
      - [ ] `LYO-Community-Post-Preview`
      - [ ] `spirited-manifestation`
- [ ] **7. Afterwards:** confirm `https://lyoai.app`, `https://www.lyoai.app`
      and `https://api.lyoai.app` all still work, and that the iPhone,
      Android and web apps can still sign in.
