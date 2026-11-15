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

internal fun warmupFor(topic: String, spanish: Boolean = false): ClassroomWarmupPrompt {
    val normalized = topic.lowercase(Locale.ROOT)
    if (spanish) return when {
        listOf("historia", "history", "civilización", "civilization").any { it in normalized } ->
            ClassroomWarmupPrompt(
                question = "¿Qué te ayuda a comprobar una afirmación histórica?",
                choices = listOf("Quién creó la fuente y cuándo", "Qué tan emocionante es la historia"),
                correctIndex = 0,
                explanation = "El origen de una fuente permite evaluar su perspectiva y confiabilidad.",
            )
        else -> ClassroomWarmupPrompt(
            question = "¿Cómo puedes comprobar si entendiste una idea nueva?",
            choices = listOf("Probar un ejemplo y explicar por qué", "Solo releer la misma definición"),
            correctIndex = 0,
            explanation = "Aplicar y explicar una idea ayuda a comprobar lo aprendido.",
        )
    }
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
    spanish: Boolean = isSpanishMission(topic, Locale.getDefault().toLanguageTag()),
) {
    val prompt = remember(topic, spanish) { warmupFor(topic, spanish) }
    var selected by remember(topic, spanish) { mutableIntStateOf(-1) }
    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .background(Surface, RoundedCornerShape(20.dp))
            .border(1.dp, LyoVioletLight.copy(alpha = 0.25f), RoundedCornerShape(20.dp))
            .padding(18.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text(
            if (spanish) "RETO RÁPIDO · SIN CALIFICACIÓN" else "QUICK WARM-UP · NOT GRADED",
            color = LyoVioletLight, style = MaterialTheme.typography.labelSmall,
        )
        Text(
            if (spanish) "Mientras tu profesor se prepara…" else "While your teacher gets ready…",
            color = TextSecondary, style = MaterialTheme.typography.bodySmall,
        )
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
                text = if (selected == prompt.correctIndex) {
                    if (spanish) "¡Buen razonamiento! ${prompt.explanation}"
                    else "Good reasoning. ${prompt.explanation}"
                } else {
                    if (spanish) "Prueba de otra manera. ${prompt.explanation}"
                    else "Try a different approach. ${prompt.explanation}"
                },
                color = TextPrimary,
                style = MaterialTheme.typography.bodyMedium,
            )
        }
        if (liveLessonReady) {
            Button(onClick = onEnterLive, modifier = Modifier.fillMaxWidth()) {
                Text(if (spanish) "Entrar a la clase" else "Enter live lesson")
            }
        } else {
            Text(
                if (spanish) "Tu clase se está preparando." else "Your live lesson is preparing.",
                color = TextSecondary,
                style = MaterialTheme.typography.labelSmall)
        }
    }
}
