package com.lyo.app.ui.navigation

import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.IconButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.scale
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.scale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import com.lyo.app.R

/**
 * LYO's premium Android tab bar, matched to web MobileNav.
 *
 * Native Android has five explicit destinations: Focus, Discover, Ask Lyo,
 * Community, and the Create (+) studio. The mascot opens canonical Chat.
 * Profile and Settings are reached through Home's avatar menu.
 * Custom 24-unit glyphs mirror the approved web NavIcons, including their
 * one warm-orange filled shape. No generic Material icon placeholders.
 */
@Composable
internal fun LyoBottomBar(currentRoute: String?, onNavigate: (String) -> Unit) {
    val breathing = rememberInfiniteTransition(label = "bottomMascot")
    val mascotScale by breathing.animateFloat(
        initialValue = 0.98f,
        targetValue = 1.045f,
        animationSpec = infiniteRepeatable(tween(1700), RepeatMode.Reverse),
        label = "mascotBreathing",
    )
    Row(
        // MainActivity enables edge-to-edge drawing. The app's navigation
        // surface needs its own system-bar inset; otherwise Samsung's 3-button
        // navigation obscures the tabs and the floating mascot.
        modifier = Modifier
            .fillMaxWidth()
            .background(Color(0xD00D0F18))
            .navigationBarsPadding()
            .height(84.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceEvenly,
    ) {
        GhostTab("Focus", Routes.HOME, "focus", currentRoute == Routes.HOME, onNavigate)
        GhostTab("Discover", Routes.DISCOVER, "discover", currentRoute == Routes.DISCOVER, onNavigate)

        Box(
            modifier = Modifier.weight(1.3f).height(84.dp)
                .semantics { contentDescription = "Ask Lyo" }
                .clickable(role = Role.Button) { onNavigate(Routes.CHAT) },
            contentAlignment = Alignment.Center,
        ) {
            Box(
                modifier = Modifier.size(116.dp).offset(y = (-19).dp)
                    .background(
                        Brush.radialGradient(
                            listOf(Color(0x8A8B5CF6), Color(0x447C3AED), Color.Transparent)
                        ),
                        CircleShape,
                    ),
            )
            Image(
                painter = painterResource(R.drawable.mascot_standing),
                contentDescription = null,
                modifier = Modifier.size(99.dp).offset(y = (-19).dp).scale(mascotScale),
            )
        }

        GhostTab("Community", Routes.COMMUNITY, "community", currentRoute == Routes.COMMUNITY, onNavigate)
        // Open the same four-mode Create studio as mobile web. The old sheet
        // intercepted this tab, making the redesigned Create screen unreachable.
        GhostTab("Create", Routes.CREATE, "create", currentRoute == Routes.CREATE, onNavigate)
    }
}

@Composable
private fun RowScope.GhostTab(
    label: String,
    route: String,
    glyph: String,
    selected: Boolean,
    onNavigate: (String) -> Unit,
) {
    IconButton(
        onClick = { onNavigate(route) },
        modifier = Modifier.weight(1f).height(68.dp),
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            LyoNavGlyph(glyph, selected)
            Box(
                modifier = Modifier.size(4.dp).offset(y = 5.dp)
                    .background(if (selected) Color.White else Color.Transparent, CircleShape),
            )
        }
    }
}

@Composable
private fun LyoNavGlyph(glyph: String, selected: Boolean) {
    val outline = Color.White.copy(alpha = if (selected) 1f else 0.52f)
    val accent = if (selected) Color(0xFFFF8C00) else outline
    Canvas(Modifier.size(26.dp).semantics { contentDescription = glyph }) {
        val line = Stroke(width = 1.8f, cap = StrokeCap.Round, join = StrokeJoin.Round)
        scale(size.width / 24f, size.height / 24f, pivot = Offset.Zero) {
            when (glyph) {
                "focus" -> {
                    drawCircle(outline, radius = 8.8f, center = Offset(12f, 12f), style = line)
                    drawArc(outline, startAngle = -90f, sweepAngle = 90f, useCenter = false,
                        topLeft = Offset(7.6f, 7.6f), size = Size(8.8f, 8.8f), style = line)
                    drawCircle(accent, radius = 2.1f, center = Offset(12f, 12f))
                }
                "discover" -> {
                    drawCircle(outline, radius = 8.8f, center = Offset(12f, 12f), style = line)
                    val play = Path().apply {
                        moveTo(10.2f, 9.3f)
                        lineTo(10.2f, 14.7f)
                        lineTo(14.8f, 12f)
                        close()
                    }
                    drawPath(play, accent)
                }
                "community" -> {
                    drawCircle(outline, radius = 3.4f, center = Offset(8.6f, 9.4f), style = line)
                    drawCircle(accent, radius = 2.6f, center = Offset(16f, 11.6f))
                    drawCircle(outline, radius = 2.6f, center = Offset(16f, 11.6f), style = line)
                    val people = Path().apply {
                        moveTo(3.4f, 19.4f)
                        cubicTo(3.4f, 16.7f, 5.7f, 14.8f, 8.6f, 14.8f)
                        cubicTo(11.5f, 14.8f, 13.8f, 16.7f, 13.8f, 19.4f)
                        moveTo(15.4f, 16.1f)
                        cubicTo(18.1f, 16.3f, 20f, 17.9f, 20f, 20f)
                    }
                    drawPath(people, outline, style = line)
                }
                "create" -> {
                    val outlinePath = Path().apply {
                        moveTo(8.6f, 4.2f)
                        lineTo(15.4f, 4.2f)
                        cubicTo(17.9f, 4.2f, 19.8f, 6.1f, 19.8f, 8.6f)
                        lineTo(19.8f, 15.4f)
                        cubicTo(19.8f, 17.9f, 17.9f, 19.8f, 15.4f, 19.8f)
                        lineTo(8.6f, 19.8f)
                        cubicTo(6.1f, 19.8f, 4.2f, 17.9f, 4.2f, 15.4f)
                        lineTo(4.2f, 8.6f)
                        cubicTo(4.2f, 6.1f, 6.1f, 4.2f, 8.6f, 4.2f)
                        close()
                    }
                    drawPath(outlinePath, outline, style = line)
                    drawLine(accent, Offset(12f, 9f), Offset(12f, 15f), strokeWidth = 1.8f,
                        cap = StrokeCap.Round)
                    drawLine(accent, Offset(9f, 12f), Offset(15f, 12f), strokeWidth = 1.8f,
                        cap = StrokeCap.Round)
                }
            }
        }
    }
}
