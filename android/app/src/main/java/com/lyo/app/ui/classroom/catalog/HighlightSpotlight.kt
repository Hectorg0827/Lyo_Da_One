package com.lyo.app.ui.classroom.catalog

import androidx.compose.animation.core.LinearOutSlowInEasing
import androidx.compose.animation.core.tween
import androidx.compose.animation.core.Animatable
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.unit.dp
import com.lyo.app.ui.classroom.a2ui.A2uiRenderScope
import com.lyo.app.ui.theme.ClassroomTokens

/**
 * A standalone "circled spotlight" board element (from a `board`
 * `action: "highlight"` turn). Web draws a real SVG ellipse anchored to the
 * exact on-screen position of the term's text within the preceding chalk
 * element (path-drawn over 700ms). Reproducing that requires text-layout
 * measurement coordination between two separately-positioned composables
 * that this v1 doesn't attempt — DELIBERATE SIMPLIFICATION: renders as its
 * own free-standing callout card (an animated oval-stroke drawn around the
 * term text itself, in place, rather than around the earlier chalk
 * occurrence) so the highlight is still clearly visible and still gets the
 * same 700ms path-draw-in feel, just not geometrically overlaid on the
 * original word. Flagged in the implementation plan as a known gap, not a
 * silent shortcut.
 */
@Composable
fun A2uiRenderScope.HighlightSpotlightRenderer() {
    val term = resolveString("term") ?: return
    val drawProgress = remember(term) { Animatable(0f) }
    LaunchedEffect(term) {
        drawProgress.animateTo(1f, animationSpec = tween(700, easing = LinearOutSlowInEasing))
    }

    Row(
        modifier = Modifier.padding(vertical = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        androidx.compose.foundation.layout.Box(contentAlignment = Alignment.Center) {
            Canvas(
                modifier = Modifier
                    .width(160.dp)
                    .height(56.dp),
            ) {
                val strokeWidth = 3.dp.toPx()
                val sweep = 360f * drawProgress.value
                drawArc(
                    color = ClassroomTokens.Gold,
                    startAngle = -90f,
                    sweepAngle = sweep,
                    useCenter = false,
                    style = Stroke(width = strokeWidth),
                    size = Size(size.width - strokeWidth, size.height - strokeWidth),
                    topLeft = androidx.compose.ui.geometry.Offset(strokeWidth / 2, strokeWidth / 2),
                )
            }
            Text(text = term, color = ClassroomTokens.Gold)
        }
    }
}
