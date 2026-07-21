package com.lyo.app.data.api

import com.google.gson.JsonArray
import com.google.gson.JsonObject
import okhttp3.MultipartBody
import okhttp3.RequestBody
import retrofit2.Response
import retrofit2.http.Body
import retrofit2.http.DELETE
import retrofit2.http.GET
import retrofit2.http.Multipart
import retrofit2.http.POST
import retrofit2.http.PUT
import retrofit2.http.Part
import retrofit2.http.Path
import retrofit2.http.Query

/**
 * Retrofit surface for the LYO backend (api.lyoai.app).
 * Mirrors web/src/lib/api.ts endpoint-for-endpoint.
 */
interface LyoApiService {

    // ── Auth ──
    @POST("auth/login")
    suspend fun login(@Body body: LoginRequest): AuthResponse

    @POST("auth/register")
    suspend fun register(@Body body: RegisterRequest): AuthResponse

    @GET("auth/me")
    suspend fun me(): UserDto

    @PUT("auth/profile")
    suspend fun updateProfile(@Body body: UpdateProfileRequest): UserDto

    @POST("auth/logout")
    suspend fun logout(): JsonObject

    @GET("auth/users/{userId}")
    suspend fun getUser(@Path("userId") userId: String): UserDto

    // ── Feed ──
    @GET("feed")
    suspend fun feed(
        @Query("page") page: Int = 1,
        @Query("per_page") perPage: Int = 20,
    ): PostsResponse

    @GET("feed/public")
    suspend fun publicFeed(
        @Query("page") page: Int = 1,
        @Query("per_page") perPage: Int = 20,
    ): PostsResponse

    @GET("posts/{postId}")
    suspend fun getPost(@Path("postId") postId: String): JsonObject

    @POST("posts")
    suspend fun createPost(@Body body: CreatePostRequest): JsonObject

    @POST("posts/{postId}/reactions")
    suspend fun reactToPost(
        @Path("postId") postId: String,
        @Body body: ReactionRequest,
    ): JsonObject

    @POST("comments")
    suspend fun createComment(@Body body: CommentRequest): JsonObject

    // ── Users / social ──
    @GET("users/{userId}/posts")
    suspend fun userPosts(
        @Path("userId") userId: String,
        @Query("page") page: Int = 1,
    ): PostsResponse

    @POST("follow")
    suspend fun follow(@Body body: FollowRequest): JsonObject

    @DELETE("follow/{userId}")
    suspend fun unfollow(@Path("userId") userId: String): JsonObject

    // ── Courses ──
    @GET("api/v1/learning/courses")
    suspend fun courses(
        @Query("skip") skip: Int = 0,
        @Query("limit") limit: Int = 20,
        @Query("subject") subject: String? = null,
        @Query("difficulty") difficulty: String? = null,
    ): List<CourseDto>

    @GET("api/v1/learning/courses/{courseId}")
    suspend fun course(@Path("courseId") courseId: String): CourseDto

    @POST("api/v1/learning/courses/generate")
    suspend fun generateCourse(@Body body: GenerateCourseRequest): JsonObject

    // ── Clips ── (same /api/v1 paths as web api.ts and iOS Endpoints)
    @GET("api/v1/clips")
    suspend fun clips(
        @Query("page") page: Int = 1,
        @Query("per_page") perPage: Int = 20,
    ): ClipsResponse

    @GET("api/v1/clips/discover")
    suspend fun discoverClips(
        @Query("page") page: Int = 1,
        @Query("per_page") perPage: Int = 20,
        @Query("subject") subject: String? = null,
    ): ClipsResponse

    @POST("api/v1/clips/{clipId}/like")
    suspend fun likeClip(@Path("clipId") clipId: String): JsonObject

    @POST("api/v1/clips/{clipId}/save")
    suspend fun saveClip(@Path("clipId") clipId: String): JsonObject

    @POST("api/v1/clips/{clipId}/view")
    suspend fun viewClip(@Path("clipId") clipId: String): JsonObject

    @POST("api/v1/clips/{clipId}/share")
    suspend fun shareClip(@Path("clipId") clipId: String): JsonObject

    @GET("api/v1/clips/saved")
    suspend fun savedClips(
        @Query("page") page: Int = 1,
        @Query("per_page") perPage: Int = 20,
    ): ClipsResponse

    @POST("api/v1/clips")
    suspend fun createClip(@Body body: ClipCreateRequest): ClipCreateResponse

    @GET("api/v1/clips/{clipId}/comments")
    suspend fun clipComments(
        @Path("clipId") clipId: String,
        @Query("page") page: Int = 1,
        @Query("per_page") perPage: Int = 50,
    ): ClipCommentsResponse

    @POST("api/v1/clips/{clipId}/comments")
    suspend fun createClipComment(
        @Path("clipId") clipId: String,
        @Body body: CommunityCommentRequest,
    ): ClipCommentDto

    @DELETE("api/v1/clips/{clipId}/comments/{commentId}")
    suspend fun deleteClipComment(
        @Path("clipId") clipId: String,
        @Path("commentId") commentId: String,
    ): Response<Unit>

    // ── Media upload (multipart; reel videos + images) ──
    @Multipart
    @POST("api/v1/media/upload")
    suspend fun uploadMedia(
        @Part file: MultipartBody.Part,
        @Part("folder") folder: RequestBody,
    ): MediaUploadResponse

    // ── Stories ── (same /api/v1 paths as web api.ts)
    @GET("api/v1/stories")
    suspend fun stories(): StoriesResponse

    @POST("api/v1/stories/{storyId}/seen")
    suspend fun markStorySeen(@Path("storyId") storyId: String): JsonObject

    // ── Gamification ──
    @GET("gamification/overview")
    suspend fun gamificationOverview(): JsonObject

    @GET("gamification/my-achievements")
    suspend fun achievements(
        @Query("completed_only") completedOnly: Boolean = false,
    ): JsonArray

    @GET("gamification/leaderboards/{type}")
    suspend fun leaderboard(
        @Path("type") type: String = "xp",
        @Query("period") period: String = "weekly",
        @Query("limit") limit: Int = 20,
    ): JsonObject

    // ── Community ── (study-groups routes, matching web api.ts and iOS)
    @GET("community/study-groups")
    suspend fun groups(): List<GroupDto>

    @POST("community/study-groups")
    suspend fun createStudyGroup(@Body body: CreateStudyGroupRequest): GroupDto

    @POST("community/study-groups/{groupId}/join")
    suspend fun joinGroup(@Path("groupId") groupId: String): JsonObject

    @DELETE("community/study-groups/{groupId}/leave")
    suspend fun leaveGroup(@Path("groupId") groupId: String): Response<Unit>

    @GET("community/events")
    suspend fun events(): List<EventDto>

    @POST("community/events")
    suspend fun createCommunityEvent(@Body body: CreateCommunityEventRequest): EventDto

    @POST("community/events/{eventId}/attend")
    suspend fun attendEvent(@Path("eventId") eventId: String): JsonObject

    @DELETE("community/events/{eventId}/attend")
    suspend fun unattendEvent(@Path("eventId") eventId: String): Response<Unit>

    // Community posts — the same store iOS renders (community/posts),
    // NOT the separate /feed store; one account, one feed everywhere.
    @GET("community/posts")
    suspend fun communityPosts(
        @Query("page") page: Int = 1,
        @Query("limit") limit: Int = 20,
    ): CommunityPostsResponse

    @GET("community/posts/{postId}")
    suspend fun communityPost(@Path("postId") postId: String): CommunityPostDto

    @POST("community/posts")
    suspend fun createCommunityPost(@Body body: CommunityCreatePostRequest): CommunityPostDto

    @POST("community/posts/{postId}/like")
    suspend fun toggleCommunityPostLike(@Path("postId") postId: String): LikeToggleResponse

    @POST("community/posts/{postId}/bookmark")
    suspend fun toggleCommunityPostBookmark(@Path("postId") postId: String): JsonObject

    @GET("community/posts/{postId}/comments")
    suspend fun communityComments(
        @Path("postId") postId: String,
        @Query("page") page: Int = 1,
        @Query("limit") limit: Int = 50,
    ): CommunityCommentsResponse

    @POST("community/posts/{postId}/comments")
    suspend fun createCommunityComment(
        @Path("postId") postId: String,
        @Body body: CommunityCommentRequest,
    ): CommunityCommentDto

    @POST("community/posts/{postId}/comments/{commentId}/like")
    suspend fun toggleCommunityCommentLike(
        @Path("postId") postId: String,
        @Path("commentId") commentId: String,
    ): LikeToggleResponse

    @DELETE("community/posts/{postId}/comments/{commentId}")
    suspend fun deleteCommunityComment(
        @Path("postId") postId: String,
        @Path("commentId") commentId: String,
    ): Response<Unit>

    // ── Messages ──
    @GET("messages/conversations")
    suspend fun conversations(): ConversationsResponse

    @GET("messages/conversations/{conversationId}")
    suspend fun messages(
        @Path("conversationId") conversationId: String,
        @Query("page") page: Int = 1,
        @Query("per_page") perPage: Int = 50,
    ): MessagesResponse

    @POST("messages/conversations")
    suspend fun createConversation(@Body body: CreateConversationRequest): ConversationDto

    @POST("messages/conversations/{conversationId}/messages")
    suspend fun sendMessage(
        @Path("conversationId") conversationId: String,
        @Body body: SendMessageRequest,
    ): MessageDto

    @POST("messages/conversations/{conversationId}/read")
    suspend fun markConversationRead(@Path("conversationId") conversationId: String): JsonObject

    // ── Notifications ──
    @GET("notifications")
    suspend fun notifications(
        @Query("page") page: Int = 1,
        @Query("per_page") perPage: Int = 50,
        @Query("type") type: String? = null,
    ): NotificationsResponse

    @POST("notifications/{notificationId}/read")
    suspend fun markNotificationRead(@Path("notificationId") notificationId: String): JsonObject

    @POST("notifications/read-all")
    suspend fun markAllNotificationsRead(): JsonObject

    // ── Search (users, groups, events, posts) ──
    @GET("api/v1/search")
    suspend fun search(
        @Query("q") q: String,
        @Query("type") type: String = "all",
        @Query("limit") limit: Int = 10,
    ): SearchResponse

    // ── Discover ──
    @GET("discover/places")
    suspend fun places(
        @Query("page") page: Int = 1,
        @Query("per_page") perPage: Int = 20,
        @Query("category") category: String? = null,
    ): PlacesResponse

    @GET("discover/trending")
    suspend fun trending(): JsonObject

    // ── AI Chat (simple, non-streaming fallback) ──
    @GET("api/v1/chat/conversations")
    suspend fun aiConversations(): AiConversationListResponse

    @GET("api/v1/chat/conversations/{conversationId}")
    suspend fun aiConversation(
        @Path("conversationId") conversationId: String,
    ): AiConversationDetailDto

    @POST("api/v1/chat/conversations")
    suspend fun createAiConversation(
        @Body body: CreateAiConversationRequest,
    ): AiConversationDetailDto

    @DELETE("api/v1/chat/conversations/{conversationId}")
    suspend fun deleteAiConversation(
        @Path("conversationId") conversationId: String,
    ): Response<Unit>

    @POST("api/v1/ai/chat")
    suspend fun simpleChat(@Body body: SimpleChatRequest): SimpleChatResponse
}
