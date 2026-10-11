package com.lyo.app.ui.classroom.catalog

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.*
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Slider
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.semantics.CustomAccessibilityAction
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.customActions
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.unit.dp
import com.google.gson.JsonElement
import com.google.gson.JsonPrimitive
import com.lyo.app.data.classroom.ClassroomBlock
import java.text.NumberFormat
import kotlin.math.PI
import kotlin.math.atan2
import kotlin.math.min

/** Shared by Chat, Classroom, and Test Prep; exploration does not grade. */
@Composable
fun FractionPieCard(visual: ClassroomBlock, id: String, onUpdate: (Map<String, JsonElement>) -> Unit) {
    var parts by remember(id) { mutableIntStateOf(visual.parts ?: 1) }
    var selected by remember(id) { mutableStateOf((0 until (visual.value ?: 0)).toSet()) }
    val original = remember(id) { (visual.parts ?: 1) to (visual.value ?: 0) }
    val spanish = visual.caption.orEmpty().contains("numerador", ignoreCase = true)
    val cyan = Color(0xFF7DD3FC)
    val value = selected.size
    val fraction = "$value/$parts"
    val decimal = value.toDouble() / parts
    val format = remember { NumberFormat.getNumberInstance().apply { maximumFractionDigits = 3 } }
    var a = value
    var b = parts
    while (b != 0) { val remainder = a % b; a = b; b = remainder }
    val reduced = "${value / a}/${parts / a}"

    fun save() { onUpdate(mapOf("parts" to JsonPrimitive(parts), "value" to JsonPrimitive(selected.size))) }
    fun toggle(index: Int) {
        selected = if (index in selected) selected - index else selected + index
        save()
    }

    Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(14.dp)) {
        Text(fraction, color = cyan, style = MaterialTheme.typography.headlineLarge)
        Text("= ${format.format(decimal)} · ${format.format(decimal * 100)}%", color = Color.White)
        Text("${if (spanish) "Forma simplificada" else "Simplest form"}: $reduced", color = Color.White.copy(alpha = 0.8f))
        if ((visual.whole ?: 1.0) != 1.0) {
            Text("${format.format(visual.whole!! * decimal)} ${visual.unit.orEmpty()}", color = Color.White)
        }
        Canvas(Modifier.fillMaxWidth().height(260.dp)
            .pointerInput(parts, selected) {
                detectTapGestures { tap ->
                    val center = Offset(size.width / 2f, size.height / 2f)
                    val delta = tap - center
                    val radius = min(size.width, size.height) / 2f - 4f
                    if (delta.getDistance() <= radius) {
                        val angle = (atan2(delta.y.toDouble(), delta.x.toDouble()) + PI / 2 + 2 * PI) % (2 * PI)
                        toggle((angle * parts / (2 * PI)).toInt().coerceIn(0, parts - 1))
                    }
                }
            }
            .semantics {
                contentDescription = if (spanish) "Diagrama de fracciones" else "Fraction pie"
                stateDescription = fraction
                customActions = (0 until parts).map { index ->
                    CustomAccessibilityAction(
                        label = if (spanish) "Cambiar parte ${index + 1} de $parts" else "Toggle slice ${index + 1} of $parts",
                        action = { toggle(index); true },
                    )
                }
            }) {
            val radius = min(size.width, size.height) / 2f - 4f
            val origin = Offset(size.width / 2 - radius, size.height / 2 - radius)
            val circleSize = Size(radius * 2, radius * 2)
            repeat(parts) { index ->
                drawArc(if (index in selected) cyan else Color.White.copy(alpha = 0.12f),
                    index * 360f / parts - 90f, 360f / parts, true, origin, circleSize)
                drawArc(Color(0xFF0F172A), index * 360f / parts - 90f, 360f / parts,
                    true, origin, circleSize, style = Stroke(width = 2.dp.toPx()))
            }
        }
        Text("${if (spanish) "Numerador · partes sombreadas" else "Numerator · shaded slices"}: $value", color = Color.White)
        Slider(value.toFloat(), onValueChange = {
            selected = (0 until it.toInt().coerceIn(0, parts)).toSet(); save()
        }, valueRange = 0f..parts.toFloat(), steps = parts - 1,
            modifier = Modifier.heightIn(min = 48.dp).semantics {
                contentDescription = if (spanish) "Numerador" else "Numerator"; stateDescription = fraction
            })
        Text("${if (spanish) "Denominador · partes iguales" else "Denominator · equal slices"}: $parts", color = Color.White)
        Slider(parts.toFloat(), onValueChange = {
            val next = it.toInt().coerceIn(1, 20)
            selected = (0 until min(selected.size, next)).toSet(); parts = next; save()
        }, valueRange = 1f..20f, steps = 18,
            modifier = Modifier.heightIn(min = 48.dp).semantics {
                contentDescription = if (spanish) "Denominador" else "Denominator"; stateDescription = parts.toString()
            })
        TextButton(onClick = {
            parts = original.first; selected = (0 until original.second).toSet(); save()
        }, modifier = Modifier.heightIn(min = 48.dp)) { Text(if (spanish) "Reiniciar" else "Reset") }
        Text(if (spanish) "El entero permanece igual. Cambiar el denominador cambia el tamaño de cada parte."
             else "The whole stays the same. Changing the denominator changes the size of each slice.",
             color = Color.White.copy(alpha = 0.65f), style = MaterialTheme.typography.bodySmall)
    }
}
