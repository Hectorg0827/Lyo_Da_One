package com.lyo.app.ui.screens.courses

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
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.navigation.NavHostController
import com.lyo.app.data.api.ApiClient
import com.lyo.app.data.api.CourseDto
import com.lyo.app.data.api.LessonDto
import com.lyo.app.ui.components.CardGradients
import com.lyo.app.ui.components.EmptyState
import com.lyo.app.ui.components.GlassCard
import com.lyo.app.ui.components.LoadingBox
import com.lyo.app.ui.components.LyoBrandGradient
import com.lyo.app.ui.theme.Background
import com.lyo.app.ui.theme.BorderColor
import com.lyo.app.ui.theme.LyoPurple
import com.lyo.app.ui.theme.Surface
import com.lyo.app.ui.theme.TextPrimary
import com.lyo.app.ui.theme.TextSecondary

private val CourseEmojis = listOf("📚", "🧠", "🎨", "🐍", "🎵", "⚛️")

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CourseDetailScreen(nav: NavHostController, courseId: String) {
    var course by remember { mutableStateOf<CourseDto?>(null) }
    var failed by remember { mutableStateOf(false) }
    var expandedLesson by remember { mutableStateOf(0) }

    LaunchedEffect(courseId) {
        runCatching { ApiClient.api.course(courseId) }
            .onSuccess { course = it }
            .onFailure { failed = true }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Background),
    ) {
        TopAppBar(
            title = { Text(course?.title ?: "Course") },
            navigationIcon = {
                IconButton(onClick = { nav.popBackStack() }) {
                    Icon(
                        Icons.AutoMirrored.Filled.ArrowBack,
                        contentDescription = "Back",
                        tint = TextPrimary,
                    )
                }
            },
            colors = TopAppBarDefaults.topAppBarColors(
                containerColor = Background,
                titleContentColor = TextPrimary,
            ),
        )

        when {
            failed -> EmptyState(
                title = "Course not found",
                subtitle = "This course may have been removed.",
            )

            course == null -> LoadingBox()

            else -> {
                val c = course!!
                // Flatten modules → lessons, else use plain lessons
                val lessons: List<Pair<String?, LessonDto>> =
                    c.modules?.flatMap { module ->
                        (module.lessons ?: emptyList()).map { module.title to it }
                    }?.takeIf { it.isNotEmpty() }
                        ?: (c.lessons ?: emptyList()).map { null to it }

                LazyColumn(
                    contentPadding = PaddingValues(16.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp),
                    modifier = Modifier.fillMaxSize(),
                ) {
                    // Hero banner
                    item {
                        Box(
                            contentAlignment = Alignment.Center,
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(140.dp)
                                .clip(RoundedCornerShape(20.dp))
                                .background(CardGradients[(c.idStr.hashCode().mod(CardGradients.size))]),
                        ) {
                            Text(
                                text = CourseEmojis[(c.idStr.hashCode().mod(CourseEmojis.size))],
                                fontSize = 56.sp,
                            )
                        }
                    }

                    item {
                        Column {
                            Text(
                                text = c.title ?: "Untitled course",
                                style = MaterialTheme.typography.headlineMedium,
                                color = TextPrimary,
                            )
                            if (!c.description.isNullOrBlank()) {
                                Text(
                                    text = c.description,
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = TextSecondary,
                                    modifier = Modifier.padding(top = 6.dp),
                                )
                            }
                            Row(
                                horizontalArrangement = Arrangement.spacedBy(8.dp),
                                modifier = Modifier.padding(top = 10.dp),
                            ) {
                                c.subject?.let { TagChip(it) }
                                c.difficulty?.let { TagChip(it) }
                            }
                        }
                    }

                    // Start Learning CTA
                    item {
                        Box(
                            contentAlignment = Alignment.Center,
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(50.dp)
                                .clip(RoundedCornerShape(14.dp))
                                .background(LyoBrandGradient)
                                .clickable { expandedLesson = 0 },
                        ) {
                            Text(
                                text = "Start Learning",
                                color = Color.White,
                                style = MaterialTheme.typography.titleMedium,
                            )
                        }
                    }

                    if (lessons.isEmpty()) {
                        item {
                            EmptyState(
                                title = "No lessons yet",
                                subtitle = "Lesson content is still being generated.",
                            )
                        }
                    } else {
                        item {
                            Text(
                                text = "Lessons",
                                style = MaterialTheme.typography.headlineSmall,
                                color = TextPrimary,
                                modifier = Modifier.padding(top = 8.dp),
                            )
                        }
                        itemsIndexed(lessons) { index, (moduleTitle, lesson) ->
                            LessonRow(
                                index = index,
                                moduleTitle = moduleTitle,
                                lesson = lesson,
                                expanded = expandedLesson == index,
                                onToggle = {
                                    expandedLesson = if (expandedLesson == index) -1 else index
                                },
                            )
                        }
                    }

                    item { Spacer(Modifier.height(24.dp)) }
                }
            }
        }
    }
}

@Composable
private fun TagChip(label: String) {
    Text(
        text = label,
        style = MaterialTheme.typography.labelMedium,
        color = LyoPurple,
        modifier = Modifier
            .clip(RoundedCornerShape(50))
            .background(LyoPurple.copy(alpha = 0.15f))
            .padding(horizontal = 10.dp, vertical = 4.dp),
    )
}

@Composable
private fun LessonRow(
    index: Int,
    moduleTitle: String?,
    lesson: LessonDto,
    expanded: Boolean,
    onToggle: () -> Unit,
) {
    GlassCard(
        modifier = Modifier
            .fillMaxWidth()
            .clickable { onToggle() },
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.padding(14.dp),
        ) {
            Box(
                contentAlignment = Alignment.Center,
                modifier = Modifier
                    .size(32.dp)
                    .clip(CircleShape)
                    .background(if (expanded) LyoPurple else Surface),
            ) {
                Text(
                    text = "${index + 1}",
                    style = MaterialTheme.typography.labelLarge,
                    color = if (expanded) Color.White else TextSecondary,
                )
            }
            Column(modifier = Modifier.padding(start = 12.dp)) {
                if (moduleTitle != null) {
                    Text(
                        text = moduleTitle,
                        style = MaterialTheme.typography.labelSmall,
                        color = TextSecondary,
                    )
                }
                Text(
                    text = lesson.title ?: "Lesson ${index + 1}",
                    style = MaterialTheme.typography.titleMedium,
                    color = TextPrimary,
                )
            }
        }
        if (expanded) {
            Text(
                text = lesson.content?.takeIf { it.isNotBlank() }
                    ?: "Content coming soon.",
                style = MaterialTheme.typography.bodyMedium,
                color = TextSecondary,
                modifier = Modifier.padding(start = 14.dp, end = 14.dp, bottom = 14.dp),
            )
        }
    }
}
