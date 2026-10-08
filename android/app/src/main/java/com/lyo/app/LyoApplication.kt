package com.lyo.app

import android.app.Application
import com.lyo.app.data.TokenManager

class LyoApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        TokenManager.init(this)
        com.lyo.app.notifications.StudyReminders.init(this)
        // Which live classroom session each course last used, so re-entering
        // a topic starts a new class and the half-finished one stays
        // reachable on purpose. See ClassroomSessionContract.
        com.lyo.app.data.classroom.ClassroomSessionStore.init(this)
    }
}
