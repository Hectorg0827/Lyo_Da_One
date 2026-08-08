package com.lyo.app.ui.classroom.catalog

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.slideInHorizontally
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.lyo.app.ui.classroom.a2ui.A2uiRenderScope
import com.lyo.app.ui.theme.TextPrimary
import kotlinx.coroutines.delay

/**
 * A `board` `action: "bullets"` element — a staggered fade-in list, ported
 * from web's `motion.li` stagger (delay ≈ min(item_count, N) * 0.55s per
 * item, see data.classroom.DirectorTurn's turn-pacing notes). Each bullet's
 * own visibility is a local `remember`-scoped flag flipped after its
 * staggered delay, rather than the generic A2UI data-binding machinery —
 * this is pure client-side entrance-animation timing, not agent-driven
 * state, so it doesn't belong in the data model.
 */
@Composable
fun A2uiRenderScope.BulletsBlockRenderer() {
    val items = resolveStringList("items")
    if (items.isEmpty()) return

    Column {
        items.forEachIndexed { index, item ->
            var visible by remember(component.id, index) { mutableStateOf(false) }
            androidx.compose.runtime.LaunchedEffect(component.id, index) {
                delay((index * 120L).coerceAtMost(2400L))
                visible = true
            }
            AnimatedVisibility(
                visible = visible,
                enter = fadeIn(tween(300)) + slideInHorizontally(tween(300), initialOffsetX = { -it / 4 }),
            ) {
                Text(
                    text = "•  $item",
                    color = TextPrimary,
                    modifier = Modifier.padding(vertical = 2.dp),
                )
            }
        }
    }
}
