# LYO Cross-Platform Architecture

This document is the answer to a recurring question: web, iOS, and Android must
look, feel, and behave as **one product**, not three. This is the concrete plan,
grounded in what actually exists in this codebase and in `LyoBackendJune`.

## 1. Current state (as of this consolidation)

Until this branch, the three clients had never shared git history:

- **iOS** (`Sources/`, `Lyo.xcodeproj`) — the most mature client. SwiftUI,
  ~428 files, its own design-token system, full feature set (chat, courses,
  community, reels, creation studio, monetization).
- **Android** (`android/`) — an early skeleton. Jetpack Compose, Retrofit
  (`ApiClient.kt`), one screen per feature area, a `Theme.kt` that was
  *hand-approximated* to look like iOS/web but used different hex values.
- **Web** (`web/`) — a fairly built-out Next.js/TypeScript app (App Router,
  Zustand stores, a `components/ui` kit) with its own third, slightly
  different color palette (in both `tailwind.config.ts` and `globals.css`).
- **Backend** (`LyoBackendJune`, separate repo) — a real FastAPI modular
  monolith (`auth`, `learning`, `feeds`, `community`, `gamification`, `core`
  modules), async SQLAlchemy + PostgreSQL, Redis, Celery. It already has:
  - JWT auth (`lyo_app/auth/jwt_auth.py`) with Firebase auth support
  - A **purpose-built multi-device sync service**
    (`lyo_app/services/conversation_sync.py`, `lyo_app/routers/sync.py`,
    `lyo_app/api/v1/websocket.py`) — device registration, session transfer,
    live conversation state over websockets, explicitly designed so "Lyo
    should feel like ONE continuous companion, not separate instances on
    different devices."
  - This sync layer is **not yet called by any client**. That's the biggest
    unfinished piece of "requirement 3/4" (same content everywhere, live
    handoff) — the backend capability exists, the wiring doesn't.

This branch (`claude/cross-platform-consistency-sync-axdu93`) merges the iOS
branch (`claude/ai-test-prep-feature-r4MYH`, chosen as canonical — most
recent, includes the classroom-engine + social/analytics lineage) with the
web/Android branch (`claude/analyze-production-readiness-1pGKe`) into one
tree for the first time.

## 2. One backend, one identity (requirements 3 & 4)

All three clients already point at the same backend and use the same
bearer-token + refresh-token auth flow (`web/src/lib/api.ts`,
`android/.../data/api/ApiClient.kt`, iOS `NetworkClient.swift` +
`TokenManager.swift`). That part is sound: one account, one username,
same backend database, regardless of platform.

**Live propagation is now wired on all three clients.** Each one connects
a websocket to the backend's Multi-Device Sync service on login and tears
it down on logout, so an action on one platform reaches the others in
real time:

| Platform | Sync client | Lifecycle hook | Live-refresh consumers |
|---|---|---|---|
| Web | `web/src/lib/sync.ts` (+ `hooks/use-sync.ts`) | `AuthProvider.tsx` | messages page, notifications page |
| Android | `android/.../data/sync/SyncClient.kt` | `Session.kt` (login/signup/hydrate/logout) | `MessagesScreen`, `NotificationsScreen` |
| iOS | `Sources/Services/SyncService.swift` | `RootViewModel.onUserAuthenticated()` / `logout()` | `NotificationCenterViewModel` |

All three speak the same contract (from `lyo_app/routers/sync.py`):
connect to `wss://<host>/api/v1/sync/ws?token=<JWT>&device_type=…`,
receive JSON events (`connected`, `message_sent`, `message_received`,
`typing_started/stopped`, `session_transferred`, `context_updated`,
`device_connected/disconnected`), send `{"type":"heartbeat"}` every 30s
and `{"type":"typing"}` on input, with exponential-backoff reconnect
(2s → 60s cap).

Note: the sync router existed in the backend but **was never registered**
in the FastAPI app — no client could have reached it. This branch's
backend change registers it in `enhanced_main.py` (under both `/sync` and
`/api/v1/sync`, matching the community/gamification pattern).

Remaining principle: local storage on every platform (Core Data/SwiftData
on iOS, Room on Android, Zustand stores on web) is treated strictly as a
**cache of server state**, never as the origin. A write goes to the
backend first; the local store updates from the server response / socket
event, not the other way around.

Known gap: web/Android default to `https://api.lyoai.app` while iOS
defaults to the Cloud Run URL in `Sources/Core/Configuration/AppConfig.swift`.
These must be unified to whichever host is the real production backend —
a deliberate decision for the product owner, since it redirects auth
traffic.

## 3. One design language, iOS as source of truth (requirement 1)

`design-tokens.json` (repo root) is now the single source of truth for
color, typography scale, spacing, radius, shadow, and motion — extracted
directly from iOS's existing `Sources/Core/DesignTokens.swift` and its
named color assets (`Sources/Resources/Assets.xcassets`). iOS itself
doesn't need to change; it already *is* the tokens.

Android's `ui/theme/Theme.kt` and web's `tailwind.config.ts` /
`globals.css` have been updated in this branch to match those hex values
exactly (previously all three platforms used three different, independently
invented purple palettes — e.g. web/Android both used `#6c63ff`, iOS used
`#6366F1`; backgrounds ranged from neutral near-black to iOS's navy-tinted
dark). Every color in `Theme.kt` and `globals.css` is now commented with
the token it maps to, so drift is visible in review.

Going forward: **any new color, spacing, or radius value gets added to
`design-tokens.json` first**, then mirrored into the three native theme
files. Typefaces stay platform-native (SF on iOS, Roboto/system on Android,
Inter on web) — the type *scale* (sizes/weights) is what has to match, not
the literal font file.

Next step beyond tokens: a shared component-behavior spec (button states,
card elevation, list-item layout, empty states) so the three platforms
don't just share colors but share interaction feel — iOS's existing
component set (`Sources/Components/`) is the reference for this.

## 4. One product, one roadmap (requirement 2)

Structurally: a "feature" is one backend contract implemented on all three
clients, not three separate backlogs. Given iOS is currently far ahead in
feature count, the realistic sequence is:

1. ✅ Consolidate all platform code into one branch/history (this change).
2. ✅ Unify the design tokens (this change).
3. Land the four pending backend patches; wire all three clients to
   `/sync` + the websocket channel.
4. Bring Android and web up to iOS feature parity, screen by screen, each
   new screen built against the shared tokens from day one.
5. Once at parity, no feature ships to one platform without a tracked plan
   (even if staged) for the other two.

## 5. Verification status

Verified in a Linux CI-like environment (no Xcode / no Android SDK):

- **Web: fully verified.** `npm ci`, `tsc --noEmit`, and `next build` all
  green — 17 routes compile, including the sync client.
- **Backend sync: verified live.** A two-device simulation (mobile_ios +
  web_desktop, same user, real JWT minted by the repo's
  `create_access_token`) against the real sync router over
  `/api/v1/sync/ws`: both devices authenticate, receive the `connected`
  welcome with a device id, and cross-device events (`device_connected`,
  `typing_started`) propagate in real time. Two backend bugs were found
  and fixed in the process: the router was never registered in the app,
  and its websocket auth imported a nonexistent `decode_token` (now
  `verify_token_async`).
- **Android: code-reviewed, not compiled** — requires the Android SDK.
  Run `./gradlew assembleDebug` in `android/` on a machine with the SDK.
- **iOS: code-reviewed, not compiled** — requires Xcode on macOS.
  `SyncService.swift` is registered in `project.pbxproj`; build the Lyo
  scheme normally.

The manual test that matters most, once deployed: log in as the same user
on two of the three clients, send a message on one, confirm it appears on
the other without a manual refresh.

## 6. Pending backend patches — landed

The four patches in `backend-patches/` have been applied to
`LyoBackendJune` and pushed to its
`claude/cross-platform-consistency-sync-axdu93` branch, together with the
sync-router registration/auth fixes. The patch files remain here as an
audit record; the branch on the backend repo is now the source of truth.
