package com.lyo.app.ui.classroom.catalog

import androidx.compose.foundation.layout.Column
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import com.lyo.app.ui.classroom.a2ui.A2uiRenderScope
import com.lyo.app.ui.theme.TextSecondary

/**
 * A "latex" board element — math notation. Same DELIBERATE v1
 * SIMPLIFICATION as MermaidBlockRenderer: no KaTeX-equivalent typesetting
 * exists on Android without a WebView bridge (same documented v2 upgrade
 * path, and cheap to add for both at once if chosen — see the
 * implementation plan). v1 shows the raw LaTeX source, labeled.
 */
@Composable
fun A2uiRenderScope.LatexBlockRenderer() {
    val latex = resolveString("latex") ?: return
    Column {
        Text(text = "Math", style = MaterialTheme.typography.labelSmall, color = TextSecondary)
        RawSourceBlock(latex)
    }
}
