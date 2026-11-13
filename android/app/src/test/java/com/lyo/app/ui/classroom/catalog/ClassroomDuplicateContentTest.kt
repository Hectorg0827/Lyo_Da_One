package com.lyo.app.ui.classroom.catalog

import com.google.gson.JsonPrimitive
import com.lyo.app.data.a2ui.*
import org.junit.Assert.*
import org.junit.Test

class ClassroomDuplicateContentTest {
    private fun card(body: String = "How much water?", role: String = "board") = A2uiComponent(
        "summary", "SummaryBlock", mapOf("content" to A2uiValue.Literal(JsonPrimitive(body)),
            "role" to A2uiValue.Literal(JsonPrimitive(role))))
    private fun surface(visible: Boolean = true, question: String = "How much water?"): A2uiSurfaceState {
        val state = A2uiSurfaceState("classroom")
        state.components["board_column"] = A2uiComponent("board_column", "Column",
            children = A2uiChildren.Fixed(if (visible) listOf("summary", "quiz") else listOf("summary")))
        state.components["quiz"] = A2uiComponent("quiz", "QuizCard",
            mapOf("question" to A2uiValue.Literal(JsonPrimitive(question))))
        return state
    }
    @Test fun exactVisibleQuestionIsShownOnlyInAnswerCard() {
        assertTrue(isRepeatedQuestionCard(surface(), card()))
    }
    @Test fun whitespaceDifferencesDoNotRepeatQuestion() {
        assertTrue(isRepeatedQuestionCard(surface(question = "How much\nwater?"), card()))
    }
    @Test fun oldSceneQuestionCannotHideCurrentContent() {
        assertFalse(isRepeatedQuestionCard(surface(visible = false), card()))
    }
    @Test fun additionalExplanationIsPreserved() {
        assertFalse(isRepeatedQuestionCard(surface(), card("How much water? Multiply distance by the rate.")))
    }
    @Test fun feedbackAndReferenceCardsArePreserved() {
        for (role in listOf("feedback", "reference", "recovery", "details"))
            assertFalse(isRepeatedQuestionCard(surface(), card(role = role)))
    }
    @Test fun emptyCardsAreNotDeduplicated() {
        assertFalse(isRepeatedQuestionCard(surface(question = ""), card("")))
    }
    @Test fun extraBulletsArePreserved() {
        val original = card()
        val rich = original.copy(properties = original.properties + ("items" to A2uiValue.Literal(
            com.google.gson.JsonArray().apply { add("Use liters") })))
        assertFalse(isRepeatedQuestionCard(surface(), rich))
    }
    @Test fun documentWithDiagramOrStepsIsPreserved() {
        val original = card()
        val rich = original.copy(properties = original.properties + ("document" to A2uiValue.Literal(
            com.google.gson.JsonParser.parseString("""{"version":1,"blocks":[{"kind":"steps","items":["How much water?"]}]}"""))))
        assertFalse(isRepeatedQuestionCard(surface(), rich))
    }
}
