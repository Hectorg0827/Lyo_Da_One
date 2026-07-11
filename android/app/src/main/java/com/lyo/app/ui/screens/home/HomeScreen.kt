package com.lyo.app.ui.screens.home

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
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AutoStories
import androidx.compose.material.icons.filled.Email
import androidx.compose.material.icons.filled.Explore
import androidx.compose.material.icons.filled.Groups
import androidx.compose.material.icons.filled.MenuBook
import androidx.compose.material.icons.filled.Notifications
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
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.navigation.NavHostController
import com.google.gson.JsonObject
import com.lyo.app.data.Session
import com.lyo.app.data.api.ApiClient
import com.lyo.app.data.api.CourseDto
import com.lyo.app.data.api.PostDto
import com.lyo.app.ui.components.CardGradients
import com.lyo.app.ui.components.GlassCard
import com.lyo.app.ui.components.LoadingBox
import com.lyo.app.ui.components.LyoAvatar
import com.lyo.app.ui.components.SectionHeader
import com.lyo.app.ui.components.formatTimeAgo
import com.lyo.app.ui.navigation.Routes
import com.lyo.app.ui.theme.LyoAmber
import com.lyo.app.ui.theme.LyoBlue
import com.lyo.app.ui.theme.LyoGreen
import com.lyo.app.ui.theme.LyoPink
import com.lyo.app.ui.theme.LyoPurple
import com.lyo.app.ui.theme.TextPrimary
import com.lyo.app.ui.theme.TextSecondary

@Composable
fun HomeScreen(nav: NavHostController) {
    var overview by remember { mutableStateOf<JsonObject?>(null) }
    var courses by remember { mutableStateOf<List<CourseDto>?>(null) }
    var posts by remember { mutableStateOf<List<PostDto>?>(null) }
    var loaded by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) {
        runCatching { ApiClient.api.gamificationOverview() }.onSuccess { overview = it }
        runCatching { ApiClient.api.courses(0, 5) }.onSuccess { courses = it }
        runCatching { ApiClient.api.publicFeed(1, 5) }.onSuccess { posts = it.posts }
        loaded = true
    }

    if (!loaded) {
        LoadingBox()
        return
    }

    // Defensive extraction from the gamification overview JsonObject
    val streak = runCatching {
        overview?.getAsJsonObject("streaks")?.get("current")?.asInt
    }.getOrNull() ?: Session.user?.streak ?: 0
    val xp = runCatching {
        overview?.getAsJsonObject("xp_summary")?.get("total")?.asInt
    }.getOrNull() ?: Session.user?.resolvedXp ?: 0
    val level = runCatching {
        overview?.getAsJsonObject("user_level")?.get("level")?.asInt
    }.getOrNull() ?: Session.user?.resolvedLevel ?: 1

    LazyColumn(
        contentPadding = PaddingValues(horizontal = 16.dp, vertical = 16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
        modifier = Modifier.fillMaxSize(),
    ) {
        // ── Top bar ──
        item {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text(
                    text = "Hi, ${Session.user?.displayName ?: "Learner"}",
                    style = MaterialTheme.typography.headlineMedium,
                    color = TextPrimary,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.weight(1f),
                )
                IconButton(onClick = { nav.navigate(Routes.NOTIFICATIONS) }) {
                    Icon(
                        Icons.Filled.Notifications,
                        contentDescription = "Notifications",
                        tint = TextSecondary,
                    )
                }
                IconButton(onClick = { nav.navigate(Routes.MESSAGES) }) {
                    Icon(
                        Icons.Filled.Email,
                        contentDescription = "Messages",
                        tint = TextSecondary,
                    )
                }
                IconButton(onClick = { nav.navigate(Routes.SETTINGS) }) {
                    Icon(
                        Icons.Filled.Settings,
                        contentDescription = "Settings",
                        tint = TextSecondary,
                    )
                }
            }
        }

        // ── Stats row ──
        item {
            Row(
                horizontalArrangement = Arrangement.spacedBy(12.dp),
                modifier = Modifier.fillMaxWidth(),
            ) {
                StatCard(
                    emoji = "🔥",
                    value = "$streak",
                    label = "Day streak",
                    accent = LyoAmber,
                    modifier = Modifier.weight(1f),
                )
                StatCard(
                    emoji = "⚡",
                    value = "$xp",
                    label = "XP earned",
                    accent = LyoPurple,
                    modifier = Modifier.weight(1f),
                )
                StatCard(
                    emoji = "🏆",
                    value = "$level",
                    label = "Level",
                    accent = LyoGreen,
                    modifier = Modifier.weight(1f),
                )
            }
        }

        // ── Continue learning ──
        item {
            SectionHeader("Continue Learning")
            val courseList = courses.orEmpty()
            if (courseList.isEmpty()) {
                GlassCard(modifier = Modifier.fillMaxWidth()) {
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable { nav.navigate(Routes.COURSES) }
                            .padding(24.dp),
                    ) {
                        Text(
                            "Start learning",
                            style = MaterialTheme.typography.titleMedium,
                            color = TextPrimary,
                        )
                        Text(
                            "Browse courses and begin your journey",
                            style = MaterialTheme.typography.bodySmall,
                            color = TextSecondary,
                            modifier = Modifier.padding(top = 4.dp),
                        )
                    }
                }
            } else {
                LazyRow(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    itemsIndexed(courseList) { index, course ->
                        CourseCard(
                            course = course,
                            gradient = CardGradients[index % CardGradients.size],
                            onClick = { nav.navigate(Routes.courseDetail(course.idStr)) },
                        )
                    }
                }
            }
        }

        // ── Quick actions ──
        item {
            SectionHeader("Quick Actions")
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    QuickActionCard(
                        icon = Icons.Filled.MenuBook,
                        label = "Courses",
                        tint = LyoPurple,
                        onClick = { nav.navigate(Routes.COURSES) },
                        modifier = Modifier.weight(1f),
                    )
                    QuickActionCard(
                        icon = Icons.Filled.Explore,
                        label = "Discover",
                        tint = LyoBlue,
                        onClick = { nav.navigate(Routes.DISCOVER) },
                        modifier = Modifier.weight(1f),
                    )
                }
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    QuickActionCard(
                        icon = Icons.Filled.AutoStories,
                        label = "Stories",
                        tint = LyoPink,
                        onClick = { nav.navigate(Routes.STORIES) },
                        modifier = Modifier.weight(1f),
                    )
                    QuickActionCard(
                        icon = Icons.Filled.Groups,
                        label = "Groups",
                        tint = LyoGreen,
                        onClick = { nav.navigate(Routes.GROUPS) },
                        modifier = Modifier.weight(1f),
                    )
                }
            }
        }

        // ── Community activity ──
        item {
            SectionHeader("Community Activity")
        }
        val postList = posts.orEmpty()
        if (postList.isEmpty()) {
            item {
                GlassCard(modifier = Modifier.fillMaxWidth()) {
                    Text(
                        "No community activity yet",
                        style = MaterialTheme.typography.bodyMedium,
                        color = TextSecondary,
                        modifier = Modifier
                            .align(Alignment.CenterHorizontally)
                            .padding(24.dp),
                    )
                }
            }
        } else {
            itemsIndexed(postList) { _, post ->
                PostCard(
                    post = post,
                    onClick = { nav.navigate(Routes.postDetail(post.idStr)) },
                )
            }
        }

        item { Spacer(Modifier.height(8.dp)) }
    }
}

// ── Private sub-composables ──────────────────────────────────────────────────

@Composable
private fun StatCard(
    emoji: String,
    value: String,
    label: String,
    accent: Color,
    modifier: Modifier = Modifier,
) {
    GlassCard(modifier = modifier) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            modifier = Modifier
                .fillMaxWidth()
                .padding(vertical = 16.dp, horizontal = 8.dp),
        ) {
            Text(emoji, style = MaterialTheme.typography.headlineSmall)
            Text(
                value,
                style = MaterialTheme.typography.headlineMedium,
                color = accent,
                modifier = Modifier.padding(top = 6.dp),
            )
            Text(
                label,
                style = MaterialTheme.typography.labelMedium,
                color = TextSecondary,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.padding(top = 2.dp),
            )
        }
    }
}

@Composable
private fun CourseCard(
    course: CourseDto,
    gradient: Brush,
    onClick: () -> Unit,
) {
    GlassCard(
        modifier = Modifier
            .width(200.dp)
            .clickable(onClick = onClick),
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(72.dp)
                .clip(RoundedCornerShape(topStart = 20.dp, topEnd = 20.dp))
                .background(gradient),
        )
        Column(modifier = Modifier.padding(12.dp)) {
            Text(
                course.title ?: "Untitled Course",
                style = MaterialTheme.typography.titleMedium,
                color = TextPrimary,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
            )
            Text(
                course.subject ?: "General",
                style = MaterialTheme.typography.labelMedium,
                color = TextSecondary,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.padding(top = 4.dp),
            )
        }
    }
}

@Composable
private fun QuickActionCard(
    icon: ImageVector,
    label: String,
    tint: Color,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    GlassCard(modifier = modifier.clickable(onClick = onClick)) {
        Column(modifier = Modifier.padding(16.dp)) {
            Icon(icon, contentDescription = label, tint = tint, modifier = Modifier.size(24.dp))
            Text(
                label,
                style = MaterialTheme.typography.titleSmall,
                color = TextPrimary,
                modifier = Modifier.padding(top = 8.dp),
            )
        }
    }
}

@Composable
private fun PostCard(
    post: PostDto,
    onClick: () -> Unit,
) {
    val authorName = post.authorName ?: post.authorUsername ?: "User"
    GlassCard(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick),
    ) {
        Column(modifier = Modifier.padding(14.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                LyoAvatar(name = authorName, avatarUrl = post.authorAvatar, size = 36)
                Column(
                    modifier = Modifier
                        .weight(1f)
                        .padding(start = 10.dp),
                ) {
                    Text(
                        authorName,
                        style = MaterialTheme.typography.titleSmall,
                        color = TextPrimary,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                    Text(
                        formatTimeAgo(post.createdAt),
                        style = MaterialTheme.typography.labelSmall,
                        color = TextSecondary,
                    )
                }
            }
            post.content?.takeIf { it.isNotBlank() }?.let {
                Text(
                    it,
                    style = MaterialTheme.typography.bodyMedium,
                    color = TextSecondary,
                    maxLines = 3,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.padding(top = 8.dp),
                )
            }
            Row(modifier = Modifier.padding(top = 8.dp)) {
                Text(
                    "❤ ${post.likeCount ?: 0}",
                    style = MaterialTheme.typography.labelMedium,
                    color = TextSecondary,
                )
                Text(
                    "💬 ${post.commentCount ?: 0}",
                    style = MaterialTheme.typography.labelMedium,
                    color = TextSecondary,
                    modifier = Modifier.padding(start = 16.dp),
                )
            }
        }
    }
}
