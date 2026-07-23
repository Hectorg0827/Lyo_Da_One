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
import androidx.compose.foundation.layout.weight
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
import androidx.compose.runtime.saveable.rememberSaveable
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

private const val MODE_OVERVIEW = "overview"
private const val MODE_PLAYER = "player"
private val courseEmojis = listOf("📚", "🧠", "🎨", "🐍", "🎵", "⚛️")

private data class CourseLessonItem(
    val moduleTitle: String?,
    val lesson: LessonDto,
) {
    val lessonId: String?
        get() = lesson.id?.toString()?.removeSuffix(".0")?.takeIf(String::isNotBlank)
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CourseDetailScreen(nav: NavHostController, courseId: String) {
    var course by remember(courseId) { mutableStateOf<CourseDto?>(null) }
    var progress by remember(courseId) { mutableStateOf<CourseProgressDto?>(null) }
    var loading by remember(courseId) { mutableStateOf(true) }
    var loadError by remember(courseId) { mutableStateOf<String?>(null) }
    var progressWarning by remember(courseId) { mutableStateOf<String?>(null) }
    var actionError by remember(courseId) { mutableStateOf<String?>(null) }
    var reloadKey by remember(courseId) { mutableStateOf(0) }
    var mode by rememberSaveable(courseId) { mutableStateOf(MODE_OVERVIEW) }
    var activeIndex by rememberSaveable(courseId) { mutableStateOf(0) }
    var localCompletedIds by remember(courseId) { mutableStateOf(emptySet<String>()) }
    var savingLessonId by remember(courseId) { mutableStateOf<String?>(null) }

    val scope = rememberCoroutineScope()
    val lessons = remember(course) { course?.flattenLessons().orEmpty() }

    LaunchedEffect(courseId, reloadKey) {
        loading = true
        loadError = null
        progressWarning = null
        actionError = null

        val loadedCourse = runCatching { ApiClient.api.course(courseId) }
            .getOrElse { error ->
                loadError = error.learningMessage("Unable to load this course.")
                loading = false
                return@LaunchedEffect
            }
        course = loadedCourse

        val loadedLessons = loadedCourse.flattenLessons()
        runCatching { ApiClient.learning.courseProgress(courseId) }
            .onSuccess { serverProgress ->
                progress = serverProgress
                val currentIndex = serverProgress.currentLessonIdString?.let { currentId ->
                    loadedLessons.indexOfFirst { it.lessonId == currentId }.takeIf { it >= 0 }
                }
                activeIndex = (
                    currentIndex
                        ?: serverProgress.completedLessons.coerceAtMost(
                            (loadedLessons.size - 1).coerceAtLeast(0),
                        )
                    ).coerceAtLeast(0)
            }
            .onFailure { error ->
                progressWarning = error.learningMessage(
                    "Saved progress is unavailable. You can still open the course.",
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
                    text = if (mode == MODE_PLAYER) "Classroom" else course?.title ?: "Course",
                    maxLines = 1,
                )
            },
            navigationIcon = {
                IconButton(
                    onClick = {
                        if (mode == MODE_PLAYER) mode = MODE_OVERVIEW else nav.popBackStack()
                    },
                ) {
                    Icon(
                        Icons.AutoMirrored.Filled.ArrowBack,
                        contentDescription = if (mode == MODE_PLAYER) "Back to course" else "Back",
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
            mode == MODE_PLAYER -> {
                CoursePlayer(
                    course = course!!,
                    lessons = lessons,
                    progress = progress,
                    activeIndex = activeIndex.coerceIn(0, (lessons.size - 1).coerceAtLeast(0)),
                    localCompletedIds = localCompletedIds,
                    savingLessonId = savingLessonId,
                    actionError = actionError,
                    progressWarning = progressWarning,
                    onSelectLesson = { index ->
                        if (savingLessonId == null) {
                            activeIndex = index
                            actionError = null
                        }
                    },
                    onPrevious = {
                        if (activeIndex > 0 && savingLessonId == null) {
                            activeIndex -= 1
                            actionError = null
                        }
                    },
                    onPrimaryAction = { index, lessonItem ->
                        val completed = lessonCompleted(
                            index,
                            lessonItem,
                            progress?.completedLessons ?: 0,
                            localCompletedIds,
                        )
                        if (completed) {
                            if (index < lessons.lastIndex) activeIndex = index + 1 else mode = MODE_OVERVIEW
                            actionError = null
                            return@CoursePlayer
                        }

                        val lessonId = lessonItem.lessonId
                        when {
                            lessonId == null -> {
                                actionError = "This lesson does not have a persistent ID, so completion cannot be saved."
                            }
                            TokenManager.accessToken == null -> {
                                actionError = "Sign in to save lesson progress across devices."
                            }
                            savingLessonId != null -> Unit
                            else -> {
                                val previousLocal = localCompletedIds
                                localCompletedIds = previousLocal + lessonId
                                savingLessonId = lessonId
                                actionError = null

                                scope.launch {
                                    runCatching {
                                        ApiClient.learning.markLessonComplete(
                                            LessonCompletionRequest(lessonId = lessonId),
                                        )
                                    }.onSuccess {
                                        runCatching { ApiClient.learning.courseProgress(courseId) }
                                            .onSuccess { refreshed ->
                                                progress = refreshed
                                                progressWarning = null
                                            }
                                            .onFailure {
                                                progressWarning =
                                                    "Completion was saved, but the latest course total could not be refreshed."
                                            }
                                        if (index < lessons.lastIndex) activeIndex = index + 1
                                    }.onFailure { error ->
                                        localCompletedIds = previousLocal
                                        actionError = error.learningMessage("Unable to save lesson completion.")
                                    }
                                    savingLessonId = null
                                }
                            }
                        }
                    },
                    onBackToOverview = { mode = MODE_OVERVIEW },
                )
            }
            else -> {
                CourseOverview(
                    course = course!!,
                    lessons = lessons,
                    progress = progress,
                    localCompletedIds = localCompletedIds,
                    progressWarning = progressWarning,
                    onStart = { if (lessons.isNotEmpty()) mode = MODE_PLAYER },
                    onSelectLesson = { index ->
                        activeIndex = index
                        mode = MODE_PLAYER
                        actionError = null
                    },
                )
            }
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
    val completedCount = completedCount(
        lessons,
        progress?.completedLessons ?: 0,
        localCompletedIds,
    )
    val percent = progressPercent(lessons.size, completedCount, progress)

    LazyColumn(
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
        modifier = Modifier.fillMaxSize(),
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
                course.description?.takeIf(String::isNotBlank)?.let { description ->
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

        if (progressWarning != null) item { InlineMessage(progressWarning, warning = true) }

        if (lessons.isEmpty()) {
            item {
                EmptyState(
                    title = "No lessons available",
                    subtitle = "This course does not currently contain playable lesson content.",
                )
            }
        } else {
            item {
                ProgressCard(
                    completedCount = completedCount,
                    totalLessons = lessons.size,
                    percent = percent,
                )
            }
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
                        style = MaterialTheme.typography.titleMedium,
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
                    completed = lessonCompleted(
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
    activeIndex: Int,
    localCompletedIds: Set<String>,
    savingLessonId: String?,
    actionError: String?,
    progressWarning: String?,
    onSelectLesson: (Int) -> Unit,
    onPrevious: () -> Unit,
    onPrimaryAction: (Int, CourseLessonItem) -> Unit,
    onBackToOverview: () -> Unit,
) {
    if (lessons.isEmpty()) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
            modifier = Modifier
                .fillMaxSize()
                .padding(24.dp),
        ) {
            EmptyState(
                title = "No playable lessons",
                subtitle = "Return to the course overview and try again later.",
            )
            OutlinedButton(onClick = onBackToOverview) { Text("Back to course") }
        }
        return
    }

    val activeLesson = lessons[activeIndex]
    val isCompleted = lessonCompleted(
        activeIndex,
        activeLesson,
        progress?.completedLessons ?: 0,
        localCompletedIds,
    )
    val completed = completedCount(
        lessons,
        progress?.completedLessons ?: 0,
        localCompletedIds,
    )
    val percent = progressPercent(lessons.size, completed, progress)
    val isLast = activeIndex == lessons.lastIndex
    val isSaving = savingLessonId == activeLesson.lessonId

    Column(modifier = Modifier.fillMaxSize()) {
        Column(modifier = Modifier.padding(horizontal = 16.dp, vertical = 10.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    text = course.title ?: "Course",
                    style = MaterialTheme.typography.labelLarge,
                    color = TextSecondary,
                    modifier = Modifier.weight(1f),
                    maxLines = 1,
                )
                Text("$percent%", color = LyoPurple, fontWeight = FontWeight.Bold)
            }
            LinearProgressIndicator(
                progress = percent / 100f,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 8.dp)
                    .height(6.dp)
                    .clip(CircleShape),
            )
            Text(
                text = "Lesson ${activeIndex + 1} of ${lessons.size}",
                style = MaterialTheme.typography.bodySmall,
                color = TextSecondary,
                modifier = Modifier.padding(top = 8.dp),
            )
        }

        if (progressWarning != null) {
            InlineMessage(
                progressWarning,
                warning = true,
                modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp),
            )
        }
        if (actionError != null) {
            InlineMessage(
                actionError,
                warning = false,
                modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp),
            )
        }

        LazyColumn(
            contentPadding = PaddingValues(horizontal = 20.dp, vertical = 18.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
            modifier = Modifier.weight(1f),
        ) {
            activeLesson.moduleTitle?.takeIf(String::isNotBlank)?.let { moduleTitle ->
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
                    text = activeLesson.lesson.title ?: "Lesson ${activeIndex + 1}",
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
                Text(
                    text = "Course outline",
                    style = MaterialTheme.typography.titleMedium,
                    color = TextPrimary,
                    modifier = Modifier.padding(top = 4.dp),
                )
            }
            itemsIndexed(lessons) { index, outlineLesson ->
                LessonRow(
                    index = index,
                    lessonItem = outlineLesson,
                    completed = lessonCompleted(
                        index,
                        outlineLesson,
                        progress?.completedLessons ?: 0,
                        localCompletedIds,
                    ),
                    current = index == activeIndex,
                    onClick = { onSelectLesson(index) },
                )
            }
        }

        Row(
            horizontalArrangement = Arrangement.spacedBy(10.dp),
            modifier = Modifier
                .fillMaxWidth()
                .background(Surface)
                .padding(14.dp),
        ) {
            OutlinedButton(
                onClick = onPrevious,
                enabled = activeIndex > 0 && savingLessonId == null,
                modifier = Modifier.weight(0.38f),
            ) {
                Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = null)
                Text("Previous", modifier = Modifier.padding(start = 4.dp))
            }
            Button(
                onClick = { onPrimaryAction(activeIndex, activeLesson) },
                enabled = savingLessonId == null,
                modifier = Modifier.weight(0.62f),
                colors = ButtonDefaults.buttonColors(containerColor = LyoPurple),
            ) {
                when {
                    isSaving -> {
                        CircularProgressIndicator(
                            modifier = Modifier.size(18.dp),
                            strokeWidth = 2.dp,
                            color = Color.White,
                        )
                        Text("Saving…", modifier = Modifier.padding(start = 8.dp))
                    }
                    isCompleted && isLast -> Text("Back to course")
                    isCompleted -> {
                        Text("Next lesson")
                        Icon(
                            Icons.AutoMirrored.Filled.ArrowForward,
                            contentDescription = null,
                            modifier = Modifier.padding(start = 4.dp),
                        )
                    }
                    isLast -> Text("Complete course")
                    else -> {
                        Text("Mark complete & next")
                        Icon(
                            Icons.AutoMirrored.Filled.ArrowForward,
                            contentDescription = null,
                            modifier = Modifier.padding(start = 4.dp),
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun ProgressCard(completedCount: Int, totalLessons: Int, percent: Int) {
    GlassCard(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(16.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = if (percent > 0) "Course progress" else "Ready to begin",
                        style = MaterialTheme.typography.titleMedium,
                        color = TextPrimary,
                    )
                    Text(
                        text = "$completedCount of $totalLessons lessons complete",
                        style = MaterialTheme.typography.bodySmall,
                        color = TextSecondary,
                    )
                }
                Text("$percent%", color = LyoPurple, fontWeight = FontWeight.Bold)
            }
            LinearProgressIndicator(
                progress = percent / 100f,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 12.dp)
                    .height(7.dp)
                    .clip(CircleShape),
            )
        }
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
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.padding(14.dp),
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
                        style = MaterialTheme.typography.labelLarge,
                        color = if (current) LyoPurple else TextSecondary,
                    )
                }
            }
            Column(
                modifier = Modifier
                    .weight(1f)
                    .padding(start = 12.dp),
            ) {
                lessonItem.moduleTitle?.takeIf(String::isNotBlank)?.let { moduleTitle ->
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
            }
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
private fun InlineMessage(
    message: String,
    warning: Boolean,
    modifier: Modifier = Modifier,
) {
    val accent = if (warning) Color(0xFFF59E0B) else Color(0xFFEF4444)
    Text(
        text = message,
        style = MaterialTheme.typography.bodySmall,
        color = accent,
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(accent.copy(alpha = 0.12f))
            .padding(12.dp),
    )
}

@Composable
private fun LoadFailure(message: String, onRetry: () -> Unit) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp),
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
    val moduleLessons = modules.orEmpty().flatMap { module ->
        module.lessons.orEmpty().map { lesson ->
            CourseLessonItem(moduleTitle = module.title, lesson = lesson)
        }
    }
    return moduleLessons.takeIf(List<CourseLessonItem>::isNotEmpty)
        ?: lessons.orEmpty().map { CourseLessonItem(moduleTitle = null, lesson = it) }
}

private fun lessonCompleted(
    index: Int,
    lessonItem: CourseLessonItem,
    serverCompletedCount: Int,
    localCompletedIds: Set<String>,
): Boolean {
    // The canonical progress response currently exposes a sequential count rather
    // than completed lesson IDs, so course order is the server-backed resume order.
    return index < serverCompletedCount.coerceAtLeast(0) ||
        lessonItem.lessonId?.let(localCompletedIds::contains) == true
}

private fun completedCount(
    lessons: List<CourseLessonItem>,
    serverCompletedCount: Int,
    localCompletedIds: Set<String>,
): Int {
    val localCount = lessons.count { lesson ->
        lesson.lessonId?.let(localCompletedIds::contains) == true
    }
    return maxOf(serverCompletedCount, localCount).coerceIn(0, lessons.size)
}

private fun progressPercent(
    totalLessons: Int,
    completedCount: Int,
    serverProgress: CourseProgressDto?,
): Int {
    if (totalLessons <= 0) return 0
    val localPercent = ((completedCount.toDouble() / totalLessons) * 100).toInt()
    return maxOf(serverProgress?.normalizedPercent ?: 0, localPercent).coerceIn(0, 100)
}

private fun Throwable.learningMessage(fallback: String): String = when (this) {
    is HttpException -> when (code()) {
        401 -> "Your session expired. Sign in again to save progress."
        403 -> "This account cannot update this course."
        404 -> "The requested learning record was not found."
        else -> message().takeIf(String::isNotBlank) ?: fallback
    }
    else -> localizedMessage?.takeIf(String::isNotBlank) ?: fallback
}
