package com.lyo.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.runtime.LaunchedEffect
import com.lyo.app.data.Session
import com.lyo.app.ui.navigation.LyoApp
import com.lyo.app.ui.theme.LyoTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        com.lyo.app.notifications.StudyReminders.openTestPrep = intent.getBooleanExtra("open_test_prep", false)
        com.lyo.app.ui.screens.community.PendingCommunityInvite.capture(intent?.dataString)
        enableEdgeToEdge()
        setContent {
            LyoTheme {
                LaunchedEffect(Unit) { Session.hydrate() }
                LyoApp()
            }
        }
    }
    override fun onNewIntent(intent: android.content.Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        com.lyo.app.notifications.StudyReminders.openTestPrep = intent.getBooleanExtra("open_test_prep", false)
        com.lyo.app.ui.screens.community.PendingCommunityInvite.capture(intent.dataString)
    }

}
