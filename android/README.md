# LYO — Android App

Native Android client for the LYO learning platform, built with **Kotlin + Jetpack Compose**, wired to the production backend at `https://api.lyoai.app`. Mirrors the feature set and dark glassmorphism look of the web and iOS apps.

## Features

- **Auth** — JWT login/signup with automatic token refresh (`/auth/*`)
- **Home** — streak/XP/level stats, continue-learning rail, community activity
- **Lyo AI Chat** — real-time SSE streaming (`/api/v1/lyo2/chat/stream`) with REST fallback
- **Community** — public feed, post detail + comments, reactions, study groups, stories rail
- **Stories** — full-screen tap-through viewer with seen tracking
- **Clips** — vertical swipe pager (TikTok-style) with like/save/view tracking
- **Courses** — browse, detail with modules/lessons, AI course generation
- **Discover** — educational places, events, online classes
- **Profile** — own + other users, follow/unfollow, achievements, learning stats
- **Messages** — real DM conversations (`/messages/*`)
- **Notifications** — live notification feed with read tracking (`/notifications`)
- **Settings** — profile editing (persists via `PUT /auth/profile`), logout

## Stack

| Layer | Choice |
|---|---|
| UI | Jetpack Compose + Material 3 (dark-first LYO theme) |
| Navigation | Navigation Compose, bottom bar with 5 tabs |
| Networking | Retrofit + OkHttp; SSE via raw OkHttp streaming |
| Auth | Bearer interceptor + OkHttp `Authenticator` refresh-on-401 |
| Images | Coil |
| State | Compose state + a small `Session` singleton (no DI framework) |

## Build

Requires JDK 17+ and the Android SDK (API 35).

```bash
cd android
# point local.properties at your SDK if not set via ANDROID_HOME
echo "sdk.dir=$ANDROID_HOME" > local.properties
gradle :app:assembleDebug        # or ./gradlew after `gradle wrapper`
```

APK output: `app/build/outputs/apk/debug/app-debug.apk`.

Which server the app talks to depends on the build type: `release` uses production (`https://api.lyoai.app`); `debug` and `staging` use the staging server once `LYO_STAGING_API_BASE_URL` is set (as a `-P` Gradle property or an environment variable), and production until then. See `docs/STAGING.md`.

Play Store builds (signing, version numbers, `google-services.json`): see `RELEASE.md`.
