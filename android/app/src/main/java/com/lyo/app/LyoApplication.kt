package com.lyo.app

import android.app.Application
import com.lyo.app.data.TokenManager

class LyoApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        TokenManager.init(this)
        com.lyo.app.notifications.StudyReminders.init(this)
    }
}
