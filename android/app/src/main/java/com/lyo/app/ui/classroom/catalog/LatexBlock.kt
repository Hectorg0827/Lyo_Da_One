package com.lyo.app.ui.classroom.catalog

import androidx.compose.foundation.layout.Column
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import com.lyo.app.ui.classroom.a2ui.A2uiRenderScope
import com.lyo.app.ui.theme.TextSecondary

/** Render explicit math notation with KaTeX; ordinary algebra has a native fallback. */
@Composable
fun A2uiRenderScope.LatexBlockRenderer() {
    val raw = resolveString("latex") ?: return
    // KaTeX.render() expects an expression, not surrounding Markdown fences.
    val latex = raw.trim().removeSurrounding("$").removeSurrounding("\\[", "\\]")
        .removeSurrounding("\\(", "\\)")
    Column {
        Text(text = "Math", style = MaterialTheme.typography.labelSmall, color = TextSecondary)
        WebViewBlock(WebViewBlockKind.LATEX, latex)
    }
}
