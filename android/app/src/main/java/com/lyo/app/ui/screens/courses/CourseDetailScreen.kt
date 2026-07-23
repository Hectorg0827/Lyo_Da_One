package com.lyo.app.ui.screens.courses

import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.navigation.NavHostController
import com.lyo.app.data.api.ApiClient
import com.lyo.app.data.api.CourseDto
import com.lyo.app.data.api.CourseProgressDto
import com.lyo.app.data.api.LearningProgressClient
import com.lyo.app.data.api.LessonDto
import com.lyo.app.ui.components.EmptyState
import com.lyo.app.ui.components.GlassCard
import com.lyo.app.ui.components.LoadingBox
import com.lyo.app.ui.theme.Background
import com.lyo.app.ui.theme.BorderColor
import com.lyo.app.ui.theme.LyoPurple
import com.lyo.app.ui.theme.Surface
import com.lyo.app.ui.theme.TextPrimary
import com.lyo.app.ui.theme.TextSecondary
import kotlinx.coroutines.launch

private data class CourseLesson(
    val moduleTitle: String?,
    val lesson: LessonDto,
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CourseDetailScreen(nav: NavHostController, courseId: String) {
    var course by remember(courseId) { mutableStateOf<CourseDto?>(null) }
    var courseError by remember(courseId) { mutableStateOf<String?>(null) }
    var progressError by remember(courseId) { mutableStateOf<String?>(null) }
    var serverProgress by remember(courseId) { mutableStateOf<CourseProgressDto?>(null) }
    var completedIds by remember(courseId) { mutableStateOf<Set<String>>(emptySet()) }
    var activeIndex by remember(courseId) { mutableStateOf(0) }
    var savingLessonId by remember(courseId) { mutableStateOf<String?>(null) }
    var actionError by remember(courseId) { mutableStateOf<String?>(null) }
    var reloadKey by remember { mutableStateOf(0) }
    val scope = rememberCoroutineScope()

    val lessons = remember(course) { flattenLessons(course) }

    LaunchedEffect(courseId, reloadKey) {
        course = null
        courseError = null
        progressError = null
        serverProgress = null
        completedIds = emptySet()
        activeIndex = 0

        try {
            val loadedCourse = ApiClient.api.course(courseId)
            val loadedLessons = flattenLessons(loadedCourse)
            course = loadedCourse

            runCatching { LearningProgressClient.getCourseProgress(courseId) }
                .onSuccess { progress ->
                    serverProgress = progress
                    completedIds = completionIdsFromProgress(loadedLessons, progress)
                    activeIndex = resumeIndex(loadedLessons, progress)
                }
                .onFailure { error ->
                    progressError = error.message ?: "Saved progress is temporarily unavailable."
                }
        } catch (error: Exception) {
            courseError = error.message ?: "Unable to load this course."
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Background),
    ) {
        TopAppBar(
            title = {
                Text(
                    text = course?.title ?: "Course",
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            },
            navigationIcon = {
                IconButton(onClick = { nav.popBackStack() }) {
                    Icon(
                        imageVector = Icons.AutoMirrored.Filled.ArrowBack,
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
            courseError != null -> Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                modifier = Modifier.fillMaxSize(),
            ) {
                EmptyState(
                    title = "Unable to open course",
                    subtitle = courseError ?: "The course could not be loaded.",
                    modifier = Modifier.weight(1f),
                )
                Button(
                    onClick = { reloadKey += 1 },
                    modifier = Modifier.padding(20.dp),
                ) {
                    Text("Try again")
                }
            }

            course == null -> LoadingBox()

            lessons.isEmpty() -> EmptyState(
                title = "No lessons available",
                subtitle = "This course does not contain playable lesson content yet.",
            )

            else -> {
                val currentIndex = activeIndex.coerceIn(0, lessons.lastIndex)
                val activeLesson = lessons[currentIndex]
                val activeLessonId = activeLesson.lesson.idString
                val activeCompleted = activeLessonId.isNotBlank() && activeLessonId in completedIds
                val lastLesson = currentIndex == lessons.lastIndex
                val progressValue = serverProgress?.normalizedProgress
                    ?: (completedIds.size.toFloat() / lessons.size.toFloat()).coerceIn(0f, 1f)

                LazyColumn(
                    contentPadding = PaddingValues(start = 16.dp, end = 16.dp, bottom = 20.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp),
                    modifier = Modifier.weight(1f),
                ) {
                    item {
                        CourseSummary(
                            course = course!!,
                            completed = completedIds.size.coerceAtMost(lessons.size),
                            total = lessons.size,
                            progress = progressValue,
                        )
                    }

                    progressError?.let { message ->
                        item { StatusBanner("Saved progress could not be loaded. $message", false) }
                    }
                    actionError?.let { message ->
                        item { StatusBanner(message, true) }
                    }

                    item {
                        Text(
                            text = "Course outline",
                            style = MaterialTheme.typography.titleLarge,
                            color = TextPrimary,
                        )
                    }

                    itemsIndexed(lessons) { index, lesson ->
                        OutlineRow(
                            index = index,
                            item = lesson,
                            selected = index == currentIndex,
                            completed = lesson.lesson.idString in completedIds,
                            onClick = {
                                activeIndex = index
                                actionError = null
                            },
                        )
                    }

                    item {
                        LessonCard(
                            item = activeLesson,
                            index = currentIndex,
                            total = lessons.size,
                        )
                    }
                }

                NavigationBar(
                    currentIndex = currentIndex,
                    total = lessons.size,
                    completed = activeCompleted,
                    saving = savingLessonId == activeLessonId,
                    onPrevious = {
                        if (currentIndex > 0) {
                            activeIndex = currentIndex - 1
                            actionError = null
                        }
                    },
                    onPrimary = {
                        actionError = null
                        when {
                            activeCompleted && !lastLesson -> activeIndex = currentIndex + 1
                            activeCompleted && lastLesson -> Unit
                            activeLessonId.isBlank() -> {
                                actionError = "This lesson is missing a stable ID, so completion cannot be saved."
                            }
                            savingLessonId == null -> {
                                val previousIds = completedIds
                                completedIds = completedIds + activeLessonId
                                savingLessonId = activeLessonId

                                scope.launch {
                                    try {
                                        LearningProgressClient.markLessonComplete(activeLessonId)
                                        runCatching { LearningProgressClient.getCourseProgress(courseId) }
                                            .onSuccess { refreshed ->
                                                serverProgress = refreshed
                                                completedIds = completedIds +
                                                    completionIdsFromProgress(lessons, refreshed)
                                                progressError = null
                                            }
                                            .onFailure { error ->
                                                progressError = error.message
                                                    ?: "Progress will refresh when the course opens again."
                                            }
                                        if (!lastLesson) activeIndex = currentIndex + 1
                                    } catch (error: Exception) {
                                        completedIds = previousIds
                                        actionError = error.message ?: "Unable to save lesson completion."
                                    } finally {
                                        savingLessonId = null
                                    }
                                }
                            }
                        }
                    },
                )
            }
        }
    }
}

@Composable
private fun CourseSummary(
    course: CourseDto,
    completed: Int,
    total: Int,
    progress: Float,
) {
    GlassCard(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(18.dp)) {
            Text(
                text = course.title ?: "Untitled course",
                style = MaterialTheme.typography.headlineSmall,
                color = TextPrimary,
            )
            course.description?.takeIf { it.isNotBlank() }?.let { description ->
                Text(
                    text = description,
                    style = MaterialTheme.typography.bodyMedium,
                    color = TextSecondary,
                    modifier = Modifier.padding(top = 8.dp),
                )
            }
            Row(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                modifier = Modifier.padding(top = 12.dp),
            ) {
                course.subject?.takeIf { it.isNotBlank() }?.let { TagChip(it) }
                course.difficulty?.takeIf { it.isNotBlank() }?.let { TagChip(it) }
            }
            Row(
                horizontalArrangement = Arrangement.SpaceBetween,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 18.dp, bottom = 8.dp),
            ) {
                Text(
                    text = "$completed of $total lessons complete",
                    style = MaterialTheme.typography.labelMedium,
                    color = TextSecondary,
                )
                Text(
                    text = "${(progress * 100).toInt()}%",
                    style = MaterialTheme.typography.labelMedium,
                    color = LyoPurple,
                    fontWeight = FontWeight.Bold,
                )
            }
            LinearProgressIndicator(
                progress = { progress },
                color = LyoPurple,
                trackColor = Surface,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(7.dp)
                    .clip(CircleShape),
            )
        }
    }
}

@Composable
private fun OutlineRow(
    index: Int,
    item: CourseLesson,
    selected: Boolean,
    completed: Boolean,
    onClick: () -> Unit,
) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(if (selected) LyoPurple.copy(alpha = 0.14f) else Surface.copy(alpha = 0.55f))
            .border(
                width = 1.dp,
                color = if (selected) LyoPurple.copy(alpha = 0.55f) else BorderColor,
                shape = RoundedCornerShape(16.dp),
            )
            .clickable(onClick = onClick)
            .padding(14.dp),
    ) {
        Box(
            contentAlignment = Alignment.Center,
            modifier = Modifier
                .size(34.dp)
                .clip(CircleShape)
                .background(if (completed) LyoPurple else Background),
        ) {
            when {
                completed -> Icon(
                    imageVector = Icons.Default.Check,
                    contentDescription = "Completed",
                    tint = Color.White,
                    modifier = Modifier.size(19.dp),
                )
                selected -> Icon(
                    imageVector = Icons.Default.PlayArrow,
                    contentDescription = "Current lesson",
                    tint = LyoPurple,
                    modifier = Modifier.size(20.dp),
                )
                else -> Text(
                    text = "${index + 1}",
                    style = MaterialTheme.typography.labelLarge,
                    color = TextSecondary,
                )
            }
        }

        Column(
            modifier = Modifier
                .weight(1f)
                .padding(horizontal = 12.dp),
        ) {
            item.moduleTitle?.takeIf { it.isNotBlank() }?.let { module ->
                Text(
                    text = module,
                    style = MaterialTheme.typography.labelSmall,
                    color = TextSecondary,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
            Text(
                text = item.lesson.title ?: "Lesson ${index + 1}",
                style = MaterialTheme.typography.titleMedium,
                color = TextPrimary,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
            )
        }

        Icon(
            imageVector = Icons.Default.ChevronRight,
            contentDescription = null,
            tint = if (selected) LyoPurple else TextSecondary,
        )
    }
}

@Composable
private fun LessonCard(item: CourseLesson, index: Int, total: Int) {
    GlassCard(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(20.dp)) {
            Text(
                text = "LESSON ${index + 1} OF $total",
                style = MaterialTheme.typography.labelSmall,
                color = LyoPurple,
                fontWeight = FontWeight.Bold,
            )
            item.moduleTitle?.takeIf { it.isNotBlank() }?.let { module ->
                Text(
                    text = module,
                    style = MaterialTheme.typography.labelMedium,
                    color = TextSecondary,
                    modifier = Modifier.padding(top = 8.dp),
                )
            }
            Text(
                text = item.lesson.title ?: "Lesson ${index + 1}",
                style = MaterialTheme.typography.headlineSmall,
                color = TextPrimary,
                modifier = Modifier.padding(top = 6.dp),
            )
            val content = item.lesson.content?.takeIf { it.isNotBlank() }
            Text(
                text = content ?: "This lesson does not have readable content yet.",
                style = MaterialTheme.typography.bodyLarge,
                color = if (content == null) TextSecondary else TextPrimary,
                modifier = Modifier.padding(top = 18.dp),
            )
        }
    }
}

@Composable
private fun NavigationBar(
    currentIndex: Int,
    total: Int,
    completed: Boolean,
    saving: Boolean,
    onPrevious: () -> Unit,
    onPrimary: () -> Unit,
) {
    val last = currentIndex == total - 1
    Row(
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .background(Surface)
            .border(1.dp, BorderColor)
            .padding(horizontal = 16.dp, vertical = 14.dp),
    ) {
        OutlinedButton(
            onClick = onPrevious,
            enabled = currentIndex > 0 && !saving,
            modifier = Modifier.weight(1f),
        ) {
            Text("Previous")
        }
        Button(
            onClick = onPrimary,
            enabled = !saving && !(completed && last),
            colors = ButtonDefaults.buttonColors(containerColor = LyoPurple),
            modifier = Modifier.weight(1.5f),
        ) {
            if (saving) {
                CircularProgressIndicator(
                    color = Color.White,
                    strokeWidth = 2.dp,
                    modifier = Modifier.size(18.dp),
                )
                Spacer(Modifier.width(8.dp))
                Text("Saving")
            } else {
                Text(
                    text = when {
                        completed && last -> "Course complete"
                        completed -> "Next lesson"
                        last -> "Complete course"
                        else -> "Complete & next"
                    },
                )
            }
        }
    }
}

@Composable
private fun StatusBanner(message: String, isError: Boolean) {
    Text(
        text = message,
        style = MaterialTheme.typography.bodySmall,
        color = if (isError) Color(0xFFFCA5A5) else TextSecondary,
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(if (isError) Color(0xFF7F1D1D).copy(alpha = 0.24f) else Surface)
            .padding(12.dp),
    )
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

private fun flattenLessons(course: CourseDto?): List<CourseLesson> {
    if (course == null) return emptyList()
    val moduleLessons = course.modules.orEmpty().flatMap { module ->
        module.lessons.orEmpty()
            .sortedBy { it.orderIndex ?: Int.MAX_VALUE }
            .map { CourseLesson(module.title, it) }
    }
    if (moduleLessons.isNotEmpty()) return moduleLessons
    return course.lessons.orEmpty()
        .sortedBy { it.orderIndex ?: Int.MAX_VALUE }
        .map { CourseLesson(null, it) }
}

private fun completionIdsFromProgress(
    lessons: List<CourseLesson>,
    progress: CourseProgressDto,
): Set<String> {
    val knownLessonIds = lessons
        .map { it.lesson.idString }
        .filter { it.isNotBlank() }
        .toSet()
    val canonicalIds = progress.completedLessonIdStrings.intersect(knownLessonIds)

    // New backends return exact completion IDs. The ordered-count fallback is
    // retained only for deployments that predate the canonical ID field.
    if (canonicalIds.isNotEmpty() || progress.completedLessons == 0) {
        return canonicalIds
    }

    return lessons
        .take(progress.completedLessons.coerceIn(0, lessons.size))
        .map { it.lesson.idString }
        .filter { it.isNotBlank() }
        .toSet()
}

private fun resumeIndex(lessons: List<CourseLesson>, progress: CourseProgressDto): Int {
    if (lessons.isEmpty()) return 0
    val current = progress.currentLessonIdStr?.let { id ->
        lessons.indexOfFirst { it.lesson.idString == id }.takeIf { it >= 0 }
    }
    return current ?: progress.completedLessons.coerceIn(0, lessons.lastIndex)
}

private val LessonDto.idString: String
    get() = id?.toString()?.removeSuffix(".0") ?: ""
