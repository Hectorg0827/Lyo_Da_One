package com.lyo.app.data.api

import retrofit2.http.Body
import retrofit2.http.GET
import retrofit2.http.POST
import retrofit2.http.Path

/**
 * Focused Retrofit surface for authenticated learning progress.
 * Keeping this separate prevents the general API interface from becoming the
 * only place every learning workflow can evolve.
 */
interface LearningApiService {
    @POST("learning/completions")
    suspend fun markLessonComplete(
        @Body body: LessonCompletionRequest,
    ): LessonCompletionResponse

    @GET("learning/users/me/courses/{courseId}/progress")
    suspend fun courseProgress(
        @Path("courseId") courseId: String,
    ): CourseProgressDto
}
