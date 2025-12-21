# Backend Fixes Needed

The iOS app is currently running in **Mock Mode** because the backend is returning errors.

## Critical Issues

1. **Database Schema Error**
   - **Error:** `column users.firebase_uid does not exist`
   - **Location:** `users` table in PostgreSQL.
   - **Action:** Run a migration to add the `firebase_uid` column to the `users` table.

2. **Authentication Failure**
   - **Error:** HTTP 403 "Not authenticated"
   - **Cause:** The backend registration/login fails due to the schema error, so the client never gets a valid token.

3. **Missing Data**
   - **Observation:** Backend returns empty arrays for courses and events.
   - **Action:** Seed the database with initial content once the schema is fixed.

## Current App State (iOS)

The `LyoAPIClient.swift` has been patched to automatically fallback to **Mock Data** when:
- The backend request fails (e.g., 403, 500).
- The backend returns an empty list (e.g., `[]`).

This allows you to verify the UI and user flow immediately.
