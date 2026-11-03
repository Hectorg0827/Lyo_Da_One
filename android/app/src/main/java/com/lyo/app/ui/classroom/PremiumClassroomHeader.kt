package com.lyo.app.ui.classroom

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.MenuBook
import androidx.compose.material.icons.filled.MoreHoriz
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.VolumeOff
import androidx.compose.material.icons.filled.VolumeUp
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.lyo.app.ui.theme.TextPrimary
import com.lyo.app.ui.theme.TextSecondary

/** The same compact two-row navigation / mode switcher across all three layouts. */
@Composable
fun PremiumClassroomHeader(
    topic: String,
    mode: ClassroomDisplayMode,
    stepNumber: Int,
    totalSteps: Int,
    isPaused: Boolean,
    isConnecting: Boolean,
    isVoiceEnabled: Boolean,
    onBack: () -> Unit,
    onPickMode: () -> Unit,
    onTogglePause: () -> Unit,
    onToggleVoice: () -> Unit,
    onNotebook: () -> Unit,
    onSettings: () -> Unit,
) {
    var toolsOpen by remember { mutableStateOf(false) }
    val violet = Color(0xFFB67AFF)
    val accent = when (mode) {
        ClassroomDisplayMode.SOLO -> violet
        ClassroomDisplayMode.CLASSROOM -> Color(0xFF78A4FF)
        ClassroomDisplayMode.REVIEW -> Color(0xFFC69AFF)
    }
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(Brush.verticalGradient(listOf(Color(0xFF0A102A), Color(0xFF111A3A))))
            .padding(start = 12.dp, end = 12.dp, top = 8.dp, bottom = 7.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(9.dp),
        ) {
            Box(
                modifier = Modifier
                    .size(40.dp)
                    .background(Color(0xFF19254A), CircleShape)
                    .border(1.dp, accent.copy(alpha = .42f), CircleShape)
                    .clickable(onClick = onBack),
                contentAlignment = Alignment.Center,
            ) { Icon(Icons.Filled.ArrowBack, "Leave classroom", tint = Color.White) }
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = "✦  Lyo Classroom",
                    color = Color.White,
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                Text(
                    text = topic,
                    color = Color(0xFFB1B9DC),
                    style = MaterialTheme.typography.labelMedium,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
            Row(
                modifier = Modifier
                    .background(Color(0xFF24215C), RoundedCornerShape(22.dp))
                    .border(1.dp, accent.copy(alpha = .72f), RoundedCornerShape(22.dp))
                    .clickable(onClick = onPickMode)
                    .padding(horizontal = 11.dp, vertical = 9.dp),
                horizontalArrangement = Arrangement.spacedBy(4.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text("Mode:", color = Color(0xFFE2DCFF), style = MaterialTheme.typography.labelSmall)
                Text(
                    text = when (mode) {
                        ClassroomDisplayMode.SOLO -> "Focus"
                        ClassroomDisplayMode.CLASSROOM -> "Live Class"
                        ClassroomDisplayMode.REVIEW -> "Review"
                    },
                    color = Color.White,
                    style = MaterialTheme.typography.labelMedium,
                    fontWeight = FontWeight.SemiBold,
                )
                Text("⌄", color = Color.White)
            }
        }

        Row(
            modifier = Modifier.fillMaxWidth().padding(start = 5.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Text(
                text = "${stepNumber.coerceAtLeast(1)} of ${totalSteps.coerceAtLeast(1)}",
                style = MaterialTheme.typography.labelSmall,
                color = Color(0xFFCFD0ED),
            )
            LinearProgressIndicator(
                progress = { (stepNumber.toFloat() / totalSteps.coerceAtLeast(1)).coerceIn(0f, 1f) },
                modifier = Modifier.weight(1f).height(5.dp),
                color = accent,
                trackColor = Color(0xFF30365F),
            )
            val status = when {
                isPaused -> "● Paused"
                isConnecting -> "○ Loading"
                else -> "● Live"
            }
            Text(
                status,
                color = when {
                    isPaused -> Color(0xFFFFC35A)
                    isConnecting -> Color(0xFFB1B9DC)
                    else -> Color(0xFF54E9BE)
                },
                style = MaterialTheme.typography.labelSmall,
            )
            IconButton(onClick = { toolsOpen = !toolsOpen }, modifier = Modifier.size(36.dp)) {
                Icon(Icons.Filled.MoreHoriz, "Classroom tools", tint = TextPrimary)
            }
        }

        if (toolsOpen) {
            Row(
                modifier = Modifier.fillMaxWidth().background(Color(0xFF172044), RoundedCornerShape(15.dp)),
                horizontalArrangement = Arrangement.SpaceEvenly,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                IconButton(onClick = onNotebook) {
                    Icon(Icons.Filled.MenuBook, "Notebook and transcript", tint = TextPrimary)
                }
                IconButton(onClick = onSettings) {
                    Icon(Icons.Filled.Settings, "Classroom settings", tint = TextPrimary)
                }
                IconButton(onClick = onToggleVoice) {
                    Icon(
                        if (isVoiceEnabled) Icons.Filled.VolumeUp else Icons.Filled.VolumeOff,
                        "Toggle teacher voice",
                        tint = TextPrimary,
                    )
                }
                IconButton(onClick = onTogglePause) {
                    Icon(
                        if (isPaused) Icons.Filled.PlayArrow else Icons.Filled.Pause,
                        if (isPaused) "Resume lesson" else "Pause lesson",
                        tint = TextPrimary,
                    )
                }
            }
        }
    }
}
