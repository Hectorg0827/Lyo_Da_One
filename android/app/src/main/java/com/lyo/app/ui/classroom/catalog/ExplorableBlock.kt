package com.lyo.app.ui.classroom.catalog

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.dp
import com.lyo.app.ui.classroom.a2ui.A2uiRenderScope
import com.lyo.app.ui.theme.ClassroomTokens
import com.lyo.app.ui.theme.LyoPurple
import com.lyo.app.ui.theme.Surface
import com.lyo.app.ui.theme.TextPrimary
import com.lyo.app.ui.theme.TextSecondary

private const val DEFAULT_X_MIN = -5.0
private const val DEFAULT_X_MAX = 5.0
private const val PLOT_SAMPLES = 80

private data class ExplorableParamSpec(
    val name: String,
    val min: Double,
    val max: Double,
    val initial: Double,
)

/**
 * A `board` `action: "explorable"` element — an interactive
 * parameterized-expression graph. v2: real live plotting, upgraded from
 * the v1 static text-only render (expression + fixed params, no
 * re-evaluation) that originally shipped here — see git history for that
 * version and the reasoning behind deferring it. Backed by
 * ExpressionEvaluator (a small hand-written parser, see that file), since
 * the wire contract's expression grammar is fixed and small enough that a
 * charting/scripting dependency would be overkill (same reasoning as
 * ChartBlock's hand-written Canvas bar/line).
 *
 * Deliberately NOT wired to any outgoing action: the wire contract has no
 * "explorable param changed" action type (actionToUserAction's table has
 * no case for it — see ClassroomBridge), so slider drags are purely local,
 * client-side visualization, matching how ImageBlock's search integration
 * and MermaidBlock/LatexBlock's real rendering are all scoped as
 * client-local upgrades that don't touch the wire contract either.
 */
@Composable
fun A2uiRenderScope.ExplorableBlockRenderer() {
    val expression = resolveString("expression") ?: return
    val promptText = resolveString("prompt")
    val xMin = resolve("xMin")?.takeIf { it.isJsonPrimitive }?.asDouble ?: DEFAULT_X_MIN
    val xMax = resolve("xMax")?.takeIf { it.isJsonPrimitive }?.asDouble ?: DEFAULT_X_MAX
    val paramsJson = resolve("params")?.takeIf { it.isJsonArray }?.asJsonArray ?: return

    val paramSpecs = remember(component.id, paramsJson.toString()) {
        paramsJson.mapNotNull { el ->
            if (!el.isJsonObject) return@mapNotNull null
            val obj = el.asJsonObject
            val name = obj.get("name")?.takeIf { it.isJsonPrimitive }?.asString ?: return@mapNotNull null
            val min = obj.get("min")?.takeIf { it.isJsonPrimitive }?.asDouble ?: 0.0
            val max = obj.get("max")?.takeIf { it.isJsonPrimitive }?.asDouble ?: 1.0
            val initial = obj.get("initial")?.takeIf { it.isJsonPrimitive }?.asDouble ?: ((min + max) / 2.0)
            ExplorableParamSpec(name, min, max, initial)
        }
    }
    if (paramSpecs.isEmpty()) return

    // One local Float state per param, keyed by component id + param name
    // so a fresh explorable element (a new turn) doesn't inherit a prior
    // one's slider positions.
    val sliderStates = paramSpecs.associate { spec ->
        spec.name to remember(component.id, spec.name) { mutableStateOf(spec.initial.toFloat()) }
    }

    val currentValues = paramSpecs.associate { it.name to sliderStates.getValue(it.name).value.toDouble() }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 6.dp)
            .background(Surface, RoundedCornerShape(12.dp))
            .padding(12.dp),
    ) {
        Text(
            text = expression,
            fontFamily = FontFamily.Monospace,
            color = ClassroomTokens.Gold,
            style = MaterialTheme.typography.titleSmall,
        )
        if (promptText != null) {
            Text(text = promptText, color = TextPrimary, modifier = Modifier.padding(top = 6.dp))
        }

        ExplorablePlot(
            expression = expression,
            xMin = xMin,
            xMax = xMax,
            paramValues = currentValues,
            modifier = Modifier
                .fillMaxWidth()
                .height(120.dp)
                .padding(top = 10.dp),
        )

        paramSpecs.forEach { spec ->
            val state = sliderStates.getValue(spec.name)
            Column(modifier = Modifier.padding(top = 8.dp)) {
                Text(
                    text = "${spec.name} = ${"%.2f".format(state.value)}",
                    color = TextSecondary,
                    style = MaterialTheme.typography.labelMedium,
                )
                Slider(
                    value = state.value,
                    onValueChange = { state.value = it },
                    valueRange = spec.min.toFloat()..spec.max.toFloat(),
                    colors = SliderDefaults.colors(thumbColor = LyoPurple, activeTrackColor = LyoPurple),
                )
            }
        }
    }
}

/** Samples `expression` across [xMin, xMax] with the current param values
 *  bound (plus `x`), and draws the resulting polyline. Points where the
 *  expression is unplottable (ExpressionEvaluator returns null — division
 *  by zero, a non-finite result, an out-of-domain input) are simply
 *  skipped rather than breaking the whole render, the same
 *  resilience-over-crash rule the rest of the catalog follows. */
@Composable
private fun ExplorablePlot(
    expression: String,
    xMin: Double,
    xMax: Double,
    paramValues: Map<String, Double>,
    modifier: Modifier = Modifier,
) {
    val range = (xMax - xMin).takeIf { it > 0.0 } ?: (DEFAULT_X_MAX - DEFAULT_X_MIN)
    val safeXMin = if (xMax > xMin) xMin else DEFAULT_X_MIN

    val samples = remember(expression, paramValues, safeXMin, range) {
        (0..PLOT_SAMPLES).mapNotNull { i ->
            val x = safeXMin + range * i / PLOT_SAMPLES
            val y = ExpressionEvaluator.evaluateExpression(expression, paramValues + ("x" to x))
            y?.let { x to it }
        }
    }

    Canvas(modifier = modifier) {
        if (samples.size < 2) return@Canvas
        val yMin = samples.minOf { it.second }
        val yMax = samples.maxOf { it.second }
        val ySpan = (yMax - yMin).takeIf { it > 1e-9 } ?: 1.0

        fun toOffset(x: Double, y: Double): Offset {
            val px = ((x - safeXMin) / range).toFloat() * size.width
            val py = size.height - ((y - yMin) / ySpan).toFloat() * size.height
            return Offset(px, py)
        }

        // Zero line, when it's within the plotted y-range — an anchor for
        // reading the curve, matching a graphing calculator's default grid.
        if (yMin <= 0.0 && yMax >= 0.0) {
            val zeroY = toOffset(safeXMin, 0.0).y
            drawLine(
                color = TextSecondary.copy(alpha = 0.25f),
                start = Offset(0f, zeroY),
                end = Offset(size.width, zeroY),
                strokeWidth = 1.dp.toPx(),
            )
        }

        for (i in 0 until samples.size - 1) {
            val (x1, y1) = samples[i]
            val (x2, y2) = samples[i + 1]
            // Don't draw a line across a gap left by a skipped (unplottable)
            // sample — only connect genuinely adjacent x-steps.
            if (x2 - x1 > range / PLOT_SAMPLES * 1.5) continue
            drawLine(
                color = ClassroomTokens.AccentPurple,
                start = toOffset(x1, y1),
                end = toOffset(x2, y2),
                strokeWidth = 3.dp.toPx(),
            )
        }
    }
}
