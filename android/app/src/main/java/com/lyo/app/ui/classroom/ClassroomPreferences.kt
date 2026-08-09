package com.lyo.app.ui.classroom

/**
 * Classroom-session preferences that persist across screen entries within
 * the process lifetime — a plain in-memory `object` singleton, matching
 * this app's no-DataStore/no-DI convention elsewhere (see
 * e.g. TokenManager). Not backed by SharedPreferences/DataStore in this v1:
 * the only setting here (`reducedMotion`) previously didn't exist as a user
 * control AT ALL (ClassroomEngine.start() hardcoded `reducedMotion = false`
 * into the connect() call) — this is the fix for that, not a full
 * persistence layer. Promoting it to real on-disk persistence is a
 * reasonable follow-up, not a silent gap: this object is the single seam
 * where that would plug in later.
 *
 * `reducedMotion` is read once at `ClassroomEngine.start()` — it's a
 * connect-time query param on the real backend's WebSocket URL (see
 * ClassroomSocketClient.connect), so changing it mid-session requires a
 * reconnect, not a live property flip. SettingsPanel's toggle therefore
 * only takes effect on the NEXT classroom session, which the panel's own
 * copy makes explicit.
 */
object ClassroomPreferences {
    var reducedMotion: Boolean = false
}
