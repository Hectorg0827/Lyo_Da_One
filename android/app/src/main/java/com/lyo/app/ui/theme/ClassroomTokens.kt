package com.lyo.app.ui.theme

import androidx.compose.animation.core.CubicBezierEasing
import androidx.compose.animation.core.Easing
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color

/**
 * Classroom-specific extension of Theme.kt's base tokens, mirroring iOS's
 * ClassroomTokens.swift (an extension of the shared DesignTokens.swift, not
 * a standalone palette) and pulling the spacing/radius/shadow/motion/
 * gradient values from /design-tokens.json that Theme.kt doesn't yet mirror
 * (Theme.kt only carries flat colors + typography, which is enough for the
 * rest of the app's plain Material screens, but the classroom's chalk
 * highlight glow / mascot halo / chip spring-motion need more).
 *
 * As with Theme.kt: do not hand-edit these values independently — update
 * design-tokens.json and mirror the change here.
 */
object ClassroomTokens {

    // color.brand.accentGold — the chalk-highlight / "cold call" color,
    // reused from web's `text-accent-gold` and iOS's ClassroomTokens.accent
    // family for the chip/highlight/hand-raise treatments.
    val Gold = Color(0xFFD9B24C)
    val GoldGlow = Color(0x66D9B24C) // shadow.glow

    // color.brand.secondary / color.gradients.accent — the purple/magenta
    // pairing used for the mascot halo and primary CTA gradient.
    val AccentPurple = Color(0xFF8B5CF6)
    val AccentMagenta = Color(0xFFD946EF)
    val AccentGlow = Color(0x808B5CF6) // shadow.accentGlow
    val AccentGradient = Brush.horizontalGradient(listOf(AccentPurple, AccentMagenta))

    // color.surface.backgroundDeep — the chalkboard's own background, a
    // radial-feeling 3-stop gradient (approximated as linear on Android;
    // Compose has no true CSS-style radial-at-top primitive without a
    // custom Brush.radialGradient anchored off-canvas, which is overkill
    // here — the 3-stop linear reads close enough to the web reference).
    val BoardBackground = Brush.verticalGradient(
        listOf(Color(0xFF17203F), Color(0xFF0D142E), Color(0xFF0A0F24)),
    )
    val BoardBorder = Color(0xFF3A3323) // the chalk-tray brown

    // spacing.* (design-tokens.json)
    object Spacing {
        val xxxs = 2
        val xxs = 4
        val xs = 8
        val sm = 12
        val md = 16
        val lg = 24
        val xl = 32
        val xxl = 48
        val xxxl = 64
    }

    // radius.*
    object Radius {
        val xs = 4
        val sm = 8
        val md = 12
        val lg = 16
        val xl = 20
        val xxl = 24
        val full = 9999
    }

    // motion.* — durations in ms; `spring`/`springBouncy` response+damping
    // map to Compose's spring(dampingRatio=, stiffness=) rather than a
    // literal response/damping pair (SwiftUI-specific spring parameters),
    // so these are Compose-idiomatic equivalents tuned to feel the same,
    // not a mechanical unit conversion.
    object Motion {
        const val QUICK_MS = 200
        const val STANDARD_MS = 300
        const val SLOW_MS = 500
        val standardEasing: Easing = CubicBezierEasing(0.4f, 0f, 0.2f, 1f) // easeInOut
        val quickEasing: Easing = CubicBezierEasing(0f, 0f, 0.2f, 1f) // easeOut
    }

    /** The 200ms mascot flip-book frame cycle (see MascotAnimator.kt) — kept
     *  here rather than under Motion since it's a classroom-specific
     *  animation rule, not a general design-token duration. */
    const val MASCOT_FRAME_MS = 200L

    /** Chrome auto-hide idle timeout (Netflix/YouTube-style), matching the
     *  3s already shipped on web (page.tsx resetHideTimer) and iOS
     *  (ActiveLessonView.swift resetChromeTimer). */
    const val CHROME_AUTO_HIDE_MS = 3_000L
}
