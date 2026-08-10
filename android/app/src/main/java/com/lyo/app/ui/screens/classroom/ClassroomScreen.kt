package com.lyo.app.ui.screens.classroom

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
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
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.School
import androidx.compose.material.icons.filled.SmartToy
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.navigation.NavHostController
import com.google.gson.JsonParser
import com.lyo.app.data.api.AiGenerateRequest
import com.lyo.app.data.api.ApiClient
import com.lyo.app.ui.theme.Background
import com.lyo.app.ui.theme.BorderColor
import com.lyo.app.ui.theme.LyoGold
import com.lyo.app.ui.theme.LyoPurple
import com.lyo.app.ui.theme.LyoVioletLight
import com.lyo.app.ui.theme.Surface
import com.lyo.app.ui.theme.TextPrimary
import com.lyo.app.ui.theme.TextSecondary
import kotlinx.coroutines.launch
import kotlin.math.max

private data class ClassroomQuizOption(
    val id: String,
    val label: String,
    val correct: Boolean = false,
)

private data class ClassroomScene(
    val title: String,
    val boardLines: List<String>,
    val teacherText: String,
    val quizQuestion: String?,
    val quizOptions: List<ClassroomQuizOption>,
)

@Composable
fun ClassroomScreen(
    nav: NavHostController,
    topic: String,
    courseId: String?,
) {
    val objective = if (courseId.isNullOrBlank()) {
        "Understand and apply $topic"
    } else {
        "Continue the same classroom experience for this course"
    }
    val outline = remember(topic, objective) {
        mutableStateListOf<String>().apply { addAll(fallbackOutline(topic, objective)) }
    }
    val scope = rememberCoroutineScope()
    var sceneIndex by remember(topic) { mutableStateOf(0) }
    var selectedAnswerId by remember(topic, sceneIndex) { mutableStateOf<String?>(null) }
    var showChoiceNudge by remember(topic, sceneIndex) { mutableStateOf(false) }
    var isExtending by remember(topic) { mutableStateOf(false) }
    var continuationBatch by remember(topic) { mutableStateOf(0) }

    suspend fun extendOutlineIfNeeded(force: Boolean = false) {
        if (isExtending) return
        val remaining = outline.size - sceneIndex
        if (!force && remaining > 2) return

        isExtending = true
        try {
            val nextBatch = continuationBatch + 1
            val generatedTitles = runCatching {
                val prompt = buildString {
                    appendLine("TOPIC: $topic")
                    appendLine("OBJECTIVE: $objective")
                    appendLine("CURRENT OUTLINE: ${outline.mapIndexed { index, title -> "${index + 1}. $title" }.joinToString(" | ")}")
                    appendLine("Return ONLY a JSON array of the NEXT 4 section titles. No markdown.")
                }
                parseTitleArray(ApiClient.api.aiGenerate(AiGenerateRequest(prompt)).response.orEmpty())
            }.getOrDefault(emptyList())

            val existing = outline.map { normalizedTitle(it) }.toSet()
            val next = generatedTitles
                .map { it.trim() }
                .filter { it.isNotBlank() && normalizedTitle(it) !in existing }
                .take(4)

            outline.addAll(next.ifEmpty { fallbackContinuationSections(topic, nextBatch) })
            continuationBatch = nextBatch
        } finally {
            isExtending = false
        }
    }

    LaunchedEffect(sceneIndex, outline.size) {
        extendOutlineIfNeeded()
    }

    val safeIndex = sceneIndex.coerceIn(0, outline.lastIndex)
    val scene = remember(safeIndex, outline.size) {
        makeScene(outline[safeIndex], topic, safeIndex)
    }
    val needsChoice = scene.quizQuestion != null && selectedAnswerId == null
    val progress = ((safeIndex + 1).toFloat() / max(outline.size, 1).toFloat()).coerceIn(0f, 1f)

    fun advance(force: Boolean = false) {
        if (!force && needsChoice) {
            showChoiceNudge = true
            return
        }
        if (sceneIndex >= outline.lastIndex) {
            scope.launch {
                extendOutlineIfNeeded(force = true)
                sceneIndex += 1
            }
        } else {
            sceneIndex += 1
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Background)
            .padding(horizontal = 16.dp, vertical = 12.dp),
    ) {
        ClassroomHeader(
            topic = topic,
            sceneNumber = safeIndex + 1,
            totalScenes = outline.size,
            progress = progress,
            onBack = { nav.popBackStack() },
        )

        ClassroomBoard(
            scene = scene,
            selectedAnswerId = selectedAnswerId,
            onAnswer = {
                selectedAnswerId = it.id
                showChoiceNudge = false
            },
            modifier = Modifier
                .weight(1f)
                .padding(top = 12.dp),
        )

        if (showChoiceNudge && needsChoice) {
            Text(
                text = "Choose an answer on the board to continue.",
                style = MaterialTheme.typography.labelMedium,
                color = Color(0xFFFF9CA3),
                modifier = Modifier
                    .align(Alignment.CenterHorizontally)
                    .padding(top = 8.dp),
            )
        }

        ClassroomTransport(
            canGoPrevious = sceneIndex > 0,
            primaryLabel = if (needsChoice) "Choose an answer" else "Continue lesson",
            isPreparing = isExtending && sceneIndex >= outline.lastIndex,
            onPrevious = { sceneIndex = (sceneIndex - 1).coerceAtLeast(0) },
            onPrimary = { advance() },
            onSkip = { advance(force = true) },
            modifier = Modifier.padding(top = 10.dp),
        )
    }
}

@Composable
private fun ClassroomHeader(
    topic: String,
    sceneNumber: Int,
    totalScenes: Int,
    progress: Float,
    onBack: () -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            IconButton(onClick = onBack) {
                Icon(
                    Icons.AutoMirrored.Filled.ArrowBack,
                    contentDescription = "Back",
                    tint = TextSecondary,
                )
            }
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = topic,
                    style = MaterialTheme.typography.titleMedium,
                    color = TextPrimary,
                    fontWeight = FontWeight.Bold,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                Text(
                    text = "Class in session · Scene $sceneNumber of $totalScenes",
                    style = MaterialTheme.typography.labelMedium,
                    color = TextSecondary,
                )
            }
        }
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(5.dp)
                .clip(RoundedCornerShape(999.dp))
                .background(Surface),
        ) {
            Box(
                modifier = Modifier
                    .fillMaxWidth(progress)
                    .height(5.dp)
                    .clip(RoundedCornerShape(999.dp))
                    .background(Brush.horizontalGradient(listOf(LyoPurple, LyoVioletLight))),
            )
        }
    }
}

@Composable
private fun ClassroomBoard(
    scene: ClassroomScene,
    selectedAnswerId: String?,
    onAnswer: (ClassroomQuizOption) -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(22.dp))
            .background(
                Brush.verticalGradient(
                    listOf(Color(0xFF17203F), Color(0xFF0D142E), Color(0xFF0A0F24)),
                ),
            )
            .border(2.dp, Color(0xFF3A3323), RoundedCornerShape(22.dp)),
    ) {
        Column(
            verticalArrangement = Arrangement.spacedBy(14.dp),
            modifier = Modifier
                .weight(1f)
                .verticalScroll(rememberScrollState())
                .padding(18.dp),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(
                    modifier = Modifier
                        .size(7.dp)
                        .clip(CircleShape)
                        .background(LyoVioletLight),
                )
                Text(
                    text = "LYO BOARD",
                    style = MaterialTheme.typography.labelSmall,
                    color = LyoVioletLight,
                    fontWeight = FontWeight.Black,
                    modifier = Modifier.padding(start = 8.dp),
                )
                Spacer(modifier = Modifier.weight(1f))
                Text(
                    text = if (scene.quizQuestion == null) "LIVE" else "PRACTICE",
                    style = MaterialTheme.typography.labelSmall,
                    color = TextSecondary,
                    fontWeight = FontWeight.Bold,
                )
            }

            Text(
                text = scene.title,
                style = MaterialTheme.typography.titleLarge,
                color = TextPrimary,
                fontWeight = FontWeight.Bold,
            )

            scene.boardLines.forEachIndexed { index, line ->
                Row(
                    horizontalArrangement = Arrangement.spacedBy(10.dp),
                    verticalAlignment = Alignment.Top,
                ) {
                    Box(
                        contentAlignment = Alignment.Center,
                        modifier = Modifier
                            .size(26.dp)
                            .clip(CircleShape)
                            .background(LyoVioletLight),
                    ) {
                        Text(
                            text = "${index + 1}",
                            style = MaterialTheme.typography.labelMedium,
                            color = Color(0xFF0A0F24),
                            fontWeight = FontWeight.Black,
                        )
                    }
                    Text(
                        text = line,
                        style = MaterialTheme.typography.bodyLarge,
                        color = if (index == 0) TextPrimary else TextSecondary,
                        fontWeight = if (index == 0) FontWeight.SemiBold else FontWeight.Normal,
                        modifier = Modifier.weight(1f),
                    )
                }
            }

            if (scene.quizQuestion != null) {
                MultipleChoiceCheck(
                    question = scene.quizQuestion,
                    options = scene.quizOptions,
                    selectedAnswerId = selectedAnswerId,
                    onAnswer = onAnswer,
                )
            }
        }

        TeacherCaption(text = scene.teacherText)
    }
}

@Composable
private fun MultipleChoiceCheck(
    question: String,
    options: List<ClassroomQuizOption>,
    selectedAnswerId: String?,
    onAnswer: (ClassroomQuizOption) -> Unit,
) {
    Column(
        verticalArrangement = Arrangement.spacedBy(10.dp),
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(LyoGold.copy(alpha = 0.10f))
            .border(1.dp, LyoGold.copy(alpha = 0.28f), RoundedCornerShape(16.dp))
            .padding(14.dp),
    ) {
        Text(
            text = "Concept Check",
            style = MaterialTheme.typography.labelMedium,
            color = LyoGold,
            fontWeight = FontWeight.Black,
        )
        Text(
            text = question,
            style = MaterialTheme.typography.titleSmall,
            color = TextPrimary,
            fontWeight = FontWeight.Bold,
        )
        options.forEach { option ->
            val selected = selectedAnswerId == option.id
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(14.dp))
                    .background(if (selected) LyoPurple.copy(alpha = 0.18f) else Color.White.copy(alpha = 0.05f))
                    .border(
                        1.dp,
                        if (selected) LyoVioletLight.copy(alpha = 0.62f) else BorderColor,
                        RoundedCornerShape(14.dp),
                    )
                    .clickable(enabled = selectedAnswerId == null) { onAnswer(option) }
                    .padding(horizontal = 12.dp, vertical = 11.dp),
            ) {
                Box(
                    contentAlignment = Alignment.Center,
                    modifier = Modifier
                        .size(18.dp)
                        .clip(CircleShape)
                        .background(if (selected) LyoVioletLight else Color.White.copy(alpha = 0.08f)),
                ) {
                    if (selected && option.correct) {
                        Icon(
                            Icons.Filled.CheckCircle,
                            contentDescription = null,
                            tint = Color(0xFF0A0F24),
                            modifier = Modifier.size(14.dp),
                        )
                    }
                }
                Text(
                    text = option.label,
                    style = MaterialTheme.typography.bodyMedium,
                    color = TextPrimary,
                    modifier = Modifier
                        .weight(1f)
                        .padding(start = 10.dp),
                )
            }
        }
    }
}

@Composable
private fun TeacherCaption(text: String) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .background(Color.Black.copy(alpha = 0.24f))
            .padding(14.dp),
    ) {
        Box(
            contentAlignment = Alignment.Center,
            modifier = Modifier
                .size(42.dp)
                .clip(CircleShape)
                .background(Color.White.copy(alpha = 0.10f))
                .border(1.dp, LyoVioletLight.copy(alpha = 0.35f), CircleShape),
        ) {
            Icon(
                Icons.Filled.School,
                contentDescription = null,
                tint = LyoVioletLight,
                modifier = Modifier.size(23.dp),
            )
        }
        Column(
            verticalArrangement = Arrangement.spacedBy(2.dp),
            modifier = Modifier
                .weight(1f)
                .padding(start = 11.dp),
        ) {
            Row(horizontalArrangement = Arrangement.spacedBy(7.dp)) {
                Text(
                    text = "Teacher",
                    style = MaterialTheme.typography.labelLarge,
                    color = TextPrimary,
                    fontWeight = FontWeight.Bold,
                )
                Text(
                    text = "AI Teacher",
                    style = MaterialTheme.typography.labelSmall,
                    color = LyoVioletLight,
                )
            }
            Text(
                text = text,
                style = MaterialTheme.typography.bodySmall,
                color = TextSecondary,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
            )
        }
        Icon(
            Icons.Filled.SmartToy,
            contentDescription = null,
            tint = LyoGold,
            modifier = Modifier.size(22.dp),
        )
    }
}

@Composable
private fun ClassroomTransport(
    canGoPrevious: Boolean,
    primaryLabel: String,
    isPreparing: Boolean,
    onPrevious: () -> Unit,
    onPrimary: () -> Unit,
    onSkip: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Row(
        horizontalArrangement = Arrangement.spacedBy(9.dp),
        modifier = modifier.fillMaxWidth(),
    ) {
        OutlinedButton(
            onClick = onPrevious,
            enabled = canGoPrevious,
            modifier = Modifier.height(48.dp),
        ) {
            Icon(
                Icons.AutoMirrored.Filled.ArrowBack,
                contentDescription = null,
                modifier = Modifier.size(18.dp),
            )
        }
        Button(
            onClick = onPrimary,
            enabled = !isPreparing,
            colors = ButtonDefaults.buttonColors(containerColor = LyoPurple),
            modifier = Modifier
                .weight(1f)
                .height(48.dp),
        ) {
            if (isPreparing) {
                CircularProgressIndicator(
                    color = Color.White,
                    strokeWidth = 2.dp,
                    modifier = Modifier.size(18.dp),
                )
            } else {
                Text(primaryLabel, maxLines = 1, overflow = TextOverflow.Ellipsis)
                Spacer(modifier = Modifier.size(7.dp))
                Icon(
                    Icons.AutoMirrored.Filled.ArrowForward,
                    contentDescription = null,
                    modifier = Modifier.size(18.dp),
                )
            }
        }
        OutlinedButton(
            onClick = onSkip,
            modifier = Modifier.height(48.dp),
        ) {
            Icon(
                Icons.AutoMirrored.Filled.ArrowForward,
                contentDescription = null,
                modifier = Modifier.size(18.dp),
            )
            Spacer(modifier = Modifier.size(6.dp))
            Text("Skip")
        }
    }
}

private fun makeScene(title: String, topic: String, index: Int): ClassroomScene {
    val focus = title.replace(Regex("^Lesson\\s+\\d+:\\s*", RegexOption.IGNORE_CASE), "")
    val hasQuiz = index % 2 == 1
    return ClassroomScene(
        title = title,
        boardLines = listOf(
            focus,
            "Name the one decision this changes when you work with ${topic.ifBlank { "this topic" }}.",
            "Use the check below to prove the idea before moving on.",
        ),
        teacherText = "Focus on the board first. I am explaining how $focus changes what you do next, so the screen and teacher are saying the same thing.",
        quizQuestion = if (hasQuiz) "What should you do with this board before moving on?" else null,
        quizOptions = if (hasQuiz) {
            listOf(
                ClassroomQuizOption("a", "Memorize the words exactly"),
                ClassroomQuizOption("b", "Explain the idea and apply it to one choice", correct = true),
                ClassroomQuizOption("c", "Skip practice until the final lesson"),
                ClassroomQuizOption("d", "Only reread the title"),
            )
        } else {
            emptyList()
        },
    )
}

private fun fallbackOutline(topic: String, objective: String): List<String> {
    val cleanTopic = topic.ifBlank { "this topic" }
    val cleanObjective = objective.ifBlank { "understand and apply $cleanTopic" }
    return listOf(
        "Lesson 1: What $cleanTopic means",
        "Lesson 2: Why $cleanTopic matters for $cleanObjective",
        "Lesson 3: A worked example with $cleanTopic",
        "Lesson 4: Common mistakes in $cleanTopic",
        "Lesson 5: Applying $cleanTopic in a new situation",
        "Lesson 6: Guided practice with feedback",
    )
}

private fun fallbackContinuationSections(topic: String, batch: Int): List<String> {
    val cleanTopic = topic.ifBlank { "this topic" }
    return listOf(
        "Lesson ${batch * 4 + 1}: Applying $cleanTopic in a new situation",
        "Lesson ${batch * 4 + 2}: Common edge cases in $cleanTopic",
        "Lesson ${batch * 4 + 3}: Guided practice with feedback",
        "Lesson ${batch * 4 + 4}: Building fluency with $cleanTopic",
    )
}

private fun parseTitleArray(raw: String): List<String> {
    val start = raw.indexOf('[')
    val end = raw.lastIndexOf(']')
    if (start < 0 || end <= start) return emptyList()
    return runCatching {
        JsonParser.parseString(raw.substring(start, end + 1))
            .asJsonArray
            .mapNotNull { element ->
                element.takeIf { it.isJsonPrimitive }
                    ?.asString
                    ?.takeIf { it.isNotBlank() }
            }
    }.getOrDefault(emptyList())
}

private fun normalizedTitle(title: String): String =
    title.lowercase().replace(Regex("[\\s:.-]"), "")
