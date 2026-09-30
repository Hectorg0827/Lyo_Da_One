package com.lyo.app.ui.classroom.catalog

import androidx.compose.foundation.Canvas
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
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage
import com.google.gson.Gson
import com.google.gson.JsonElement
import com.google.gson.JsonObject
import com.google.gson.JsonPrimitive
import com.lyo.app.data.classroom.ClassroomBlock
import com.lyo.app.data.classroom.TeachingVisualItem
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

    @Composable
    fun EntryButton(index: Int, item: TeachingVisualItem, prefix: String = "") {
        TextButton(
            onClick = { change(index) },
            modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp)
                .semantics { selected = value == index }
                .background(if (value == index) cyan.copy(alpha = 0.1f) else Color.Transparent, RoundedCornerShape(12.dp))
                .border(1.dp, if (value == index) cyan.copy(alpha = 0.5f) else Color.White.copy(alpha = 0.12f), RoundedCornerShape(12.dp)),
        ) {
            Column(Modifier.fillMaxWidth()) {
                Text(prefix + item.label.orEmpty(), color = Color.White)
                if (value == index) {
                    Text(item.detail.orEmpty(), color = Color.White.copy(alpha = 0.8f), style = MaterialTheme.typography.bodySmall)
                }
            }
        }
    }

    Column(
        Modifier.fillMaxWidth().padding(vertical = 6.dp)
            .background(cyan.copy(alpha = 0.06f), RoundedCornerShape(16.dp))
            .border(1.dp, cyan.copy(alpha = 0.25f), RoundedCornerShape(16.dp)).padding(18.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
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
                    Text("${"%.3f".format(amount).trimEnd('0').trimEnd('.', ',')} ${visual.unit.orEmpty()}",
                        color = Color.White, style = MaterialTheme.typography.titleMedium)
                }
                Row(
                    Modifier.fillMaxWidth().height(56.dp).semantics {
                        contentDescription = visual.description.orEmpty(); stateDescription = "$value/$parts"
                    },
                    horizontalArrangement = Arrangement.spacedBy(3.dp),
                ) {
                    repeat(parts) { index ->
                        Box(Modifier.weight(1f).fillMaxHeight()
                            .background(if (index < value) cyan else Color.White.copy(alpha = 0.1f), RoundedCornerShape(4.dp)))
                    }
                }
                Slider(
                    value = value.toFloat(),
                    onValueChange = { change(it.toInt()) },
                    valueRange = 0f..parts.toFloat(),
                    steps = parts - 1,
                    modifier = Modifier.heightIn(min = 48.dp).semantics { contentDescription = visual.title.orEmpty() },
                )
            }

            "comparison", "sequence" -> {
                val entries = visual.entries!!
                entries.forEachIndexed { index, item ->
                    EntryButton(index, item, if (visual.kind == "sequence") "${index + 1}.  " else "")
                }
                Text(
                    entries[value].detail.orEmpty(),
                    color = Color.White,
                    style = MaterialTheme.typography.bodyLarge,
                    modifier = Modifier.fillMaxWidth().semantics { liveRegion = LiveRegionMode.Polite }
                        .background(Color.Black.copy(alpha = 0.15f), RoundedCornerShape(12.dp)).padding(14.dp),
                )
            }

            "process_flow" -> {
                val entries = visual.entries!!
                entries.forEachIndexed { index, item ->
                    EntryButton(index, item)
                    if (index < entries.lastIndex) {
                        Text("↓", color = cyan.copy(alpha = 0.75f), style = MaterialTheme.typography.titleLarge,
                            modifier = Modifier.fillMaxWidth())
                    }
                }
            }

            "timeline" -> {
                val entries = visual.entries!!
                entries.forEachIndexed { index, item ->
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        Text(if (index == value) "●" else "○", color = cyan, modifier = Modifier.padding(top = 12.dp))
                        Box(Modifier.weight(1f)) { EntryButton(index, item) }
                    }
                }
            }

            "number_line" -> {
                val entries = visual.entries!!
                val min = visual.x_min!!
                val max = visual.x_max!!
                Canvas(Modifier.fillMaxWidth().height(72.dp).semantics { contentDescription = visual.description.orEmpty() }) {
                    val y = size.height / 2
                    drawLine(Color.White.copy(alpha = 0.45f), Offset(0f, y), Offset(size.width, y), strokeWidth = 3f)
                    entries.forEachIndexed { index, item ->
                        val ratio = ((item.position!! - min) / (max - min)).toFloat().coerceIn(0f, 1f)
                        val x = ratio * size.width
                        drawCircle(if (index == value) cyan else Color.White.copy(alpha = 0.75f), radius = if (index == value) 12f else 8f, center = Offset(x, y))
                    }
                }
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    Text("$min", color = Color.White.copy(alpha = 0.6f), style = MaterialTheme.typography.bodySmall)
                    Text("$max", color = Color.White.copy(alpha = 0.6f), style = MaterialTheme.typography.bodySmall)
                }
                entries.forEachIndexed { index, item -> EntryButton(index, item, "${item.position}: ") }
            }

            "annotated_image" -> {
                if (!visual.image_url.isNullOrBlank()) {
                    AsyncImage(
                        model = visual.image_url,
                        contentDescription = visual.description,
                        contentScale = ContentScale.Fit,
                        modifier = Modifier.fillMaxWidth().heightIn(min = 180.dp, max = 420.dp)
                            .background(Color.Black.copy(alpha = 0.18f), RoundedCornerShape(12.dp)),
                    )
                } else {
                    Text(
                        visual.description.orEmpty(),
                        color = Color.White.copy(alpha = 0.85f),
                        modifier = Modifier.fillMaxWidth().background(Color.Black.copy(alpha = 0.15f), RoundedCornerShape(12.dp)).padding(14.dp),
                    )
                }
                visual.entries.orEmpty().forEachIndexed { index, item ->
                    EntryButton(index, item, "${index + 1}.  ")
                }
                if (!visual.attribution.isNullOrBlank()) {
                    Text(visual.attribution, color = Color.White.copy(alpha = 0.55f), style = MaterialTheme.typography.bodySmall)
                }
            }

            "graph" -> {
                val params = visual.params!!
                var values by remember(id) { mutableStateOf(params.associate { it.name!! to it.initial!! }) }
                ExplorablePlot(
                    visual.expression!!, visual.x_min!!, visual.x_max!!, values,
                    Modifier.fillMaxWidth().height(160.dp).semantics { contentDescription = visual.description.orEmpty() },
                    yBounds = visual.y_min!!..visual.y_max!!,
                )
                Text("x: ${visual.x_min} … ${visual.x_max} · y: ${visual.y_min} … ${visual.y_max}",
                    color = Color.White.copy(alpha = 0.7f), style = MaterialTheme.typography.bodySmall)
                params.forEach { param ->
                    Text("${param.name} = ${"%.2f".format(values.getValue(param.name!!))}", color = cyan)
                    Slider(
                        value = values.getValue(param.name!!).toFloat(),
                        onValueChange = { next ->
                            values = values + (param.name to next.toDouble())
                            val snapshot = JsonObject().apply { values.forEach { (name, v) -> addProperty(name, v) } }
                            onUpdate(mapOf("params" to snapshot))
                        },
                        valueRange = param.min!!.toFloat()..param.max!!.toFloat(),
                        modifier = Modifier.heightIn(min = 48.dp).semantics { contentDescription = param.name },
                    )
                }
            }
        }
    }
}
