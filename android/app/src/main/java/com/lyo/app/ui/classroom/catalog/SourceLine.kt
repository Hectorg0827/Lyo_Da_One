package com.lyo.app.ui.classroom.catalog

import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.lyo.app.ui.classroom.a2ui.A2uiRenderScope
import com.lyo.app.ui.theme.TextSecondary

/** A small "Source: a · b · c" attribution line (`source_attributions` on
 *  any component — see data.classroom.ClassroomComponent.source_attributions). */
@Composable
fun A2uiRenderScope.SourceLineRenderer() {
    val labels = resolveStringList("labels")
    if (labels.isEmpty()) return
    Text(
        text = "Source: " + labels.joinToString(" · "),
        color = TextSecondary,
        style = MaterialTheme.typography.labelSmall,
        modifier = Modifier.padding(top = 4.dp, bottom = 4.dp),
    )
}
