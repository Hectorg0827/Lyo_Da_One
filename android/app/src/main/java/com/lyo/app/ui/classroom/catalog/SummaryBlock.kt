package com.lyo.app.ui.classroom.catalog

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.material3.TextButton
import com.lyo.app.data.classroom.parseBoardDocument
import com.lyo.app.ui.theme.LyoVioletLight
import com.lyo.app.ui.theme.LyoAmber
import com.lyo.app.ui.theme.Surface
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.lyo.app.ui.classroom.a2ui.A2uiRenderScope
import com.lyo.app.ui.theme.LyoGreen
import com.lyo.app.ui.theme.TextPrimary
import com.lyo.app.ui.theme.TextSecondary

/**
 * An `ExampleBlock` or `LessonBlock`(block_type=="summary") component — a
 * worked example or end-of-scene recap: title, optional prose content, an
 * optional bullet list, and an optional "spaced retrieval scheduled" badge.
 * Green-bordered per web's BoardElementView summary treatment.
 */
@Composable
fun A2uiRenderScope.SummaryBlockRenderer() {
    val title = resolveString("title") ?: "Summary"
    val content = resolveString("content")
    val items = resolveStringList("items")
    val retrievalScheduled = resolveBoolean("retrievalScheduled", false)
    val role = resolveString("role", "board") ?: "board"
    val document = parseBoardDocument(resolve("document"))
    var expanded by remember(component.id) { mutableStateOf(role != "details") }
    val accent = if (role == "recovery") LyoAmber else LyoVioletLight
    val label = when (role) {
        "reference" -> "KEEP IN VIEW"
        "feedback" -> "FEEDBACK"
        "recovery" -> "LESSON PAUSED"
        "details" -> "LESSON DETAILS"
        else -> "TEACHING TOOL"
    }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 6.dp)
            .border(1.dp, accent.copy(alpha = 0.35f), RoundedCornerShape(12.dp))
            .background(Surface, RoundedCornerShape(12.dp))
            .padding(12.dp),
    ) {
        Text(text = label, color = accent)
        Text(text = title, color = TextPrimary)
        if (role == "details") TextButton(onClick = { expanded = !expanded }) { Text(if (expanded) "Hide details" else "Read details") }
        if (expanded && document != null) {
            BoardDocumentView(document)
        } else if (expanded && content != null) {
            Text(text = content, color = TextPrimary, modifier = Modifier.padding(top = 4.dp))
        }
        if (expanded) items.forEach { item ->
            Text(text = "•  $item", color = TextSecondary, modifier = Modifier.padding(top = 2.dp))
        }
        if (retrievalScheduled) {
            Text(
                text = "Spaced retrieval scheduled",
                color = LyoGreen,
                modifier = Modifier.padding(top = 6.dp),
            )
        }
    }
}
