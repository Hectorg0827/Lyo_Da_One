package com.lyo.app.ui.classroom.catalog

import androidx.compose.foundation.Image
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.unit.dp
import com.lyo.app.ui.classroom.a2ui.A2uiRenderScope
import com.lyo.app.ui.theme.ClassroomTokens

/**
 * Renders Lyo the mascot: `lyoState`-driven flip-book/idle animation via
 * MascotAnimator's `rememberMascotFrame`. Registered under "MascotAvatar" in
 * ClassroomCatalog; ClassroomBridge's initial surface includes exactly one
 * permanent instance (id "lyo_mascot", bound to `/mascot/state`), rendered
 * directly by ClassroomScreen via RenderNode — kept on screen permanently,
 * never wrapped in the chrome auto-hide conditional.
 *
 * The Teacher badge is visually similar (same `rememberMascotFrame`
 * machinery, `variant = "teacher"`) but is NOT an A2UI component — its
 * identity is 100% locally computed, never wire-contract-driven, so
 * ClassroomChrome's `TeacherBadgeAndCaption` calls `rememberMascotFrame`
 * directly instead of going through this renderer/the A2UI tree at all.
 * `MascotAvatarRenderer`'s own `variant` parameter support exists for
 * schema completeness/future reuse, not because anything currently routes
 * a non-"lyo" variant through it.
 */
@Composable
fun A2uiRenderScope.MascotAvatarRenderer() {
    val state = resolveString("lyoState", "reading") ?: "reading"
    val variant = literalString("variant", "lyo") ?: "lyo"
    val sizeDp = (resolve("size")?.takeIf { it.isJsonPrimitive }?.asInt ?: 56).dp

    val frame = rememberMascotFrame(state, variant)
    val ringColor = if (variant == "lyo") Color.Transparent else ClassroomTokens.AccentGlow
    Image(
        painter = painterResource(frame.drawableRes),
        contentDescription = "$variant is $state",
        modifier = frame.modifier
            .size(sizeDp)
            .border(2.dp, ringColor, CircleShape),
    )
}
