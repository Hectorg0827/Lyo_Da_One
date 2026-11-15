package com.lyo.app.ui.screens.classroom

/**
 * A learner should hear one recognizable teacher throughout an active lesson,
 * even if an incoming turn uses a different teacher alias. Real student and
 * companion voices remain separate because they represent distinct speakers.
 *
 * The policy is scoped to one ClassroomVoicePlayer (one Classroom session).
 */
internal data class ClassroomVoiceIdentity(val speakerId: String, val voice: String)

internal class ClassroomTeacherVoicePolicy {
    private var selectedTeacher: ClassroomVoiceIdentity? = null

    fun resolve(speakerId: String, requestedVoice: String): ClassroomVoiceIdentity {
        if (!speakerId.matches(Regex("""teacher_\d+"""))) {
            return ClassroomVoiceIdentity(speakerId, requestedVoice)
        }
        val initial = selectedTeacher
        if (initial != null) return initial
        return ClassroomVoiceIdentity(speakerId, requestedVoice).also {
            selectedTeacher = it
        }
    }
}
