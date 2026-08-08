package com.lyo.app.ui.classroom.catalog

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.LinearOutSlowInEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.graphicsLayer
import com.lyo.app.R
import com.lyo.app.ui.theme.ClassroomTokens
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive

/**
 * The 9 canonical `lyoState` values from the director-turn wire contract
 * (see data.classroom.DirectorTurn.lyo_state / .state), treated as the
 * source of truth for mascot animation because it's the only
 * implementation actually wired end-to-end to the backend's turn stream —
 * iOS decodes an equivalent field but never consumes it anywhere (verified
 * by full-repo grep during this feature's design pass). Ported from
 * web/src/app/(main)/classroom/page.tsx's LYO_STATE_IMG/LYO_ANIMATED_STATES.
 */
private val ANIMATED_STATES = setOf(
    "reading", "thinking", "curious", "surprised", "confused", "shy", "sleeping",
)

/** One 4-frame "reading" flip-book, reused across every animated state (the
 *  web reference also collapses several distinct states onto this same
 *  4-frame set rather than shipping bespoke art per state). */
private val READING_FRAMES = intArrayOf(
    R.drawable.mascot_reading_1,
    R.drawable.mascot_reading_2,
    R.drawable.mascot_reading_3,
    R.drawable.mascot_reading_4,
)

private const val STANDING_FRAME = R.drawable.mascot_standing

/**
 * Drives one mascot's current drawable resource + a breathing/bounce
 * `Modifier` for idle states. `variant` distinguishes Lyo (state-animated)
 * from the Teacher/student badges (always a single static frame, no
 * lyoState-driven cycling) while sharing the same breathing-idle treatment.
 */
data class MascotFrame(val drawableRes: Int, val modifier: Modifier)

@Composable
fun rememberMascotFrame(state: String, variant: String = "lyo"): MascotFrame {
    if (variant != "lyo") {
        // Teacher/student badges: a single static frame with a gentle
        // breathing scale, never the reading flip-book — their `state`
        // input is unused.
        return MascotFrame(STANDING_FRAME, rememberBreathingModifier())
    }

    val normalizedState = if (state in ANIMATED_STATES || state == "listening" || state == "celebrating") state else "reading"
    var frameIndex by remember(normalizedState) { mutableIntStateOf(0) }

    if (normalizedState in ANIMATED_STATES) {
        LaunchedEffect(normalizedState) {
            frameIndex = 0
            while (isActive) {
                delay(ClassroomTokens.MASCOT_FRAME_MS)
                frameIndex = (frameIndex + 1) % READING_FRAMES.size
            }
        }
        return MascotFrame(READING_FRAMES[frameIndex], Modifier)
    }

    // Idle states (listening, celebrating): a single static frame — the
    // reading pose family is close enough to a resting frame that no
    // separate "idle" art asset is needed, matching web's fallback of
    // reusing mascot_reading_1 for states outside its animated set.
    val breathing = rememberBreathingModifier()
    if (normalizedState == "celebrating") {
        // A one-shot bounce/wiggle on entering the state, not a loop —
        // web's equivalent transform is {scale:[1,1.25,1], rotate:[0,10,-10,0], y:[0,-10,0]}.
        val bounce = remember { Animatable(0f) }
        LaunchedEffect(Unit) {
            bounce.animateTo(
                1f,
                animationSpec = spring(dampingRatio = Spring.DampingRatioMediumBouncy),
            )
        }
        return MascotFrame(
            READING_FRAMES[0],
            breathing.graphicsLayer {
                translationY = -12f * bounce.value * (1f - bounce.value) * 4f
                rotationZ = 8f * bounce.value * (1f - bounce.value) * 4f
            },
        )
    }
    return MascotFrame(READING_FRAMES[0], breathing)
}

@Composable
private fun rememberBreathingModifier(): Modifier {
    val transition = rememberInfiniteTransition(label = "mascot-breathing")
    val scale by transition.animateFloat(
        initialValue = 1f,
        targetValue = 1.03f,
        animationSpec = infiniteRepeatable(
            animation = tween(1800, easing = LinearOutSlowInEasing),
            repeatMode = RepeatMode.Reverse,
        ),
        label = "mascot-breathing-scale",
    )
    return Modifier.graphicsLayer { scaleX = scale; scaleY = scale }
}
