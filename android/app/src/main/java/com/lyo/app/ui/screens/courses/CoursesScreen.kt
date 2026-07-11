package com.lyo.app.ui.screens.courses

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Scaffold
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
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.navigation.NavHostController
import com.lyo.app.data.api.ApiClient
import com.lyo.app.data.api.CourseDto
import com.lyo.app.data.api.GenerateCourseRequest
import com.lyo.app.ui.components.CardGradients
import com.lyo.app.ui.components.EmptyState
import com.lyo.app.ui.components.GlassCard
import com.lyo.app.ui.components.LoadingBox
import com.lyo.app.ui.components.LyoBrandGradient
import com.lyo.app.ui.navigation.Routes
import com.lyo.app.ui.theme.Background
import com.lyo.app.ui.theme.BorderColor
import com.lyo.app.ui.theme.LyoAmber
import com.lyo.app.ui.theme.LyoGreen
import com.lyo.app.ui.theme.LyoPurple
import com.lyo.app.ui.theme.LyoRed
import com.lyo.app.ui.theme.Surface
import com.lyo.app.ui.theme.TextPrimary
import com.lyo.app.ui.theme.TextSecondary
import kotlinx.coroutines.launch

private val CourseEmojis = listOf("📚", "🧠", "🎨", "🐍", "🎵", "⚛️")
private val DifficultyOptions = listOf("beginner", "intermediate", "advanced")

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CoursesScreen(nav: NavHostController) {
    var courses by remember { mutableStateOf<List<CourseDto>>(emptyList()) }
    var loading by remember { mutableStateOf(true) }
    var topic by remember { mutableStateOf("") }
    var difficulty by remember { mutableStateOf("beginner") }
    var generating by remember { mutableStateOf(false) }
    var status by remember { mutableStateOf<String?>(null) }
    var subjectFilter by remember { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()

    LaunchedEffect(Unit) {
        runCatching { ApiClient.api.courses(0, 30) }
            .onSuccess { courses = it }
        loading = false
    }

    val subjects = remember(courses) {
        courses.mapNotNull { c -> c.subject?.takeIf { it.isNotBlank() } }.distinct()
    }
    val visibleCourses =
        if (subjectFilter == null) courses
        else courses.filter { it.subject == subjectFilter }

    fun generate() {
        if (generating || topic.isBlank()) return
        generating = true
        status = null
        scope.launch {
            runCatching {
                ApiClient.api.generateCourse(GenerateCourseRequest(topic.trim(), difficulty))
            }.onSuccess {
                status = "Course generation started… check back soon!"
                topic = ""
            }.onFailure {
                status = "Could not start generation. Please try again."
            }
            generating = false
        }
    }

    Scaffold(
        containerColor = Background,
        topBar = {
            TopAppBar(
                title = { Text("Courses") },
                navigationIcon = {
                    IconButton(onClick = { nav.popBackStack() }) {
                        Icon(
                            Icons.Filled.ArrowBack,
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
        },
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 16.dp),
        ) {
            // ── Generate with AI ──
            GlassCard(modifier = Modifier.fillMaxWidth()) {
                Column(Modifier.padding(16.dp)) {
                    Text(
                        "✨ Generate with AI",
                        style = MaterialTheme.typography.titleLarge,
                        color = TextPrimary,
                    )
                    Spacer(Modifier.height(12.dp))
                    OutlinedTextField(
                        value = topic,
                        onValueChange = { topic = it },
                        label = { Text("Topic") },
                        placeholder = { Text("e.g. Machine Learning basics") },
                        singleLine = true,
                        shape = RoundedCornerShape(14.dp),
                        colors = OutlinedTextFieldDefaults.colors(
                            focusedBorderColor = LyoPurple,
                            unfocusedBorderColor = BorderColor,
                            focusedLabelColor = LyoPurple,
                            unfocusedLabelColor = TextSecondary,
                            cursorColor = LyoPurple,
                        ),
                        modifier = Modifier.fillMaxWidth(),
                    )
                    Spacer(Modifier.height(12.dp))
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        DifficultyOptions.forEach { option ->
                            CoursePill(
                                text = option.replaceFirstChar { it.uppercase() },
                                selected = difficulty == option,
                                onClick = { difficulty = option },
                            )
                        }
                    }
                    Spacer(Modifier.height(14.dp))
                    Box(
                        contentAlignment = Alignment.Center,
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(46.dp)
                            .clip(RoundedCornerShape(14.dp))
                            .background(LyoBrandGradient)
                            .clickable(enabled = !generating) { generate() },
                    ) {
                        if (generating) {
                            CircularProgressIndicator(
                                color = Color.White,
                                strokeWidth = 2.dp,
                                modifier = Modifier.size(20.dp),
                            )
                        } else {
                            Text(
                                "Generate",
                                color = Color.White,
                                style = MaterialTheme.typography.titleMedium,
                            )
                        }
                    }
                    status?.let {
                        Text(
                            it,
                            style = MaterialTheme.typography.bodySmall,
                            color = LyoGreen,
                            modifier = Modifier.padding(top = 10.dp),
                        )
                    }
                }
            }

            Spacer(Modifier.height(16.dp))

            // ── Subject filter chips ──
            if (subjects.isNotEmpty()) {
                Row(
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    modifier = Modifier
                        .fillMaxWidth()
                        .horizontalScroll(rememberScrollState()),
                ) {
                    CoursePill(
                        text = "All",
                        selected = subjectFilter == null,
                        onClick = { subjectFilter = null },
                    )
                    subjects.forEach { subject ->
                        CoursePill(
                            text = subject,
                            selected = subjectFilter == subject,
                            onClick = {
                                subjectFilter = if (subjectFilter == subject) null else subject
                            },
                        )
                    }
                }
                Spacer(Modifier.height(16.dp))
            }

            // ── Course list ──
            when {
                loading -> LoadingBox()
                visibleCourses.isEmpty() -> EmptyState(
                    title = "No courses yet",
                    subtitle = "Generate your first course with AI",
                )
                else -> Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    visibleCourses.forEachIndexed { index, course ->
                        CourseCard(course = course, index = index) {
                            nav.navigate(Routes.courseDetail(course.idStr))
                        }
                    }
                }
            }

            Spacer(Modifier.height(24.dp))
        }
    }
}

@Composable
private fun CourseCard(course: CourseDto, index: Int, onClick: () -> Unit) {
    GlassCard(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(20.dp))
            .clickable(onClick = onClick),
    ) {
        Box(
            contentAlignment = Alignment.Center,
            modifier = Modifier
                .fillMaxWidth()
                .height(96.dp)
                .background(CardGradients[index % CardGradients.size]),
        ) {
            Text(CourseEmojis[index % CourseEmojis.size], fontSize = 40.sp)
        }
        Column(Modifier.padding(14.dp)) {
            Text(
                text = course.title ?: "Untitled course",
                style = MaterialTheme.typography.titleMedium,
                color = TextPrimary,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
            )
            course.subject?.takeIf { it.isNotBlank() }?.let {
                Text(
                    text = it,
                    style = MaterialTheme.typography.bodySmall,
                    color = TextSecondary,
                    modifier = Modifier.padding(top = 4.dp),
                )
            }
            course.difficulty?.takeIf { it.isNotBlank() }?.let { diff ->
                val color = when (diff.lowercase()) {
                    "beginner" -> LyoGreen
                    "intermediate" -> LyoAmber
                    "advanced" -> LyoRed
                    else -> LyoPurple
                }
                Text(
                    text = diff.replaceFirstChar { it.uppercase() },
                    style = MaterialTheme.typography.labelMedium,
                    color = color,
                    modifier = Modifier
                        .padding(top = 8.dp)
                        .clip(RoundedCornerShape(50))
                        .background(color.copy(alpha = 0.15f))
                        .padding(horizontal = 10.dp, vertical = 4.dp),
                )
            }
        }
    }
}

@Composable
private fun CoursePill(text: String, selected: Boolean, onClick: () -> Unit) {
    Text(
        text = text,
        style = MaterialTheme.typography.labelLarge,
        color = if (selected) Color.White else TextSecondary,
        modifier = Modifier
            .clip(RoundedCornerShape(50))
            .background(if (selected) LyoPurple else Surface)
            .border(
                1.dp,
                if (selected) LyoPurple else BorderColor,
                RoundedCornerShape(50),
            )
            .clickable(onClick = onClick)
            .padding(horizontal = 14.dp, vertical = 8.dp),
    )
}
