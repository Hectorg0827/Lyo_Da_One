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
import com.lyo.app.ui.components.LyoBrandGradient
import com.lyo.app.ui.theme.Background
import com.lyo.app.ui.theme.LyoPurple
import com.lyo.app.ui.theme.Surface
import com.lyo.app.ui.theme.TextPrimary
import com.lyo.app.ui.theme.TextSecondary
import kotlinx.coroutines.launch
import retrofit2.HttpException

private val CourseEmojis = listOf("📚", "🧠", "🎨", "🐍", "🎵", "⚛️")
private const val MODE_OVERVIEW = "overview"
private const val MODE_PLAYER = "player"

private data class CourseLessonItem(
    val moduleTitle: String?,
    val lesson: LessonDto,
) {
    val lessonId: String?
        get() = lesson.id?.toString()?.removeSuffix(".0")?.takeIf { it.isNotBlank() }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CourseDetailScreen(nav: NavHostController, courseId: String) {
    var course by remember(courseId) { mutableStateOf<CourseDto?>(null) }
    var progress by remember(courseId) { mutableStateOf<CourseProgressDto?>(null) }
    var loadError by remember(courseId) { mutableStateOf<String?>(null) }
    var progressWarning by remember(courseId) { mutableStateOf<String?>(null) }
    var actionError by remember(courseId) { mutableStateOf<String?>(null) }
    var isLoading by remember(courseId) { mutableStateOf(true) }
    var reloadNonce by remember(courseId) { mutableStateOf(0) }
    var screenMode by rememberSaveable(courseId) { mutableStateOf(MODE_OVERVIEW) }
    var activeLessonIndex by rememberSaveable(courseId) { mutableStateOf(0) }
    var locallyCompletedLessonIds by remember(courseId) { mutableStateOf(emptySet<String>()) }
    var savingLessonId by remember(courseId) { mutableStateOf<String?>(null) }

    val scope = rememberCoroutineScope()
    val lessons = remember(course) { course?.flattenLessons().orEmpty() }

    LaunchedEffect(courseId, reloadNonce) {
        isLoading = true
        loadError = null
        progressWarning = null
        actionError = null

        val loadedCourse = runCatching { ApiClient.api.course(courseId) }
            .getOrElse { error ->
                loadError = error.learningMessage("Unable to load this course.")
                isLoading = false
                return@LaunchedEffect
            }

        course = loadedCourse
        val loadedLessons = loadedCourse.flattenLessons()

        runCatching { ApiClient.learning.courseProgress(courseId) }
            .onSuccess { serverProgress ->
                progress = serverProgress
                val currentLessonIndex = serverProgress.currentLessonIdString?.let { currentId ->
                    loadedLessons.indexOfFirst { it.lessonId == currentId }.takeIf { it >= 0 }
                }
                activeLessonIndex = (
                    currentLessonIndex
                        ?: serverProgress.completedLessons.coerceAtMost((loadedLessons.size - 1).coerceAtLeast(0))
                    ).coerceAtLeast(0)
            }
            .onFailure { error ->
                progressWarning = error.learningMessage(
                    "Saved progress is unavailable. You can still open the course, but resume state may be incomplete.",
                )
            }

        isLoading = false
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Background),
    ) {
        TopAppBar(
            title = {
                Text(
                    if (screenMode == MODE_PLAYER) "Classroom" else course?.title ?: "Course",
                    maxLines = 1,
                )
            },
            navigationIcon = {
                IconButton(
                    onClick = {
                        if (screenMode == MODE_PLAYER) {
                            screenMode = MODE_OVERVIEW
                        } else {
                            nav.popBackStack()
                        }
                    },
                ) {
                    Icon(
                        Icons.AutoMirrored.Filled.ArrowBack,
                        contentDescription = if (screenMode == MODE_PLAYER) "Back to course" else "Back",
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
            isLoading -> LoadingBox()

            loadError != null -> LoadFailure(
                message = loadError!!,
                onRetry = { reloadNonce += 1 },
            )

            course == null -> LoadFailure(
                message = "Course data is unavailable.",
                onRetry = { reloadNonce += 1 },
            )

            screenMode == MODE_PLAYER -> CoursePlayer(
                course = course!!,
                lessons = lessons,
                progress = progress,
                activeLessonIndex = activeLessonIndex.coerceIn(
                    0,
                    (lessons.size - 1).coerceAtLeast(0),
                ),
                locallyCompletedLessonIds = locallyCompletedLessonIds,
                savingLessonId = savingLessonId,
                actionError = actionError,
                progressWarning = progressWarning,
                onSelectLesson = { index ->
                    activeLessonIndex = index
                    actionError = null
                },
                onPrevious = {
                    if (activeLessonIndex > 0) {
                        activeLessonIndex -= 1
                        actionError = null
                    }
                },
                onCompleteOrAdvance = { index, item ->
                    val alreadyCompleted = isLessonCompleted(
                        index = index,
                        item = item,
                        serverCompletedCount = progress?.completedLessons ?: 0,
                        locallyCompletedLessonIds = locallyCompletedLessonIds,
                    )

                    if (alreadyCompleted) {
                        if (index < lessons.lastIndex) {
                            activeLessonIndex = index + 1
                        } else {
                            screenMode = MODE_OVERVIEW
                        }
                        actionError = null
                    } else {
                        val lessonId = item.lessonId
                        if (lessonId == null) {
                            actionError = "This lesson does not have a persistent ID, so completion cannot be saved."
                        } else if (TokenManager.accessToken == null) {
                            actionError = "Sign in to save lesson progress across devices."
                        } else if (savingLessonId == null) {
                            val previousLocal = locallyCompletedLessonIds
                            locallyCompletedLessonIds = previousLocal + lessonId
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

                                    if (index < lessons.lastIndex) {
                                        activeLessonIndex = index + 1
                                    }
                                }.onFailure { error ->
                                    locallyCompletedLessonIds = previousLocal
                                    actionError = error.learningMessage("Unable to save lesson completion.")
                                }
                                savingLessonId = null
                            }
                        }
                    }
                },
                onBackToOverview = { screenMode = MODE_OVERVIEW },
            )

            else -> CourseOverview(
                course = course!!,
                lessons = lessons,
                progress = progress,
                locallyCompletedLessonIds = locallyCompletedLessonIds,
                progressWarning = progressWarning,
                onStart = {
                    if (lessons.isNotEmpty()) {
                        screenMode = MODE_PLAYER
                    }
                },
                onSelectLesson = { index ->
                    activeLessonIndex = index
                    screenMode = MODE_PLAYER
                    actionError = null
                },
            )
        }
    }
}

@Composable
private fun CourseOverview(
    course: CourseDto,
    lessons: List<CourseLessonItem>,
    progress: CourseProgressDto?,
    locallyCompletedLessonIds: Set<String>,
    progressWarning: String?,
    onStart: () -> Unit,
    onSelectLesson: (Int) -> Unit,
) {
    val completedCount = resolvedCompletedCount(
        lessons = lessons,
        serverCompletedCount = progress?.completedLessons ?: 0,
        locallyCompletedLessonIds = locallyCompletedLessonIds,
    )
    val progressPercent = resolvedProgressPercent(
        totalLessons = lessons.size,
        completedCount = completedCount,
        serverProgress = progress,
    )

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
                    text = CourseEmojis[course.idStr.hashCode().mod(CourseEmojis.size)],
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
                if (!course.description.isNullOrBlank()) {
                    Text(
                        text = course.description,
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

        if (lessons.isNotEmpty()) {
            item {
                GlassCard(modifier = Modifier.fillMaxWidth()) {
                    Column(modifier = Modifier.padding(16.dp)) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            modifier = Modifier.fillMaxWidth(),
                        ) {
                            Column(modifier = Modifier.weight(1f)) {
                                Text(
                                    text = if (progressPercent > 0) "Course progress" else "Ready to begin",
                                    style = MaterialTheme.typography.titleMedium,
                                    color = TextPrimary,
                                )
                                Text(
                                    text = "$completedCount of ${lessons.size} lessons complete",
                                    style = MaterialTheme.typography.bodySmall,
                                    color = TextSecondary,
                                    modifier = Modifier.padding(top = 2.dp),
                                )
                            }
                            Text(
                                text = "$progressPercent%",
                                style = MaterialTheme.typography.titleMedium,
                                color = LyoPurple,
                            )
                        }
                        LinearProgressIndicator(
                            progress = progressPercent / 100f,
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(top = 12.dp)
                                .height(7.dp)
                                .clip(CircleShape),
                        )
                    }
                }
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
                        text = if (progressPercent > 0) "Resume Learning" else "Start Learning",
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

            itemsIndexed(lessons) { index, item ->
                LessonListRow(
                    index = index,
                    item = item,
                    completed = isLessonCompleted(
                        index = index,
                        item = item,
                        serverCompletedCount = progress?.completedLessons ?: 0,
                        locallyCompletedLessonIds = locallyCompletedLessonIds,
                    ),
                    current = progress?.currentLessonIdString == item.lessonId,
                    onClick = { onSelectLesson(index) },
                )
            }
        } else {
            item {
                EmptyState(
                    title = "No lessons available",
                    subtitle = "This course does not currently contain playable lesson content.",
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
    activeLessonIndex: Int,
    locallyCompletedLessonIds: Set<String>,
    savingLessonId: String?,
    actionError: String?,
    progressWarning: String?,
    onSelectLesson: (Int) -> Unit,
    onPrevious: () -> Unit,
    onCompleteOrAdvance: (Int, CourseLessonItem) -> Unit,
    onBackToOverview: () -> Unit,
) {
    if (lessons.isEmpty()) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            modifier = Modifier
                .fillMaxSize()
                .padding(24.dp),
        ) {
            EmptyState(
                title = "No playable lessons",
                subtitle = "Return to the course overview and try again when lesson content is available.",
            )
            OutlinedButton(onClick = onBackToOverview) {
                Text("Back to course")
            }
        }
        return
    }

    val item = lessons[activeLessonIndex]
    val completed = isLessonCompleted(
        index = activeLessonIndex,
        item = item,
        serverCompletedCount = progress?.completedLessons ?: 0,
        locallyCompletedLessonIds = locallyCompletedLessonIds,
    )
    val completedCount = resolvedCompletedCount(
        lessons = lessons,
        serverCompletedCount = progress?.completedLessons ?: 0,
        locallyCompletedLessonIds = locallyCompletedLessonIds,
    )
    val progressPercent = resolvedProgressPercent(
        totalLessons = lessons.size,
        completedCount = completedCount,
        serverProgress = progress,
    )
    val isLast = activeLessonIndex == lessons.lastIndex
    val isSaving = savingLessonId == item.lessonId

    Column(modifier = Modifier.fillMaxSize()) {
        Column(modifier = Modifier.padding(horizontal = 16.dp, vertical = 10.dp)) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text(
                    text = course.title ?: "Course",
                    style = MaterialTheme.typography.labelLarge,
                    color = TextSecondary,
                    modifier = Modifier.weight(1f),
                    maxLines = 1,
                )
                Text(
                    text = "$progressPercent%",
                    style = MaterialTheme.typography.labelLarge,
                    color = LyoPurple,
                )
            }
            LinearProgressIndicator(
                progress = progressPercent / 100f,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 8.dp)
                    .height(6.dp)
                    .clip(CircleShape),
            )
            Text(
                text = "Lesson ${activeLessonIndex + 1} of ${lessons.size}",
                style = MaterialTheme.typography.bodySmall,
                color = TextSecondary,
                modifier = Modifier.padding(top = 8.dp),
            )
        }

        if (progressWarning != null) {
            InlineMessage(
                message = progressWarning,
                warning = true,
                modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp),
            )
        }
        if (actionError != null) {
            InlineMessage(
                message = actionError,
                warning = false,
                modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp),
            )
        }

        LazyColumn(
            contentPadding = PaddingValues(horizontal = 20.dp, vertical = 18.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
            modifier = Modifier.weight(1f),
        ) {
            item.moduleTitle?.takeIf { it.isNotBlank() }?.let { moduleTitle ->
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
                    text = item.lesson.title ?: "Lesson ${activeLessonIndex + 1}",
                    style = MaterialTheme.typography.headlineMedium,
                    color = TextPrimary,
                )
            }

            item {
                GlassCard(modifier = Modifier.fillMaxWidth()) {
                    val content = item.lesson.content?.trim().orEmpty()
                    if (content.isNotEmpty()) {
                        Text(
                            text = content,
                            style = MaterialTheme.typography.bodyLarge,
                            color = TextPrimary,
                            modifier = Modifier.padding(18.dp),
                        )
                    } else {
                        Column(modifier = Modifier.padding(18.dp)) {
                            Text(
                                text = "Lesson content unavailable",
                                style = MaterialTheme.typography.titleMedium,
                                color = TextPrimary,
                            )
                            Text(
                                text = "This lesson record exists, but the backend did not provide instructional content.",
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
                    modifier = Modifier.padding(top = 6.dp),
                )
            }

            itemsIndexed(lessons) { index, outlineItem ->
                LessonListRow(
                    index = index,
                    item = outlineItem,
                    completed = isLessonCompleted(
                        index = index,
                        item = outlineItem,
                        serverCompletedCount = progress?.completedLessons ?: 0,
                        locallyCompletedLessonIds = locallyCompletedLessonIds,
                    ),
                    current = index == activeLessonIndex,
                    onClick = { onSelectLesson(index) },
                )
            }
        }

        Row(
            horizontalArrangement = Arrangement.spacedBy(10.dp),
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier
                .fillMaxWidth()
                .background(Surface)
                .padding(14.dp),
        ) {
            OutlinedButton(
                onClick = onPrevious,
                enabled = activeLessonIndex > 0 && savingLessonId == null,
                modifier = Modifier.weight(0.38f),
            ) {
                Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = null)
                Text("Previous", modifier = Modifier.padding(start = 4.dp))
            }

            Button(
                onClick = { onCompleteOrAdvance(activeLessonIndex, item) },
                enabled = savingLessonId == null || isSaving,
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
                    completed && isLast -> Text("Back to course")
                    completed -> {
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
private fun LessonListRow(
    index: Int,
    item: CourseLessonItem,
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
                item.moduleTitle?.takeIf { it.isNotBlank() }?.let { moduleTitle ->
                    Text(
                        text = moduleTitle,
                        style = MaterialTheme.typography.labelSmall,
                        color = TextSecondary,
                        maxLines = 1,
                    )
                }
                Text(
                    text = item.lesson.title ?: "Lesson ${index + 1}",
                    style = MaterialTheme.typography.titleMedium,
                    color = TextPrimary,
                    maxLines = 2,
                )
            }
            if (current && !completed) {
                Text(
                    text = "CURRENT",
                    style = MaterialTheme.typography.labelSmall,
                    fontWeight = FontWeight.Bold,
                    color = LyoPurple,
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
private fun LoadFailure(
    message: String,
    onRetry: () -> Unit,
) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp),
    ) {
        EmptyState(
            title = "Unable to open course",
            subtitle = message,
        )
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
    return moduleLessons.takeIf { it.isNotEmpty() }
        ?: lessons.orEmpty().map { lesson -> CourseLessonItem(moduleTitle = null, lesson = lesson) }
}

private fun isLessonCompleted(
    index: Int,
    item: CourseLessonItem,
    serverCompletedCount: Int,
    locallyCompletedLessonIds: Set<String>,
): Boolean {
    // The backend progress model currently exposes a sequential completed count,
    // not completed lesson IDs. Course order is therefore the canonical resume order.
    return index < serverCompletedCount.coerceAtLeast(0) ||
        item.lessonId?.let(locallyCompletedLessonIds::contains) == true
}

private fun resolvedCompletedCount(
    lessons: List<CourseLessonItem>,
    serverCompletedCount: Int,
    locallyCompletedLessonIds: Set<String>,
): Int {
    val localOnly = lessons.count { item ->
        item.lessonId?.let(locallyCompletedLessonIds::contains) == true
    }
    return maxOf(serverCompletedCount, localOnly).coerceIn(0, lessons.size)
}

private fun resolvedProgressPercent(
    totalLessons: Int,
    completedCount: Int,
    serverProgress: CourseProgressDto?,
): Int {
    if (totalLessons <= 0) return 0
    val localPercent = ((completedCount.toDouble() / totalLessons.toDouble()) * 100.0).toInt()
    return maxOf(serverProgress?.normalizedPercent ?: 0, localPercent).coerceIn(0, 100)
}

private fun Throwable.learningMessage(fallback: String): String = when (this) {
    is HttpException -> when (code()) {
        401 -> "Your session expired. Sign in again to continue saving progress."
        403 -> "This account does not have access to update this course."
        404 -> "The requested learning record was not found."
        else -> message().takeIf { it.isNotBlank() } ?: fallback
    }
    else -> localizedMessage?.takeIf { it.isNotBlank() } ?: fallback
}
