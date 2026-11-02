package com.lyo.app.ui.screens.chat

import android.Manifest
import android.content.pm.PackageManager
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import androidx.lifecycle.lifecycleScope
import com.lyo.app.BuildConfig
import com.lyo.app.R
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/** Deliberately separate from canonical Chat; voice-quality prototype only. */
class GptLiveTrialActivity : ComponentActivity() {
    private var stage by mutableStateOf("Ready for your 60-second staging trial")
    private var userCaption by mutableStateOf("")
    private var lyoCaption by mutableStateOf("")
    private var error by mutableStateOf<String?>(null)
    private var remaining by mutableIntStateOf(60)
    private var active by mutableStateOf(false)
    private var connecting by mutableStateOf(false)
    private var stream: GptLiveTrialStream? = null
    private var timer: Job? = null

    private val microphonePermission = registerForActivityResult(
        ActivityResultContracts.RequestPermission(),
    ) { granted ->
        if (granted) openTrial() else error = "Microphone permission is needed for a voice trial."
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (BuildConfig.API_ENVIRONMENT != "staging" || !BuildConfig.GPT_LIVE_TRIAL_UI) {
            finish()
            return
        }
        setContent { TrialScreen() }
    }

    private fun requestTrial() {
        if (active || connecting) return
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            openTrial()
        } else {
            microphonePermission.launch(Manifest.permission.RECORD_AUDIO)
        }
    }

    private fun openTrial() {
        if (active || connecting) return
        connecting = true
        error = null
        userCaption = ""
        lyoCaption = ""
        remaining = 60
        stage = "Checking staging safety controls…"
        val live = GptLiveTrialStream(
            this, lifecycleScope,
            GptLiveTrialStream.Callbacks(
                onReady = {
                    runOnUiThread {
                        connecting = false
                        active = true
                        stage = "Listening · just talk naturally"
                        timer?.cancel()
                        timer = lifecycleScope.launch {
                            while (active && remaining > 0) {
                                delay(1000)
                                remaining -= 1
                            }
                        }
                    }
                },
                onTranscript = { role, delta ->
                    runOnUiThread {
                        if (role == "user") {
                            userCaption = (userCaption + delta).takeLast(420)
                            stage = "Listening · no taps needed"
                        } else {
                            lyoCaption = (lyoCaption + delta).takeLast(420)
                            stage = "Lyo is speaking · interrupt anytime"
                        }
                    }
                },
                onEnded = { reason ->
                    runOnUiThread {
                        connecting = false
                        active = false
                        timer?.cancel()
                        stage = if (reason == "time_limit") "Trial time completed safely" else "Trial finished"
                    }
                },
                onError = { message ->
                    runOnUiThread {
                        connecting = false
                        active = false
                        timer?.cancel()
                        stage = "Trial unavailable"
                        error = message
                    }
                },
            ),
        )
        stream = live
        live.start()
    }

    private fun stopTrial() {
        stream?.stop()
        stream = null
        timer?.cancel()
        active = false
        connecting = false
        stage = "Trial finished"
    }

    override fun onStop() {
        // A trial must not keep capturing the microphone in the background.
        stopTrial()
        super.onStop()
    }

    override fun onDestroy() {
        stopTrial()
        super.onDestroy()
    }

    @Composable
    private fun TrialScreen() {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .background(
                    Brush.verticalGradient(
                        listOf(Color(0xFF110D22), Color(0xFF291344), Color(0xFF110D22)),
                    ),
                )
                .padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.SpaceBetween,
        ) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text(
                    "● Live with Lyo · Voice Lab",
                    color = Color(0xFF95EDC3),
                    style = MaterialTheme.typography.headlineSmall,
                )
                Spacer(Modifier.height(12.dp))
                Text(
                    "STAGING TRIAL ONLY · ${remaining}s left",
                    color = Color(0xFFC8BAFF),
                    style = MaterialTheme.typography.labelLarge,
                )
            }
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Image(
                    painter = painterResource(R.drawable.mascot_standing),
                    contentDescription = "Lyo, your learning companion",
                    contentScale = ContentScale.Fit,
                    modifier = Modifier
                        .size(250.dp)
                        .clip(CircleShape)
                        .background(Color(0x553FBC93)),
                )
                Spacer(Modifier.height(20.dp))
                Text(
                    stage,
                    color = Color.White,
                    style = MaterialTheme.typography.titleLarge,
                    textAlign = TextAlign.Center,
                )
                Spacer(Modifier.height(14.dp))
                Text(
                    "Ask about cells, fractions or algebra. Talk over Lyo if you like — no Listen or Interrupt buttons.",
                    color = Color(0xFFC8BAFF),
                    textAlign = TextAlign.Center,
                    style = MaterialTheme.typography.bodyMedium,
                )
                if (userCaption.isNotBlank()) {
                    Spacer(Modifier.height(22.dp))
                    Text("You: $userCaption", color = Color(0xFF95EDC3),
                        style = MaterialTheme.typography.bodyLarge, textAlign = TextAlign.Center)
                }
                if (lyoCaption.isNotBlank()) {
                    Spacer(Modifier.height(12.dp))
                    Text("Lyo: $lyoCaption", color = Color.White,
                        style = MaterialTheme.typography.bodyLarge, textAlign = TextAlign.Center)
                }
                if (error != null) {
                    Spacer(Modifier.height(12.dp))
                    Text(error.orEmpty(), color = Color(0xFFFF9D9D), textAlign = TextAlign.Center)
                }
            }
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                if (!active) {
                    Button(
                        enabled = !connecting,
                        onClick = ::requestTrial,
                        modifier = Modifier.fillMaxWidth().height(54.dp),
                        shape = RoundedCornerShape(24.dp),
                    ) { Text(if (connecting) "Checking safety…" else "Start 60-second voice trial") }
                } else {
                    OutlinedButton(
                        onClick = ::stopTrial,
                        modifier = Modifier.fillMaxWidth().height(54.dp),
                    ) { Text("End trial") }
                }
                Spacer(Modifier.height(8.dp))
                Text(
                    "This only tests voice quality. Full lessons and memory remain in normal LYO Chat.",
                    style = MaterialTheme.typography.bodySmall,
                    color = Color.White.copy(alpha = 0.6f),
                    textAlign = TextAlign.Center,
                )
                Spacer(Modifier.height(12.dp))
                OutlinedButton(onClick = { stopTrial(); finish() }) { Text("Back to LYO") }
            }
        }
    }
}
