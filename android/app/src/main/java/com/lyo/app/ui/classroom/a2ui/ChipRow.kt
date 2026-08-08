package com.lyo.app.ui.classroom.a2ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.lyo.app.ui.theme.LyoGreen
import com.lyo.app.ui.theme.LyoPurple
import com.lyo.app.ui.theme.LyoRed
import com.lyo.app.ui.theme.SurfaceElevated
import com.lyo.app.ui.theme.TextPrimary

/**
 * Shared chip-row rendering, used by both BasicCatalog's plain `ChoicePicker`
 * (a user_prompt's chip options — every chip visually equal, no correctness
 * concept) and ui.classroom.catalog.QuizCardView (a QuizCard's options,
 * which DO have a correct/incorrect state once answered). Pulled out once
 * so the "3 real options, no padding/truncation, wraps to a new line"
 * layout logic lives in exactly one place.
 */
enum class ChipState { DEFAULT, SELECTED, CORRECT, INCORRECT }

@Composable
fun ClassroomChipRow(
    options: List<String>,
    stateFor: (String) -> ChipState,
    enabledFor: (String) -> Boolean,
    onSelect: (String) -> Unit,
    modifier: Modifier = Modifier,
) {
    Row(
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        modifier = modifier.padding(4.dp),
    ) {
        options.forEach { option ->
            val state = stateFor(option)
            val (background, contentColor) = when (state) {
                ChipState.CORRECT -> LyoGreen.copy(alpha = 0.25f) to LyoGreen
                ChipState.INCORRECT -> LyoRed.copy(alpha = 0.25f) to LyoRed
                ChipState.SELECTED -> LyoPurple to Color.White
                ChipState.DEFAULT -> SurfaceElevated to TextPrimary
            }
            val enabled = enabledFor(option)
            Text(
                text = option,
                color = if (enabled || state != ChipState.DEFAULT) contentColor else contentColor.copy(alpha = 0.45f),
                fontWeight = if (state == ChipState.SELECTED || state == ChipState.CORRECT) FontWeight.Bold else FontWeight.Normal,
                modifier = Modifier
                    .background(background, RoundedCornerShape(50))
                    .clickable(enabled = enabled) { onSelect(option) }
                    .padding(horizontal = 16.dp, vertical = 10.dp),
            )
        }
    }
}
