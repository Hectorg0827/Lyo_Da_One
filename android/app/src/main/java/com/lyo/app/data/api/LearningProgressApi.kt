package com.lyo.app.data.api

import com.google.gson.annotations.SerializedName
import retrofit2.http.Body
import retrofit2.http.GET
import retrofit2.http.POST
import retrofit2.http.Path

/**
 * Canonical cross-device learning-progress contract.
 * Mirrors web/src/lib/learning-progress.ts and the iOS CourseProgress model.
 */
interface LearningProgressApiService {
    @GET("learning/users/me/courses/{courseId}/progress")
    suspend fun courseProgress(
        @Path("courseId") courseId: String,
    ): CourseProgressResponse

    @POST("learning/completions")
    suspend fun markLessonComplete(
        @Body body: LessonCompletionRequest,
    ): LessonCompletionResponse
}

data class LessonCompletionRequest(
    @SerializedName("lesson_id") val lessonId: String,
    val score: Int? = null,
)

data class LessonCompletionResponse(
    val id: String? = null,
    @SerializedName("lesson_id") val lessonId: Any? = null,
    @SerializedName("completed_at") val completedAt: String? = null,
    val score: Int? = null,
    @SerializedName("xp_awarded") val xpAwarded: Int? = null,
)

data class CourseProgressResponse(
    @SerializedName("course_id") val courseId: Any? = null,
    @SerializedName("user_id") val userId: Any? = null,
    @SerializedName("total_lessons") val totalLessons: Int = 0,
    @SerializedName("completed_lessons") val completedLessons: Int = 0,
    @SerializedName("progress_percent") val progressPercent: Double = 0.0,
    @SerializedName("current_lesson_id") val currentLessonId: Any? = null,
    @SerializedName("last_accessed_at") val lastAccessedAt: String? = null,
    @SerializedName("estimated_time_remaining") val estimatedTimeRemaining: Int? = null,
) {
    val normalizedPercent: Int
        get() {
            val percent = if (progressPercent > 1.0) progressPercent else progressPercent * 100.0
            return percent.coerceIn(0.0, 100.0).toInt()
        }

    val currentLessonIdString: String?
        get() = currentLessonId?.toString()?.removeSuffix(".0")?.takeIf { it.isNotBlank() }
}
