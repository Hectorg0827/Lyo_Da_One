# Lyo Web on Railway

The production split is intentional:

- `https://lyoai.app` and `https://www.lyoai.app` serve the adaptive Next.js app.
- `https://api.lyoai.app` serves `LyoBackendJune` only.

## Create the web service

1. Open the same Railway project that contains `LyoBackendJune`.
2. Select **New → GitHub Repo** and choose `Hectorg0827/Lyo_Da_One`.
3. Open the new service settings and set **Root Directory** to `/web`.
4. Set **Config File Path** to `/web/railway.toml`. Railway does not
   automatically resolve config-as-code files relative to a service Root
   Directory. The `Dockerfile` remains auto-detected from `/web`.
5. Add these service variables:

   ```text
   NODE_ENV=production
   NEXT_PUBLIC_API_URL=https://api.lyoai.app
   ```

   `NEXT_PUBLIC_API_URL` is compiled into the browser bundle. Changing it
   requires a rebuild, not only a restart.

6. Deploy and wait for `/api/health` to report HTTP 200.
7. Generate a temporary Railway domain and test login, Chat, Community, and
   AI Classroom through that domain before moving the public hostname.

## Move the public domain without losing the API

1. In the `LyoBackendJune` service, keep `api.lyoai.app` attached.
2. Set the backend `CORS_ORIGINS` variable to a valid JSON array containing
   the production web origins (and preserve any other origins you still use):

   ```json
   ["https://lyoai.app","https://www.lyoai.app"]
   ```

   The backend parses this setting as `List[str]`; a comma-separated value is
   not valid. Redeploy the backend and verify a browser preflight from
   `https://lyoai.app` succeeds before moving the domain.
3. Remove only `lyoai.app` from `LyoBackendJune` after the temporary web
   domain passes the smoke test.
4. Immediately add `lyoai.app` to the new web service and apply the exact
   CNAME/A/ALIAS and TXT records Railway displays. Both routing and ownership
   verification records must be valid before the domain will serve the web app.
5. Optionally attach `www.lyoai.app` to the web service and redirect it to the
   root domain at the DNS or application layer.

## How a release reaches production

Nothing in `.github/workflows/ci.yml` deploys the web app. This service is
connected to the GitHub repository directly, so **Railway** is what notices a
push to `main`, builds `web/Dockerfile` and swaps the running instance. CI's
`Publish production web image` job pushes a parallel image to GHCR that this
service does not consume.

A green pipeline therefore does not mean the site changed. The `deploy-check`
job closes that gap: it polls `https://lyoai.app/api/health` until the
`commit` field matches the commit being released, and fails with a diagnosis
when it never does. It asserts; it does not deploy. If it fails, look at
Railway, not at CI.

`/api/health` reports `commit` from `LYO_GIT_COMMIT`, then
`RAILWAY_GIT_COMMIT_SHA`, then `GIT_COMMIT`, and `null` when none is set —
never a guess, because a health endpoint that invents a commit makes a stale
deploy look current. If it reports `null` on a current deploy, add a service
variable `LYO_GIT_COMMIT` set to the **reference** `${{RAILWAY_GIT_COMMIT_SHA}}`
so it changes per deploy; a literal commit pasted there would freeze the field.

## Release gate

- `https://lyoai.app/api/health` returns HTTP 200 from `lyo-web`.
- `https://lyoai.app/api/health` reports the `commit` that was released.
- `https://api.lyoai.app/health` returns HTTP 200 from `LyoBackendJune`.
- A real user can sign in on web.
- The same conversation appears after refresh and on a second device.
- Community posts, groups, and events load from the production account.
- AI Classroom loads the published course catalog and resumes progress.
