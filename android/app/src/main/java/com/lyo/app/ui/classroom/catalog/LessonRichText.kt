package com.lyo.app.ui.classroom.catalog

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import com.lyo.app.ui.theme.TextPrimary

/**
 * Lesson documents contain Markdown with *embedded* LaTeX, rather than only
 * standalone board/latex events. Send those paragraphs through KaTeX too.
 * Source is HTML-escaped in WebViewBlock; never execute teacher-provided HTML.
 */
fun containsLessonMath(value: String): Boolean =
    value.contains("$$") ||
        value.contains("\\(") || value.contains("\\[") ||
        value.contains("\\frac") ||
        Regex("""(?<!\\)\$[^$\n]+\$""").containsMatchIn(value)

/** Format ordinary prose natively; use the shared math renderer for rich paragraphs. */
@Composable
fun LessonRichText(value: String, modifier: Modifier = Modifier) {
    if (containsLessonMath(value)) {
        WebViewBlock(WebViewBlockKind.RICH, value, modifier)
    } else {
        Text(
            text = cleanClassroomText(value)
                .lineSequence()
                .joinToString("\n") { it.replace(Regex("""^\s*#{1,4}\s+"""), "") },
            style = MaterialTheme.typography.bodyMedium,
            color = TextPrimary,
            modifier = modifier,
        )
    }
}
