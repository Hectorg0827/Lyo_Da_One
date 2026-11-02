package com.lyo.app

import android.content.ClipData
import android.content.ClipboardManager
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.lyo.app.data.Session
import com.lyo.app.ui.navigation.LyoApp
import com.lyo.app.ui.theme.LyoTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        com.lyo.app.notifications.StudyReminders.openTestPrep = intent.getBooleanExtra("open_test_prep", false)
        com.lyo.app.ui.screens.community.PendingCommunityInvite.capture(intent?.dataString)
        val diagnostics = getSharedPreferences("lyo_preview_diagnostics", MODE_PRIVATE)
        val savedCrash = if (BuildConfig.DEBUG) diagnostics.getString("last_crash", null) else null
        enableEdgeToEdge()
        setContent {
            LyoTheme {
                var previewCrash by remember { mutableStateOf(savedCrash) }
                if (BuildConfig.DEBUG && previewCrash != null) {
                    PreviewCrashScreen(
                        report = previewCrash.orEmpty(),
                        onCopy = {
                            getSystemService(ClipboardManager::class.java)?.setPrimaryClip(
                                ClipData.newPlainText("LYO Preview crash", previewCrash.orEmpty())
                            )
                        },
                        onRetry = {
                            diagnostics.edit().remove("last_crash").apply()
                            previewCrash = null
                        },
                    )
                } else {
                    LaunchedEffect(Unit) { Session.hydrate() }
                    LyoApp()
                }
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

/**
 * Device-local debug-only crash report. A learner can copy this after a fatal
 * Samsung exception; it is never uploaded and never included in release UI.
 */
@Composable
private fun PreviewCrashScreen(
    report: String,
    onCopy: () -> Unit,
    onRetry: () -> Unit,
) {
    var copied by remember { mutableStateOf(false) }
    Column(
        verticalArrangement = Arrangement.spacedBy(16.dp),
        modifier = Modifier
            .fillMaxSize()
            .background(Color(0xFF0B1230))
            .verticalScroll(rememberScrollState())
            .padding(24.dp),
    ) {
        Text(
            "LYO Premium Preview encountered an error",
            color = Color.White,
            style = MaterialTheme.typography.headlineMedium,
        )
        Text(
            "Please tap Copy crash details and paste them into our ChatGPT conversation. " +
                "This report stays on your phone unless you choose to share it.",
            color = Color(0xFFC9D1F2),
            style = MaterialTheme.typography.bodyMedium,
        )
        Button(onClick = { onCopy(); copied = true }) {
            Text(if (copied) "Copied — paste into ChatGPT" else "Copy crash details")
        }
        OutlinedButton(onClick = onRetry) {
            Text("Try opening LYO again")
        }
        Text(
            report.take(5_000),
            color = Color(0xFFFFC8C8),
            style = MaterialTheme.typography.bodySmall,
        )
    }
}
