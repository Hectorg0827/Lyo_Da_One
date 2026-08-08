package com.lyo.app.ui.classroom.a2ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.wrapContentWidth
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Circle
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Checkbox
import androidx.compose.material3.Divider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage
import com.google.gson.JsonPrimitive
import com.lyo.app.data.a2ui.A2uiChildren
import com.lyo.app.data.a2ui.A2uiValue
import com.lyo.app.ui.theme.LyoPurple
import com.lyo.app.ui.theme.Surface
import com.lyo.app.ui.theme.SurfaceElevated
import com.lyo.app.ui.theme.TextPrimary
import com.lyo.app.ui.theme.TextSecondary

/**
 * The subset of A2UI's basic 18-component catalog
 * (specification/v1_0/catalogs/basic/catalog.json) actually needed by the
 * AI Classroom wire contract — Video/AudioPlayer/Tabs/Modal/DateTimeInput
 * aren't reachable from anything ClassroomBridge emits, so they're not
 * implemented. Each renderer follows the basic-catalog implementation
 * guide's "leaf-margin strategy" (a uniform default external margin on
 * leaf/visual elements, 8dp here) to avoid nested-spacing multiplication —
 * translated directly from the generic guidance into a Compose default,
 * overridable per-component where the classroom catalog needs tighter
 * control (see ui.classroom.catalog for those overrides).
 */
val BasicCatalog: A2uiCatalog = A2uiCatalog(
    mapOf(
        "Text" to A2uiComponentRenderer { TextRenderer() },
        "Image" to A2uiComponentRenderer { ImageRenderer() },
        "Icon" to A2uiComponentRenderer { IconRenderer() },
        "Row" to A2uiComponentRenderer { RowRenderer() },
        "Column" to A2uiComponentRenderer { ColumnRenderer() },
        "List" to A2uiComponentRenderer { ListRenderer() },
        "Card" to A2uiComponentRenderer { CardRenderer() },
        "Divider" to A2uiComponentRenderer { DividerRenderer() },
        "Button" to A2uiComponentRenderer { ButtonRenderer() },
        "TextField" to A2uiComponentRenderer { TextFieldRenderer() },
        "CheckBox" to A2uiComponentRenderer { CheckBoxRenderer() },
        "ChoicePicker" to A2uiComponentRenderer { ChoicePickerRenderer() },
        "Slider" to A2uiComponentRenderer { SliderRenderer() },
    ),
)

private val leafMargin = Modifier.padding(8.dp)

/** Every input renderer below reads its bound path this same way — pulled
 *  out once so the `as?` cast isn't repeated at every call site. */
private fun A2uiRenderScope.boundPath(propertyName: String): String? =
    (component.properties[propertyName] as? A2uiValue.PathRef)?.path

@Composable
private fun A2uiRenderScope.TextRenderer() {
    val text = resolveString("text") ?: return
    val variant = literalString("variant", "body")
    val style = when (variant) {
        "title" -> MaterialTheme.typography.titleMedium
        "headline" -> MaterialTheme.typography.headlineSmall
        "caption" -> MaterialTheme.typography.labelSmall
        else -> MaterialTheme.typography.bodyMedium
    }
    Text(text = text, style = style, color = TextPrimary, modifier = leafMargin)
}

@Composable
private fun A2uiRenderScope.ImageRenderer() {
    val url = resolveString("url") ?: return
    AsyncImage(model = url, contentDescription = resolveString("alt"), modifier = leafMargin)
}

@Composable
private fun A2uiRenderScope.IconRenderer() {
    // Only a spot-color dot is needed by anything the classroom emits today
    // (activity/status indicators) — full SVG-path icon support isn't
    // reachable from the wire contract, so it's intentionally not built.
    Icon(
        imageVector = Icons.Filled.Circle,
        contentDescription = null,
        tint = LyoPurple,
        modifier = leafMargin,
    )
}

@Composable
private fun A2uiRenderScope.RowRenderer() {
    Row(
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        modifier = Modifier.wrapContentWidth(),
    ) {
        renderChildren((component.children as? A2uiChildren.Fixed)?.ids ?: emptyList())
    }
}

@Composable
private fun A2uiRenderScope.ColumnRenderer() {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        renderChildren((component.children as? A2uiChildren.Fixed)?.ids ?: emptyList())
    }
}

@Composable
private fun A2uiRenderScope.ListRenderer() {
    val direction = literalString("direction", "vertical")
    when (val children = component.children) {
        is A2uiChildren.Fixed -> {
            if (direction == "horizontal") {
                LazyRow { items(children.ids) { id -> renderChild(id) } }
            } else {
                LazyColumn { items(children.ids) { id -> renderChild(id) } }
            }
        }
        is A2uiChildren.Template -> {
            // Template/iteration children need their own per-element scope
            // path, which the generic renderChild/renderChildren helpers
            // (fixed scopePath) can't provide — RenderTemplateChildren in
            // A2uiRenderer.kt handles that directly.
            RenderTemplateChildren(
                templatePath = children.path,
                componentId = children.componentId,
                state = surface,
                catalog = catalog,
                onAction = onAction,
            )
        }
        null -> Unit
    }
}

@Composable
private fun A2uiRenderScope.CardRenderer() {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(Surface, RoundedCornerShape(16.dp))
            .padding(12.dp),
    ) {
        renderChild(component.child)
    }
}

@Composable
private fun A2uiRenderScope.DividerRenderer() {
    Divider(color = TextSecondary.copy(alpha = 0.15f), modifier = leafMargin)
}

@Composable
private fun A2uiRenderScope.ButtonRenderer() {
    val label = resolveString("label") ?: literalString("label") ?: return
    val enabled = resolveBoolean("enabled", true)
    val actionName = literalString("action") ?: return
    Button(
        onClick = { fireAction(actionName) },
        enabled = enabled,
        colors = ButtonDefaults.buttonColors(containerColor = LyoPurple, contentColor = Color.White),
        modifier = leafMargin,
    ) {
        Text(label)
    }
}

@Composable
private fun A2uiRenderScope.TextFieldRenderer() {
    val path = boundPath("value")
    val placeholder = resolveString("placeholder") ?: ""
    val multiline = literalString("variant") == "longText"
    val keyboardType = when (literalString("variant")) {
        "number" -> KeyboardType.Number
        else -> KeyboardType.Text
    }
    var localValue by remember(component.id) {
        mutableStateOf(resolveString("value") ?: "")
    }
    OutlinedTextField(
        value = localValue,
        onValueChange = { newValue ->
            localValue = newValue
            // Two-way binding contract: local data-model write happens
            // immediately on every keystroke; network sync only happens on
            // an explicit action (e.g. a submit Button), never here.
            if (path != null) writeLocalDataModel(path, JsonPrimitive(newValue))
        },
        placeholder = { Text(placeholder, color = TextSecondary) },
        singleLine = !multiline,
        keyboardOptions = KeyboardOptions(keyboardType = keyboardType),
        modifier = leafMargin.fillMaxWidth(),
    )
}

@Composable
private fun A2uiRenderScope.CheckBoxRenderer() {
    val path = boundPath("checked")
    val checked = resolveBoolean("checked", false)
    val label = resolveString("label")
    Row(
        modifier = leafMargin,
        horizontalArrangement = Arrangement.spacedBy(4.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Checkbox(
            checked = checked,
            onCheckedChange = { newValue ->
                if (path != null) writeLocalDataModel(path, JsonPrimitive(newValue))
            },
        )
        if (label != null) Text(label, color = TextPrimary)
    }
}

/**
 * ChoicePicker with `displayStyle: "chips"` is the direct A2UI equivalent of
 * the dynamic prompt/quiz chip UI already shipped on web
 * (web/src/app/(main)/classroom/page.tsx PromptChipFlow-equivalent) and iOS
 * (ActiveLessonView.swift's PromptChipFlow) — real, question-specific
 * options, never a hardcoded yes/no default, never padded/truncated: the
 * chip count and labels are 100% driven by what's actually bound at
 * `options`.
 */
@Composable
private fun A2uiRenderScope.ChoicePickerRenderer() {
    val options = resolveStringList("options")
    if (options.isEmpty()) return
    val path = boundPath("value")
    val selected = resolveString("value")
    val actionName = literalString("action")

    Row(
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        modifier = Modifier.padding(4.dp),
    ) {
        options.forEach { option ->
            val isSelected = option == selected
            Text(
                text = option,
                color = if (isSelected) Color.White else TextPrimary,
                fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal,
                modifier = Modifier
                    .background(
                        if (isSelected) LyoPurple else SurfaceElevated,
                        RoundedCornerShape(50),
                    )
                    .clickable(enabled = selected == null) {
                        if (path != null) writeLocalDataModel(path, JsonPrimitive(option))
                        if (actionName != null) {
                            fireAction(
                                actionName,
                                mapOf("selectedLabel" to JsonPrimitive(option)),
                            )
                        }
                    }
                    .padding(horizontal = 16.dp, vertical = 10.dp),
            )
        }
    }
}

@Composable
private fun A2uiRenderScope.SliderRenderer() {
    val path = boundPath("value")
    val min = resolve("min")?.takeIf { it.isJsonPrimitive }?.asFloat ?: 0f
    val max = resolve("max")?.takeIf { it.isJsonPrimitive }?.asFloat ?: 1f
    var localValue by remember(component.id) {
        mutableStateOf(resolve("value")?.takeIf { it.isJsonPrimitive }?.asFloat ?: min)
    }
    Slider(
        value = localValue,
        onValueChange = { newValue ->
            localValue = newValue
            if (path != null) writeLocalDataModel(path, JsonPrimitive(newValue))
        },
        valueRange = min..max,
        colors = SliderDefaults.colors(thumbColor = LyoPurple, activeTrackColor = LyoPurple),
        modifier = leafMargin,
    )
}
