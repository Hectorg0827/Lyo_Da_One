# Lyo Web on Railway

The production split is intentional:

- `https://lyoai.app` and `https://www.lyoai.app` serve the adaptive Next.js app.
- `https://api.lyoai.app` serves `LyoBackendJune` only.

## Create the web service

1. Open the same Railway project that contains `LyoBackendJune`.
2. Select **New → GitHub Repo** and choose `Hectorg0827/Lyo_Da_One`.
3. Open the new service settings and set **Root Directory** to `/web`.
4. Confirm Railway detects `web/Dockerfile` and `web/railway.toml`.
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
2. Add these backend `CORS_ORIGINS` entries if they are not already present:

   ```text
   https://lyoai.app,https://www.lyoai.app
   ```

3. Remove only `lyoai.app` from `LyoBackendJune` after the temporary web
   domain passes the smoke test.
4. Immediately add `lyoai.app` to the new web service and apply the exact DNS
   record Railway displays.
5. Optionally attach `www.lyoai.app` to the web service and redirect it to the
   root domain at the DNS or application layer.

## Release gate

- `https://lyoai.app/api/health` returns HTTP 200 from `lyo-web`.
- `https://api.lyoai.app/health` returns HTTP 200 from `LyoBackendJune`.
- A real user can sign in on web.
- The same conversation appears after refresh and on a second device.
- Community posts, groups, and events load from the production account.
- AI Classroom loads the published course catalog and resumes progress.

