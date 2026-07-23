package com.lyo.app.data.api

import com.google.gson.annotations.SerializedName

/**
 * Canonical learning-progress contracts shared with the web and iOS clients.
 * IDs remain flexible because the backend may serialize database identifiers as
 * either numbers or strings during migration periods.
 */
data class LessonCompletionRequest(
    @SerializedName("lesson_id") val lessonId: String,
    val score: Int? = null,
)

data class LessonCompletionResponse(
    val id: Any? = null,
    @SerializedName("lesson_id") val lessonId: Any? = null,
    @SerializedName("completed_at") val completedAt: String? = null,
    val score: Int? = null,
    @SerializedName("xp_awarded") val xpAwarded: Int? = null,
)

data class CourseProgressDto(
    @SerializedName("course_id") val courseId: Any? = null,
    @SerializedName("user_id") val userId: Any? = null,
    @SerializedName("total_lessons") val totalLessons: Int = 0,
    @SerializedName("completed_lessons") val completedLessons: Int = 0,
    @SerializedName("progress_percent") val progressPercent: Double = 0.0,
    @SerializedName("current_lesson_id") val currentLessonId: Any? = null,
    @SerializedName("last_accessed_at") val lastAccessedAt: String? = null,
    @SerializedName("estimated_time_remaining") val estimatedTimeRemaining: Int? = null,
) {
    val currentLessonIdString: String?
        get() = currentLessonId?.toString()?.removeSuffix(".0")

    val normalizedPercent: Int
        get() {
            val percent = if (progressPercent > 1.0) progressPercent else progressPercent * 100.0
            return percent.toInt().coerceIn(0, 100)
        }
}
