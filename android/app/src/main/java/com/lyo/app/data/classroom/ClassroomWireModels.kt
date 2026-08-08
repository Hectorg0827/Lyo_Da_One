package com.lyo.app.data.classroom

/**
 * Wire types for the AI Classroom real-time protocol
 * (LyoBackendJune lyo_app/ai_classroom), ported field-for-field from the
 * canonical client implementation at web/src/stores/classroom-store.ts (see
 * also Sources/Models/SDUIModels.swift on iOS, which implements a subset).
 *
 * These are the RAW backend shapes. Nothing here knows about A2UI — the
 * translation into A2UI messages happens one layer up, in
 * ui.classroom.ClassroomBridge. Kept here as plain Gson-friendly data
 * classes: every field is nullable/optional exactly where the web contract
 * treats it as optional, since Gson silently leaves missing keys null and a
 * strict schema would break the moment the backend evolves a new field.
 */

/** One selectable answer inside a `QuizCard` component's `options`. */
data class QuizOption(
    val id: String? = null,
    val label: String? = null,
    val is_correct: Boolean? = null,
    val feedback_correct: String? = null,
    val feedback_incorrect: String? = null,
    val misconception_tag: String? = null,
    val remediation_hint: String? = null,
)

/** Nested rich-content payload for a `LessonBlock` component (block_type == "summary"). */
data class ClassroomBlock(
    val title: String? = null,
    val content: String? = null,
    val items: List<String>? = null,
    val source_attributions: List<String>? = null,
    val retrieval_scheduled: Boolean? = null,
)

/**
 * The `component_render` payload. `type` is the discriminator dispatched on
 * in ClassroomBridge.onServerEvent — see that file for the exact handled
 * values. The real backend's `ComponentType` enum (LyoBackendJune
 * lyo_app/ai_classroom/sdui_models.py) has 13 values; this client handles
 * 9 of them (TeacherMessage, StudentPrompt, QuizCard, InputField,
 * ExampleBlock, LessonBlock, ProgressBar, CTAButton, Celebration — the
 * last confirmed actively emitted on lesson-mastery/course-complete
 * scenes). TextBlock/ChatBubble/TypingIndicator/ReflectionPrompt are
 * declared in the backend's schema/union but have zero constructor call
 * sites there as of this writing — dead types, not implemented here;
 * ClassroomBridge's `else -> unchanged(...)` branch drops them safely
 * (no crash) if that ever changes. Fields beyond `component_id`/`type`
 * are a superset across every handled component type; each handler reads
 * only the subset it needs.
 */
data class ClassroomComponent(
    val component_id: String? = null,
    val type: String? = null,
    val text: String? = null,
    val label: String? = null,
    val student_name: String? = null,
    val question: String? = null,
    val options: List<QuizOption>? = null,
    val action_intent: String? = null,
    val concept_id: String? = null,
    val current: Int? = null,
    val total: Int? = null,
    val placeholder: String? = null,
    val expected_keywords: List<String>? = null,
    val min_words: Int? = null,
    val max_words: Int? = null,
    val min_score: Double? = null,
    val evidence_type: String? = null,
    val source_attributions: List<String>? = null,
    val title: String? = null,
    val content: String? = null,
    val block_type: String? = null,
    val block: ClassroomBlock? = null,
    // Celebration-only fields (lyo_app's _create_celebration_components).
    val message: String? = null,
    val celebration_type: String? = null,
    val particle_effect: String? = null,
    val achievement_type: String? = null,
    val points_earned: Int? = null,
    val auto_dismiss_ms: Int? = null,
)

/** One parameter slider for an `explorable` board action (a graphable expression). */
data class ExplorableParam(
    val name: String? = null,
    val min: Double? = null,
    val max: Double? = null,
    val initial: Double? = null,
    val step: Double? = null,
)

/**
 * One director turn inside a `TeacherMessage`'s JSON-array `text` payload.
 * `type` selects which of the remaining fields are meaningful — see
 * ClassroomBridge.directorTurnToA2ui for the exact handling of every `type`
 * value ("speech" | "user_prompt" | "lyo_state" | "board" | "ambient" |
 * "pause" | "session_end") and every `board` `action`
 * ("write" | "draw" | "highlight" | "image" | "bullets" | "chart" | "explorable").
 */
data class DirectorTurn(
    val type: String? = null,
    val speaker: String? = null,
    val text: String? = null,
    val input: String? = null,
    val options: List<String>? = null,
    val beat_seconds: Double? = null,
    val state: String? = null,
    val action: String? = null,
    val content: String? = null,
    val seconds: Double? = null,
    val sound: String? = null,
    val homework: String? = null,
    val next_hook: String? = null,
    val lyo_state: String? = null,
    // Phase 2 board-action vocabulary
    val query: String? = null,
    val caption: String? = null,
    val items: List<String>? = null,
    val chart_type: String? = null,
    val labels: List<String>? = null,
    val values: List<Double>? = null,
    val expression: String? = null,
    val params: List<ExplorableParam>? = null,
    val x_min: Double? = null,
    val x_max: Double? = null,
    val prompt: String? = null,
)

/**
 * Outgoing `user_action` envelope — identical shape for every action the
 * learner takes (answering a prompt/quiz/transfer, asking a question,
 * requesting a hint, signaling confused/too-easy, continuing the lesson).
 * See ClassroomBridge.actionToUserAction for the exact
 * action_intent/component_id/answer_data values per action.
 */
data class UserActionEnvelope(
    val event_type: String = "user_action",
    val session_id: String,
    val action_intent: String,
    val component_id: String,
    val timestamp: String,
    val answer_data: Map<String, Any?>? = null,
)
