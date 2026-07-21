package com.lyo.app.data.api

import com.google.gson.annotations.SerializedName

// ── Auth ─────────────────────────────────────────────────────────────────────

data class LoginRequest(val email: String, val password: String)

data class RegisterRequest(
    val email: String,
    val username: String,
    val password: String,
    @SerializedName("confirm_password") val confirmPassword: String,
    @SerializedName("first_name") val firstName: String? = null,
    @SerializedName("last_name") val lastName: String? = null,
)

data class AuthResponse(
    val user: UserDto?,
    @SerializedName("access_token") val accessToken: String?,
    @SerializedName("refresh_token") val refreshToken: String?,
)

data class UpdateProfileRequest(
    @SerializedName("full_name") val fullName: String? = null,
    val bio: String? = null,
    @SerializedName("avatar_url") val avatarUrl: String? = null,
)

data class UserDto(
    val id: String? = null,
    val email: String? = null,
    val username: String? = null,
    @SerializedName("first_name") val firstName: String? = null,
    @SerializedName("last_name") val lastName: String? = null,
    @SerializedName("avatar_url") val avatarUrl: String? = null,
    val bio: String? = null,
    val streak: Int? = null,
    val xp: Int? = null,
    @SerializedName("total_xp") val totalXp: Int? = null,
    val level: Int? = null,
    @SerializedName("current_level") val currentLevel: Int? = null,
    @SerializedName("courses_completed") val coursesCompleted: Int? = null,
    @SerializedName("followers_count") val followersCount: Int? = null,
    @SerializedName("following_count") val followingCount: Int? = null,
    @SerializedName("created_at") val createdAt: String? = null,
    @SerializedName("is_premium") val isPremium: Boolean? = null,
) {
    val displayName: String
        get() = listOfNotNull(firstName, lastName)
            .filter { it.isNotBlank() }
            .joinToString(" ")
            .ifBlank { username ?: "User" }

    val resolvedXp: Int get() = xp ?: totalXp ?: 0
    val resolvedLevel: Int get() = level ?: currentLevel ?: 1
}

// ── Feed ─────────────────────────────────────────────────────────────────────

data class PostDto(
    val id: Any? = null,
    val content: String? = null,
    @SerializedName("author_id") val authorId: Any? = null,
    @SerializedName("author_name") val authorName: String? = null,
    @SerializedName("author_username") val authorUsername: String? = null,
    @SerializedName("author_avatar") val authorAvatar: String? = null,
    @SerializedName("like_count") val likeCount: Int? = null,
    @SerializedName("comment_count") val commentCount: Int? = null,
    @SerializedName("media_urls") val mediaUrls: List<String>? = null,
    @SerializedName("created_at") val createdAt: String? = null,
) {
    val idStr: String get() = id?.toString()?.removeSuffix(".0") ?: ""
}

data class PostsResponse(
    val posts: List<PostDto>? = null,
    val total: Int? = null,
)

data class CreatePostRequest(
    val content: String,
    @SerializedName("media_urls") val mediaUrls: List<String>? = null,
)

data class ReactionRequest(
    @SerializedName("post_id") val postId: Long,
    @SerializedName("reaction_type") val reactionType: String = "like",
)

data class CommentRequest(
    @SerializedName("post_id") val postId: Long,
    val content: String,
)

data class FollowRequest(
    @SerializedName("followed_user_id") val followedUserId: Long,
)

// ── Clips ────────────────────────────────────────────────────────────────────

// The clips backend serializes camelCase (Clip.to_dict); keep the snake_case
// alternates so older payload shapes still decode.
data class ClipDto(
    val id: Any? = null,
    val title: String? = null,
    val description: String? = null,
    @SerializedName(value = "videoURL", alternate = ["video_url", "videoUrl"]) val videoUrl: String? = null,
    @SerializedName(value = "thumbnailURL", alternate = ["thumbnail_url", "thumbnailUrl"]) val thumbnailUrl: String? = null,
    @SerializedName(value = "viewCount", alternate = ["view_count"]) val viewCount: Int? = null,
    @SerializedName(value = "likeCount", alternate = ["like_count"]) val likeCount: Int? = null,
    @SerializedName(value = "commentCount", alternate = ["comment_count"]) val commentCount: Int? = null,
    @SerializedName(value = "shareCount", alternate = ["share_count"]) val shareCount: Int? = null,
    @SerializedName(value = "isLiked", alternate = ["is_liked"]) val isLiked: Boolean? = null,
    @SerializedName(value = "isSaved", alternate = ["is_saved"]) val isSaved: Boolean? = null,
    @SerializedName(value = "authorName", alternate = ["author_name"]) val authorName: String? = null,
    val subject: String? = null,
    @SerializedName(value = "createdAt", alternate = ["created_at"]) val createdAt: String? = null,
) {
    val idStr: String get() = id?.toString()?.removeSuffix(".0") ?: ""
}

data class ClipCreateRequest(
    // The clips create endpoint reads camelCase keys (pydantic ClipCreate).
    val title: String,
    val description: String? = null,
    val videoUrl: String,
    val thumbnailUrl: String? = null,
    val durationSeconds: Double = 0.0,
    val subject: String? = null,
    val topic: String? = null,
    val level: String = "beginner",
    val keyPoints: List<String> = emptyList(),
    val tags: List<String> = emptyList(),
    val isPublic: Boolean = true,
    val enableCourseGeneration: Boolean = true,
)

data class ClipCreateResponse(
    val success: Boolean? = null,
    val clip: ClipDto? = null,
)

data class ClipCommentDto(
    val id: String? = null,
    val userId: Any? = null,
    val authorName: String? = null,
    @SerializedName("authorAvatarURL") val authorAvatar: String? = null,
    val content: String? = null,
    val createdAt: String? = null,
) {
    val userIdStr: String get() = userId?.toString()?.removeSuffix(".0") ?: ""
}

data class ClipCommentsResponse(
    val items: List<ClipCommentDto>? = null,
    @SerializedName("total_count") val totalCount: Int? = null,
)

data class MediaUploadResponse(
    val success: Boolean? = null,
    val url: String? = null,
    val path: String? = null,
)

// ── Search ───────────────────────────────────────────────────────────────────

data class SearchUserDto(
    val id: Any? = null,
    val username: String? = null,
    val name: String? = null,
    @SerializedName("avatar_url") val avatarUrl: String? = null,
) {
    val idStr: String get() = id?.toString()?.removeSuffix(".0") ?: ""
}

data class SearchResponse(
    val query: String? = null,
    val users: List<SearchUserDto>? = null,
    val total: Int? = null,
)

data class ClipsResponse(
    val clips: List<ClipDto>? = null,
    val total: Int? = null,
)

// ── Stories ──────────────────────────────────────────────────────────────────

data class StoryDto(
    val id: Any? = null,
    @SerializedName("user_id") val userId: Any? = null,
    @SerializedName("user_name") val userName: String? = null,
    val username: String? = null,
    @SerializedName("display_name") val displayName: String? = null,
    @SerializedName("avatar_url") val avatarUrl: String? = null,
    @SerializedName("media_url") val mediaUrl: String? = null,
    val caption: String? = null,
    val viewed: Boolean? = null,
    @SerializedName("is_seen") val isSeen: Boolean? = null,
    @SerializedName("created_at") val createdAt: String? = null,
) {
    val idStr: String get() = id?.toString()?.removeSuffix(".0") ?: ""
    val name: String get() = userName ?: displayName ?: username ?: "User"
    val seen: Boolean get() = viewed ?: isSeen ?: false
}

data class StoriesResponse(
    val stories: List<StoryDto>? = null,
    @SerializedName("my_story") val myStory: StoryDto? = null,
)

// ── Courses ──────────────────────────────────────────────────────────────────

data class CourseDto(
    val id: Any? = null,
    val title: String? = null,
    val description: String? = null,
    val subject: String? = null,
    val difficulty: String? = null,
    @SerializedName("estimated_duration_hours") val durationHours: Double? = null,
    @SerializedName("created_at") val createdAt: String? = null,
    val lessons: List<LessonDto>? = null,
    val modules: List<ModuleDto>? = null,
) {
    val idStr: String get() = id?.toString()?.removeSuffix(".0") ?: ""
}

data class LessonDto(
    val id: Any? = null,
    val title: String? = null,
    val content: String? = null,
    @SerializedName("order_index") val orderIndex: Int? = null,
)

data class ModuleDto(
    val id: Any? = null,
    val title: String? = null,
    val lessons: List<LessonDto>? = null,
)

data class GenerateCourseRequest(
    val topic: String,
    val difficulty: String = "beginner",
    @SerializedName("duration_hours") val durationHours: Int = 2,
    @SerializedName("include_exercises") val includeExercises: Boolean = true,
    @SerializedName("include_assessments") val includeAssessments: Boolean = true,
)

// ── Community ────────────────────────────────────────────────────────────────

data class GroupDto(
    val id: Any? = null,
    val name: String? = null,
    val description: String? = null,
    @SerializedName("member_count") val memberCount: Int? = null,
    val category: String? = null,
    val privacy: String? = null,
    @SerializedName("max_members") val maxMembers: Int? = null,
    @SerializedName("is_member") val isMember: Boolean? = null,
) {
    val idStr: String get() = id?.toString()?.removeSuffix(".0") ?: ""
}

data class EventDto(
    val id: Any? = null,
    val title: String? = null,
    val name: String? = null,
    val description: String? = null,
    @SerializedName("start_time") val startTime: String? = null,
    @SerializedName("end_time") val endTime: String? = null,
    @SerializedName("event_type") val eventType: String? = null,
    val location: String? = null,
    @SerializedName("is_online") val isOnline: Boolean? = null,
    @SerializedName("attendee_count") val attendeeCount: Int? = null,
    @SerializedName("max_attendees") val maxAttendees: Int? = null,
    @SerializedName("user_attendance_status") val userAttendanceStatus: String? = null,
    val latitude: Double? = null,
    val longitude: Double? = null,
) {
    val idStr: String get() = id?.toString()?.removeSuffix(".0") ?: ""
    val displayTitle: String get() = title ?: name ?: "Event"
    val isAttending: Boolean get() = userAttendanceStatus != null
}

data class CreateStudyGroupRequest(
    val name: String,
    val description: String? = null,
    val privacy: String = "public",
    @SerializedName("max_members") val maxMembers: Int = 20,
    @SerializedName("requires_approval") val requiresApproval: Boolean = false,
)

data class CreateCommunityEventRequest(
    val title: String,
    val description: String? = null,
    @SerializedName("event_type") val eventType: String = "study_session",
    val location: String? = null,
    @SerializedName("max_attendees") val maxAttendees: Int = 50,
    @SerializedName("start_time") val startTime: String,
    @SerializedName("end_time") val endTime: String,
    val timezone: String,
    val latitude: Double? = null,
    val longitude: Double? = null,
)

// ── Community posts (community/posts — the same store iOS renders) ──────────

data class CommunityPostDto(
    val id: String? = null,
    @SerializedName("author_id") val authorId: Any? = null,
    @SerializedName("author_name") val authorName: String? = null,
    @SerializedName("author_avatar") val authorAvatar: String? = null,
    @SerializedName("author_level") val authorLevel: Int? = null,
    val content: String? = null,
    @SerializedName("media_urls") val mediaUrls: List<String>? = null,
    val tags: List<String>? = null,
    @SerializedName("post_type") val postType: String? = null,
    @SerializedName("like_count") val likeCount: Int? = null,
    @SerializedName("comment_count") val commentCount: Int? = null,
    @SerializedName("has_liked") val hasLiked: Boolean? = null,
    @SerializedName("has_bookmarked") val hasBookmarked: Boolean? = null,
    @SerializedName("created_at") val createdAt: String? = null,
) {
    val idStr: String get() = id.orEmpty()
}

data class CommunityPostsResponse(
    val items: List<CommunityPostDto>? = null,
    @SerializedName("total_count") val totalCount: Int? = null,
)

data class CommunityCreatePostRequest(
    val content: String,
    val tags: List<String>? = null,
    @SerializedName("media_urls") val mediaUrls: List<String>? = null,
    @SerializedName("post_type") val postType: String = "text",
)

data class CommunityCommentDto(
    val id: String? = null,
    @SerializedName("author_id") val authorId: Any? = null,
    @SerializedName("author_name") val authorName: String? = null,
    @SerializedName("author_avatar") val authorAvatar: String? = null,
    val content: String? = null,
    @SerializedName("like_count") val likeCount: Int? = null,
    @SerializedName("has_liked") val hasLiked: Boolean? = null,
    @SerializedName("created_at") val createdAt: String? = null,
) {
    val authorIdStr: String get() = authorId?.toString()?.removeSuffix(".0") ?: ""
}

data class CommunityCommentsResponse(
    val items: List<CommunityCommentDto>? = null,
    @SerializedName("total_count") val totalCount: Int? = null,
)

data class CommunityCommentRequest(
    val content: String,
    @SerializedName("parent_id") val parentId: String? = null,
)

data class LikeToggleResponse(
    val liked: Boolean? = null,
    @SerializedName("like_count") val likeCount: Int? = null,
)

// ── Messages ─────────────────────────────────────────────────────────────────

data class ParticipantDto(
    val id: Any? = null,
    val username: String? = null,
    @SerializedName("display_name") val displayName: String? = null,
    @SerializedName("avatar_url") val avatarUrl: String? = null,
) {
    val idStr: String get() = id?.toString()?.removeSuffix(".0") ?: ""
    val name: String get() = displayName ?: username ?: "User"
}

data class MessageDto(
    val id: Any? = null,
    @SerializedName("conversation_id") val conversationId: Any? = null,
    @SerializedName("sender_id") val senderId: Any? = null,
    val content: String? = null,
    @SerializedName("message_type") val messageType: String? = null,
    @SerializedName("created_at") val createdAt: String? = null,
) {
    val idStr: String get() = id?.toString()?.removeSuffix(".0") ?: ""
    val senderIdStr: String get() = senderId?.toString()?.removeSuffix(".0") ?: ""
}

data class ConversationDto(
    val id: Any? = null,
    val type: String? = null,
    val name: String? = null,
    val participants: List<ParticipantDto>? = null,
    @SerializedName("last_message") val lastMessage: MessageDto? = null,
    @SerializedName("unread_count") val unreadCount: Int? = null,
    @SerializedName("updated_at") val updatedAt: String? = null,
) {
    val idStr: String get() = id?.toString()?.removeSuffix(".0") ?: ""
}

data class ConversationsResponse(val conversations: List<ConversationDto>? = null)

data class MessagesResponse(
    val messages: List<MessageDto>? = null,
    val total: Int? = null,
)

data class CreateConversationRequest(
    @SerializedName("participant_ids") val participantIds: List<Long>,
)

data class SendMessageRequest(
    val content: String,
    @SerializedName("message_type") val messageType: String = "text",
)

// ── Notifications ────────────────────────────────────────────────────────────

data class NotificationDto(
    val id: Any? = null,
    val type: String? = null,
    val title: String? = null,
    val body: String? = null,
    @SerializedName("actor_id") val actorId: Any? = null,
    @SerializedName("actor_display_name") val actorDisplayName: String? = null,
    @SerializedName("actor_username") val actorUsername: String? = null,
    @SerializedName("actor_avatar_url") val actorAvatarUrl: String? = null,
    @SerializedName("target_id") val targetId: String? = null,
    @SerializedName("target_type") val targetType: String? = null,
    @SerializedName("is_read") val isRead: Boolean? = null,
    @SerializedName("created_at") val createdAt: String? = null,
) {
    val idStr: String get() = id?.toString()?.removeSuffix(".0") ?: ""
}

data class NotificationsResponse(
    val notifications: List<NotificationDto>? = null,
    val total: Int? = null,
    @SerializedName("unread_count") val unreadCount: Int? = null,
)

// ── Discover ─────────────────────────────────────────────────────────────────

data class PlaceDto(
    val id: String? = null,
    val name: String? = null,
    val description: String? = null,
    val category: String? = null,
    val lat: Double? = null,
    val lng: Double? = null,
    val rating: Double? = null,
    @SerializedName("review_count") val reviewCount: Int? = null,
    @SerializedName("image_url") val imageUrl: String? = null,
    val address: String? = null,
    val website: String? = null,
    val tags: List<String>? = null,
    @SerializedName("is_featured") val isFeatured: Boolean? = null,
)

data class PlacesResponse(
    val places: List<PlaceDto>? = null,
    val total: Int? = null,
)

// ── AI Chat ──────────────────────────────────────────────────────────────────

data class SimpleChatRequest(
    val message: String,
    val provider: String = "gemini",
)

data class SimpleChatResponse(
    val response: String? = null,
)

// ── Canonical AI conversation continuity ────────────────────────────────────

data class AiConversationMessageDto(
    val id: String,
    @SerializedName("conversation_id") val conversationId: String,
    val role: String,
    val content: String,
    @SerializedName("created_at") val createdAt: String,
)

data class AiConversationSummaryDto(
    val id: String,
    val title: String,
    @SerializedName("message_count") val messageCount: Int = 0,
    @SerializedName("last_message_preview") val lastMessagePreview: String? = null,
    @SerializedName("created_at") val createdAt: String,
    @SerializedName("updated_at") val updatedAt: String,
)

data class AiConversationDetailDto(
    val id: String,
    val title: String,
    @SerializedName("created_at") val createdAt: String,
    @SerializedName("updated_at") val updatedAt: String,
    val messages: List<AiConversationMessageDto> = emptyList(),
)

data class AiConversationListResponse(
    val conversations: List<AiConversationSummaryDto> = emptyList(),
    @SerializedName("has_more") val hasMore: Boolean = false,
)

data class CreateAiConversationRequest(
    val title: String? = null,
    @SerializedName("device_id") val deviceId: String = "android",
)
