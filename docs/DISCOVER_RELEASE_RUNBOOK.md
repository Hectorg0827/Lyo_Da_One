# Discover release runbook

How to take Discover from "switched off" to "live", one gated step at a
time. Every step says what to run and what a pass looks like. Do not skip
ahead: each step proves something the next one relies on.

Tracking issue: #159. Backend changes: `LyoBackendJune` branch
`ccr-7f237727-28qyod`. Web/iOS/Android changes: this repo, branch
`ccr-7f237727-28qyod`.

## Why Discover broke, in one paragraph

The two videos in the live feed were uploaded before durable storage
existed, onto the server's own disk. Every redeploy replaces that disk, so
the videos vanished while their feed entries stayed. Nothing stopped this
from happening again: the API published whatever video address an app sent
and served every public entry. The permanent fix is that a clip now records
whether its video is really in storage (`media_status`); publishing checks
storage first, and the feed only serves clips marked `ready`.

## What is already done and proven (locally)

| Proof | Result |
| --- | --- |
| All migrations build a fresh PostgreSQL 16 database; the new one downgrades and re-upgrades; it upgrades a database with old clips in it | passed |
| Publishing refuses missing uploads and foreign video links; feed, topics, saved list and shared links serve only `ready` clips | 10 PostgreSQL tests pass |
| Video URLs answer HEAD, valid ranges (206) and invalid ranges (416 with `Content-Range`) | 78 media tests pass |
| Fresh upload → restart with the server's disk wiped → identical bytes from the new process and from a second copy | 35/35, 34/34, 35/35 checks |
| The same check against today's `main` code | fails: HEAD gives 405, missing and foreign videos get published |
| Web Discover in a real browser (phone and desktop size) | 20/20 checks; first frame 645–766 ms; next video 114–126 ms |
| Web unit tests, type check, production build, 24 cross-platform checks | all pass |

"Locally" means one machine with no real network delay. The steps below
repeat the important checks against the real services.

## Step 1 — Merge and deploy the backend (Discover stays off)

1. Merge the backend branch. Railway deploys `main` automatically. Before
   starting the app, it runs `alembic upgrade head`, which adds the new clip
   columns.
2. Wait for the deploy to finish. Then open `https://api.lyoai.app/health`
   and check that `commit_sha` is the merged commit.

Pass: `/health` reports the new commit and `"status": "healthy"`.

If launch-readiness (backend #146) merges first, its migrations become the
newest. Then change `down_revision` in
`alembic/versions/clips_media_001_media_status_and_provenance.py` to that
newest revision, or `alembic upgrade head` will stop with "multiple heads".

## Step 2 — Mark which existing clips still have their video

Right after Step 1, every existing clip is `unverified` and hidden. Showing
nothing beats showing two broken videos. The audit checks storage and
records the truth for each clip:

```bash
# read-only: prints what it would change
python scripts/discover_media_audit.py

# after taking a database backup in Railway:
DISCOVER_AUDIT_APPLY=YES \
DISCOVER_AUDIT_BACKUP_VERIFIED=YES \
DISCOVER_AUDIT_EXPECTED_TARGET=<database host>/<database name> \
python scripts/discover_media_audit.py
```

Run it with the backend's own variables (for example `railway run`). The
`EXPECTED_TARGET` must name both the database server and the database. A
different database on the same server is refused. Only videos on
`api.lyoai.app` can be marked `ready`. If the API also answers on another
domain, list both in `DISCOVER_AUDIT_API_HOSTS` (comma-separated).

Pass: legacy clips 1 and 2 show `missing`. Nothing is deleted and nobody's
privacy setting changes. They can only come back if someone re-uploads the
original files; quarantining them does not count as fixing playback.

## Step 3 — Prove storage survives a redeploy, on the real API

Use a dedicated test account. The script uploads a brand-new video and
poster, checks them, and publishes them as a **private** clip.

```bash
export DISCOVER_CERTIFY_EMAIL=<test account email>
export DISCOVER_CERTIFY_PASSWORD=<its password>
# optional, read-only bucket credentials to compare bytes in storage:
export DISCOVER_CERTIFY_S3_ENDPOINT=... DISCOVER_CERTIFY_S3_BUCKET=...
export DISCOVER_CERTIFY_S3_ACCESS_KEY=... DISCOVER_CERTIFY_S3_SECRET_KEY=...

python scripts/discover_media_certify.py upload --api https://api.lyoai.app --state certify.json --report upload.json
```

Now redeploy the backend in Railway. If you can, run two replicas for this
check. Then:

```bash
python scripts/discover_media_certify.py reverify --state certify.json --report reverify.json
```

Pass: both commands end with `"status": "passed"`, and the reverify report
shows `served_by_a_process_that_did_not_serve_the_upload` passed. With two
replicas, `replicas_observed` is 2. The private test clip is deleted at the
end.

## Step 4 — Build the STEM library (20+ real videos)

The library tool never invents an entry. Every video comes from NASA's
library (public domain) or Wikimedia Commons (Creative Commons). A person
approves each one, and nothing is published until it has been downloaded,
converted for phones, uploaded and played back.

```bash
# 1. find candidates (repeat with different searches)
python scripts/discover_catalog.py search nasa "Perseverance landing" >> drafts.jsonl
python scripts/discover_catalog.py search commons "mitosis" >> drafts.jsonl

# 2. copy the ones you want into catalog.json as {"entries": [ ... ]}
#    and for each: set "subject", then under "review" set approved,
#    factChecked, ageAppropriate and rightsCleared to true and put your
#    name in "reviewer".

# 3. check the list before publishing anything
python scripts/discover_catalog.py validate --manifest catalog.json

# 4. publish (use a dedicated "Lyo Library" account)
DISCOVER_CERTIFY_EMAIL=<library account> DISCOVER_CERTIFY_PASSWORD=<password> \
python scripts/discover_catalog.py ingest --manifest catalog.json --api https://api.lyoai.app --report catalog-report.json
```

Allowed licences are public domain, CC0, CC BY and CC BY-SA.
NonCommercial and NoDerivatives licences are refused automatically. No
TikTok or YouTube footage. Every video must carry a credit, and one source
can be published only once.

`ingest` uploads nothing if `validate` would fail. To publish the ready
entries of a list that is still short of 20, add `--partial`. Discover is
still off at this point, so a partial library is not public yet.

Starter searches, two per area:

| Area | NASA | Commons |
| --- | --- | --- |
| Astronomy | `James Webb`, `solar eclipse` | `planet orbit animation` |
| Physics | `microgravity demonstration` | `pendulum` |
| Chemistry | `combustion experiment` | `chemical reaction`, `flame test` |
| Biology | `plant growth space station` | `mitosis`, `cell division` |
| Math | — | `fourier series animation`, `pythagorean theorem` |
| Engineering | `rocket engine test` | `bridge construction` |
| Technology | `satellite deployment` | `transistor` |
| Coding | — | `sorting algorithm` |
| Robotics | `Robonaut`, `Ingenuity helicopter` | `robot arm` |
| Environment | `sea ice`, `hurricane from space` | `water cycle` |

Pass: `validate` says `"status": "passed"` with at least 20 ready entries,
and `ingest` ends with `"status": "passed"`. Keep `catalog-report.json`: it
is the licence and attribution record for every published video.

## Step 5 — Deploy the web candidate with Discover still off

Merge the web branch. The Railway web service rebuilds. Leave
`NEXT_PUBLIC_DISCOVER_LAUNCH_ENABLED` unset.

Pass: no Discover tab, no "Search discoveries" box, no "Make your first
clip" or "Teach it" buttons. Visiting `/discover` shows "Discover is being
updated". This is also the rollback state, so prove it works now.

## Step 6 — Test on real devices

The web checks above ran in a desktop test browser. Phones behave
differently: autoplay rules, audio interruptions, backgrounding, mobile
data. Test on a real iPhone (Safari and the app), a real Android phone
(Chrome and the app), and desktop Chrome and Safari:

- [ ] First video plays within about 1 second (Wi-Fi), with sound off until unmuted
- [ ] 10 fast swipes up and down: only the video on screen plays, no error messages
- [ ] Each swipe starts the next video quickly; note the time on Wi-Fi and on mobile data
- [ ] Dragging the progress bar jumps and keeps playing
- [ ] Lock the phone, unlock: the video resumes or waits for a tap, never plays hidden
- [ ] Phone call or another app's audio: Discover pauses and recovers
- [ ] Like, save, comment, share, Learn with Lyo, Course and mute all do what they say
- [ ] The credit line under a library video opens its source page
- [ ] Report on someone else's video: pick a reason, send; it leaves your feed and "Thanks" shows. Your own videos have no Report button
- [ ] Block, from Report on another learner's video: it asks first, then every video by them leaves your feed. Library videos offer no Block. Settings lists them under Blocked accounts, and Unblock brings their videos back after a refresh
- [ ] Like a video and unlike it straight away in the app: the heart count stays right after reopening Discover
- [ ] Create video: record with the camera, upload from the gallery, refuse a non-video file

## Step 7 — Switch Discover on

Two Railway services serve the website, and both need the switch:

| Address | Railway project | Environment | Service |
| --- | --- | --- | --- |
| `www.lyoai.app` | `zonal-wisdom` | production | `Lyo_Da_One` |
| `lyoai.app` | `caring-cat` | Lyo | `LyoWeb` |

1. On both services, set `NEXT_PUBLIC_DISCOVER_LAUNCH_ENABLED=true` and
   redeploy. It is compiled into the site, so it needs a new build, and
   `web/Dockerfile` must declare it as a build arg or the build never sees it
   (`dockerfile-build-args.test.mjs` checks this).
2. Check `/discover` on both addresses shows the feed, not "Discover is being
   updated".
3. Run the live probe in `LyoBackendJune` (`discover-live-probe.yml`): its
   last step reads the feed as the library account and checks every clip is
   ready and plays.

To roll back, delete the variable on both services and redeploy. Step 5
already proved that state works.

## Things found outside Discover

- The production backend (`api.lyoai.app`) and the bare-domain website
  (`lyoai.app`) live in Railway project `caring-cat`, environment "Lyo". The
  same project's "production" environment has a `LyoBackendJune` service whose
  deploys have all failed since 8 October because its `DATABASE_URL` is empty.
  It has no domain. If it is an old copy, remove it; its failed deploys make the
  real deploy status hard to read.
- During Railway's capacity pause on 21 to 23 October, pushes to `main` created
  no deployments at all. Deploying again (reconnecting the service's source)
  queued them, and they ran when the pause lifted.
- The API refused every request over 10 MB, so videos over 10 MB could not be
  uploaded. Fixed in `LyoBackendJune` #151: the upload route now gets its own
  201 MB cap.
