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
import androidx.compose.material.icons.filled.Email
import androidx.compose.material.icons.filled.MenuBook
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.SmartToy
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
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.navigation.NavHostController
import com.google.gson.JsonObject
import com.lyo.app.data.RecentCourseStore
import com.lyo.app.data.Session
import com.lyo.app.data.api.ApiClient
import com.lyo.app.data.api.CourseDto
import com.lyo.app.ui.components.CardGradients
import com.lyo.app.ui.components.GlassCard
import com.lyo.app.ui.components.LoadingBox
import com.lyo.app.ui.components.SectionHeader
import com.lyo.app.ui.navigation.Routes
import com.lyo.app.ui.theme.LyoAmber
import com.lyo.app.ui.theme.LyoBlue
import com.lyo.app.ui.theme.LyoGreen
import com.lyo.app.ui.theme.LyoPurple
import com.lyo.app.ui.theme.TextPrimary
import com.lyo.app.ui.theme.TextSecondary

@Composable
fun HomeScreen(nav: NavHostController) {
    val context = LocalContext.current
    var overview by remember { mutableStateOf<JsonObject?>(null) }
    var featuredCourses by remember { mutableStateOf<List<CourseDto>>(emptyList()) }
    var recentCourseId by remember { mutableStateOf<String?>(null) }
    var recentCourse by remember { mutableStateOf<CourseDto?>(null) }
    var catalogError by remember { mutableStateOf<String?>(null) }
    var recentCourseUnavailable by remember { mutableStateOf(false) }
    var loaded by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) {
        val storedRecent = RecentCourseStore.load(context)
        recentCourseId = storedRecent?.id

        runCatching { ApiClient.api.gamificationOverview() }
            .onSuccess { overview = it }

        runCatching { ApiClient.api.courses(0, 5) }
            .onSuccess {
                featuredCourses = it
                catalogError = null
            }
            .onFailure {
                catalogError = it.localizedMessage ?: "The course catalog is unavailable."
            }

        if (storedRecent != null) {
            runCatching { ApiClient.api.course(storedRecent.id) }
                .onSuccess {
                    recentCourse = it
                    recentCourseUnavailable = false
                }
                .onFailure {
                    recentCourseUnavailable = true
                }
        }

        loaded = true
    }

    if (!loaded) {
        LoadingBox()
        return
    }

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

        item {
            SectionHeader("Your Learning")
            when {
                recentCourse != null -> RecentCourseCard(
                    title = recentCourse?.title ?: "Course",
                    subtitle = "Recent on this device · account progress refreshes when opened",
                    onClick = {
                        recentCourseId?.let { nav.navigate(Routes.courseDetail(it)) }
                    },
                )
                recentCourseId != null && recentCourseUnavailable -> RecentCourseCard(
                    title = "Recent course",
                    subtitle = "Course details are temporarily unavailable. Open it to retry.",
                    onClick = {
                        recentCourseId?.let { nav.navigate(Routes.courseDetail(it)) }
                    },
                )
                else -> EmptyLearningCard(
                    onClick = { nav.navigate(Routes.COURSES) },
                )
            }
        }

        item {
            SectionHeader("Explore Courses")
            when {
                featuredCourses.isNotEmpty() -> {
                    LazyRow(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        itemsIndexed(featuredCourses) { index, course ->
                            CatalogCourseCard(
                                course = course,
                                gradient = CardGradients[index % CardGradients.size],
                                onClick = { nav.navigate(Routes.courseDetail(course.idStr)) },
                            )
                        }
                    }
                }
                catalogError != null -> GlassCard(modifier = Modifier.fillMaxWidth()) {
                    Column(modifier = Modifier.padding(18.dp)) {
                        Text(
                            text = "Course catalog unavailable",
                            style = MaterialTheme.typography.titleMedium,
                            color = TextPrimary,
                        )
                        Text(
                            text = catalogError ?: "The course catalog could not be loaded.",
                            style = MaterialTheme.typography.bodySmall,
                            color = TextSecondary,
                            modifier = Modifier.padding(top = 4.dp),
                        )
                    }
                }
                else -> GlassCard(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { nav.navigate(Routes.COURSES) },
                ) {
                    Column(modifier = Modifier.padding(18.dp)) {
                        Text(
                            text = "No published courses",
                            style = MaterialTheme.typography.titleMedium,
                            color = TextPrimary,
                        )
                        Text(
                            text = "Open Courses to check for newly published learning content.",
                            style = MaterialTheme.typography.bodySmall,
                            color = TextSecondary,
                            modifier = Modifier.padding(top = 4.dp),
                        )
                    }
                }
            }
        }

        item {
            SectionHeader("Learning Actions")
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                QuickActionCard(
                    icon = Icons.Filled.MenuBook,
                    label = "Browse Courses",
                    tint = LyoPurple,
                    onClick = { nav.navigate(Routes.COURSES) },
                    modifier = Modifier.weight(1f),
                )
                QuickActionCard(
                    icon = Icons.Filled.SmartToy,
                    label = "Ask Lyo",
                    tint = LyoBlue,
                    onClick = { nav.navigate(Routes.CHAT) },
                    modifier = Modifier.weight(1f),
                )
            }
        }

        item { Spacer(Modifier.height(8.dp)) }
    }
}

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
                text = value,
                style = MaterialTheme.typography.headlineMedium,
                color = accent,
                modifier = Modifier.padding(top = 6.dp),
            )
            Text(
                text = label,
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
private fun RecentCourseCard(
    title: String,
    subtitle: String,
    onClick: () -> Unit,
) {
    GlassCard(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick),
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.padding(18.dp),
        ) {
            Box(
                contentAlignment = Alignment.Center,
                modifier = Modifier
                    .size(48.dp)
                    .clip(RoundedCornerShape(14.dp))
                    .background(LyoPurple.copy(alpha = 0.18f)),
            ) {
                Icon(
                    Icons.Filled.PlayArrow,
                    contentDescription = null,
                    tint = LyoPurple,
                )
            }
            Column(
                modifier = Modifier
                    .weight(1f)
                    .padding(start = 14.dp),
            ) {
                Text(
                    text = title,
                    style = MaterialTheme.typography.titleMedium,
                    color = TextPrimary,
                    fontWeight = FontWeight.Bold,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                )
                Text(
                    text = subtitle,
                    style = MaterialTheme.typography.bodySmall,
                    color = TextSecondary,
                    modifier = Modifier.padding(top = 4.dp),
                )
            }
        }
    }
}

@Composable
private fun EmptyLearningCard(onClick: () -> Unit) {
    GlassCard(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick),
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            modifier = Modifier
                .fillMaxWidth()
                .padding(24.dp),
        ) {
            Text(
                text = "No recent course on this device",
                style = MaterialTheme.typography.titleMedium,
                color = TextPrimary,
            )
            Text(
                text = "Open a real course from Explore. Focus will remember the course ID and refresh account progress when you return.",
                style = MaterialTheme.typography.bodySmall,
                color = TextSecondary,
                modifier = Modifier.padding(top = 5.dp),
            )
        }
    }
}

@Composable
private fun CatalogCourseCard(
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
                text = course.title ?: "Untitled Course",
                style = MaterialTheme.typography.titleMedium,
                color = TextPrimary,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
            )
            Text(
                text = course.subject ?: "General",
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
                text = label,
                style = MaterialTheme.typography.titleSmall,
                color = TextPrimary,
                modifier = Modifier.padding(top = 8.dp),
            )
        }
    }
}
