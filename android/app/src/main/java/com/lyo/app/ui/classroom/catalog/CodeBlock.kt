package com.lyo.app.ui.classroom.catalog

import androidx.compose.foundation.background
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.dp
import com.lyo.app.ui.classroom.a2ui.A2uiRenderScope
import com.lyo.app.ui.theme.Background
import com.lyo.app.ui.theme.TextPrimary

/** A "code" board element — a plain monospace block. Also reused as the
 *  fallback rendering for `mermaid`/`latex` (see MermaidBlock.kt/LatexBlock.kt)
 *  since v1 shows their raw source styled the same way, per the
 *  implementation plan's decision to defer real diagram/math rendering. */
@Composable
fun A2uiRenderScope.CodeBlockRenderer() {
    val code = resolveString("code") ?: resolveString("text") ?: return
    RawSourceBlock(code)
}

@Composable
internal fun RawSourceBlock(source: String) {
    Text(
        text = source,
        color = TextPrimary,
        fontFamily = FontFamily.Monospace,
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 4.dp)
            .background(Background, RoundedCornerShape(8.dp))
            .horizontalScroll(rememberScrollState())
            .padding(10.dp),
    )
}
