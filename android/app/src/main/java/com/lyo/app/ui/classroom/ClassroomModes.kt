package com.lyo.app.ui.classroom

/**
 * Visual modes share the same live session and server-owned progress.
 *
 * Review is a user-selected quiet, read-only study presentation. A real
 * network stall/lesson recovery is a separate automatic state, never a fake
 * error screen shown merely because Review was selected.
 */
enum class ClassroomDisplayMode(val label: String, val description: String) {
    SOLO("Focus", "Practice independently, with hints and Lyo nearby"),
    CLASSROOM("Live Class", "Teacher-led lesson and real classmate participation"),
    REVIEW("Review & Resume", "Revisit completed steps and return to the live lesson");

    companion object {
        fun fromTeachingMode(value: String): ClassroomDisplayMode =
            when (value.lowercase()) {
                "classroom", "group", "multi" -> CLASSROOM
                "review" -> REVIEW
                else -> SOLO
            }
    }

    fun backendModeWhenStarting(): String = if (this == CLASSROOM) "classroom" else "solo"
}
