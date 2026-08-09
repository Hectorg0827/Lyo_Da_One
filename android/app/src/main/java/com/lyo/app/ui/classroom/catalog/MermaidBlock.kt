package com.lyo.app.ui.classroom.catalog

import androidx.compose.foundation.layout.Column
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import com.lyo.app.ui.classroom.a2ui.A2uiRenderScope
import com.lyo.app.ui.theme.TextSecondary

/**
 * A "mermaid" board element — a diagram. DELIBERATE v1 SIMPLIFICATION per
 * the implementation plan: no mermaid.js renderer exists on Android without
 * a WebView bridge (documented v2 upgrade path — a shared WebViewBlock
 * hosting mermaid.js/KaTeX). v1 shows the raw diagram source in the same
 * styled monospace block as CodeBlockRenderer, labeled so it's obviously a
 * diagram description rather than lesson code.
 */
@Composable
fun A2uiRenderScope.MermaidBlockRenderer() {
    val source = resolveString("source") ?: return
    Column {
        Text(text = "Diagram", style = MaterialTheme.typography.labelSmall, color = TextSecondary)
        RawSourceBlock(source)
    }
}
