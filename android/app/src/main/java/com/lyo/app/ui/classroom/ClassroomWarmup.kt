package com.lyo.app.ui.classroom

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.lyo.app.ui.theme.LyoVioletLight
import com.lyo.app.ui.theme.Surface
import com.lyo.app.ui.theme.TextPrimary
import com.lyo.app.ui.theme.TextSecondary
import java.util.Locale

/**
 * Immediate, local, ungraded activity while the real teacher/lesson loads.
 * Never manufactures learner evidence, a score, or an AI-generated scene.
 */
internal data class ClassroomWarmupPrompt(
    val question: String,
    val choices: List<String>,
    val correctIndex: Int,
    val explanation: String,
)

internal fun warmupFor(topic: String): ClassroomWarmupPrompt {
    val normalized = topic.lowercase(Locale.ROOT)
    return when {
        listOf("science", "biology", "experiment", "plants").any { it in normalized } ->
            ClassroomWarmupPrompt(
                question = "You are testing whether water helps a plant grow. What should you change?",
                choices = listOf("Only the amount of water", "Water and sunlight together"),
                correctIndex = 0,
                explanation = "A fair test changes one variable and keeps the others the same.",
            )
        listOf("math", "fraction", "algebra", "numbers").any { it in normalized } ->
            ClassroomWarmupPrompt(
                question = "Which number is greater?",
                choices = listOf("One half (1/2)", "One third (1/3)"),
                correctIndex = 0,
                explanation = "With equal-sized wholes, dividing into two pieces makes larger pieces than dividing into three.",
            )
        listOf("history", "historical", "civilization").any { it in normalized } ->
            ClassroomWarmupPrompt(
                question = "What helps you assess a historical claim?",
                choices = listOf("Who made the source and when", "How exciting the story sounds"),
                correctIndex = 0,
                explanation = "Knowing a source's origin helps you evaluate its perspective and reliability.",
            )
        else -> ClassroomWarmupPrompt(
            question = "How can you check whether you understand a new idea?",
            choices = listOf("Try an example and explain why", "Only reread the same definition"),
            correctIndex = 0,
            explanation = "Applying and explaining an idea gives you a way to check your understanding.",
        )
    }
}

@Composable
fun ClassroomWarmup(
    topic: String,
    modifier: Modifier = Modifier,
    onInteraction: () -> Unit = {},
    liveLessonReady: Boolean = false,
    onEnterLive: () -> Unit = {},
) {
    val prompt = remember(topic) { warmupFor(topic) }
    var selected by remember(topic) { mutableIntStateOf(-1) }
    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .background(Surface, RoundedCornerShape(20.dp))
            .border(1.dp, LyoVioletLight.copy(alpha = 0.25f), RoundedCornerShape(20.dp))
            .padding(18.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text("QUICK WARM-UP · NOT GRADED", color = LyoVioletLight,
            style = MaterialTheme.typography.labelSmall)
        Text("While your teacher gets ready…", color = TextSecondary,
            style = MaterialTheme.typography.bodySmall)
        Text(prompt.question, color = TextPrimary,
            style = MaterialTheme.typography.titleMedium)
        prompt.choices.forEachIndexed { index, answer ->
            OutlinedButton(
                onClick = {
                    selected = index
                    onInteraction()
                },
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text(answer)
            }
        }
        if (selected >= 0) {
            Text(
                text = if (selected == prompt.correctIndex)
                    "Good reasoning. ${prompt.explanation}"
                else "Try a different approach. ${prompt.explanation}",
                color = TextPrimary,
                style = MaterialTheme.typography.bodyMedium,
            )
        }
        if (liveLessonReady) {
            Button(onClick = onEnterLive, modifier = Modifier.fillMaxWidth()) {
                Text("Enter live lesson")
            }
        } else {
            Text("Your live lesson is preparing.", color = TextSecondary,
                style = MaterialTheme.typography.labelSmall)
        }
    }
}
