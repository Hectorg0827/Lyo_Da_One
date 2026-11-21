# LYO — Web-first release candidate (20 November 2026)

## Source of truth
- Candidate branch: `release/lyo-web-first-20261120`, rooted at exact Web main SHA `b8ee0bff57786759ddc1e076c5eedb51d6fbf1bd`.
- Only Web files changed between main and isolated preview SHA `2ca0a7f8860089d938b6335dc46bbef1dbba18af` are imported. Their original Git blobs are reused; no Android, iOS or production source modifications.
- The staging Web deployment at `70836eb4` is the approved comparison baseline; preview Web at `2ca0a7f8860089d938b6335dc46bbef1dbba18af` contributes newer Classroom bridge and recovery behavior.
- This branch and its draft PR are **not approved for merging or deploying** until the following gates have evidence at exact head SHA.
- Canonical production targets: Railway `api.lyoai.app`, `lyoai.app`, and `www.lyoai.app`. No deployments or activation are authorized by this document.

## Release gates (all currently unverified for this exact integrated candidate)
1. **Identity and privacy:** visible signup, sign-in, token refresh, sign-out, password recovery, guest denial, cross-user data isolation, account deletion; browser/mobile breakpoints.
2. **Course creation:** prompt or Create action generates an actual persisted course; learner can reopen on a new session, navigate modules, complete an assignment and see accurate progress; no hidden API 405/401/422.
3. **Classroom:** actual AI lesson, teacher voice audible, board/chart/LaTeX legible, grade and explanation correct for 30 manually scored math/science/language cases, no duplicate writes, session persistence.
4. **Resilience:** 30-minute authenticated lesson, access token expiry, WebSocket disconnect/resume and scene identity, retry without double-advancement; measure cold/warm 20 starts and 10 transitions, p50/p95 visible text, full scene and audible first segment.
5. **Chat and voice:** transcript history and draft preserved, media and speech permissions, 20 spoken turns/5 interruptions, English and Spanish, no overlapping teacher/bridge audio, graceful failure modes.
6. **Product breadth:** Focus, Discover, Community, Create, Courses, profile/settings and moderation flows work with real backend records; no false promises or blank demo-only stubs.
7. **Launch hardening:** Web unit/type/build green at exact SHA, real authenticated Chromium smoke in isolated staging, mobile/desktop a11y and visual acceptance, critical security/performance review, no unresolved P0/P1, budget/AI controls, known-good rollback for all domains.

## Known limits / evidence discipline
- Existing synthetic Classroom and preview evidence is **not** final QA on this new release commit.
- Standard and preview Railway services are separate; their health does not prove functional parity.
- No autonomous engineering agents are implied by tracking issues or automation comments.
- Until a full authenticated journey passes against this branch in isolated staging, the release remains **NO-GO**.
- Android and iOS work is deferred. PR #210 stays unchanged.
