package com.lyo.app.data.api

import retrofit2.http.*

data class PrepMaterial(val name: String, val uri: String, val modality: String, val mime_type: String)
data class PrepTopic(val name: String, val weight: Double = 1.0, val confidence: Int = 5)
data class PrepTurn(val role: String, val content: String)
data class PrepProfile(
    val id: String, val subject: String, val test_date: String, val topics: List<PrepTopic>,
    val daily_minutes_available: Int, val study_days_per_week: Int,
    val materials: List<PrepMaterial>, val intake_complete: Boolean, val intake_transcript: List<PrepTurn>,
)
data class PrepMilestone(val week: Int, val focus: String)
data class PrepPlan(val id: String, val status: String, val weekly_milestones: List<PrepMilestone>)
data class PrepSession(
    val id: String, val topic: String, val scheduled_at: String, val duration_minutes: Int,
    val session_type: String, val status: String, val concept_id: String,
)
data class PrepSnapshot(val profile: PrepProfile?, val plan: PrepPlan?, val timezone: String,
    val revision: Int, val sessions: List<PrepSession>)
data class PrepIntake(val user_message: String, val test_profile_id: String?, val request_id: String,
    val timezone: String = java.time.ZoneId.systemDefault().id, val materials: List<PrepMaterial> = emptyList())
data class PrepReply(val test_profile_id: String, val message_to_user: String, val intake_complete: Boolean)
data class PrepStanding(val topic: String, val mastery: Double?, val attempts: Int)
data class PrepReadiness(val topics_assessed: Int, val readiness: Double?, val days_remaining: Int?,
    val topics: List<PrepStanding>, val focus_next: List<String>)
data class PrepOutcome(val performance_score: Double?, val graded: Int, val seen: Int)
data class PrepEdit(val expected_revision: Int, val subject: String? = null, val test_date: String? = null,
    val topics: List<PrepTopic>? = null, val daily_minutes_available: Int? = null,
    val study_days_per_week: Int? = null, val timezone: String? = null,
    val materials: List<PrepMaterial>? = null)
data class PrepEdited(val needs_plan: Boolean)

interface TestPrepApi {
    @GET("api/v1/me/study_plans/state") suspend fun state(): PrepSnapshot
    @POST("api/v1/me/study_plans/intake/turn") suspend fun intake(@Body body: PrepIntake): PrepReply
    @POST("api/v1/me/study_plans/plans/generate") suspend fun generate(@Query("test_profile_id") id: String): Map<String, Any>
    @GET("api/v1/me/study_plans/plans/{id}/readiness") suspend fun readiness(@Path("id") id: String): PrepReadiness
    @PATCH("api/v1/me/study_plans/profiles/{id}") suspend fun edit(@Path("id") id: String, @Body body: PrepEdit): PrepEdited
    @POST("api/v1/me/study_plans/sessions/{id}/complete") suspend fun complete(@Path("id") id: String): PrepOutcome
}
