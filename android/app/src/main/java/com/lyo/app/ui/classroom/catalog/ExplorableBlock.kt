package com.lyo.app.ui.classroom.catalog

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.dp
import com.lyo.app.ui.classroom.a2ui.A2uiRenderScope
import com.lyo.app.ui.theme.ClassroomTokens
import com.lyo.app.ui.theme.Surface
import com.lyo.app.ui.theme.TextPrimary
import com.lyo.app.ui.theme.TextSecondary

/**
 * A `board` `action: "explorable"` element — an interactive
 * parameterized-expression graph on web (draggable sliders re-evaluating a
 * plotted expression live). SCOPED AS v1 STATIC per the implementation
 * plan's own recommendation (this is the wire contract's most complex
 * element): renders the expression and its parameter list with each
 * parameter's initial value, no live re-plotting or draggable sliders yet.
 * Flagged as a known v2 gap, not a silent shortcut — see ClassroomCatalog.
 */
@Composable
fun A2uiRenderScope.ExplorableBlockRenderer() {
    val expression = resolveString("expression") ?: return
    val promptText = resolveString("prompt")
    val paramsJson = resolve("params")?.takeIf { it.isJsonArray }?.asJsonArray ?: return

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
        paramsJson.forEach { paramElement ->
            if (!paramElement.isJsonObject) return@forEach
            val param = paramElement.asJsonObject
            val name = param.get("name")?.takeIf { it.isJsonPrimitive }?.asString ?: return@forEach
            val initial = param.get("initial")?.takeIf { it.isJsonPrimitive }?.asDouble
            val min = param.get("min")?.takeIf { it.isJsonPrimitive }?.asDouble
            val max = param.get("max")?.takeIf { it.isJsonPrimitive }?.asDouble
            Row(modifier = Modifier.padding(top = 4.dp)) {
                Text(text = "$name = ${initial ?: "?"}", color = TextSecondary)
                if (min != null && max != null) {
                    Text(text = "  (range $min–$max)", color = TextSecondary.copy(alpha = 0.6f))
                }
            }
        }
    }
}
