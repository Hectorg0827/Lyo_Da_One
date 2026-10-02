package com.lyo.app.ui.screens.home

import androidx.compose.foundation.Canvas
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotate
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.exp
import kotlin.math.sin

/**
 * Cover art for a saved course, drawn from the course's own subject.
 *
 * A course can exist seconds after Lio makes it, so there is no moment at
 * which an uploaded cover image could have arrived. The alternatives were an
 * empty grey thumbnail or stock imagery unrelated to the subject; this draws
 * bonds for chemistry, speech arcs for a language, a distribution for
 * statistics, and so on.
 *
 * The motif comes from [FocusPresentation.motifFor], which shares its hash
 * and motif order with iOS and web, so the same course is drawn the same way
 * everywhere and keeps its art across launches.
 */

private data class Palette(val stops: List<Color>, val ink: Color, val glow: Color)

private fun paletteFor(motif: FocusPresentation.Motif): Palette = when (motif) {
    FocusPresentation.Motif.Lattice -> Palette(
        listOf(Color(0xFF3B2A7A), Color(0xFF241A52), Color(0xFF140F2E)),
        Color(0xFFC4AEFF), Color(0xFFA97BFF),
    )
    FocusPresentation.Motif.Speech -> Palette(
        listOf(Color(0xFF6B1F62), Color(0xFF3C1550), Color(0xFF1A0F2E)),
        Color(0xFFFFC9EC), Color(0xFFFF8FD4),
    )
    FocusPresentation.Motif.Curve -> Palette(
        listOf(Color(0xFF123C66), Color(0xFF12274F), Color(0xFF0D1430)),
        Color(0xFF9BD8FF), Color(0xFF5BB8F5),
    )
    FocusPresentation.Motif.Staff -> Palette(
        listOf(Color(0xFF5A3410), Color(0xFF35210F), Color(0xFF1C1226)),
        Color(0xFFFFE6B8), Color(0xFFFFC266),
    )
    FocusPresentation.Motif.Grid -> Palette(
        listOf(Color(0xFF1E2A6E), Color(0xFF16205A), Color(0xFF0E1230)),
        Color(0xFFA9BEFF), Color(0xFF7B93FF),
    )
    FocusPresentation.Motif.Orbit -> Palette(
        listOf(Color(0xFF13405A), Color(0xFF14304A), Color(0xFF0C1326)),
        Color(0xFFA8F2D4), Color(0xFF4FD6A8),
    )
}

@Composable
fun CourseArtwork(title: String, modifier: Modifier = Modifier) {
    val motif = FocusPresentation.motifFor(title)
    val palette = paletteFor(motif)

    Canvas(modifier = modifier) {
        drawRect(
            brush = Brush.linearGradient(
                colors = palette.stops,
                start = Offset.Zero,
                end = Offset(size.width, size.height),
            ),
        )

        // One light source in the top-right for every motif, so the set reads
        // as one system rather than six unrelated pictures.
        drawCircle(
            brush = Brush.radialGradient(
                colors = listOf(palette.glow.copy(alpha = 0.38f), Color.Transparent),
                center = Offset(size.width * 0.97f, size.height * 0.1f),
                radius = maxOf(size.width, size.height) * 0.9f,
            ),
            radius = maxOf(size.width, size.height) * 0.9f,
            center = Offset(size.width * 0.97f, size.height * 0.1f),
        )

        when (motif) {
            FocusPresentation.Motif.Lattice -> drawLattice(palette.ink)
            FocusPresentation.Motif.Speech -> drawSpeech(palette.ink)
            FocusPresentation.Motif.Curve -> drawCurve(palette.ink, palette.glow)
            FocusPresentation.Motif.Staff -> drawStaff(palette.ink)
            FocusPresentation.Motif.Grid -> drawGrid(palette.ink)
            FocusPresentation.Motif.Orbit -> drawOrbit(palette.ink)
        }
    }
}

/** Fused six-rings, the way a mechanism is drawn on a board. */
private fun DrawScope.drawLattice(ink: Color) {
    val radius = size.height * 0.17f
    val stepX = radius * 1.5f
    val stepY = radius * 0.866f

    var row = 0
    var y = size.height * 0.26f
    while (y < size.height * 1.05f) {
        var x = if (row % 2 == 0) size.width * 0.14f else size.width * 0.14f + stepX
        while (x < size.width * 1.05f) {
            val path = Path()
            for (corner in 0 until 6) {
                val angle = corner * PI / 3 - PI / 6
                val px = x + radius * cos(angle).toFloat()
                val py = y + radius * sin(angle).toFloat()
                if (corner == 0) path.moveTo(px, py) else path.lineTo(px, py)
            }
            path.close()
            drawPath(path, color = ink.copy(alpha = 0.34f), style = Stroke(width = 1.4f))
            drawCircle(ink.copy(alpha = 0.5f), radius = 2.6f, center = Offset(x, y))
            x += stepX * 2
        }
        y += stepY * 2
        row += 1
    }
}

/** Speech radiating from the bottom-left, with a short waveform beside it. */
private fun DrawScope.drawSpeech(ink: Color) {
    val origin = Offset(size.width * 0.1f, size.height * 0.94f)
    var radius = size.height * 0.16f
    while (radius < size.height * 1.5f) {
        drawCircle(
            color = ink.copy(alpha = maxOf(0.3f - radius / (size.height * 6f), 0.05f)),
            radius = radius,
            center = origin,
            style = Stroke(width = 1.3f),
        )
        radius += size.height * 0.145f
    }

    val heights = listOf(0.08f, 0.2f, 0.12f, 0.3f, 0.17f, 0.38f, 0.22f, 0.14f, 0.32f, 0.18f)
    heights.forEachIndexed { index, factor ->
        val barHeight = size.height * factor
        drawRoundRectBar(
            x = size.width * 0.54f + index * size.width * 0.042f,
            y = size.height * 0.68f - barHeight / 2,
            width = 3.4f,
            height = barHeight,
            color = ink.copy(alpha = 0.46f),
        )
    }
}

private fun DrawScope.drawRoundRectBar(x: Float, y: Float, width: Float, height: Float, color: Color) {
    drawRoundRect(
        color = color,
        topLeft = Offset(x, y),
        size = Size(width, height),
        cornerRadius = CornerRadius(width / 2, width / 2),
    )
}

/** A distribution with its scatter sitting on the curve, not beside it. */
private fun DrawScope.drawCurve(ink: Color, glow: Color) {
    val baseline = size.height * 0.8f
    val peak = size.height * 0.2f
    val left = size.width * 0.02f
    val right = size.width * 0.98f
    val mid = (left + right) / 2

    val curve = Path().apply {
        moveTo(left, baseline)
        cubicTo(
            left + (mid - left) * 0.52f, baseline,
            mid - (mid - left) * 0.42f, peak,
            mid, peak,
        )
        cubicTo(
            mid + (right - mid) * 0.42f, peak,
            right - (right - mid) * 0.52f, baseline,
            right, baseline,
        )
    }

    val filled = Path().apply {
        addPath(curve)
        lineTo(left, baseline)
        close()
    }
    drawPath(
        filled,
        brush = Brush.verticalGradient(
            colors = listOf(glow.copy(alpha = 0.42f), Color.Transparent),
            startY = peak,
            endY = baseline,
        ),
    )
    drawPath(curve, color = ink.copy(alpha = 0.75f), style = Stroke(width = 2f))
    drawLine(ink.copy(alpha = 0.3f), Offset(left, baseline), Offset(right, baseline), strokeWidth = 1.4f)

    var tick = left + size.width * 0.08f
    while (tick < right) {
        drawLine(
            ink.copy(alpha = 0.28f),
            Offset(tick, baseline),
            Offset(tick, baseline + size.height * 0.035f),
            strokeWidth = 1.2f,
        )
        tick += size.width * 0.09f
    }

    for (step in 1 until 10) {
        val t = step / 10f
        val px = left + (right - left) * t
        val normalised = (px - mid) / ((right - left) * 0.3f)
        val py = baseline - (baseline - peak) * exp(-0.5f * normalised * normalised)
        drawCircle(ink.copy(alpha = 0.75f), radius = 2.6f, center = Offset(px, py))
    }
}

/** Five staves with noteheads on lines and in spaces. */
private fun DrawScope.drawStaff(ink: Color) {
    val top = size.height * 0.3f
    val spacing = size.height * 0.1f
    for (line in 0 until 5) {
        val y = top + line * spacing
        drawLine(ink.copy(alpha = 0.3f), Offset(size.width * 0.04f, y), Offset(size.width * 0.96f, y), strokeWidth = 1.3f)
    }

    val steps = listOf(2f, 0.5f, 3f, 1.5f, 4f, 2.5f, 1f, 3.5f)
    steps.forEachIndexed { index, step ->
        val cx = size.width * 0.12f + index * size.width * 0.112f
        val cy = top + step * spacing
        rotate(degrees = -18f, pivot = Offset(cx, cy)) {
            drawOval(
                color = ink.copy(alpha = 0.55f),
                topLeft = Offset(cx - 7.5f, cy - 5.2f),
                size = Size(15f, 10.4f),
            )
        }
    }
}

/** Axes with a vector triangle over them. */
private fun DrawScope.drawGrid(ink: Color) {
    var x = size.width * 0.06f
    while (x < size.width) {
        drawLine(ink.copy(alpha = 0.16f), Offset(x, 0f), Offset(x, size.height), strokeWidth = 1f)
        x += size.width * 0.1f
    }
    var y = size.height * 0.08f
    while (y < size.height) {
        drawLine(ink.copy(alpha = 0.16f), Offset(0f, y), Offset(size.width, y), strokeWidth = 1f)
        y += size.height * 0.16f
    }

    val a = Offset(size.width * 0.15f, size.height * 0.82f)
    val b = Offset(size.width * 0.54f, size.height * 0.26f)
    val c = Offset(size.width * 0.62f, size.height * 0.9f)
    val triangle = Path().apply {
        moveTo(a.x, a.y)
        lineTo(b.x, b.y)
        lineTo(c.x, c.y)
        close()
    }
    drawPath(triangle, color = ink.copy(alpha = 0.12f))
    drawPath(triangle, color = ink.copy(alpha = 0.58f), style = Stroke(width = 2f))
    for (point in listOf(a, b, c)) {
        drawCircle(ink.copy(alpha = 0.8f), radius = 3f, center = point)
    }
}

/** Concentric paths with a body on each — the general-purpose motif. */
private fun DrawScope.drawOrbit(ink: Color) {
    val centre = Offset(size.width * 0.72f, size.height * 0.52f)
    var radius = size.height * 0.16f
    var index = 0
    while (radius < size.height * 0.9f) {
        drawOval(
            color = ink.copy(alpha = 0.26f),
            topLeft = Offset(centre.x - radius * 1.35f, centre.y - radius),
            size = Size(radius * 2.7f, radius * 2f),
            style = Stroke(width = 1.3f),
        )
        val angle = index * 1.9
        drawCircle(
            ink.copy(alpha = 0.7f),
            radius = 3.4f,
            center = Offset(
                centre.x + radius * 1.35f * cos(angle).toFloat(),
                centre.y + radius * sin(angle).toFloat(),
            ),
        )
        radius += size.height * 0.19f
        index += 1
    }
}
