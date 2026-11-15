package com.lyo.app.ui.screens.classroom

/**
 * Source-selection contract for one Classroom lesson. It is deliberately
 * independent of Android's TTS engine so the no-voice-switch rule is testable.
 */
internal enum class ClassroomVoiceRoute { UNDECIDED, SHARED, DEVICE }

internal class ClassroomVoiceRoutePolicy {
    var route: ClassroomVoiceRoute = ClassroomVoiceRoute.UNDECIDED
        private set

    val useDevice: Boolean get() = route == ClassroomVoiceRoute.DEVICE

    fun sharedPlaybackBegan() {
        route = ClassroomVoiceRoute.SHARED
    }

    /**
     * True only when device speech is allowed. Before any shared teacher
     * audio it is a stable lesson-wide fallback. After shared playback
     * begins, fail to readable captions instead of swapping narrator.
     */
    fun sharedSpeechFailed(): Boolean =
        when (route) {
            ClassroomVoiceRoute.UNDECIDED -> {
                route = ClassroomVoiceRoute.DEVICE
                true
            }
            ClassroomVoiceRoute.DEVICE -> true
            ClassroomVoiceRoute.SHARED -> false
        }
}
