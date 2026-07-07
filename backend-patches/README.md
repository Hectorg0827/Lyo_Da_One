# Backend patches for LyoBackendJune

These three patches are the backend work from this branch's sessions. They
could not be pushed to `Hectorg0827/LyoBackendJune` from the development
environment (no push access), so they are preserved here.

1. **0001** — Adds the messaging (`/messages/*`), notifications
   (`/notifications`), and discover (`/discover/*`) routers, registers them in
   `enhanced_main.py`, and adds the matching iOS `Endpoints.swift` cases.
2. **0002** — Emits in-app notifications on comment / reaction / follow /
   achievement-unlock so the notifications feed actually populates.
3. **0003** — Five bug fixes found by end-to-end testing the full stack
   locally (unmounted feeds router, 500-instead-of-401 on missing auth,
   broken `/community/events`, MissingGreenlet on comment serialization,
   silent no-op profile renames).

## To apply

```bash
cd LyoBackendJune
git checkout -b claude/analyze-production-readiness-1pGKe
git am path/to/LYO_Da_ONE/backend-patches/*.patch
git push -u origin claude/analyze-production-readiness-1pGKe
```

Verified against a local boot of the backend: 43/43 API checks and 21/21
Playwright browser checks passed (see the web repo's commit `a1c867f` for the
matching client-side fixes).

Note for deployment: `init_db()`'s `create_all` currently fails on a
pre-existing duplicate-table conflict before it runs, so the new
`notifications` table needs an Alembic migration (or that conflict fixed)
before these endpoints go live in production.
