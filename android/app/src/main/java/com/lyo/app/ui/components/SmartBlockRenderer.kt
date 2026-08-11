package com.lyo.app.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Cancel
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Lightbulb
import androidx.compose.material.icons.filled.RadioButtonUnchecked
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.LinearProgressIndicator
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import com.lyo.app.data.api.CheckAnswerResult
import com.lyo.app.data.api.CodeBlockPayload
import com.lyo.app.data.api.DataVizBlockPayload
import com.lyo.app.data.api.FlashcardBlockPayload
import com.lyo.app.data.api.InteractiveBlockPayload
import com.lyo.app.data.api.MasteryMapBlockPayload
import com.lyo.app.data.api.MediaBlockPayload
import com.lyo.app.data.api.ProgressBlockPayload
import com.lyo.app.data.api.QuizBlockPayload
import com.lyo.app.data.api.SmartBlock
import com.lyo.app.data.api.SmartBlockContent
import com.lyo.app.data.api.TextBlockPayload
import com.lyo.app.ui.theme.BorderColor
import com.lyo.app.ui.theme.LyoPurple
import com.lyo.app.ui.theme.Surface
import com.lyo.app.ui.theme.TextPrimary
import com.lyo.app.ui.theme.TextSecondary
import kotlinx.coroutines.delay

private val CorrectGreen = Color(0xFF34C759)
private val WrongRed = Color(0xFFFF3B30)

/**
 * Renders a turn's structured lesson blocks in order — every beat (hook,
 * callout, dataViz, flashcard, quiz, ...), not just plain text. Mirrors
 * iOS's UnifiedBlockRenderer and web's BlockRenderer.tsx; the wire
 * vocabulary is pinned by scripts/verify-chat-blocks-parity.mjs.
 */
@Composable
fun SmartBlockList(
    blocks: List<SmartBlock>,
    checkResults: Map<String, CheckAnswerResult>,
    onQuizAnswer: (blockId: String, selectedIndex: Int) -> Unit,
    modifier: Modifier = Modifier,
    contentColor: Color = TextPrimary,
) {
    Column(modifier = modifier, verticalArrangement = Arrangement.spacedBy(10.dp)) {
        blocks.forEach { block ->
            SmartBlockView(
                block = block,
                checkResult = checkResults[block.id],
                onAnswer = { index -> onQuizAnswer(block.id, index) },
                color = contentColor,
            )
        }
    }
}

@Composable
private fun SmartBlockView(
    block: SmartBlock,
    checkResult: CheckAnswerResult?,
    onAnswer: (Int) -> Unit,
    color: Color,
) {
    when (val content = block.content) {
        is SmartBlockContent.Text -> TextBlockView(content.payload, block.subtype, color)
        is SmartBlockContent.Code -> CodeBlockView(content.payload, color)
        is SmartBlockContent.Quiz -> QuizBlockView(content.payload, checkResult, onAnswer, color)
        is SmartBlockContent.Flashcard -> FlashcardBlockView(content.payload, color)
        is SmartBlockContent.DataViz -> DataVizBlockView(content.payload, color)
        is SmartBlockContent.Media -> MediaBlockView(content.payload)
        is SmartBlockContent.Progress -> ProgressBlockView(content.payload)
        is SmartBlockContent.Interactive -> InteractiveBlockView(content.payload, color)
        is SmartBlockContent.MasteryMap -> MasteryMapBlockView(content.payload, color)
        is SmartBlockContent.Unknown -> UnknownBlockView()
    }
}

// ── Text (subtypes: heading, summary, callout, hook, paragraph default) ─────

@Composable
private fun TextBlockView(payload: TextBlockPayload, subtype: String?, color: Color) {
    when (subtype) {
        "heading" -> Text(
            text = payload.text,
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.Bold,
            color = color,
        )

        "summary" -> Column(
            modifier = Modifier
                .fillMaxWidth()
                .background(color.copy(alpha = 0.06f), RoundedCornerShape(12.dp))
                .padding(12.dp),
            verticalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            Text("SUMMARY", style = MaterialTheme.typography.labelSmall, color = TextSecondary)
            MarkdownText(payload.text, color = color)
        }

        "callout" -> Row(
            modifier = Modifier
                .fillMaxWidth()
                .background(Color(0xFFFFC107).copy(alpha = 0.12f), RoundedCornerShape(12.dp))
                .padding(12.dp),
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Icon(Icons.Default.Lightbulb, contentDescription = null, tint = Color(0xFFFFC107))
            MarkdownText(payload.text, color = color)
        }

        "hook" -> Text(
            text = payload.text,
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Bold,
            color = color,
            modifier = Modifier
                .fillMaxWidth()
                .background(LyoPurple.copy(alpha = 0.14f), RoundedCornerShape(16.dp))
                .padding(14.dp),
        )

        else -> MarkdownText(payload.text, color = color)
    }
}

@Composable
private fun CodeBlockView(payload: CodeBlockPayload, color: Color) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(Color.Black.copy(alpha = 0.35f), RoundedCornerShape(12.dp))
            .padding(12.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Text(payload.language.uppercase(), style = MaterialTheme.typography.labelSmall, color = TextSecondary)
        Text(payload.code, fontFamily = FontFamily.Monospace, fontSize = 13.sp, color = color)
    }
}

// ── Quiz — the answerable check ──────────────────────────────────────────────

/**
 * An answerable check inside a chat lesson.
 *
 * The verdict comes from the server (`checkResult`), never from comparing a
 * tap against `payload.correctIndex` — that field rides on the wire for the
 * *server's* use when grading, and this view never reads it. Same rule as
 * web's CheckBlock.tsx and iOS's SmartQuizBlockView, for the same reason:
 * deciding correctness on the client is the exact bug this feature exists
 * to remove (chat praising a wrong answer).
 */
@Composable
private fun QuizBlockView(
    payload: QuizBlockPayload,
    checkResult: CheckAnswerResult?,
    onAnswer: (Int) -> Unit,
    color: Color,
) {
    var pendingIndex by remember(payload) { mutableStateOf<Int?>(null) }
    val answered = checkResult != null
    val isGrading = pendingIndex != null && checkResult == null

    // Grading is normally near-instant. If the request drops (no result,
    // no error surfaced back into this view — onAnswer is fire-and-forget)
    // the option would otherwise be stuck showing a spinner forever with no
    // way to retry. Recover by re-enabling the options after a timeout.
    LaunchedEffect(pendingIndex, checkResult) {
        if (pendingIndex != null && checkResult == null) {
            delay(15_000)
            pendingIndex = null
        }
    }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(Surface, RoundedCornerShape(16.dp))
            .border(1.dp, BorderColor, RoundedCornerShape(16.dp))
            .padding(14.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        MarkdownText(payload.question, color = color)

        payload.options.forEachIndexed { index, option ->
            val isBailout = payload.bailoutIndex == index
            val isChosen = checkResult?.selectedIndex == index
            val isCorrectAnswer = answered && checkResult?.correctIndex == index
            val isWrongChoice = isChosen && checkResult != null && !checkResult.correct && !checkResult.bailedOut
            val isPendingChoice = !answered && pendingIndex == index

            val rowBackground = when {
                isCorrectAnswer -> CorrectGreen.copy(alpha = 0.15f)
                isWrongChoice -> WrongRed.copy(alpha = 0.15f)
                isPendingChoice -> LyoPurple.copy(alpha = 0.12f)
                else -> Color.White.copy(alpha = 0.05f)
            }

            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(10.dp),
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(12.dp))
                    .background(rowBackground)
                    .then(
                        if (!answered && pendingIndex == null) {
                            Modifier.clickable {
                                pendingIndex = index
                                onAnswer(index)
                            }
                        } else {
                            Modifier
                        },
                    )
                    .padding(12.dp),
            ) {
                when {
                    isPendingChoice && isGrading ->
                        CircularProgressIndicator(color = LyoPurple, strokeWidth = 2.dp, modifier = Modifier.size(16.dp))
                    isCorrectAnswer -> Icon(Icons.Default.CheckCircle, contentDescription = null, tint = CorrectGreen)
                    isWrongChoice -> Icon(Icons.Default.Cancel, contentDescription = null, tint = WrongRed)
                    else -> Icon(Icons.Default.RadioButtonUnchecked, contentDescription = null, tint = TextSecondary)
                }
                Text(
                    text = option.text,
                    style = MaterialTheme.typography.bodyMedium,
                    color = if (isBailout && !answered) TextSecondary else color,
                    fontStyle = if (isBailout && !answered) FontStyle.Italic else FontStyle.Normal,
                )
            }
        }

        checkResult?.let { result ->
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(
                        (if (result.correct) CorrectGreen else WrongRed).copy(alpha = if (result.bailedOut) 0f else 0.1f),
                        RoundedCornerShape(10.dp),
                    )
                    .padding(10.dp),
                verticalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                Text(
                    text = when {
                        result.bailedOut -> "No problem — here it is."
                        result.correct -> "Correct."
                        else -> "Not quite."
                    },
                    style = MaterialTheme.typography.labelMedium,
                    color = when {
                        result.bailedOut -> TextSecondary
                        result.correct -> CorrectGreen
                        else -> WrongRed
                    },
                )
                // Naming the specific confusion is the point — not just "wrong".
                if (!result.correct && result.misconception != null) {
                    Text(result.misconception, style = MaterialTheme.typography.bodySmall, color = TextSecondary)
                }
                result.explanation?.let { MarkdownText(it, color = color) }
            }
        }
    }
}

// ── Flashcard — tap to flip ──────────────────────────────────────────────────

@Composable
private fun FlashcardBlockView(payload: FlashcardBlockPayload, color: Color) {
    var flipped by remember(payload) { mutableStateOf(false) }
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .heightIn(min = 120.dp)
            .clip(RoundedCornerShape(16.dp))
            .background(Surface)
            .border(1.dp, BorderColor, RoundedCornerShape(16.dp))
            .clickable { flipped = !flipped }
            .padding(20.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = if (flipped) payload.back else payload.front,
            style = if (flipped) MaterialTheme.typography.bodyLarge else MaterialTheme.typography.titleMedium,
            color = color,
            textAlign = TextAlign.Center,
        )
    }
}

// ── Data visualization ───────────────────────────────────────────────────────

@Composable
private fun DataVizBlockView(payload: DataVizBlockPayload, color: Color) {
    Column(modifier = Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(6.dp)) {
        payload.title?.let { Text(it, style = MaterialTheme.typography.labelMedium, color = TextSecondary) }
        // No mermaid.js/KaTeX renderer wired in here — WebViewBlock.kt hosts
        // one, but its own doc comment discloses it hasn't been verified on
        // a real device. Labeled raw source is the same honest fallback iOS
        // uses for math (UnifiedBlockRenderer.swift) and this codebase
        // already uses for diagrams elsewhere (MermaidBlockRenderer.kt).
        Text(
            text = payload.source,
            fontFamily = FontFamily.Monospace,
            fontSize = 12.sp,
            color = color,
            modifier = Modifier
                .fillMaxWidth()
                .background(Color.Black.copy(alpha = 0.3f), RoundedCornerShape(10.dp))
                .padding(12.dp),
        )
    }
}

@Composable
private fun MediaBlockView(payload: MediaBlockPayload) {
    Column(modifier = Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(4.dp)) {
        AsyncImage(
            model = payload.url,
            contentDescription = payload.alt ?: payload.caption,
            contentScale = ContentScale.Fit,
            modifier = Modifier
                .fillMaxWidth()
                .heightIn(min = 120.dp, max = 280.dp)
                .clip(RoundedCornerShape(12.dp)),
        )
        payload.caption?.let { Text(it, style = MaterialTheme.typography.bodySmall, color = TextSecondary) }
    }
}

@Composable
private fun ProgressBlockView(payload: ProgressBlockPayload) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(Surface, RoundedCornerShape(12.dp))
            .padding(12.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        payload.label?.let { Text(it, style = MaterialTheme.typography.labelSmall, color = TextSecondary) }
        val fraction = if (payload.total > 0) payload.completed.toFloat() / payload.total.toFloat() else 0f
        LinearProgressIndicator(
            progress = { fraction },
            modifier = Modifier.fillMaxWidth(),
            color = LyoPurple,
        )
        Text("${payload.completed}/${payload.total}", style = MaterialTheme.typography.labelSmall, color = TextSecondary)
    }
}

@Composable
private fun InteractiveBlockView(payload: InteractiveBlockPayload, color: Color) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(Surface, RoundedCornerShape(14.dp))
            .padding(12.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        payload.title?.let { Text(it, style = MaterialTheme.typography.labelMedium, color = TextSecondary) }
        payload.items.forEach { item ->
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(Color.White.copy(alpha = 0.05f), RoundedCornerShape(8.dp))
                    .padding(8.dp),
            ) {
                Text(item.label, style = MaterialTheme.typography.labelSmall, fontWeight = FontWeight.Bold, color = color)
                Text(item.detail, style = MaterialTheme.typography.bodySmall, color = TextSecondary)
            }
        }
    }
}

@Composable
private fun MasteryMapBlockView(payload: MasteryMapBlockPayload, color: Color) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(Surface, RoundedCornerShape(14.dp))
            .padding(12.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Text(payload.title, style = MaterialTheme.typography.titleSmall, color = color)
        payload.nodes.forEach { node ->
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(10.dp),
                modifier = Modifier.fillMaxWidth(),
            ) {
                val statusColor = when (node.status) {
                    "completed" -> CorrectGreen
                    "current", "in_progress" -> LyoPurple
                    else -> TextSecondary
                }
                Box(modifier = Modifier.size(10.dp).clip(CircleShape).background(statusColor)) {}
                Text(
                    text = node.title,
                    style = MaterialTheme.typography.bodyMedium,
                    color = color,
                    modifier = Modifier.weight(1f),
                )
                node.masteryLevel?.let {
                    Text("${(it * 100).toInt()}%", style = MaterialTheme.typography.labelSmall, color = TextSecondary)
                }
            }
        }
    }
}

@Composable
private fun UnknownBlockView() {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
        modifier = Modifier
            .fillMaxWidth()
            .background(Surface, RoundedCornerShape(12.dp))
            .padding(12.dp),
    ) {
        Icon(Icons.Default.Info, contentDescription = null, tint = TextSecondary)
        Column {
            Text("New Content Available", style = MaterialTheme.typography.labelMedium, color = TextPrimary)
            Text("Update Lyo to see this content", style = MaterialTheme.typography.bodySmall, color = TextSecondary)
        }
    }
}
