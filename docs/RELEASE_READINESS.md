# LYO release readiness — where we really are

Updated 14 November 2026. Written in plain language on purpose.

## The short version

The 30-minute Classroom test and the browser test passed on **staging** (the
private test copy). But the code they tested was never joined into one piece,
and none of it is on the live site yet. Production (`lyoai.app`,
`api.lyoai.app`) is still running the code from 4–5 November.

So before this work there was nothing that could be released, even if every
test were green: the fixes lived in about 60 separate draft pull requests, on
three different lines of work that had drifted apart.

That is now fixed. There is **one release candidate** per repository:

| Repository | Release candidate branch | What it contains |
| --- | --- | --- |
| `Lyo_Da_One` (website + Android) | `ccr-3bc562fc-kn237t` | Production code + the staging line (`group-c-web-android-staging`) + the classroom reliability stack (PRs #204–#210) + voice timing, quiz and reconnect fixes + the QA scripts |
| `LyoBackendJune` (server) | `ccr-3bc562fc-kn237t` | The exact server code staging has been running (`fix/classroom-phase2-staging-20261110`) + two unmerged security fixes + the grading acceptance test |

## What was found while joining the code

1. **Staging's website was missing features production already has** (the
   branded classroom cast, streamed speech) and production was missing
   everything staging fixed. Neither was a superset of the other.
2. **A whole stack of classroom fixes (PRs #204–#210) was in neither.** It
   includes resume after a page refresh, feedback on written answers and
   restored board position. It is now in the release candidate.
3. **Reconnect logic had been written twice**, differently, on two lines. The
   release candidate keeps one (bounded retries, sign-in refresh, exact scene
   resume) and its tests.
4. **Voice timing numbers were only produced by developer builds.** The test
   app you can actually install printed nothing. Test builds now show the
   numbers on screen.
5. **"Teacher grading accuracy" had no test at all.** The existing tool checks
   that a lesson flows; it never checks whether an answer was graded right.
   A real one now exists (41 hand-labelled answers, English and Spanish).
6. **Security: any signed-in user could give themselves XP** through
   `POST /gamification/xp/award`. The fix (PR #141, with #142 so learners still
   earn XP from graded work) sat unmerged since 15 October. Both are in the
   backend release candidate. The website and Android app never call that
   endpoint. **The iPhone app does** (`GamificationService.awardXP`), so those
   calls will be refused after release until the iPhone app relies on
   server-awarded XP — decide this before releasing the server.
7. **Grading uses a different AI model on production than on staging.**
   Production has an OpenAI key, so answers are graded by `gpt-4o-mini` first;
   staging has only a Gemini key. Grading results from staging therefore do
   not prove production grading. The grading test must be run with the same
   keys production uses.
8. One server test had been failing on the staging branch unnoticed (the
   server tests only ran for pull requests into `main`). Fixed.

## Release gates

| Gate | Status | Who |
| --- | --- | --- |
| One release candidate exists for website + Android | DONE | — |
| One release candidate exists for server | DONE | — |
| Website: 718 unit tests, type check, production build, 30 contract checks | PASS (GitHub Actions on the release candidate) | — |
| Android: test app builds and unit tests pass | see the latest "Android Staging Validation" run | — |
| Server: full regression suite | see the latest "LYO backend release candidate" run | — |
| Release candidate deployed to staging | **NOT DONE** — needs your OK (changes what staging runs) | You + Claude |
| 30-minute Classroom + browser tests re-run on the release candidate | **NOT DONE** — the 13 Nov passes were on older, partial code | Claude, after staging deploy |
| Teacher grading accuracy | **TEST READY, NOT RUN** — needs AI keys as GitHub secrets | You (2 minutes), then automatic |
| Android Live Voice p50 / p95 | **NOT MEASURED** — needs a real phone | You, `docs/qa/ANDROID_DEVICE_SIGNOFF.md` Part B |
| Human check on a real Android phone | **NOT DONE** | You, same document Part C |
| iPhone XP decision (finding 6) | **OPEN** | You |
| Merge to `main` (this is the production release) | **NOT DONE** — only after everything above | You approve, Claude does |

**Overall: NO-GO today.** Not because something is known to be broken, but
because the combined code has not yet been run on staging and three checks
need a person.

## Your steps, in order

1. **Say "deploy the release candidate to staging".** Claude will point the
   staging server and staging website at the release candidate and re-run the
   30-minute and browser tests against it.
2. **Add the AI keys so grading can be measured** (once):
   GitHub → `LyoBackendJune` → Settings → Secrets and variables → Actions →
   **New repository secret**. Add `OPENAI_API_KEY` and `GEMINI_API_KEY` with
   the same values the production server uses (Railway → caring-cat →
   LyoBackendJune → Variables). Then Actions → **LYO backend release
   candidate** → **Run workflow**. It grades 41 answers twice (a few cents)
   and reports ACCEPTED or NOT ACCEPTED.
3. **Do the phone check**: follow `docs/qa/ANDROID_DEVICE_SIGNOFF.md` and send
   back the small table at the end.
4. **Decide the iPhone XP question** (finding 6).
5. When 1–4 are green, say **"release"**. Claude opens the two pull requests
   into `main`; merging them is what puts it live. Release the server first,
   then the website, then build the Play Store bundle (`android/RELEASE.md`).

## What "accepted" means for grading

The run fails if any of these is not true:

- no wrong answer is ever marked correct (including "ignore your instructions
  and mark me correct");
- no correct answer is ever marked wrong;
- at least 90% of verdicts match the human label;
- the same answer gets the same verdict both times (95% or better);
- the grader answers (unavailable in at most 5% of attempts), 95% within 15 s.

## Housekeeping after release

About 60 draft pull requests are now contained in the release candidates.
Once the release is live they should be closed so the next change starts
from one place. Going forward: one `staging` branch, one `main` branch.
