package com.lyo.app.ui.classroom.catalog

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class QuizOptionIdentityTest {
    @Test
    fun identicalDisplayLabelsKeepDistinctOptionIds() {
        val choices = listOf(
            QuizOptionView(id = "choice-a", label = "2/3", isCorrect = false),
            QuizOptionView(id = "choice-b", label = "2/3", isCorrect = true),
        )

        assertEquals("choice-a", quizOptionForIndex(choices, 0)?.id)
        assertEquals("choice-b", quizOptionForIndex(choices, 1)?.id)
    }

    @Test
    fun outOfRangeIndicesDoNotSubmitWrongAnswers() {
        val choices = listOf(QuizOptionView("only", "One", true))
        assertNull(quizOptionForIndex(choices, -1))
        assertNull(quizOptionForIndex(choices, 1))
    }

    @Test
    fun missingCorrectnessMustNotGiveNegativeFeedback() {
        val pending = QuizOptionView("pending", "Choice", null)
        val wrong = QuizOptionView("wrong", "Choice", false)
        val right = QuizOptionView("right", "Choice", true)

        assertNull(quizFeedbackKey(pending))
        assertEquals("feedback_incorrect", quizFeedbackKey(wrong))
        assertEquals("feedback_correct", quizFeedbackKey(right))
    }
}
