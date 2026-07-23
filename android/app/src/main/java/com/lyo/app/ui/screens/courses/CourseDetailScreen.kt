package com.lyo.app.ui.screens.courses

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
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
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
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
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.navigation.NavHostController
import com.lyo.app.data.TokenManager
import com.lyo.app.data.api.ApiClient
import com.lyo.app.data.api.CourseDto
import com.lyo.app.data.api.CourseProgressDto
import com.lyo.app.data.api.LessonCompletionRequest
import com.lyo.app.data.api.LessonDto
import com.lyo.app.ui.components.CardGradients
import com.lyo.app.ui.components.EmptyState
import com.lyo.app.ui.components.GlassCard
import com.lyo.app.ui.components.LoadingBox
import com.lyo.app.ui.theme.Background
import com.lyo.app.ui.theme.LyoPurple
import com.lyo.app.ui.theme.Surface
import com.lyo.app.ui.theme.TextPrimary
import com.lyo.app.ui.theme.TextSecondary
import kotlinx.coroutines.launch
import retrofit2.HttpException

private enum class CourseMode { OVERVIEW, PLAYER }

private val courseEmojis = listOf("📚", "🧠", "🎨", "🐍", "🎵", "⚛️")

private data class CourseLessonItem(
    val moduleTitle: String?,
    val lesson: LessonDto,
) {
    val lessonId: String?
        get() {
            val value = lesson.id?.toString()?.removeSuffix(".0") ?: return null
            return value.takeIf { it.isNotBlank() }
        }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CourseDetailScreen(nav: NavHostController, courseId: String) {
    var course by remember(courseId) { mutableStateOf<CourseDto?>(null) }
    var progress by remember(courseId) { mutableStateOf<CourseProgressDto?>(null) }
    var mode by remember(courseId) { mutableStateOf(CourseMode.OVERVIEW) }
    var activeLessonIndex by remember(courseId) { mutableStateOf(0) }
    var localCompletedIds by remember(courseId) { mutableStateOf(emptySet<String>()) }
    var savingLessonId by remember(courseId) { mutableStateOf<String?>(null) }
    var loading by remember(courseId) { mutableStateOf(true) }
    var loadError by remember(courseId) { mutableStateOf<String?>(null) }
    var progressWarning by remember(courseId) { mutableStateOf<String?>(null) }
    var actionError by remember(courseId) { mutableStateOf<String?>(null) }
    var reloadKey by remember(courseId) { mutableStateOf(0) }

    val scope = rememberCoroutineScope()
    val lessons = remember(course) { course?.flattenLessons().orEmpty() }

    LaunchedEffect(courseId, reloadKey) {
        loading = true
        loadError = null
        progressWarning = null
        actionError = null

        val loadedCourse = try {
            ApiClient.api.course(courseId)
        } catch (error: Throwable) {
            loadError = error.learningMessage("Unable to load this course.")
            loading = false
            return@LaunchedEffect
        }

        course = loadedCourse
        val loadedLessons = loadedCourse.flattenLessons()

        try {
            val serverProgress = ApiClient.learning.courseProgress(courseId)
            progress = serverProgress
            val currentId = serverProgress.currentLessonIdString
            val currentIndex = if (currentId == null) {
                -1
            } else {
                loadedLessons.indexOfFirst { it.lessonId == currentId }
            }
            activeLessonIndex = if (currentIndex >= 0) {
                currentIndex
            } else {
                serverProgress.completedLessons.coerceIn(
                    0,
                    (loadedLessons.size - 1).coerceAtLeast(0),
                )
            }
        } catch (error: Throwable) {
            progressWarning = error.learningMessage(
                "Saved progress is unavailable. You can still open this course.",
            )
        }

        loading = false
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Background),
    ) {
        TopAppBar(
            title = {
                Text(
                    text = if (mode == CourseMode.PLAYER) "Classroom" else course?.title ?: "Course",
                    maxLines = 1,
                )
            },
            navigationIcon = {
                IconButton(
                    onClick = {
                        if (mode == CourseMode.PLAYER) {
                            mode = CourseMode.OVERVIEW
                        } else {
                            nav.popBackStack()
                        }
                    },
                ) {
                    Icon(
                        Icons.AutoMirrored.Filled.ArrowBack,
                        contentDescription = if (mode == CourseMode.PLAYER) "Back to course" else "Back",
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
            loading -> LoadingBox()
            loadError != null -> LoadFailure(loadError!!) { reloadKey += 1 }
            course == null -> LoadFailure("Course data is unavailable.") { reloadKey += 1 }
            mode == CourseMode.OVERVIEW -> CourseOverview(
                course = course!!,
                lessons = lessons,
                progress = progress,
                localCompletedIds = localCompletedIds,
                progressWarning = progressWarning,
                onStart = {
                    if (lessons.isNotEmpty()) mode = CourseMode.PLAYER
                },
                onSelectLesson = { index ->
                    activeLessonIndex = index
                    actionError = null
                    mode = CourseMode.PLAYER
                },
            )
            else -> CoursePlayer(
                course = course!!,
                lessons = lessons,
                progress = progress,
                localCompletedIds = localCompletedIds,
                activeLessonIndex = activeLessonIndex.coerceIn(
                    0,
                    (lessons.size - 1).coerceAtLeast(0),
                ),
                savingLessonId = savingLessonId,
                progressWarning = progressWarning,
                actionError = actionError,
                onSelectLesson = { index ->
                    if (savingLessonId == null) {
                        activeLessonIndex = index
                        actionError = null
                    }
                },
                onPrevious = {
                    if (savingLessonId == null && activeLessonIndex > 0) {
                        activeLessonIndex -= 1
                        actionError = null
                    }
                },
                onPrimary = { index, lessonItem ->
                    val serverCompleted = progress?.completedLessons ?: 0
                    val alreadyCompleted = isLessonCompleted(
                        index,
                        lessonItem,
                        serverCompleted,
                        localCompletedIds,
                    )

                    if (alreadyCompleted) {
                        if (index < lessons.lastIndex) {
                            activeLessonIndex = index + 1
                        } else {
                            mode = CourseMode.OVERVIEW
                        }
                        actionError = null
                    } else {
                        val lessonId = lessonItem.lessonId
                        if (lessonId == null) {
                            actionError = "This lesson does not have a persistent ID, so completion cannot be saved."
                        } else if (TokenManager.accessToken == null) {
                            actionError = "Sign in to save lesson progress across devices."
                        } else if (savingLessonId == null) {
                            val previousLocal = localCompletedIds
                            localCompletedIds = previousLocal + lessonId
                            savingLessonId = lessonId
                            actionError = null

                            scope.launch {
                                try {
                                    ApiClient.learning.markLessonComplete(
                                        LessonCompletionRequest(lessonId = lessonId),
                                    )

                                    try {
                                        progress = ApiClient.learning.courseProgress(courseId)
                                        progressWarning = null
                                    } catch (_: Throwable) {
                                        progressWarning =
                                            "Completion was saved, but the latest course total could not be refreshed."
                                    }

                                    if (index < lessons.lastIndex) {
                                        activeLessonIndex = index + 1
                                    }
                                } catch (error: Throwable) {
                                    localCompletedIds = previousLocal
                                    actionError = error.learningMessage("Unable to save lesson completion.")
                                } finally {
                                    savingLessonId = null
                                }
                            }
                        }
                    }
                },
                onBackToCourse = { mode = CourseMode.OVERVIEW },
            )
        }
    }
}

@Composable
private fun CourseOverview(
    course: CourseDto,
    lessons: List<CourseLessonItem>,
    progress: CourseProgressDto?,
    localCompletedIds: Set<String>,
    progressWarning: String?,
    onStart: () -> Unit,
    onSelectLesson: (Int) -> Unit,
) {
    val completed = resolvedCompletedCount(
        lessons,
        progress?.completedLessons ?: 0,
        localCompletedIds,
    )
    val percent = resolvedProgressPercent(lessons.size, completed, progress)

    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        item {
            Box(
                contentAlignment = Alignment.Center,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(140.dp)
                    .clip(RoundedCornerShape(20.dp))
                    .background(CardGradients[course.idStr.hashCode().mod(CardGradients.size)]),
            ) {
                Text(
                    text = courseEmojis[course.idStr.hashCode().mod(courseEmojis.size)],
                    fontSize = 56.sp,
                )
            }
        }

        item {
            Column {
                Text(
                    text = course.title ?: "Untitled course",
                    style = MaterialTheme.typography.headlineMedium,
                    color = TextPrimary,
                )
                val description = course.description
                if (!description.isNullOrBlank()) {
                    Text(
                        text = description,
                        style = MaterialTheme.typography.bodyMedium,
                        color = TextSecondary,
                        modifier = Modifier.padding(top = 6.dp),
                    )
                }
                Row(
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    modifier = Modifier.padding(top = 10.dp),
                ) {
                    course.subject?.let { TagChip(it) }
                    course.difficulty?.let { TagChip(it) }
                }
            }
        }

        if (progressWarning != null) {
            item { InlineMessage(progressWarning, warning = true) }
        }

        if (lessons.isEmpty()) {
            item {
                EmptyState(
                    title = "No lessons available",
                    subtitle = "This course does not currently contain playable lesson content.",
                )
            }
        } else {
            item { ProgressCard(completed, lessons.size, percent) }
            item {
                Button(
                    onClick = onStart,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(50.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = LyoPurple),
                    shape = RoundedCornerShape(14.dp),
                ) {
                    Icon(Icons.Default.PlayArrow, contentDescription = null)
                    Text(
                        text = if (percent > 0) "Resume Learning" else "Start Learning",
                        modifier = Modifier.padding(start = 8.dp),
                    )
                }
            }
            item {
                Text(
                    text = "Lessons",
                    style = MaterialTheme.typography.headlineSmall,
                    color = TextPrimary,
                    modifier = Modifier.padding(top = 8.dp),
                )
            }
            itemsIndexed(lessons) { index, lessonItem ->
                LessonRow(
                    index = index,
                    lessonItem = lessonItem,
                    completed = isLessonCompleted(
                        index,
                        lessonItem,
                        progress?.completedLessons ?: 0,
                        localCompletedIds,
                    ),
                    current = progress?.currentLessonIdString == lessonItem.lessonId,
                    onClick = { onSelectLesson(index) },
                )
            }
        }
        item { Spacer(Modifier.height(24.dp)) }
    }
}

@Composable
private fun CoursePlayer(
    course: CourseDto,
    lessons: List<CourseLessonItem>,
    progress: CourseProgressDto?,
    localCompletedIds: Set<String>,
    activeLessonIndex: Int,
    savingLessonId: String?,
    progressWarning: String?,
    actionError: String?,
    onSelectLesson: (Int) -> Unit,
    onPrevious: () -> Unit,
    onPrimary: (Int, CourseLessonItem) -> Unit,
    onBackToCourse: () -> Unit,
) {
    if (lessons.isEmpty()) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
        ) {
            EmptyState(
                title = "No playable lessons",
                subtitle = "Return to the course overview and try again later.",
            )
            OutlinedButton(onClick = onBackToCourse) { Text("Back to course") }
        }
        return
    }

    val activeLesson = lessons[activeLessonIndex]
    val completed = resolvedCompletedCount(
        lessons,
        progress?.completedLessons ?: 0,
        localCompletedIds,
    )
    val percent = resolvedProgressPercent(lessons.size, completed, progress)
    val currentCompleted = isLessonCompleted(
        activeLessonIndex,
        activeLesson,
        progress?.completedLessons ?: 0,
        localCompletedIds,
    )
    val isLast = activeLessonIndex == lessons.lastIndex
    val isSaving = savingLessonId == activeLesson.lessonId

    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        item {
            Column {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        text = course.title ?: "Course",
                        style = MaterialTheme.typography.labelLarge,
                        color = TextSecondary,
                        maxLines = 1,
                    )
                    Text(
                        text = "$percent%",
                        color = LyoPurple,
                        fontWeight = FontWeight.Bold,
                    )
                }
                ProgressBar(percent)
                Text(
                    text = "Lesson ${activeLessonIndex + 1} of ${lessons.size}",
                    style = MaterialTheme.typography.bodySmall,
                    color = TextSecondary,
                    modifier = Modifier.padding(top = 8.dp),
                )
            }
        }

        if (progressWarning != null) {
            item { InlineMessage(progressWarning, warning = true) }
        }
        if (actionError != null) {
            item { InlineMessage(actionError, warning = false) }
        }

        val moduleTitle = activeLesson.moduleTitle
        if (!moduleTitle.isNullOrBlank()) {
            item {
                Text(
                    text = moduleTitle.uppercase(),
                    style = MaterialTheme.typography.labelMedium,
                    color = LyoPurple,
                )
            }
        }

        item {
            Text(
                text = activeLesson.lesson.title ?: "Lesson ${activeLessonIndex + 1}",
                style = MaterialTheme.typography.headlineMedium,
                color = TextPrimary,
            )
        }

        item {
            GlassCard(modifier = Modifier.fillMaxWidth()) {
                val content = activeLesson.lesson.content?.trim().orEmpty()
                Column(modifier = Modifier.padding(18.dp)) {
                    if (content.isNotEmpty()) {
                        Text(
                            text = content,
                            style = MaterialTheme.typography.bodyLarge,
                            color = TextPrimary,
                        )
                    } else {
                        Text(
                            text = "Lesson content unavailable",
                            style = MaterialTheme.typography.titleMedium,
                            color = TextPrimary,
                        )
                        Text(
                            text = "The backend returned this lesson without instructional content.",
                            style = MaterialTheme.typography.bodyMedium,
                            color = TextSecondary,
                            modifier = Modifier.padding(top = 6.dp),
                        )
                    }
                }
            }
        }

        item {
            OutlinedButton(
                onClick = onPrevious,
                enabled = activeLessonIndex > 0 && savingLessonId == null,
                modifier = Modifier.fillMaxWidth(),
            ) {
                Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = null)
                Text("Previous lesson", modifier = Modifier.padding(start = 6.dp))
            }
        }

        item {
            Button(
                onClick = { onPrimary(activeLessonIndex, activeLesson) },
                enabled = savingLessonId == null,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(50.dp),
                colors = ButtonDefaults.buttonColors(containerColor = LyoPurple),
            ) {
                if (isSaving) {
                    CircularProgressIndicator(
                        modifier = Modifier.size(18.dp),
                        color = Color.White,
                        strokeWidth = 2.dp,
                    )
                    Text("Saving…", modifier = Modifier.padding(start = 8.dp))
                } else {
                    val label = when {
                        currentCompleted && isLast -> "Back to course"
                        currentCompleted -> "Next lesson"
                        isLast -> "Complete course"
                        else -> "Mark complete & next"
                    }
                    Text(label)
                    if (!(currentCompleted && isLast)) {
                        Icon(
                            Icons.AutoMirrored.Filled.ArrowForward,
                            contentDescription = null,
                            modifier = Modifier.padding(start = 6.dp),
                        )
                    }
                }
            }
        }

        item {
            Text(
                text = "Course outline",
                style = MaterialTheme.typography.titleMedium,
                color = TextPrimary,
                modifier = Modifier.padding(top = 8.dp),
            )
        }

        itemsIndexed(lessons) { index, lessonItem ->
            LessonRow(
                index = index,
                lessonItem = lessonItem,
                completed = isLessonCompleted(
                    index,
                    lessonItem,
                    progress?.completedLessons ?: 0,
                    localCompletedIds,
                ),
                current = index == activeLessonIndex,
                onClick = { onSelectLesson(index) },
            )
        }

        item { Spacer(Modifier.height(24.dp)) }
    }
}

@Composable
private fun ProgressCard(completed: Int, total: Int, percent: Int) {
    GlassCard(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(16.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Column {
                    Text(
                        text = if (percent > 0) "Course progress" else "Ready to begin",
                        style = MaterialTheme.typography.titleMedium,
                        color = TextPrimary,
                    )
                    Text(
                        text = "$completed of $total lessons complete",
                        style = MaterialTheme.typography.bodySmall,
                        color = TextSecondary,
                    )
                }
                Text(
                    text = "$percent%",
                    color = LyoPurple,
                    fontWeight = FontWeight.Bold,
                )
            }
            ProgressBar(percent)
        }
    }
}

@Composable
private fun ProgressBar(percent: Int) {
    val fraction = (percent.coerceIn(0, 100) / 100f)
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 12.dp)
            .height(7.dp)
            .clip(CircleShape)
            .background(Color.White.copy(alpha = 0.10f)),
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth(fraction)
                .fillMaxHeight()
                .background(LyoPurple),
        )
    }
}

@Composable
private fun LessonRow(
    index: Int,
    lessonItem: CourseLessonItem,
    completed: Boolean,
    current: Boolean,
    onClick: () -> Unit,
) {
    GlassCard(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick),
    ) {
        Row(
            modifier = Modifier.padding(14.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(
                contentAlignment = Alignment.Center,
                modifier = Modifier
                    .size(34.dp)
                    .clip(CircleShape)
                    .background(
                        when {
                            completed -> LyoPurple
                            current -> LyoPurple.copy(alpha = 0.25f)
                            else -> Surface
                        },
                    ),
            ) {
                if (completed) {
                    Icon(
                        Icons.Default.CheckCircle,
                        contentDescription = "Completed",
                        tint = Color.White,
                        modifier = Modifier.size(20.dp),
                    )
                } else {
                    Text(
                        text = "${index + 1}",
                        color = if (current) LyoPurple else TextSecondary,
                    )
                }
            }
            Column(modifier = Modifier.padding(start = 12.dp)) {
                val moduleTitle = lessonItem.moduleTitle
                if (!moduleTitle.isNullOrBlank()) {
                    Text(
                        text = moduleTitle,
                        style = MaterialTheme.typography.labelSmall,
                        color = TextSecondary,
                        maxLines = 1,
                    )
                }
                Text(
                    text = lessonItem.lesson.title ?: "Lesson ${index + 1}",
                    style = MaterialTheme.typography.titleMedium,
                    color = TextPrimary,
                    maxLines = 2,
                )
                if (current && !completed) {
                    Text(
                        text = "CURRENT",
                        style = MaterialTheme.typography.labelSmall,
                        color = LyoPurple,
                        fontWeight = FontWeight.Bold,
                    )
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
private fun InlineMessage(message: String, warning: Boolean) {
    val accent = if (warning) Color(0xFFF59E0B) else Color(0xFFEF4444)
    Text(
        text = message,
        style = MaterialTheme.typography.bodySmall,
        color = accent,
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(accent.copy(alpha = 0.12f))
            .padding(12.dp),
    )
}

@Composable
private fun LoadFailure(message: String, onRetry: () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        EmptyState(title = "Unable to open course", subtitle = message)
        Button(
            onClick = onRetry,
            modifier = Modifier.padding(top = 16.dp),
            colors = ButtonDefaults.buttonColors(containerColor = LyoPurple),
        ) {
            Text("Try again")
        }
    }
}

private fun CourseDto.flattenLessons(): List<CourseLessonItem> {
    val fromModules = modules.orEmpty().flatMap { module ->
        module.lessons.orEmpty().map { lesson ->
            CourseLessonItem(moduleTitle = module.title, lesson = lesson)
        }
    }
    if (fromModules.isNotEmpty()) return fromModules
    return lessons.orEmpty().map { lesson ->
        CourseLessonItem(moduleTitle = null, lesson = lesson)
    }
}

private fun isLessonCompleted(
    index: Int,
    lessonItem: CourseLessonItem,
    serverCompletedCount: Int,
    localCompletedIds: Set<String>,
): Boolean {
    return index < serverCompletedCount.coerceAtLeast(0) ||
        lessonItem.lessonId?.let { localCompletedIds.contains(it) } == true
}

private fun resolvedCompletedCount(
    lessons: List<CourseLessonItem>,
    serverCompletedCount: Int,
    localCompletedIds: Set<String>,
): Int {
    val localCount = lessons.count { lessonItem ->
        val lessonId = lessonItem.lessonId
        lessonId != null && localCompletedIds.contains(lessonId)
    }
    return maxOf(serverCompletedCount, localCount).coerceIn(0, lessons.size)
}

private fun resolvedProgressPercent(
    totalLessons: Int,
    completed: Int,
    serverProgress: CourseProgressDto?,
): Int {
    if (totalLessons <= 0) return 0
    val localPercent = ((completed.toDouble() / totalLessons.toDouble()) * 100.0).toInt()
    return maxOf(serverProgress?.normalizedPercent ?: 0, localPercent).coerceIn(0, 100)
}

private fun Throwable.learningMessage(fallback: String): String {
    if (this is HttpException) {
        return when (code()) {
            401 -> "Your session expired. Sign in again to save progress."
            403 -> "This account cannot update this course."
            404 -> "The requested learning record was not found."
            else -> fallback
        }
    }
    val detail = localizedMessage
    return if (detail.isNullOrBlank()) fallback else detail
}
