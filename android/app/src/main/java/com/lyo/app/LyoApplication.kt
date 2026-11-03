package com.lyo.app

import android.app.Application
import com.lyo.app.data.TokenManager

class LyoApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        if (BuildConfig.DEBUG) installPreviewCrashCapture()
        TokenManager.init(this)
        com.lyo.app.notifications.StudyReminders.init(this)
        // Which live classroom session each course last used, so re-entering
        // a topic starts a new class and the half-finished one stays
        // reachable on purpose. See ClassroomSessionContract.
        com.lyo.app.data.classroom.ClassroomSessionStore.init(this)
    }

    /** Debug-only, device-local crash information for a test APK that cannot
     * be attached to a desktop debugger. Never sent to a server. */
    private fun installPreviewCrashCapture() {
        val previous = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, failure ->
            try {
                val detail = failure.stackTraceToString().take(12_000)
                getSharedPreferences("lyo_preview_diagnostics", MODE_PRIVATE)
                    .edit()
                    .putString("last_crash", detail)
                    .commit()
            } catch (_: Throwable) {
                // Preserve Android's normal crash handling even if storage fails.
            }
            if (previous != null) previous.uncaughtException(thread, failure)
            else android.os.Process.killProcess(android.os.Process.myPid())
        }
    }
}
