package com.lyo.app.ui.classroom

/**
 * Actors are useful teaching cues, not permanent chrome. This policy is kept
 * free of Compose so each context can be tested without an Android device.
 * A prompt gives the entire screen back to the learner; the teacher returns
 * when speaking, and Lyo returns for support or a brief celebration.
 */
data class ClassroomPresence(
    val teacher: Boolean,
    val companion: Boolean,
    val caption: Boolean,
)

object ClassroomPresencePolicy {
    fun decide(
        speaker: String?,
        learnerWorking: Boolean,
        paused: Boolean,
        supportCue: Boolean,
        celebrationCue: Boolean,
        captionsEnabled: Boolean,
    ): ClassroomPresence {
        val speaking = !speaker.isNullOrBlank() && !paused
        val companionSpeaking = speaker?.equals("lyo", ignoreCase = true) == true ||
            speaker?.equals("companion", ignoreCase = true) == true
        // A spoken prompt stays on-screen through its audio even when the
        // student's checkpoint has technically opened. Once audio ends,
        // both rows collapse and learner work owns the canvas.
        val teacher = speaking && !companionSpeaking
        val companion = (companionSpeaking && speaking) || supportCue || celebrationCue
        return ClassroomPresence(
            teacher = teacher,
            companion = companion,
            caption = captionsEnabled && speaking,
        )
    }
}

object ClassroomLessonDuration {
    val choices = listOf(15, 30, 45)
    const val default = 30
    fun normalize(minutes: Int) = minutes.takeIf { it in choices } ?: default
}
