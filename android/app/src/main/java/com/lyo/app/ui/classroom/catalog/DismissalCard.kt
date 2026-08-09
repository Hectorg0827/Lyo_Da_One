package com.lyo.app.ui.classroom.catalog

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.lyo.app.ui.classroom.a2ui.A2uiRenderScope
import com.lyo.app.ui.theme.ClassroomTokens
import com.lyo.app.ui.theme.Surface
import com.lyo.app.ui.theme.TextPrimary
import com.lyo.app.ui.theme.TextSecondary

/** A `session_end` director turn — "class dismissed", with optional
 *  homework/next-lesson-hook text. Always the last board element of a
 *  lesson (see ClassroomBridge.directorTurnToA2ui's session_end branch). */
@Composable
fun A2uiRenderScope.DismissalCardRenderer() {
    val homework = resolveString("homework")
    val nextHook = resolveString("nextHook")

    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 12.dp)
            .background(Surface, RoundedCornerShape(16.dp))
            .padding(20.dp),
    ) {
        Text(
            text = "🔔 Class dismissed",
            style = MaterialTheme.typography.titleMedium,
            color = ClassroomTokens.Gold,
            textAlign = TextAlign.Center,
        )
        if (homework != null) {
            Text(
                text = "Homework: $homework",
                color = TextPrimary,
                textAlign = TextAlign.Center,
                modifier = Modifier.padding(top = 8.dp),
            )
        }
        if (nextHook != null) {
            Text(
                text = nextHook,
                color = TextSecondary,
                textAlign = TextAlign.Center,
                modifier = Modifier.padding(top = 4.dp),
            )
        }
    }
}
