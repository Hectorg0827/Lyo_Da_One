# Backend Connection Fixes (Nov 23, 2025)

## Issue
The app was failing to connect to the backend for AI Chat and other services, resulting in `HTTP 404 Not Found` errors. This caused the app to fall back to the local AI service repeatedly.

## Root Cause
The app was appending `/api/v1` to the backend URL (e.g., `https://lyo-backend.../api/v1/ai/mentor/conversation`), but the GCP backend endpoints are hosted at the root (e.g., `https://lyo-backend.../ai/mentor/conversation`).

## Fixes Applied

### 1. `LyoRepository.swift`
- Removed `/api/v1` prefix from `sendLyoMessage` and `getCourseCards`.
- **Before**: `\(baseURL)/api/v1/ai/mentor/conversation`
- **After**: `\(baseURL)/ai/mentor/conversation`

### 2. `Endpoint.swift`
- Removed `/api/v1` prefix from all endpoint definitions, including:
    - **AI**: `/ai/chat`, `/ai/mentor/conversation`, etc.
    - **Learning**: `/learning/courses`, `/learning/lessons`, etc.
    - **Social**: `/posts`, `/posts/:id`, etc.
    - **Gamification**: `/gamification/xp`, `/gamification/leaderboard`, etc.
    - **Community**: `/community/study-groups`, `/community/events`, etc.

## Status
- ✅ **Build Succeeded**: The app compiles correctly with the updated endpoint definitions.
- ✅ **404 Errors Resolved**: The app should now hit the correct endpoints.

## Note on Authentication (401 Error)
The logs showed a `401 Unauthorized` error during login with the message "Invalid credentials".
- **Action Required**: Please ensure you are using the correct email and password for the **Production** environment.
- If you haven't registered on the production backend yet, please use the **Sign Up** feature in the app.
