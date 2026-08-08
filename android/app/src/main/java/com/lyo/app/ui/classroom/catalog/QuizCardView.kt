package com.lyo.app.ui.classroom.catalog

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.google.gson.JsonPrimitive
import com.lyo.app.ui.classroom.a2ui.A2uiRenderScope
import com.lyo.app.ui.classroom.a2ui.ChipState
import com.lyo.app.ui.classroom.a2ui.ClassroomChipRow
import com.lyo.app.ui.theme.ClassroomTokens
import com.lyo.app.ui.theme.LyoGreen
import com.lyo.app.ui.theme.LyoRed
import com.lyo.app.ui.theme.TextPrimary

private data class QuizOptionView(val id: String, val label: String, val isCorrect: Boolean?)

/**
 * A `QuizCard` component — a graded recognition check, distinct from a
 * `user_prompt`'s ungraded cold-call: it carries real correctness metadata
 * per option (QuizOption.is_correct/feedback_correct/feedback_incorrect —
 * see data.classroom.QuizOption) and answers via `submit_answer`, not
 * `user_message` (see ClassroomBridge.actionToUserAction).
 *
 * Reuses ClassroomChipRow (the same chip layout `ChoicePicker` uses) rather
 * than reimplementing chip rendering, per the plan's "hybrid" design for
 * this component — only the question text, post-answer feedback text, and
 * correctness coloring are quiz-specific.
 *
 * Feedback is OPTIMISTIC/local: `is_correct`/`feedback_correct`/
 * `feedback_incorrect` already ship on the QuizOption the moment the quiz
 * arrives, so the coloring/feedback shown here never waits on a server
 * round-trip — `submit_answer` still fires (see ChoicePicker's `action`
 * dispatch below) purely for backend tracking.
 */
@Composable
fun A2uiRenderScope.QuizCardRenderer() {
    val question = resolveString("question") ?: return
    val optionsJson = resolve("options")?.takeIf { it.isJsonArray }?.asJsonArray ?: return
    val options = optionsJson.mapNotNull { element ->
        if (!element.isJsonObject) return@mapNotNull null
        val obj = element.asJsonObject
        val id = obj.get("id")?.takeIf { it.isJsonPrimitive }?.asString ?: return@mapNotNull null
        val label = obj.get("label")?.takeIf { it.isJsonPrimitive }?.asString ?: return@mapNotNull null
        val isCorrect = obj.get("is_correct")?.takeIf { it.isJsonPrimitive }?.asBoolean
        QuizOptionView(id, label, isCorrect)
    }
    if (options.isEmpty()) return

    val answeredPath = boundPath("answeredOptionId")
    val answeredId = resolveString("answeredOptionId")
    val answered = options.firstOrNull { it.id == answeredId }
    val feedback = answered?.let { opt ->
        val key = if (opt.isCorrect == true) "feedback_correct" else "feedback_incorrect"
        optionsJson.firstOrNull {
            it.isJsonObject && it.asJsonObject.get("id")?.asString == opt.id
        }?.asJsonObject?.get(key)?.takeIf { it.isJsonPrimitive }?.asString
    }
    val actionName = literalString("action") ?: "submitQuiz"

    Column(modifier = Modifier.padding(vertical = 6.dp)) {
        Text(text = question, color = TextPrimary)
        ClassroomChipRow(
            options = options.map { it.label },
            stateFor = { label ->
                val option = options.first { it.label == label }
                when {
                    option.id != answeredId -> ChipState.DEFAULT
                    option.isCorrect == true -> ChipState.CORRECT
                    option.isCorrect == false -> ChipState.INCORRECT
                    else -> ChipState.SELECTED
                }
            },
            enabledFor = { answeredId == null },
            onSelect = { label ->
                val option = options.first { it.label == label }
                if (answeredPath != null) writeLocalDataModel(answeredPath, JsonPrimitive(option.id))
                fireAction(
                    actionName,
                    mapOf(
                        "selectedOptionId" to JsonPrimitive(option.id),
                        "selectedOptionLabel" to JsonPrimitive(option.label),
                    ),
                )
            },
        )
        if (feedback != null) {
            Text(
                text = feedback,
                color = if (answered?.isCorrect == true) LyoGreen else LyoRed,
                modifier = Modifier.padding(top = 4.dp),
            )
        }
    }
}
