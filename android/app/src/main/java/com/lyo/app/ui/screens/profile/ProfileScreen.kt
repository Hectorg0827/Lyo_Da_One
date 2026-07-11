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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
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
import com.lyo.app.data.api.CourseDto
import com.lyo.app.data.api.FollowRequest
import com.lyo.app.data.api.PostDto
import com.lyo.app.data.api.UserDto
import com.lyo.app.ui.components.CardGradients
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
import kotlinx.coroutines.launch

private val ProfileTabs = listOf("Activity", "Courses", "Achievements", "Stats")

private data class AchievementUi(
    val title: String,
    val description: String,
    val xp: Int,
    val unlocked: Boolean,
)

@Composable
fun ProfileScreen(nav: NavHostController, userId: String? = null) {
    val isOwn = userId == null
    val scope = rememberCoroutineScope()

    var otherUser by remember { mutableStateOf<UserDto?>(null) }
    var selectedTab by remember { mutableStateOf("Activity") }
    var posts by remember { mutableStateOf<List<PostDto>>(emptyList()) }
    var courses by remember { mutableStateOf<List<CourseDto>>(emptyList()) }
    var achievements by remember { mutableStateOf<List<AchievementUi>>(emptyList()) }
    var overview by remember { mutableStateOf<JsonObject?>(null) }
    var following by remember { mutableStateOf(false) }

    val user: UserDto? = if (isOwn) Session.user else otherUser

    LaunchedEffect(userId) {
        if (!isOwn && userId != null) {
            runCatching { ApiClient.api.getUser(userId) }.onSuccess { otherUser = it }
        }
    }

    LaunchedEffect(user?.id) {
        val uid = user?.id ?: return@LaunchedEffect
        runCatching { ApiClient.api.userPosts(uid) }
            .onSuccess { posts = it.posts ?: emptyList() }
        runCatching { ApiClient.api.courses(0, 10) }
            .onSuccess { courses = it }
        runCatching { ApiClient.api.achievements() }
            .onSuccess { achievements = parseAchievements(it) }
        runCatching { ApiClient.api.gamificationOverview() }
            .onSuccess { overview = it }
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
        // ── Header ──
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
                    Text(
                        text = "@${user.username ?: ""}",
                        style = MaterialTheme.typography.bodyMedium,
                        color = TextSecondary,
                    )
                    if (!user.bio.isNullOrBlank()) {
                        Text(
                            text = user.bio,
                            style = MaterialTheme.typography.bodyMedium,
                            color = TextSecondary,
                            modifier = Modifier.padding(top = 8.dp),
                        )
                    }

                    // Counts
                    Row(
                        horizontalArrangement = Arrangement.spacedBy(24.dp),
                        modifier = Modifier.padding(top = 14.dp),
                    ) {
                        CountStat(user.followersCount ?: 0, "Followers")
                        CountStat(user.followingCount ?: 0, "Following")
                        CountStat(user.coursesCompleted ?: 0, "Courses")
                    }

                    // Gamification chips
                    Row(
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                        modifier = Modifier.padding(top = 14.dp),
                    ) {
                        StatChip("🔥 ${user.streak ?: 0} day streak")
                        StatChip("⚡ ${user.resolvedXp} XP")
                        StatChip("Lv ${user.resolvedLevel}")
                    }

                    // Action button
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
                        Box(
                            contentAlignment = Alignment.Center,
                            modifier = Modifier
                                .clip(RoundedCornerShape(12.dp))
                                .background(
                                    if (following) Surface.copy(alpha = 0.9f)
                                    else Color.Transparent
                                )
                                .let {
                                    if (following) it else it.background(LyoBrandGradient)
                                }
                                .clickable {
                                    scope.launch {
                                        val target = userId?.toLongOrNull() ?: 0L
                                        if (following) {
                                            runCatching { ApiClient.api.unfollow(userId ?: "") }
                                        } else {
                                            runCatching { ApiClient.api.follow(FollowRequest(target)) }
                                        }
                                        following = !following
                                    }
                                }
                                .padding(horizontal = 28.dp, vertical = 10.dp),
                        ) {
                            Text(
                                text = if (following) "Following" else "Follow",
                                style = MaterialTheme.typography.titleSmall,
                                color = Color.White,
                            )
                        }
                    }
                }
            }
        }

        // ── Tabs ──
        item {
            LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                items(ProfileTabs) { tab ->
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

        // ── Tab content ──
        when (selectedTab) {
            "Activity" -> {
                if (posts.isEmpty()) {
                    item { EmptyState("No activity yet", "Posts will appear here.") }
                } else {
                    items(posts) { post ->
                        GlassCard(modifier = Modifier.fillMaxWidth()) {
                            Column(modifier = Modifier.padding(14.dp)) {
                                Text(
                                    text = post.content ?: "",
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = TextPrimary,
                                    maxLines = 2,
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

            "Courses" -> {
                if (courses.isEmpty()) {
                    item { EmptyState("No courses yet", "Completed courses will appear here.") }
                } else {
                    items(courses) { course ->
                        GlassCard(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable { nav.navigate(Routes.courseDetail(course.idStr)) },
                        ) {
                            Row(
                                verticalAlignment = Alignment.CenterVertically,
                                modifier = Modifier.padding(12.dp),
                            ) {
                                Box(
                                    modifier = Modifier
                                        .size(48.dp)
                                        .clip(RoundedCornerShape(12.dp))
                                        .background(
                                            CardGradients[
                                                course.idStr.hashCode().mod(CardGradients.size)
                                            ]
                                        ),
                                )
                                Column(modifier = Modifier.padding(start = 12.dp)) {
                                    Text(
                                        text = course.title ?: "Untitled",
                                        style = MaterialTheme.typography.titleMedium,
                                        color = TextPrimary,
                                        maxLines = 1,
                                        overflow = TextOverflow.Ellipsis,
                                    )
                                    Text(
                                        text = course.subject ?: "General",
                                        style = MaterialTheme.typography.bodySmall,
                                        color = TextSecondary,
                                    )
                                }
                            }
                        }
                    }
                }
            }

            "Achievements" -> {
                if (achievements.isEmpty()) {
                    item { EmptyState("No achievements yet", "Keep learning to unlock them!") }
                } else {
                    items(achievements.chunked(2)) { rowItems ->
                        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                            rowItems.forEach { ach ->
                                AchievementCard(ach, Modifier.weight(1f))
                            }
                            if (rowItems.size == 1) Spacer(Modifier.weight(1f))
                        }
                    }
                }
            }

            "Stats" -> {
                item {
                    val totalXp = extractInt(overview, "xp_summary", "total")
                        ?: user.resolvedXp
                    val weekXp = extractInt(overview, "xp_summary", "this_week") ?: 0
                    val curStreak = extractInt(overview, "streaks", "current")
                        ?: user.streak ?: 0
                    val longStreak = extractInt(overview, "streaks", "longest") ?: curStreak

                    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                            StatTile("Total XP", "$totalXp", Modifier.weight(1f))
                            StatTile("XP this week", "$weekXp", Modifier.weight(1f))
                        }
                        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                            StatTile("Current streak", "$curStreak days", Modifier.weight(1f))
                            StatTile("Longest streak", "$longStreak days", Modifier.weight(1f))
                        }
                        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                            StatTile("Level", "${user.resolvedLevel}", Modifier.weight(1f))
                            StatTile("Courses", "${user.coursesCompleted ?: 0}", Modifier.weight(1f))
                        }
                    }
                }
            }
        }

        item { Spacer(Modifier.height(24.dp)) }
    }
}

private fun parseAchievements(arr: JsonArray): List<AchievementUi> =
    arr.mapNotNull { el ->
        runCatching {
            val obj = el.asJsonObject
            AchievementUi(
                title = obj.str("name") ?: obj.str("achievement_name") ?: "Achievement",
                description = obj.str("description") ?: "",
                xp = runCatching { obj.get("xp_reward")?.asInt }.getOrNull() ?: 100,
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
private fun AchievementCard(ach: AchievementUi, modifier: Modifier = Modifier) {
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
                        if (ach.unlocked) it.background(LyoBrandGradient)
                        else it.background(Surface)
                    },
            ) {
                if (ach.unlocked) {
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
                text = ach.title,
                style = MaterialTheme.typography.titleSmall,
                color = if (ach.unlocked) TextPrimary else TextSecondary,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.padding(top = 8.dp),
            )
            Text(
                text = ach.description,
                style = MaterialTheme.typography.bodySmall,
                color = TextSecondary,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.padding(top = 2.dp),
            )
            Text(
                text = "+${ach.xp} XP",
                style = MaterialTheme.typography.labelMedium,
                color = LyoAmber,
                modifier = Modifier.padding(top = 6.dp),
            )
        }
    }
}
