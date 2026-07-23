package com.lyo.app.data.api

import com.google.gson.JsonObject
import com.google.gson.annotations.SerializedName
import com.lyo.app.BuildConfig
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.HttpUrl.Companion.toHttpUrl

/** Canonical progress response shared with iOS and web. */
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
    val currentLessonIdStr: String?
        get() = currentLessonId?.toString()?.removeSuffix(".0")

    val normalizedProgress: Float
        get() {
            val value = if (progressPercent > 1.0) progressPercent / 100.0 else progressPercent
            return value.coerceIn(0.0, 1.0).toFloat()
        }
}

data class LessonCompletionDto(
    val id: Any? = null,
    @SerializedName("lesson_id") val lessonId: Any? = null,
    @SerializedName("completed_at") val completedAt: String? = null,
    val score: Int? = null,
    @SerializedName("xp_awarded") val xpAwarded: Int = 0,
)

/**
 * Small authenticated client for learning progress endpoints.
 *
 * It reuses [ApiClient.okHttp], so bearer injection and the existing refresh-token
 * authenticator remain identical to every other Android API call.
 */
object LearningProgressClient {
    private val jsonMediaType = "application/json; charset=utf-8".toMediaType()

    suspend fun getCourseProgress(courseId: String): CourseProgressDto = withContext(Dispatchers.IO) {
        val url = BuildConfig.API_BASE_URL.toHttpUrl().newBuilder()
            .addPathSegments("learning/users/me/courses")
            .addPathSegment(courseId)
            .addPathSegment("progress")
            .build()
        execute(
            Request.Builder()
                .url(url)
                .get()
                .build(),
        )
    }

    suspend fun markLessonComplete(lessonId: String, score: Int? = null): LessonCompletionDto =
        withContext(Dispatchers.IO) {
            val payload = JsonObject().apply {
                addProperty("lesson_id", lessonId)
                score?.let { addProperty("score", it) }
            }
            val request = Request.Builder()
                .url(BuildConfig.API_BASE_URL.toHttpUrl().newBuilder().addPathSegments("learning/completions").build())
                .post(ApiClient.gson.toJson(payload).toRequestBody(jsonMediaType))
                .build()
            execute(request)
        }

    private inline fun <reified T> execute(request: Request): T {
        ApiClient.okHttp.newCall(request).execute().use { response ->
            val rawBody = response.body?.string().orEmpty()
            if (!response.isSuccessful) {
                val message = runCatching {
                    val payload = ApiClient.gson.fromJson(rawBody, JsonObject::class.java)
                    payload.get("detail")?.asString
                        ?: payload.get("message")?.asString
                }.getOrNull()
                    ?: when (response.code) {
                        401 -> "Your session expired. Sign in again to save progress."
                        else -> "Unable to save learning progress."
                    }
                throw LearningProgressException(response.code, message)
            }
            if (rawBody.isBlank()) {
                throw LearningProgressException(response.code, "The learning service returned an empty response.")
            }
            return ApiClient.gson.fromJson(rawBody, T::class.java)
        }
    }
}

class LearningProgressException(
    val statusCode: Int,
    override val message: String,
) : Exception(message)
