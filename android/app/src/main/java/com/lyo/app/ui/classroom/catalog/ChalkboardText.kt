package com.lyo.app.ui.classroom.catalog

import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.withStyle
import com.lyo.app.ui.classroom.a2ui.A2uiRenderScope
import com.lyo.app.ui.theme.ClassroomTokens
import com.lyo.app.ui.theme.TextPrimary

/**
 * "chalk" board content — plain lesson text, with an optional highlighted
 * substring (`highlightedTerm`, mutated in place by a later `board`
 * `action: "highlight"` turn — see ClassroomBridge.directorTurnToA2ui).
 * Ported from web/src/components/classroom/BoardElementView.tsx's
 * `chalkTextWithHighlight()`: case-insensitive FIRST occurrence only,
 * wrapped in a pulsing gold span, everything else plain.
 */
@Composable
fun A2uiRenderScope.ChalkboardTextRenderer() {
    val text = resolveString("text") ?: return
    val highlightedTerm = resolveString("highlightedTerm")

    val transition = rememberInfiniteTransition(label = "chalk-highlight-pulse")
    val pulseAlpha by transition.animateFloat(
        initialValue = 0.15f,
        targetValue = 0.4f,
        animationSpec = infiniteRepeatable(
            animation = tween(700, easing = LinearEasing),
            repeatMode = RepeatMode.Reverse,
        ),
        label = "chalk-highlight-pulse-alpha",
    )

    val annotated = buildAnnotatedString {
        val index = highlightedTerm?.takeIf { it.isNotEmpty() }
            ?.let { term -> text.indexOf(term, ignoreCase = true) }
            ?: -1
        if (index == -1 || highlightedTerm == null) {
            append(text)
        } else {
            append(text.substring(0, index))
            withStyle(
                SpanStyle(
                    color = ClassroomTokens.Gold,
                    background = ClassroomTokens.Gold.copy(alpha = pulseAlpha),
                ),
            ) {
                append(text.substring(index, index + highlightedTerm.length))
            }
            append(text.substring(index + highlightedTerm.length))
        }
    }

    Text(text = annotated, color = TextPrimary)
}
