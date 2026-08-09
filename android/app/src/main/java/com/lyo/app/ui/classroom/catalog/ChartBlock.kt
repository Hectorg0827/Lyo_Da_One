package com.lyo.app.ui.classroom.catalog

import androidx.compose.animation.core.LinearOutSlowInEasing
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.unit.dp
import com.lyo.app.ui.classroom.a2ui.A2uiRenderScope
import com.lyo.app.ui.theme.ClassroomTokens
import com.lyo.app.ui.theme.TextSecondary
import kotlin.math.max

/**
 * A `board` `action: "chart"` element — bar or line, per
 * data.classroom.DirectorTurn.chart_type. Hand-written Canvas rather than a
 * charting dependency (see the implementation plan's dependency
 * decision) — only these two chart types are reachable from the wire
 * contract, so a full charting library is more than this needs.
 */
@Composable
fun A2uiRenderScope.ChartBlockRenderer() {
    val chartType = literalString("chartType") ?: resolveString("chartType") ?: "bar"
    val labels = resolveStringList("labels")
    val values = resolve("values")?.takeIf { it.isJsonArray }
        ?.asJsonArray?.mapNotNull { if (it.isJsonPrimitive) it.asDouble else null }
        ?: emptyList()
    if (values.isEmpty()) return

    val progress = remember(component.id) { Animatable(0f) }
    LaunchedEffect(component.id) {
        progress.animateTo(1f, animationSpec = tween(900, easing = LinearOutSlowInEasing))
    }
    val maxValue = max(values.maxOrNull() ?: 1.0, 0.0001)

    Column(modifier = Modifier.padding(vertical = 8.dp)) {
        Canvas(
            modifier = Modifier
                .fillMaxWidth()
                .height(140.dp),
        ) {
            val barGap = 12.dp.toPx()
            val barWidth = (size.width - barGap * (values.size + 1)) / values.size

            if (chartType == "line") {
                val points = values.mapIndexed { index, value ->
                    val x = barGap + barWidth / 2 + index * (barWidth + barGap)
                    val y = size.height - (value / maxValue).toFloat() * size.height * progress.value
                    Offset(x, y)
                }
                for (i in 0 until points.size - 1) {
                    drawLine(
                        color = ClassroomTokens.AccentPurple,
                        start = points[i],
                        end = points[i + 1],
                        strokeWidth = 4.dp.toPx(),
                    )
                }
                points.forEach { point ->
                    drawCircle(ClassroomTokens.AccentPurple, radius = 5.dp.toPx(), center = point)
                }
            } else {
                values.forEachIndexed { index, value ->
                    val barHeight = (value / maxValue).toFloat() * size.height * progress.value
                    val left = barGap + index * (barWidth + barGap)
                    drawRoundRect(
                        color = ClassroomTokens.AccentPurple,
                        topLeft = Offset(left, size.height - barHeight),
                        size = androidx.compose.ui.geometry.Size(barWidth, barHeight),
                        cornerRadius = androidx.compose.ui.geometry.CornerRadius(6.dp.toPx(), 6.dp.toPx()),
                    )
                }
            }
        }
        if (labels.isNotEmpty()) {
            androidx.compose.foundation.layout.Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = androidx.compose.foundation.layout.Arrangement.SpaceEvenly,
            ) {
                labels.forEach { label ->
                    Text(text = label, style = MaterialTheme.typography.labelSmall, color = TextSecondary)
                }
            }
        }
    }
}
