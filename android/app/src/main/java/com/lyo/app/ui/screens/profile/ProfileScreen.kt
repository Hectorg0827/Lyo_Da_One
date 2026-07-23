package com.lyo.app.ui.screens.profile

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.navigation.NavHostController
import com.google.gson.JsonArray
import com.google.gson.JsonObject
import com.lyo.app.data.Session
import com.lyo.app.data.api.ApiClient
import com.lyo.app.data.api.FollowRequest
import com.lyo.app.data.api.PostDto
import com.lyo.app.data.api.UserDto
import com.lyo.app.ui.components.EmptyState
import com.lyo.app.ui.components.GlassCard
import com.lyo.app.ui.components.LoadingBox
import com.lyo.app.ui.components.LyoAvatar
import com.lyo.app.ui.components.LyoBrandGradient
import com.lyo.app.ui.components.formatTimeAgo
import com.lyo.app.ui.navigation.Routes
import com.lyo.app.ui.theme.Background
import com.lyo.app.ui.theme.LyoAmber
import com.lyo.app.ui.theme.LyoPurple
import com.lyo.app.ui.theme.Surface
import com.lyo.app.ui.theme.TextPrimary
import com.lyo.app.ui.theme.TextSecondary
import java.io.IOException
import kotlinx.coroutines.launch
import retrofit2.HttpException

private val OwnProfileTabs = listOf("Activity", "Achievements", "Stats")
private val PublicProfileTabs = listOf("Activity")

private data class AchievementUi(
    val title: String,
    val description: String,
    val xp: Int,
    val unlocked: Boolean,
)

@Composable
fun ProfileScreen(nav: NavHostController, userId: String? = null) {
    val isOwn = userId == null
    val profileTabs = if (isOwn) OwnProfileTabs else PublicProfileTabs
    val scope = rememberCoroutineScope()

    var otherUser by remember(userId) { mutableStateOf<UserDto?>(null) }
    var profileLoading by remember(userId) { mutableStateOf(!isOwn) }
    var profileError by remember(userId) { mutableStateOf<String?>(null) }
    var profileReload by remember(userId) { mutableStateOf(0) }

    var selectedTab by remember(userId) { mutableStateOf("Activity") }
    var posts by remember(userId) { mutableStateOf<List<PostDto>>(emptyList()) }
    var activityLoading by remember(userId) { mutableStateOf(false) }
    var activityLoaded by remember(userId) { mutableStateOf(false) }
    var activityError by remember(userId) { mutableStateOf<String?>(null) }

    var achievements by remember(userId) { mutableStateOf<List<AchievementUi>>(emptyList()) }
    var achievementsLoading by remember(userId) { mutableStateOf(false) }
    var achievementsLoaded by remember(userId) { mutableStateOf(false) }
    var achievementsError by remember(userId) { mutableStateOf<String?>(null) }

    var overview by remember(userId) { mutableStateOf<JsonObject?>(null) }
    var statsLoading by remember(userId) { mutableStateOf(false) }
    var statsLoaded by remember(userId) { mutableStateOf(false) }
    var statsError by remember(userId) { mutableStateOf<String?>(null) }
    var contentReload by remember(userId) { mutableStateOf(0) }

    var following by remember(userId) { mutableStateOf(false) }
    var followPending by remember(userId) { mutableStateOf(false) }
    var followError by remember(userId) { mutableStateOf<String?>(null) }

    val user: UserDto? = if (isOwn) Session.user else otherUser

    LaunchedEffect(userId, profileReload) {
        selectedTab = "Activity"
        following = false
        followPending = false
        followError = null

        if (!isOwn && userId != null) {
            profileLoading = true
            profileError = null
            otherUser = null
            runCatching { ApiClient.api.getUser(userId) }
                .onSuccess { otherUser = it }
                .onFailure { profileError = profileLoadMessage(it) }
            profileLoading = false
        }
    }

    LaunchedEffect(user?.id, contentReload) {
        val uid = user?.id ?: return@LaunchedEffect

        activityLoading = true
        activityLoaded = false
        activityError = null
        posts = emptyList()
        runCatching { ApiClient.api.userPosts(uid) }
            .onSuccess { posts = it.posts ?: emptyList() }
            .onFailure { activityError = contentLoadMessage(it, "activity") }
        activityLoading = false
        activityLoaded = true

        if (isOwn) {
            achievementsLoading = true
            achievementsLoaded = false
            achievementsError = null
            achievements = emptyList()
            runCatching { ApiClient.api.achievements() }
                .onSuccess { achievements = parseAchievements(it) }
                .onFailure { achievementsError = contentLoadMessage(it, "achievements") }
            achievementsLoading = false
            achievementsLoaded = true

            statsLoading = true
            statsLoaded = false
            statsError = null
            overview = null
            runCatching { ApiClient.api.gamificationOverview() }
                .onSuccess { overview = it }
                .onFailure { statsError = contentLoadMessage(it, "stats") }
            statsLoading = false
            statsLoaded = true
        } else {
            achievements = emptyList()
            achievementsLoading = false
            achievementsLoaded = false
            achievementsError = null
            overview = null
            statsLoading = false
            statsLoaded = false
            statsError = null
        }
    }

    if (!isOwn && profileLoading) {
        LoadingBox()
        return
    }

    if (!isOwn && profileError != null) {
        FullScreenError(
            title = "Profile unavailable",
            message = profileError ?: "The profile could not be loaded.",
            onRetry = { profileReload += 1 },
        )
        return
    }

    if (user == null) {
        LoadingBox()
        return
    }

    LazyColumn(
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
        modifier = Modifier
            .fillMaxSize()
            .background(Background),
    ) {
        item {
            GlassCard(modifier = Modifier.fillMaxWidth()) {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(20.dp),
                ) {
                    LyoAvatar(
                        name = user.displayName,
                        avatarUrl = user.avatarUrl,
                        size = 80,
                    )
                    Text(
                        text = user.displayName,
                        style = MaterialTheme.typography.headlineMedium,
                        color = TextPrimary,
                        modifier = Modifier.padding(top = 10.dp),
                    )
                    user.username?.takeIf { it.isNotBlank() }?.let { username ->
                        Text(
                            text = "@$username",
                            style = MaterialTheme.typography.bodyMedium,
                            color = TextSecondary,
                        )
                    }
                    if (!user.bio.isNullOrBlank()) {
                        Text(
                            text = user.bio,
                            style = MaterialTheme.typography.bodyMedium,
                            color = TextSecondary,
                            modifier = Modifier.padding(top = 8.dp),
                        )
                    }

                    Row(
                        horizontalArrangement = Arrangement.spacedBy(24.dp),
                        modifier = Modifier.padding(top = 14.dp),
                    ) {
                        CountStat(user.followersCount ?: 0, "Followers")
                        CountStat(user.followingCount ?: 0, "Following")
                        CountStat(user.coursesCompleted ?: 0, "Completed")
                    }

                    Row(
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                        modifier = Modifier.padding(top = 14.dp),
                    ) {
                        StatChip("🔥 ${user.streak ?: 0} day streak")
                        StatChip("⚡ ${user.resolvedXp} XP")
                        StatChip("Lv ${user.resolvedLevel}")
                    }

                    Spacer(Modifier.height(16.dp))
                    if (isOwn) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            modifier = Modifier
                                .clip(RoundedCornerShape(12.dp))
                                .background(Surface)
                                .clickable { nav.navigate(Routes.SETTINGS) }
                                .padding(horizontal = 20.dp, vertical = 10.dp),
                        ) {
                            Icon(
                                Icons.Filled.Settings,
                                contentDescription = null,
                                tint = TextSecondary,
                                modifier = Modifier.size(16.dp),
                            )
                            Text(
                                text = "  Settings",
                                style = MaterialTheme.typography.titleSmall,
                                color = TextPrimary,
                            )
                        }
                    } else {
                        val followButtonBase = Modifier
                            .clip(RoundedCornerShape(12.dp))
                            .let { base ->
                                if (following) base.background(Surface) else base.background(LyoBrandGradient)
                            }

                        Box(
                            contentAlignment = Alignment.Center,
                            modifier = followButtonBase
                                .clickable(enabled = !followPending) {
                                    val targetUserId = userId
                                    val target = targetUserId?.toLongOrNull()
                                    if (targetUserId == null || target == null) {
                                        followError = "This profile does not have a valid follow identifier."
                                        return@clickable
                                    }

                                    scope.launch {
                                        followPending = true
                                        followError = null
                                        val result = if (following) {
                                            runCatching { ApiClient.api.unfollow(targetUserId) }
                                        } else {
                                            runCatching { ApiClient.api.follow(FollowRequest(target)) }
                                        }
                                        result
                                            .onSuccess { following = !following }
                                            .onFailure { followError = followActionMessage(it) }
                                        followPending = false
                                    }
                                }
                                .padding(horizontal = 28.dp, vertical = 10.dp),
                        ) {
                            Text(
                                text = when {
                                    followPending -> "Saving…"
                                    following -> "Following"
                                    else -> "Follow"
                                },
                                style = MaterialTheme.typography.titleSmall,
                                color = if (following) TextPrimary else Color.White,
                            )
                        }

                        followError?.let { message ->
                            Text(
                                text = message,
                                style = MaterialTheme.typography.bodySmall,
                                color = Color(0xFFFF7B7B),
                                modifier = Modifier.padding(top = 8.dp),
                            )
                        }
                    }
                }
            }
        }

        item {
            LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                items(profileTabs) { tab ->
                    val active = selectedTab == tab
                    Text(
                        text = tab,
                        style = MaterialTheme.typography.labelLarge,
                        color = if (active) Color.White else TextSecondary,
                        modifier = Modifier
                            .clip(RoundedCornerShape(12.dp))
                            .let {
                                if (active) it.background(LyoBrandGradient)
                                else it.background(Surface)
                            }
                            .clickable { selectedTab = tab }
                            .padding(horizontal = 14.dp, vertical = 8.dp),
                    )
                }
            }
        }

        when (selectedTab) {
            "Activity" -> {
                when {
                    activityLoading -> item { LoadingCard("Loading activity…") }
                    activityError != null -> item {
                        InlineErrorCard(
                            title = "Activity unavailable",
                            message = activityError ?: "Activity could not be loaded.",
                            onRetry = { contentReload += 1 },
                        )
                    }
                    activityLoaded && posts.isEmpty() -> item {
                        EmptyState("No activity yet", "Published posts will appear here.")
                    }
                    else -> items(posts) { post ->
                        GlassCard(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable { nav.navigate(Routes.postDetail(post.idStr)) },
                        ) {
                            Column(modifier = Modifier.padding(14.dp)) {
                                Text(
                                    text = post.content ?: "",
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = TextPrimary,
                                    maxLines = 3,
                                    overflow = TextOverflow.Ellipsis,
                                )
                                Text(
                                    text = "${post.likeCount ?: 0} likes  ·  " +
                                        "${post.commentCount ?: 0} comments  ·  " +
                                        formatTimeAgo(post.createdAt),
                                    style = MaterialTheme.typography.bodySmall,
                                    color = TextSecondary,
                                    modifier = Modifier.padding(top = 6.dp),
                                )
                            }
                        }
                    }
                }
            }

            "Achievements" -> {
                when {
                    !isOwn -> item {
                        InlineErrorCard(
                            title = "Private section",
                            message = "Achievements are shown only on your own profile.",
                            onRetry = null,
                        )
                    }
                    achievementsLoading -> item { LoadingCard("Loading achievements…") }
                    achievementsError != null -> item {
                        InlineErrorCard(
                            title = "Achievements unavailable",
                            message = achievementsError ?: "Achievements could not be loaded.",
                            onRetry = { contentReload += 1 },
                        )
                    }
                    achievementsLoaded && achievements.isEmpty() -> item {
                        EmptyState("No achievements yet", "Keep learning to unlock them.")
                    }
                    else -> items(achievements.chunked(2)) { rowItems ->
                        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                            rowItems.forEach { achievement ->
                                AchievementCard(achievement, Modifier.weight(1f))
                            }
                            if (rowItems.size == 1) Spacer(Modifier.weight(1f))
                        }
                    }
                }
            }

            "Stats" -> {
                when {
                    !isOwn -> item {
                        InlineErrorCard(
                            title = "Private section",
                            message = "Detailed learning statistics are shown only on your own profile.",
                            onRetry = null,
                        )
                    }
                    statsLoading -> item { LoadingCard("Loading learning stats…") }
                    statsError != null -> item {
                        InlineErrorCard(
                            title = "Stats unavailable",
                            message = statsError ?: "Learning statistics could not be loaded.",
                            onRetry = { contentReload += 1 },
                        )
                    }
                    statsLoaded && overview != null -> item {
                        val totalXp = extractInt(overview, "xp_summary", "total") ?: user.resolvedXp
                        val weekXp = extractInt(overview, "xp_summary", "this_week") ?: 0
                        val currentStreak = extractInt(overview, "streaks", "current")
                            ?: user.streak ?: 0
                        val longestStreak = extractInt(overview, "streaks", "longest")
                            ?: currentStreak

                        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                                StatTile("Total XP", "$totalXp", Modifier.weight(1f))
                                StatTile("XP this week", "$weekXp", Modifier.weight(1f))
                            }
                            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                                StatTile("Current streak", "$currentStreak days", Modifier.weight(1f))
                                StatTile("Longest streak", "$longestStreak days", Modifier.weight(1f))
                            }
                            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                                StatTile("Level", "${user.resolvedLevel}", Modifier.weight(1f))
                                StatTile("Completed", "${user.coursesCompleted ?: 0}", Modifier.weight(1f))
                            }
                        }
                    }
                }
            }
        }

        item { Spacer(Modifier.height(24.dp)) }
    }
}

private fun parseAchievements(arr: JsonArray): List<AchievementUi> =
    arr.mapNotNull { element ->
        runCatching {
            val obj = element.asJsonObject
            AchievementUi(
                title = obj.str("name") ?: obj.str("achievement_name") ?: "Achievement",
                description = obj.str("description") ?: "",
                xp = runCatching { obj.get("xp_reward")?.asInt }.getOrNull() ?: 0,
                unlocked = runCatching { obj.get("completed")?.asBoolean }.getOrNull()
                    ?: runCatching { obj.get("is_completed")?.asBoolean }.getOrNull()
                    ?: false,
            )
        }.getOrNull()
    }

private fun JsonObject.str(key: String): String? =
    runCatching { get(key)?.takeIf { !it.isJsonNull }?.asString }.getOrNull()

private fun extractInt(obj: JsonObject?, section: String, key: String): Int? =
    runCatching {
        obj?.getAsJsonObject(section)?.get(key)?.takeIf { !it.isJsonNull }?.asInt
    }.getOrNull()

private fun profileLoadMessage(error: Throwable): String = when (error) {
    is HttpException -> when (error.code()) {
        401, 403 -> "You are not authorized to view this profile."
        404 -> "This profile no longer exists."
        else -> "The profile request failed (${error.code()})."
    }
    is IOException -> "Check your connection and try again."
    else -> error.localizedMessage ?: "The profile could not be loaded."
}

private fun contentLoadMessage(error: Throwable, content: String): String = when (error) {
    is HttpException -> when (error.code()) {
        401, 403 -> "You are not authorized to view this $content."
        404 -> "No $content endpoint is available for this profile."
        else -> "The $content request failed (${error.code()})."
    }
    is IOException -> "Check your connection and retry the $content request."
    else -> error.localizedMessage ?: "The $content could not be loaded."
}

private fun followActionMessage(error: Throwable): String = when (error) {
    is HttpException -> when (error.code()) {
        401, 403 -> "Sign in again before changing this relationship."
        404 -> "This profile is no longer available."
        409 -> "The follow state changed elsewhere. Refresh the profile and retry."
        else -> "The follow request failed (${error.code()})."
    }
    is IOException -> "Check your connection and try again."
    else -> error.localizedMessage ?: "The follow request could not be completed."
}

@Composable
private fun FullScreenError(
    title: String,
    message: String,
    onRetry: () -> Unit,
) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
        modifier = Modifier
            .fillMaxSize()
            .background(Background)
            .padding(24.dp),
    ) {
        Text(title, style = MaterialTheme.typography.headlineSmall, color = TextPrimary)
        Text(
            message,
            style = MaterialTheme.typography.bodyMedium,
            color = TextSecondary,
            modifier = Modifier.padding(top = 8.dp),
        )
        Text(
            "Retry",
            style = MaterialTheme.typography.titleSmall,
            color = LyoPurple,
            modifier = Modifier
                .padding(top = 16.dp)
                .clickable(onClick = onRetry)
                .padding(8.dp),
        )
    }
}

@Composable
private fun InlineErrorCard(
    title: String,
    message: String,
    onRetry: (() -> Unit)?,
) {
    GlassCard(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(title, style = MaterialTheme.typography.titleMedium, color = TextPrimary)
            Text(
                message,
                style = MaterialTheme.typography.bodySmall,
                color = TextSecondary,
                modifier = Modifier.padding(top = 4.dp),
            )
            onRetry?.let { retry ->
                Text(
                    "Retry",
                    style = MaterialTheme.typography.titleSmall,
                    color = LyoPurple,
                    modifier = Modifier
                        .padding(top = 10.dp)
                        .clickable(onClick = retry)
                        .padding(vertical = 4.dp),
                )
            }
        }
    }
}

@Composable
private fun LoadingCard(message: String) {
    GlassCard(modifier = Modifier.fillMaxWidth()) {
        Text(
            message,
            style = MaterialTheme.typography.bodyMedium,
            color = TextSecondary,
            modifier = Modifier.padding(18.dp),
        )
    }
}

@Composable
private fun CountStat(count: Int, label: String) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(
            text = "$count",
            style = MaterialTheme.typography.titleLarge,
            color = TextPrimary,
        )
        Text(
            text = label,
            style = MaterialTheme.typography.bodySmall,
            color = TextSecondary,
        )
    }
}

@Composable
private fun StatChip(label: String) {
    Text(
        text = label,
        style = MaterialTheme.typography.labelMedium,
        color = LyoAmber,
        modifier = Modifier
            .clip(RoundedCornerShape(50))
            .background(LyoAmber.copy(alpha = 0.12f))
            .padding(horizontal = 10.dp, vertical = 5.dp),
    )
}

@Composable
private fun StatTile(label: String, value: String, modifier: Modifier = Modifier) {
    GlassCard(modifier = modifier) {
        Column(modifier = Modifier.padding(14.dp)) {
            Text(
                text = value,
                style = MaterialTheme.typography.headlineSmall,
                color = LyoPurple,
            )
            Text(
                text = label,
                style = MaterialTheme.typography.bodySmall,
                color = TextSecondary,
                modifier = Modifier.padding(top = 2.dp),
            )
        }
    }
}

@Composable
private fun AchievementCard(achievement: AchievementUi, modifier: Modifier = Modifier) {
    GlassCard(modifier = modifier) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            modifier = Modifier
                .fillMaxWidth()
                .padding(14.dp),
        ) {
            Box(
                contentAlignment = Alignment.Center,
                modifier = Modifier
                    .size(48.dp)
                    .clip(RoundedCornerShape(14.dp))
                    .let {
                        if (achievement.unlocked) it.background(LyoBrandGradient)
                        else it.background(Surface)
                    },
            ) {
                if (achievement.unlocked) {
                    Text(text = "🏆")
                } else {
                    Icon(
                        Icons.Filled.Lock,
                        contentDescription = "Locked",
                        tint = TextSecondary,
                        modifier = Modifier.size(18.dp),
                    )
                }
            }
            Text(
                text = achievement.title,
                style = MaterialTheme.typography.titleSmall,
                color = if (achievement.unlocked) TextPrimary else TextSecondary,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.padding(top = 8.dp),
            )
            if (achievement.description.isNotBlank()) {
                Text(
                    text = achievement.description,
                    style = MaterialTheme.typography.bodySmall,
                    color = TextSecondary,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.padding(top = 2.dp),
                )
            }
            if (achievement.xp > 0) {
                Text(
                    text = "+${achievement.xp} XP",
                    style = MaterialTheme.typography.labelMedium,
                    color = LyoAmber,
                    modifier = Modifier.padding(top = 6.dp),
                )
            }
        }
    }
}