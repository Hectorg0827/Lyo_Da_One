package com.lyo.app.ui.classroom.catalog

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Slider
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.unit.dp
import com.google.gson.Gson
import com.google.gson.JsonElement
import com.google.gson.JsonObject
import com.google.gson.JsonPrimitive
import com.lyo.app.data.classroom.ClassroomBlock
import com.lyo.app.data.classroom.isTeachingVisualValid
import com.lyo.app.ui.classroom.a2ui.A2uiRenderScope

/** Exploring changes the representation; only a separate server checkpoint is graded. */
@Composable
fun A2uiRenderScope.TeachingVisualRenderer() {
    val raw = resolve("visual") ?: return
    val visual = remember(raw) { runCatching { Gson().fromJson(raw, ClassroomBlock::class.java) }.getOrNull() } ?: return
    TeachingVisualCard(visual, component.id) { fireAction("update_activity", it) }
}

@Composable
fun TeachingVisualCard(visual: ClassroomBlock, id: String, onUpdate: (Map<String, JsonElement>) -> Unit) {
    val cyan = Color(0xFF7DD3FC)
    var value by remember(id) { mutableIntStateOf(visual.value ?: 0) }
    fun change(next: Int) {
        value = next
        onUpdate(mapOf("value" to JsonPrimitive(next)))
    }
    Column(Modifier.fillMaxWidth().padding(vertical = 6.dp)
        .background(cyan.copy(alpha = 0.06f), RoundedCornerShape(16.dp))
        .border(1.dp, cyan.copy(alpha = 0.25f), RoundedCornerShape(16.dp)).padding(18.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp)) {
        Text(visual.title.orEmpty(), color = Color.White, style = MaterialTheme.typography.titleMedium)
        Text(visual.caption.orEmpty(), color = Color.White.copy(alpha = 0.85f), style = MaterialTheme.typography.bodyMedium)
        if (!visual.isTeachingVisualValid()) {
            Text(visual.description.orEmpty(), color = Color.White)
        } else when (visual.kind) {
            "fraction_bar" -> {
                val parts = visual.parts!!
                val amount = visual.whole!! * value / parts
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    Text("$value/$parts", color = cyan, style = MaterialTheme.typography.headlineMedium)
                    Text("${"%.3f".format(amount).trimEnd('0').trimEnd('.', ',')} ${visual.unit.orEmpty()}", color = Color.White, style = MaterialTheme.typography.titleMedium)
                }
                Row(Modifier.fillMaxWidth().height(56.dp).semantics {
                    contentDescription = visual.description.orEmpty(); stateDescription = "$value/$parts"
                }, horizontalArrangement = Arrangement.spacedBy(3.dp)) {
                    repeat(parts) { index -> Box(Modifier.weight(1f).fillMaxHeight()
                        .background(if (index < value) cyan else Color.White.copy(alpha = 0.1f), RoundedCornerShape(4.dp))) }
                }
                Slider(value = value.toFloat(), onValueChange = { change(it.toInt()) },
                    valueRange = 0f..parts.toFloat(), steps = parts - 1,
                    modifier = Modifier.heightIn(min = 48.dp).semantics { contentDescription = visual.title.orEmpty() })
            }
            "comparison", "sequence" -> {
                val entries = visual.entries!!
                entries.forEachIndexed { index, item ->
                    TextButton(onClick = { change(index) }, modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp)
                        .semantics { selected = value == index }
                        .background(if (value == index) cyan.copy(alpha = 0.1f) else Color.Transparent, RoundedCornerShape(12.dp))
                        .border(1.dp, if (value == index) cyan.copy(alpha = 0.5f) else Color.White.copy(alpha = 0.12f), RoundedCornerShape(12.dp))) {
                        Text((if (visual.kind == "sequence") "${index + 1}.  " else "") + item.label.orEmpty(), color = Color.White, modifier = Modifier.fillMaxWidth())
                    }
                }
                Text(entries[value].detail.orEmpty(), color = Color.White, style = MaterialTheme.typography.bodyLarge,
                    modifier = Modifier.fillMaxWidth().semantics { liveRegion = LiveRegionMode.Polite }.background(Color.Black.copy(alpha = 0.15f), RoundedCornerShape(12.dp)).padding(14.dp))
            }
            "graph" -> {
                val params = visual.params!!
                var values by remember(id) { mutableStateOf(params.associate { it.name!! to it.initial!! }) }
                ExplorablePlot(visual.expression!!, visual.x_min!!, visual.x_max!!, values,
                    Modifier.fillMaxWidth().height(160.dp).semantics { contentDescription = visual.description.orEmpty() },
                    yBounds = visual.y_min!!..visual.y_max!!)
                Text("x: ${visual.x_min} … ${visual.x_max} · y: ${visual.y_min} … ${visual.y_max}",
                    color = Color.White.copy(alpha = 0.7f), style = MaterialTheme.typography.bodySmall)
                params.forEach { param ->
                    Text("${param.name} = ${"%.2f".format(values.getValue(param.name!!))}", color = cyan)
                    Slider(value = values.getValue(param.name!!).toFloat(), onValueChange = { next ->
                        values = values + (param.name to next.toDouble())
                        val snapshot = JsonObject().apply { values.forEach { (name, v) -> addProperty(name, v) } }
                        onUpdate(mapOf("params" to snapshot))
                    }, valueRange = param.min!!.toFloat()..param.max!!.toFloat(),
                        modifier = Modifier.heightIn(min = 48.dp).semantics { contentDescription = param.name })
                }
            }
        }
    }
}
