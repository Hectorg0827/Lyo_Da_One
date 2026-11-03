package com.lyo.app.ui.classroom

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.lyo.app.ui.classroom.catalog.cleanClassroomText

/** Distinct, recoverable interruption design; never fabricate a failed lesson. */
@Composable
fun PremiumClassroomRecovery(
    lastLessonText: String?,
    canReviewPrevious: Boolean,
    isFatal: Boolean,
    onRetry: () -> Unit,
    onReviewPrevious: () -> Unit,
    onRestart: () -> Unit,
) {
    val gold = Color(0xFFFFB944)
    val shape = RoundedCornerShape(21.dp)
    Column(
        modifier = Modifier.fillMaxWidth().padding(horizontal = 8.dp, vertical = 6.dp),
        verticalArrangement = Arrangement.spacedBy(13.dp),
    ) {
        Column(
            modifier = Modifier.fillMaxWidth()
                .background(
                    Brush.verticalGradient(listOf(Color(0xFF20234C), Color(0xFF171B3F))),
                    shape,
                )
                .border(1.5.dp, gold.copy(alpha = .9f), shape)
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Row(horizontalArrangement = Arrangement.spacedBy(11.dp), verticalAlignment = Alignment.CenterVertically) {
                Text("ⓘ", color = gold, style = MaterialTheme.typography.headlineMedium)
                Text("A quick pause", color = Color.White,
                    style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
            }
            Text(
                if (isFatal) "The classroom disconnected. Restart this lesson to reconnect."
                else "We couldn't load the next step. You can try again or review an earlier step.",
                color = Color(0xFFC5C6E7),
                style = MaterialTheme.typography.bodyMedium,
            )
            Box(
                modifier = Modifier.fillMaxWidth()
                    .background(
                        Brush.horizontalGradient(listOf(Color(0xFF655BFB), Color(0xFFAB4EF4))),
                        RoundedCornerShape(16.dp),
                    )
                    .clickable(onClick = onRetry)
                    .padding(vertical = 15.dp),
                contentAlignment = Alignment.Center,
            ) {
                Text("Try again  →", color = Color.White,
                    style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
            }
            if (canReviewPrevious) {
                TextButton(onClick = onReviewPrevious, modifier = Modifier.fillMaxWidth()) {
                    Text("Return to an earlier step", color = Color(0xFFBE91FF))
                }
            } else {
                TextButton(onClick = onRestart, modifier = Modifier.fillMaxWidth()) {
                    Text("Start lesson over", color = Color(0xFFBE91FF))
                }
            }
        }
        Column(
            modifier = Modifier.fillMaxWidth()
                .background(Color(0xFF182347), shape)
                .border(1.dp, Color(0xFF4E458C), shape)
                .padding(14.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Text("▣  What we learned", color = Color.White,
                style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
            Text(
                lastLessonText?.let(::cleanClassroomText)?.take(240)
                    ?.takeIf(String::isNotBlank)
                    ?: "Your earlier lesson steps are available from Previous.",
                color = Color(0xFFD4D1F3),
                style = MaterialTheme.typography.bodyMedium,
            )
            Text("✓  Lesson history available on this device",
                color = Color(0xFF67E2C4), style = MaterialTheme.typography.labelSmall)
        }
    }
}
