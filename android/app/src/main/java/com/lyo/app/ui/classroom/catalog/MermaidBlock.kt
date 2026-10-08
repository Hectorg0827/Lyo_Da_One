package com.lyo.app.ui.classroom.catalog

import androidx.compose.foundation.layout.Column
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import com.lyo.app.ui.classroom.a2ui.A2uiRenderScope
import com.lyo.app.ui.theme.TextSecondary

/** Render a Classroom teaching element with a readable offline fallback. */
@Composable
fun A2uiRenderScope.MermaidBlockRenderer() {
    val source = resolveString("source") ?: return
    Column {
        Text(text = "Diagram", style = MaterialTheme.typography.labelSmall, color = TextSecondary)
        WebViewBlock(WebViewBlockKind.MERMAID, source)
    }
}
