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
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Refresh
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
import androidx.compose.material3.TextButton
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
import androidx.navigation.NavHostController
import com.google.gson.JsonElement
import com.google.gson.JsonParser
import com.lyo.app.data.api.ApiClient
import com.lyo.app.data.api.CourseDto
import com.lyo.app.data.api.CourseProgressResponse
import com.lyo.app.data.api.LessonCompletionRequest
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
import retrofit2.HttpException
import java.io.IOException
import kotlin.math.max

private data class CourseLessonItem(
    val moduleTitle: String?,
    val lesson: LessonDto,
) {
    val lessonId: String
        get() = lesson.id?.toString()?.removeSuffix(".0").orEmpty()
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CourseDetailScreen(nav: NavHostController, courseId: String) {
    var course by remember(courseId) { mutableStateOf<CourseDto?>(null) }
    var lessons by remember(courseId) { mutableStateOf<List<CourseLessonItem>>(emptyList()) }
    var activeLessonIndex by remember(courseId) { mutableStateOf(0) }
    var completedLessonIds by remember(courseId) { mutableStateOf<Set<String>>(emptySet()) }
    var canonicalProgress by remember(courseId) { mutableStateOf<CourseProgressResponse?>(null) }
    var completedCount by remember(courseId) { mutableStateOf(0) }
    var displayedProgressPercent by remember(courseId) { mutableStateOf(0) }
    var loading by remember(courseId) { mutableStateOf(true) }
    var loadError by remember(courseId) { mutableStateOf<String?>(null) }
    var progressWarning by remember(courseId) { mutableStateOf<String?>(null) }
    var actionError by remember(courseId) { mutableStateOf<String?>(null) }
    var completionNotice by remember(courseId) { mutableStateOf<String?>(null) }
    var savingLessonId by remember(courseId) { mutableStateOf<String?>(null) }
    var reloadVersion by remember(courseId) { mutableStateOf(0) }
    val scope = rememberCoroutineScope()

    LaunchedEffect(courseId, reloadVersion) {
        loading = true
        loadError = null
        progressWarning = null
        actionError = null
        completionNotice = null

        val loadedCourse = runCatching { ApiClient.api.course(courseId) }
            .getOrElse { error ->
                loadError = courseLoadMessage(error)
                loading = false
                return@LaunchedEffect
            }

        val flattenedLessons = flattenLessons(loadedCourse)
        course = loadedCourse
        lessons = flattenedLessons
        completedLessonIds = emptySet()
        activeLessonIndex = 0
        completedCount = 0
        displayedProgressPercent = 0
        canonicalProgress = null

        runCatching { ApiClient.learning.courseProgress(courseId) }
            .onSuccess { progress ->
                canonicalProgress = progress
                completedCount = progress.completedLessons.coerceIn(0, max(progress.totalLessons, flattenedLessons.size))
                displayedProgressPercent = progress.normalizedPercent
                val resumeLessonId = progress.currentLessonIdString
                val resumeIndex = flattenedLessons.indexOfFirst { it.lessonId == resumeLessonId }
                if (resumeIndex >= 0) activeLessonIndex = resumeIndex
            }
            .onFailure { error ->
                progressWarning = progressLoadMessage(error)
            }

        loading = false
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
            loading -> LoadingBox()
            loadError != null -> CourseLoadError(
                message = loadError!!,
                onRetry = { reloadVersion += 1 },
            )
            course == null -> CourseLoadError(
                message = "The course could not be loaded.",
                onRetry = { reloadVersion += 1 },
            )
            lessons.isEmpty() -> EmptyState(
                title = "No published lessons",
                subtitle = "This course exists, but it does not contain lesson content yet.",
            )
            else -> {
                val activeItem = lessons[activeLessonIndex.coerceIn(0, lessons.lastIndex)]
                val lessonContent = readableLessonContent(activeItem.lesson.content)
                val isLocallyCompleted = activeItem.lessonId in completedLessonIds
                val isSaving = savingLessonId == activeItem.lessonId
                val isLastLesson = activeLessonIndex == lessons.lastIndex
                val totalLessons = canonicalProgress?.totalLessons?.takeIf { it > 0 } ?: lessons.size
                val safeCompletedCount = completedCount.coerceIn(0, max(totalLessons, lessons.size))
                val fallbackPercent = if (totalLessons > 0) {
                    ((safeCompletedCount.toDouble() / totalLessons.toDouble()) * 100.0).toInt()
                } else {
                    0
                }
                val progressPercent = max(displayedProgressPercent, fallbackPercent).coerceIn(0, 100)

                LazyColumn(
                    contentPadding = PaddingValues(start = 16.dp, end = 16.dp, bottom = 32.dp),
                    verticalArrangement = Arrangement.spacedBy(14.dp),
                    modifier = Modifier.fillMaxSize(),
                ) {
                    item {
                        CourseHeader(
                            course = course!!,
                            completedLessons = safeCompletedCount,
                            totalLessons = totalLessons,
                            progressPercent = progressPercent,
                        )
                    }

                    progressWarning?.let { warning ->
                        item {
                            StatusCard(
                                message = warning,
                                actionLabel = "Retry progress",
                                onAction = { reloadVersion += 1 },
                            )
                        }
                    }

                    actionError?.let { error ->
                        item {
                            StatusCard(
                                message = error,
                                actionLabel = "Dismiss",
                                onAction = { actionError = null },
                                isError = true,
                            )
                        }
                    }

                    completionNotice?.let { notice ->
                        item {
                            StatusCard(
                                message = notice,
                                actionLabel = "Dismiss",
                                onAction = { completionNotice = null },
                            )
                        }
                    }

                    item {
                        ActiveLessonCard(
                            item = activeItem,
                            lessonNumber = activeLessonIndex + 1,
                            lessonCount = lessons.size,
                            paragraphs = lessonContent,
                            completed = isLocallyCompleted,
                        )
                    }

                    item {
                        LessonNavigation(
                            canGoPrevious = activeLessonIndex > 0 && !isSaving,
                            isSaving = isSaving,
                            isCompleted = isLocallyCompleted,
                            isLastLesson = isLastLesson,
                            canComplete = activeItem.lessonId.isNotBlank() && lessonContent.isNotEmpty(),
                            onPrevious = {
                                actionError = null
                                completionNotice = null
                                activeLessonIndex = (activeLessonIndex - 1).coerceAtLeast(0)
                            },
                            onCompleteOrNext = {
                                actionError = null
                                completionNotice = null

                                if (isLocallyCompleted) {
                                    if (!isLastLesson) activeLessonIndex += 1
                                    return@LessonNavigation
                                }

                                if (activeItem.lessonId.isBlank()) {
                                    actionError = "This lesson does not have a persistent backend identifier, so progress cannot be saved."
                                    return@LessonNavigation
                                }
                                if (lessonContent.isEmpty()) {
                                    actionError = "This lesson has no published content and cannot be completed yet."
                                    return@LessonNavigation
                                }

                                val lessonId = activeItem.lessonId
                                val previousCompletedIds = completedLessonIds
                                val previousCompletedCount = completedCount
                                val previousProgressPercent = displayedProgressPercent

                                completedLessonIds = completedLessonIds + lessonId
                                completedCount = (completedCount + 1).coerceAtMost(totalLessons)
                                displayedProgressPercent = if (totalLessons > 0) {
                                    ((completedCount.toDouble() / totalLessons.toDouble()) * 100.0).toInt()
                                } else {
                                    displayedProgressPercent
                                }
                                savingLessonId = lessonId

                                scope.launch {
                                    runCatching {
                                        ApiClient.learning.markLessonComplete(
                                            LessonCompletionRequest(lessonId = lessonId),
                                        )
                                    }.onSuccess { completion ->
                                        val refreshedProgress = runCatching {
                                            ApiClient.learning.courseProgress(courseId)
                                        }.getOrNull()

                                        if (refreshedProgress != null) {
                                            canonicalProgress = refreshedProgress
                                            completedCount = refreshedProgress.completedLessons
                                            displayedProgressPercent = refreshedProgress.normalizedPercent
                                            progressWarning = null
                                        } else {
                                            progressWarning = "The lesson was saved, but the latest course total could not be refreshed."
                                        }

                                        completionNotice = when {
                                            isLastLesson && completedCount >= totalLessons -> {
                                                val xp = completion.xpAwarded?.takeIf { it > 0 }
                                                if (xp != null) "Course complete. $xp XP awarded." else "Course complete. Your progress was saved."
                                            }
                                            else -> "Lesson complete. Your progress was saved."
                                        }

                                        if (!isLastLesson) activeLessonIndex += 1
                                    }.onFailure { error ->
                                        completedLessonIds = previousCompletedIds
                                        completedCount = previousCompletedCount
                                        displayedProgressPercent = previousProgressPercent
                                        actionError = completionSaveMessage(error)
                                    }
                                    savingLessonId = null
                                }
                            },
                        )
                    }

                    item {
                        Text(
                            text = "Course outline",
                            style = MaterialTheme.typography.titleLarge,
                            color = TextPrimary,
                            fontWeight = FontWeight.Bold,
                            modifier = Modifier.padding(top = 8.dp),
                        )
                    }

                    itemsIndexed(lessons) { index, item ->
                        CourseOutlineRow(
                            item = item,
                            index = index,
                            selected = index == activeLessonIndex,
                            completedThisSession = item.lessonId in completedLessonIds,
                            onClick = {
                                if (savingLessonId == null) {
                                    actionError = null
                                    completionNotice = null
                                    activeLessonIndex = index
                                }
                            },
                        )
                    }

                    item { Spacer(Modifier.height(12.dp)) }
                }
            }
        }
    }
}

@Composable
private fun CourseHeader(
    course: CourseDto,
    completedLessons: Int,
    totalLessons: Int,
    progressPercent: Int,
) {
    GlassCard(modifier = Modifier.fillMaxWidth()) {
        Column(
            verticalArrangement = Arrangement.spacedBy(10.dp),
            modifier = Modifier.padding(18.dp),
        ) {
            Text(
                text = course.title ?: "Untitled course",
                style = MaterialTheme.typography.headlineSmall,
                color = TextPrimary,
                fontWeight = FontWeight.Bold,
            )
            if (!course.description.isNullOrBlank()) {
                Text(
                    text = course.description,
                    style = MaterialTheme.typography.bodyMedium,
                    color = TextSecondary,
                )
            }
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                course.subject?.takeIf { it.isNotBlank() }?.let { TagChip(it) }
                course.difficulty?.takeIf { it.isNotBlank() }?.let { TagChip(it) }
            }
            LinearProgressIndicator(
                progress = { progressPercent / 100f },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(7.dp)
                    .clip(CircleShape),
                color = LyoPurple,
                trackColor = Surface,
            )
            Row(
                horizontalArrangement = Arrangement.SpaceBetween,
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text(
                    text = "$completedLessons of $totalLessons lessons complete",
                    style = MaterialTheme.typography.labelMedium,
                    color = TextSecondary,
                )
                Text(
                    text = "$progressPercent%",
                    style = MaterialTheme.typography.labelMedium,
                    color = LyoPurple,
                    fontWeight = FontWeight.Bold,
                )
            }
        }
    }
}

@Composable
private fun ActiveLessonCard(
    item: CourseLessonItem,
    lessonNumber: Int,
    lessonCount: Int,
    paragraphs: List<String>,
    completed: Boolean,
) {
    GlassCard(modifier = Modifier.fillMaxWidth()) {
        Column(
            verticalArrangement = Arrangement.spacedBy(14.dp),
            modifier = Modifier.padding(18.dp),
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween,
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text(
                    text = "Lesson $lessonNumber of $lessonCount",
                    style = MaterialTheme.typography.labelLarge,
                    color = LyoPurple,
                    fontWeight = FontWeight.Bold,
                )
                if (completed) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(5.dp),
                    ) {
                        Icon(
                            Icons.Default.CheckCircle,
                            contentDescription = null,
                            tint = Color(0xFF35C98A),
                            modifier = Modifier.size(17.dp),
                        )
                        Text(
                            text = "Saved",
                            style = MaterialTheme.typography.labelMedium,
                            color = Color(0xFF35C98A),
                        )
                    }
                }
            }
            item.moduleTitle?.takeIf { it.isNotBlank() }?.let { moduleTitle ->
                Text(
                    text = moduleTitle,
                    style = MaterialTheme.typography.labelMedium,
                    color = TextSecondary,
                )
            }
            Text(
                text = item.lesson.title ?: "Lesson $lessonNumber",
                style = MaterialTheme.typography.headlineSmall,
                color = TextPrimary,
                fontWeight = FontWeight.Bold,
            )

            if (paragraphs.isEmpty()) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(14.dp))
                        .background(Surface)
                        .padding(16.dp),
                ) {
                    Text(
                        text = "This lesson does not have published content yet.",
                        style = MaterialTheme.typography.bodyMedium,
                        color = TextSecondary,
                    )
                }
            } else {
                paragraphs.forEach { paragraph ->
                    Text(
                        text = paragraph,
                        style = MaterialTheme.typography.bodyLarge,
                        color = TextPrimary,
                    )
                }
            }
        }
    }
}

@Composable
private fun LessonNavigation(
    canGoPrevious: Boolean,
    isSaving: Boolean,
    isCompleted: Boolean,
    isLastLesson: Boolean,
    canComplete: Boolean,
    onPrevious: () -> Unit,
    onCompleteOrNext: () -> Unit,
) {
    Row(
        horizontalArrangement = Arrangement.spacedBy(10.dp),
        modifier = Modifier.fillMaxWidth(),
    ) {
        OutlinedButton(
            onClick = onPrevious,
            enabled = canGoPrevious,
            modifier = Modifier.weight(1f),
        ) {
            Icon(
                Icons.AutoMirrored.Filled.ArrowBack,
                contentDescription = null,
                modifier = Modifier.size(17.dp),
            )
            Spacer(Modifier.size(6.dp))
            Text("Previous")
        }

        Button(
            onClick = onCompleteOrNext,
            enabled = !isSaving && (isCompleted || canComplete),
            colors = ButtonDefaults.buttonColors(containerColor = LyoPurple),
            modifier = Modifier.weight(1.6f),
        ) {
            when {
                isSaving -> {
                    CircularProgressIndicator(
                        modifier = Modifier.size(18.dp),
                        color = Color.White,
                        strokeWidth = 2.dp,
                    )
                    Spacer(Modifier.size(8.dp))
                    Text("Saving…")
                }
                isCompleted && isLastLesson -> {
                    Icon(Icons.Default.Check, contentDescription = null, modifier = Modifier.size(18.dp))
                    Spacer(Modifier.size(6.dp))
                    Text("Course complete")
                }
                isCompleted -> {
                    Text("Next lesson")
                    Spacer(Modifier.size(6.dp))
                    Icon(Icons.AutoMirrored.Filled.ArrowForward, contentDescription = null, modifier = Modifier.size(18.dp))
                }
                isLastLesson -> {
                    Text("Complete course")
                    Spacer(Modifier.size(6.dp))
                    Icon(Icons.Default.Check, contentDescription = null, modifier = Modifier.size(18.dp))
                }
                else -> {
                    Text("Complete & next")
                    Spacer(Modifier.size(6.dp))
                    Icon(Icons.AutoMirrored.Filled.ArrowForward, contentDescription = null, modifier = Modifier.size(18.dp))
                }
            }
        }
    }
}

@Composable
private fun CourseOutlineRow(
    item: CourseLessonItem,
    index: Int,
    selected: Boolean,
    completedThisSession: Boolean,
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
                            completedThisSession -> Color(0xFF35C98A).copy(alpha = 0.18f)
                            selected -> LyoPurple
                            else -> Surface
                        },
                    ),
            ) {
                if (completedThisSession) {
                    Icon(
                        Icons.Default.Check,
                        contentDescription = "Completed",
                        tint = Color(0xFF35C98A),
                        modifier = Modifier.size(18.dp),
                    )
                } else {
                    Text(
                        text = "${index + 1}",
                        style = MaterialTheme.typography.labelLarge,
                        color = if (selected) Color.White else TextSecondary,
                    )
                }
            }
            Column(modifier = Modifier.padding(start = 12.dp).weight(1f)) {
                item.moduleTitle?.takeIf { it.isNotBlank() }?.let { moduleTitle ->
                    Text(
                        text = moduleTitle,
                        style = MaterialTheme.typography.labelSmall,
                        color = TextSecondary,
                    )
                }
                Text(
                    text = item.lesson.title ?: "Lesson ${index + 1}",
                    style = MaterialTheme.typography.titleMedium,
                    color = if (selected) LyoPurple else TextPrimary,
                    fontWeight = if (selected) FontWeight.Bold else FontWeight.Medium,
                )
            }
            if (selected) {
                Text(
                    text = "Current",
                    style = MaterialTheme.typography.labelSmall,
                    color = LyoPurple,
                )
            }
        }
    }
}

@Composable
private fun CourseLoadError(message: String, onRetry: () -> Unit) {
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
        TextButton(onClick = onRetry) {
            Icon(Icons.Default.Refresh, contentDescription = null, modifier = Modifier.size(18.dp))
            Spacer(Modifier.size(6.dp))
            Text("Try again")
        }
    }
}

@Composable
private fun StatusCard(
    message: String,
    actionLabel: String,
    onAction: () -> Unit,
    isError: Boolean = false,
) {
    val accent = if (isError) Color(0xFFFF7A7A) else LyoPurple
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(accent.copy(alpha = 0.12f))
            .padding(horizontal = 14.dp, vertical = 12.dp),
    ) {
        Text(
            text = message,
            style = MaterialTheme.typography.bodySmall,
            color = if (isError) Color(0xFFFFB3B3) else TextSecondary,
            modifier = Modifier.weight(1f),
        )
        TextButton(onClick = onAction) {
            Text(actionLabel, color = accent)
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

private fun flattenLessons(course: CourseDto): List<CourseLessonItem> {
    val moduleLessons = course.modules.orEmpty().flatMap { module ->
        module.lessons.orEmpty()
            .sortedBy { it.orderIndex ?: Int.MAX_VALUE }
            .map { lesson -> CourseLessonItem(module.title, lesson) }
    }
    if (moduleLessons.isNotEmpty()) return moduleLessons

    return course.lessons.orEmpty()
        .sortedBy { it.orderIndex ?: Int.MAX_VALUE }
        .map { lesson -> CourseLessonItem(null, lesson) }
}

private fun readableLessonContent(raw: String?): List<String> {
    val trimmed = raw?.trim().orEmpty()
    if (trimmed.isBlank()) return emptyList()

    val extractedJsonText = if (trimmed.startsWith("{") || trimmed.startsWith("[")) {
        runCatching { collectReadableJson(JsonParser.parseString(trimmed)) }.getOrDefault(emptyList())
    } else {
        emptyList()
    }

    val source = extractedJsonText.takeIf { it.isNotEmpty() }
        ?: trimmed.split(Regex("\\n\\s*\\n|\\r\\n\\s*\\r\\n"))

    return source
        .map { it.trim().removePrefix("# ").removePrefix("## ").removePrefix("### ") }
        .filter { it.isNotBlank() }
        .distinct()
}

private fun collectReadableJson(element: JsonElement): List<String> {
    val values = mutableListOf<String>()

    fun visit(node: JsonElement) {
        when {
            node.isJsonArray -> node.asJsonArray.forEach(::visit)
            node.isJsonObject -> {
                val objectNode = node.asJsonObject
                val priorityKeys = listOf("title", "heading", "content", "body", "text", "summary", "explanation")
                priorityKeys.forEach { key ->
                    objectNode.get(key)?.let(::visit)
                }
                objectNode.entrySet()
                    .filterNot { it.key in priorityKeys }
                    .filter { it.key in setOf("blocks", "sections", "items", "paragraphs", "lesson") }
                    .forEach { visit(it.value) }
            }
            node.isJsonPrimitive && node.asJsonPrimitive.isString -> {
                node.asString.trim().takeIf { it.isNotBlank() }?.let(values::add)
            }
        }
    }

    visit(element)
    return values
}

private fun courseLoadMessage(error: Throwable): String = when (error) {
    is HttpException -> when (error.code()) {
        401 -> "Your session expired. Sign in again and reopen the course."
        403 -> "Your account does not have access to this course."
        404 -> "This course was not found or is no longer available."
        else -> "The course service returned an error (${error.code()})."
    }
    is IOException -> "Check your connection and try again."
    else -> error.message ?: "The course could not be loaded."
}

private fun progressLoadMessage(error: Throwable): String = when (error) {
    is HttpException -> when (error.code()) {
        401 -> "Sign in to resume and save progress across devices."
        404 -> "No saved progress exists for this course yet."
        else -> "Course content is available, but saved progress could not be loaded."
    }
    is IOException -> "Course content is available offline, but saved progress could not be refreshed."
    else -> "Course content is available, but saved progress could not be loaded."
}

private fun completionSaveMessage(error: Throwable): String = when (error) {
    is HttpException -> when (error.code()) {
        400, 422 -> "The backend rejected this lesson completion. Reopen the course and try again."
        401 -> "Your session expired. Sign in again to save progress."
        403 -> "Your account cannot update this course."
        404 -> "This lesson no longer exists on the server."
        else -> "Progress was not saved because the learning service returned an error (${error.code()})."
    }
    is IOException -> "Progress was not saved. Check your connection and try again."
    else -> error.message ?: "Progress was not saved. Try again."
}
