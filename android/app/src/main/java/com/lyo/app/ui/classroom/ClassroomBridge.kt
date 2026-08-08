package com.lyo.app.ui.classroom

import com.google.gson.JsonArray
import com.google.gson.JsonElement
import com.google.gson.JsonNull
import com.google.gson.JsonObject
import com.google.gson.JsonPrimitive
import com.lyo.app.data.a2ui.A2uiAction
import com.lyo.app.data.a2ui.A2uiChildren
import com.lyo.app.data.a2ui.A2uiComponent
import com.lyo.app.data.a2ui.A2uiMessage
import com.lyo.app.data.a2ui.A2uiValue
import com.lyo.app.data.classroom.ClassroomComponent
import com.lyo.app.data.classroom.ClassroomServerEvent
import com.lyo.app.data.classroom.DirectorTurn
import com.lyo.app.data.classroom.UserActionEnvelope
import com.lyo.app.data.classroom.isoTimestampNow
import java.util.UUID

/**
 * Translates the real backend's bespoke DirectorTurn/ClassroomComponent
 * wire contract (data.classroom — see that package's doc comments) into
 * genuine A2UI protocol messages, and translates the renderer's outgoing
 * A2uiAction back into the real backend's `user_action` envelope. This is
 * the ONE place in the codebase that knows about both worlds — the A2UI
 * renderer (ui.classroom.a2ui, ui.classroom.catalog) never sees a
 * DirectorTurn or ClassroomComponent, and ClassroomSocketClient never sees
 * an A2uiMessage. See the implementation plan's Architecture section for
 * why a local bridge plays the "agent" role honestly instead of claiming
 * end-to-end A2UI conformance this session can't actually deliver (the real
 * backend doesn't speak A2UI).
 *
 * Deliberately stateless: every function's output depends only on its
 * arguments, never on hidden mutable fields. ui.classroom.ClassroomEngine
 * owns all state (the turn queue, pacing timers, and — since appending a
 * board element requires knowing what's already on the board — the current
 * `board_column` children list, threaded through via BoardMutation.boardChildren).
 * This keeps the wire-contract translation table (this file) independently
 * reviewable line-by-line against the fact sheet, without needing to
 * simulate timing.
 */
object ClassroomBridge {

    const val SURFACE_ID = "classroom"
    private const val ROOT_ID = "root"
    private const val BOARD_COLUMN_ID = "board_column"
    private const val LYO_MASCOT_ID = "lyo_mascot"

    /** Synthetic DirectorTurn.type used only internally by this bridge (see
     *  extractTurns) to carry a TeacherMessage's source_attributions
     *  through the same paced turn queue as its real content, rather than
     *  needing a second non-queued code path. Never a value the real wire
     *  contract itself sends. */
    private const val SOURCE_ATTRIBUTION_TURN_TYPE = "__source_attribution"

    /** Result of any operation that may append to (or reset) the board:
     *  the A2UI messages to apply, and the resulting `board_column`
     *  children list the caller must remember and pass into the next call. */
    data class BoardMutation(
        val messages: List<A2uiMessage>,
        val boardChildren: List<String>,
    )

    /**
     * The initial component tree for a fresh classroom session: an empty
     * board, and a permanent Lyo mascot node addressed directly by id (not
     * nested under `root` — ClassroomScreen renders it with its own
     * RenderNode call, outside the auto-hiding chrome, exactly like the
     * permanent Teacher badge is rendered outside it too — see
     * ClassroomScreen.kt).
     */
    fun createInitialSurface(): A2uiMessage.CreateSurface {
        val initialDataModel = JsonObject().apply {
            add("caption", JsonNull.INSTANCE)
            add("activeSpeaker", JsonNull.INSTANCE)
            add("mascot", JsonObject().apply { addProperty("state", "reading") })
            add("prompt", JsonNull.INSTANCE)
            add("progress", JsonObject().apply { addProperty("current", 0); addProperty("total", 1) })
            addProperty("canContinue", false)
        }
        return A2uiMessage.CreateSurface(
            surfaceId = SURFACE_ID,
            components = listOf(
                A2uiComponent(id = ROOT_ID, component = "Column", children = A2uiChildren.Fixed(listOf(BOARD_COLUMN_ID))),
                A2uiComponent(id = BOARD_COLUMN_ID, component = "Column", children = A2uiChildren.Fixed(emptyList())),
                A2uiComponent(
                    id = LYO_MASCOT_ID,
                    component = "MascotAvatar",
                    properties = mapOf(
                        "lyoState" to A2uiValue.PathRef("/mascot/state"),
                        "variant" to A2uiValue.Literal(JsonPrimitive("lyo")),
                        "size" to A2uiValue.Literal(JsonPrimitive(56)),
                    ),
                ),
            ),
            dataModel = initialDataModel,
        )
    }

    /** Resets the board to empty — used for the "scene_start" lazy-erase
     *  pattern (erase only when the NEXT turn's content actually lands, not
     *  the instant scene_start arrives, so the board never flashes empty
     *  during ordinary LLM latency — see ClassroomEngine). */
    fun clearBoard(): BoardMutation {
        val boardColumn = A2uiComponent(id = BOARD_COLUMN_ID, component = "Column", children = A2uiChildren.Fixed(emptyList()))
        return BoardMutation(
            messages = listOf(A2uiMessage.UpdateComponents(SURFACE_ID, listOf(boardColumn))),
            boardChildren = emptyList(),
        )
    }

    // ── Incoming, turn-based component types ─────────────────────────────

    /**
     * `TeacherMessage`/`StudentPrompt` are the only two component types
     * that expand into director TURNS, which ClassroomEngine enqueues and
     * plays back ONE AT A TIME with per-turn-type pacing delays (see the
     * turn table in DirectorTurn's doc comment) — NOT applied all at once.
     * Every other component type below (QuizCard, InputField, ExampleBlock,
     * LessonBlock, ProgressBar, CTAButton) renders immediately instead, via
     * onImmediateComponentRender — the wire contract never paces those.
     * Returns null for anything that isn't turn-based, so the caller knows
     * to route it to onImmediateComponentRender instead.
     */
    fun extractTurns(component: ClassroomComponent): List<DirectorTurn>? {
        return when (component.type) {
            "TeacherMessage" -> {
                val text = component.text?.trim().orEmpty()
                if (text.isEmpty()) return emptyList()
                val turns = if (text.startsWith("[")) parseTurnsLeniently(text) else null
                val effectiveTurns = turns ?: listOf(DirectorTurn(type = "speech", speaker = "Teacher", text = text))
                if (component.source_attributions.isNullOrEmpty()) {
                    effectiveTurns
                } else {
                    // A synthetic marker turn, not part of the real wire
                    // vocabulary — carries the attribution labels through
                    // the SAME paced queue as everything else so it lands
                    // after the message's own content, in order, rather
                    // than needing a separate non-queued code path.
                    effectiveTurns + DirectorTurn(type = SOURCE_ATTRIBUTION_TURN_TYPE, items = component.source_attributions)
                }
            }

            "StudentPrompt" -> listOf(
                DirectorTurn(type = "speech", speaker = component.student_name ?: "Maya", text = component.text.orEmpty()),
            )

            else -> null
        }
    }

    // ── Incoming, immediately-rendered component types ───────────────────

    fun onImmediateComponentRender(component: ClassroomComponent, boardChildren: List<String>): BoardMutation {
        return when (component.type) {
            "QuizCard" -> {
                // No id prefix here, deliberately: `id` becomes both the
                // A2uiComponent's id AND (via action.sourceComponentId,
                // which fireAction() always sets to component.id) the
                // outgoing user_action's component_id — it MUST equal the
                // backend's own component_id exactly, or the answer won't
                // round-trip to the right question server-side. A random
                // fallback UUID is fine when the backend didn't send one:
                // there's nothing meaningful to match against anyway.
                val id = component.component_id ?: UUID.randomUUID().toString()
                appendLeaf(
                    boardChildren = boardChildren,
                    newComponent = A2uiComponent(
                        id = id,
                        component = "QuizCard",
                        properties = mapOf(
                            "question" to A2uiValue.PathRef("/board/elements/$id/question"),
                            "options" to A2uiValue.PathRef("/board/elements/$id/options"),
                            "answeredOptionId" to A2uiValue.PathRef("/board/elements/$id/answeredOptionId"),
                            "action" to A2uiValue.Literal(JsonPrimitive("submitQuiz")),
                        ),
                    ),
                    dataModelWrites = listOf(
                        "/board/elements/$id/question" to JsonPrimitive(component.question ?: component.text ?: ""),
                        "/board/elements/$id/options" to quizOptionsToJson(component),
                        "/board/elements/$id/answeredOptionId" to JsonNull.INSTANCE,
                    ),
                )
            }

            "InputField" -> {
                // Same no-prefix rule as QuizCard above, for the same
                // round-trip reason. The real backend action_intent (which
                // can vary per component — see actionToUserAction's
                // "submitTransfer" case) travels as a separate literal
                // "actionIntent" property rather than overloading "action"
                // (the fixed routing key TransferInputRenderer passes to
                // fireAction), so a custom backend intent never gets lost.
                val id = component.component_id ?: UUID.randomUUID().toString()
                appendLeaf(
                    boardChildren = boardChildren,
                    newComponent = A2uiComponent(
                        id = id,
                        component = "TransferInput",
                        properties = mapOf(
                            "question" to A2uiValue.PathRef("/board/elements/$id/question"),
                            "placeholder" to A2uiValue.PathRef("/board/elements/$id/placeholder"),
                            "minWords" to A2uiValue.PathRef("/board/elements/$id/minWords"),
                            "response" to A2uiValue.PathRef("/board/elements/$id/response"),
                            "submitted" to A2uiValue.PathRef("/board/elements/$id/submitted"),
                            "action" to A2uiValue.Literal(JsonPrimitive("submitTransfer")),
                            "actionIntent" to A2uiValue.Literal(
                                JsonPrimitive(component.action_intent ?: "submit_transfer"),
                            ),
                        ),
                    ),
                    dataModelWrites = listOf(
                        "/board/elements/$id/question" to JsonPrimitive(component.question ?: component.text ?: ""),
                        "/board/elements/$id/placeholder" to JsonPrimitive(component.placeholder ?: "Explain in your own words…"),
                        "/board/elements/$id/minWords" to JsonPrimitive(component.min_words ?: 6),
                        "/board/elements/$id/response" to JsonPrimitive(""),
                        "/board/elements/$id/submitted" to JsonPrimitive(false),
                    ),
                )
            }

            "ExampleBlock" -> {
                val id = UUID.randomUUID().toString()
                appendSummary(
                    id = id,
                    title = component.title ?: "Worked example",
                    content = component.content,
                    items = emptyList(),
                    retrievalScheduled = false,
                    boardChildren = boardChildren,
                )
            }

            "LessonBlock" -> {
                if (component.block_type == "summary" && component.block != null) {
                    val id = UUID.randomUUID().toString()
                    val block = component.block
                    val summaryMutation = appendSummary(
                        id = id,
                        title = block.title ?: "Lesson summary",
                        content = block.content,
                        items = block.items ?: emptyList(),
                        retrievalScheduled = block.retrieval_scheduled == true,
                        boardChildren = boardChildren,
                    )
                    val sourceMutation = appendSourceLine(block.source_attributions, summaryMutation.boardChildren)
                    BoardMutation(summaryMutation.messages + sourceMutation.messages, sourceMutation.boardChildren)
                } else {
                    unchanged(boardChildren)
                }
            }

            "ProgressBar" -> {
                BoardMutation(
                    messages = listOf(
                        A2uiMessage.UpdateDataModel(SURFACE_ID, "/progress/current", JsonPrimitive((component.current ?: 0).coerceAtLeast(0))),
                        A2uiMessage.UpdateDataModel(SURFACE_ID, "/progress/total", JsonPrimitive((component.total ?: 1).coerceAtLeast(1))),
                    ),
                    boardChildren = boardChildren,
                )
            }

            "CTAButton" -> {
                // canContinue/continueLabel/nextActionIntent are read directly
                // by ClassroomEngine off the data model — ClassroomChrome's
                // "Continue" button lives outside the A2UI tree entirely
                // (it's page chrome, not agent-authored content), so this
                // only needs to update the data model, no component.
                BoardMutation(
                    messages = listOf(
                        A2uiMessage.UpdateDataModel(SURFACE_ID, "/canContinue", JsonPrimitive(true)),
                        A2uiMessage.UpdateDataModel(SURFACE_ID, "/continueLabel", JsonPrimitive(component.label ?: "Continue")),
                        A2uiMessage.UpdateDataModel(SURFACE_ID, "/nextActionIntent", JsonPrimitive(component.action_intent ?: "continue")),
                    ),
                    boardChildren = boardChildren,
                )
            }

            else -> unchanged(boardChildren)
        }
    }

    // ── Director turn table ──────────────────────────────────────────────

    fun directorTurnToA2ui(turn: DirectorTurn, boardChildren: List<String>): BoardMutation {
        return when (turn.type) {
            "speech" -> {
                val text = turn.text?.trim().orEmpty()
                if (text.isEmpty()) return unchanged(boardChildren)
                val speaker = turn.speaker ?: "Teacher"
                BoardMutation(captionMessages(speaker, text), boardChildren)
            }

            "user_prompt" -> {
                val text = turn.text?.trim().orEmpty()
                val speaker = turn.speaker ?: "Teacher"
                // This id is purely a client-side bookkeeping id (matching
                // web's `nextId()`-generated prompt.id) — a user_prompt
                // director turn carries no backend component_id at all, so
                // there is nothing server-issued to reuse here, unlike
                // QuizCard/InputField above. ClassroomEngine tracks it as
                // `currentPromptId` for checkpoint/timeout bookkeeping —
                // it is NOT stored in the data model (see the panelId note
                // below for why).
                val promptId = UUID.randomUUID().toString()
                val options = turn.options?.filter { it.isNotBlank() } ?: emptyList()
                val captionMsgs = captionMessages(speaker, text)

                // The prompt panel is its own board element (a small Column
                // of a question Text + either a ChoicePicker or a TextField
                // + Send/"I'm not sure" buttons), appended to board_column
                // exactly like any other board content. ALL of its content
                // — including the answer once given — is bound under this
                // PERSISTENT /board/elements/$panelId path, deliberately
                // NOT under a transient /prompt object: the panel must keep
                // showing its question and the learner's chosen answer as a
                // scroll-back transcript record after the prompt itself is
                // no longer "active" (chrome's checkpoint-blocking state is
                // tracked separately, directly on ClassroomEngine, not
                // through the data model at all — see hasActiveCheckpoint).
                val panelId = "prompt_$promptId"
                val questionId = "${panelId}_q"
                val controlId = "${panelId}_control"

                val questionComponent = A2uiComponent(
                    id = questionId,
                    component = "Text",
                    properties = mapOf(
                        "text" to A2uiValue.PathRef("/board/elements/$panelId/text"),
                        "variant" to A2uiValue.Literal(JsonPrimitive("title")),
                    ),
                )

                val extraComponents = mutableListOf<A2uiComponent>()
                val extraDataWrites = mutableListOf<Pair<String, JsonElement>>()
                val controlComponent: A2uiComponent
                if (options.isNotEmpty()) {
                    controlComponent = A2uiComponent(
                        id = controlId,
                        component = "ChoicePicker",
                        properties = mapOf(
                            "options" to A2uiValue.PathRef("/board/elements/$panelId/options"),
                            "value" to A2uiValue.PathRef("/board/elements/$panelId/selectedId"),
                            "promptId" to A2uiValue.Literal(JsonPrimitive(promptId)),
                            "action" to A2uiValue.Literal(JsonPrimitive("submitPrompt")),
                        ),
                    )
                    extraDataWrites += "/board/elements/$panelId/options" to
                        JsonArray().apply { options.forEach { add(it) } }
                    extraDataWrites += "/board/elements/$panelId/selectedId" to JsonNull.INSTANCE
                } else {
                    // Open response: a TextField (bound to a scratch
                    // per-panel draftText, separate from selectedId which
                    // represents the final submitted answer) plus a "Send"
                    // button and a low-friction "I'm not sure" quick-submit,
                    // matching web's promptOptionsContent /
                    // openResponseContent split exactly. Both buttons
                    // resolve their own "value" property as the fireAction
                    // context's submitted answer — Send's is bound to the
                    // live draft text, "I'm not sure"'s is a fixed literal.
                    // KNOWN v1 GAP: neither button disables itself once
                    // answered (BasicCatalog's generic Button has no
                    // conditional-local-write mechanism to flip an "open"
                    // flag on tap without adding classroom-specific
                    // plumbing to a catalog file meant to stay
                    // protocol-only — see the implementation plan). A
                    // double-tap sends a harmless duplicate user_message,
                    // not a crash or data-corruption risk.
                    val fieldId = "${controlId}_field"
                    val sendId = "${controlId}_send"
                    val notSureId = "${controlId}_notsure"
                    val actionsRowId = "${controlId}_actions"

                    extraComponents += A2uiComponent(
                        id = fieldId,
                        component = "TextField",
                        properties = mapOf(
                            "value" to A2uiValue.PathRef("/board/elements/$panelId/draftText"),
                            "placeholder" to A2uiValue.Literal(JsonPrimitive("Explain in your own words…")),
                            "variant" to A2uiValue.Literal(JsonPrimitive("longText")),
                        ),
                    )
                    extraComponents += A2uiComponent(
                        id = sendId,
                        component = "Button",
                        properties = mapOf(
                            "label" to A2uiValue.Literal(JsonPrimitive("Send")),
                            "value" to A2uiValue.PathRef("/board/elements/$panelId/draftText"),
                            "promptId" to A2uiValue.Literal(JsonPrimitive(promptId)),
                            "action" to A2uiValue.Literal(JsonPrimitive("submitPrompt")),
                        ),
                    )
                    extraComponents += A2uiComponent(
                        id = notSureId,
                        component = "Button",
                        properties = mapOf(
                            "label" to A2uiValue.Literal(JsonPrimitive("I'm not sure")),
                            "value" to A2uiValue.Literal(JsonPrimitive("I'm not sure")),
                            "promptId" to A2uiValue.Literal(JsonPrimitive(promptId)),
                            "action" to A2uiValue.Literal(JsonPrimitive("submitPrompt")),
                        ),
                    )
                    extraComponents += A2uiComponent(
                        id = actionsRowId,
                        component = "Row",
                        children = A2uiChildren.Fixed(listOf(notSureId, sendId)),
                    )
                    controlComponent = A2uiComponent(
                        id = controlId,
                        component = "Column",
                        children = A2uiChildren.Fixed(listOf(fieldId, actionsRowId)),
                    )
                    extraDataWrites += "/board/elements/$panelId/draftText" to JsonPrimitive("")
                }
                val panelComponent = A2uiComponent(
                    id = panelId,
                    component = "Column",
                    children = A2uiChildren.Fixed(listOf(questionId, controlId)),
                )

                val boardColumn = A2uiComponent(
                    id = BOARD_COLUMN_ID,
                    component = "Column",
                    children = A2uiChildren.Fixed(boardChildren + panelId),
                )

                val dataModelMessages = (
                    listOf("/board/elements/$panelId/text" to JsonPrimitive(text) as Pair<String, JsonElement>) +
                        extraDataWrites
                    ).map { (path, value) -> A2uiMessage.UpdateDataModel(SURFACE_ID, path, value) }

                BoardMutation(
                    messages = captionMsgs + listOf(
                        A2uiMessage.UpdateComponents(
                            SURFACE_ID,
                            listOf(questionComponent) + extraComponents + listOf(controlComponent, panelComponent, boardColumn),
                        ),
                    ) + dataModelMessages,
                    boardChildren = boardChildren + panelId,
                )
            }

            "lyo_state" -> {
                val state = turn.state ?: return unchanged(boardChildren)
                BoardMutation(
                    listOf(A2uiMessage.UpdateDataModel(SURFACE_ID, "/mascot/state", JsonPrimitive(state))),
                    boardChildren,
                )
            }

            "board" -> boardActionToA2ui(turn, boardChildren)

            SOURCE_ATTRIBUTION_TURN_TYPE -> appendSourceLine(turn.items, boardChildren)

            "ambient" -> unchanged(boardChildren) // sound effects are stubbed for v1 — no TTS/audio integration yet

            "pause" -> unchanged(boardChildren) // pure timing directive, handled by ClassroomEngine's delay()

            "session_end" -> {
                val id = UUID.randomUUID().toString()
                val dismissalComponent = A2uiComponent(
                    id = "dismissal_$id",
                    component = "DismissalCard",
                    properties = mapOf(
                        "homework" to A2uiValue.PathRef("/board/elements/dismissal_$id/homework"),
                        "nextHook" to A2uiValue.PathRef("/board/elements/dismissal_$id/nextHook"),
                    ),
                )
                val newChildren = boardChildren + "dismissal_$id"
                val boardColumn = A2uiComponent(BOARD_COLUMN_ID, "Column", children = A2uiChildren.Fixed(newChildren))
                BoardMutation(
                    messages = listOf(
                        A2uiMessage.UpdateComponents(SURFACE_ID, listOf(dismissalComponent, boardColumn)),
                        A2uiMessage.UpdateDataModel(SURFACE_ID, "/board/elements/dismissal_$id/homework", turn.homework?.let { JsonPrimitive(it) } ?: JsonNull.INSTANCE),
                        A2uiMessage.UpdateDataModel(SURFACE_ID, "/board/elements/dismissal_$id/nextHook", turn.next_hook?.let { JsonPrimitive(it) } ?: JsonNull.INSTANCE),
                        A2uiMessage.UpdateDataModel(SURFACE_ID, "/mascot/state", JsonPrimitive(turn.lyo_state ?: "celebrating")),
                        A2uiMessage.UpdateDataModel(SURFACE_ID, "/canContinue", JsonPrimitive(true)),
                        A2uiMessage.UpdateDataModel(SURFACE_ID, "/caption", JsonNull.INSTANCE),
                        A2uiMessage.UpdateDataModel(SURFACE_ID, "/activeSpeaker", JsonNull.INSTANCE),
                    ),
                    boardChildren = newChildren,
                )
            }

            else -> unchanged(boardChildren)
        }
    }

    private fun boardActionToA2ui(turn: DirectorTurn, boardChildren: List<String>): BoardMutation {
        return when (turn.action) {
            "image" -> {
                if (turn.query.isNullOrBlank() && turn.content.isNullOrBlank()) return unchanged(boardChildren)
                val id = UUID.randomUUID().toString()
                appendLeaf(
                    boardChildren = boardChildren,
                    newComponent = A2uiComponent(
                        id = "image_$id",
                        component = "ImageBlock",
                        properties = mapOf(
                            "url" to A2uiValue.PathRef("/board/elements/image_$id/url"),
                            "caption" to A2uiValue.PathRef("/board/elements/image_$id/caption"),
                            "query" to A2uiValue.PathRef("/board/elements/image_$id/query"),
                        ),
                    ),
                    dataModelWrites = listOf(
                        // url starts null — a real image search integration
                        // would resolve and updateDataModel it in later; not
                        // wired to a search backend in this v1, so the
                        // "finding a picture of…" placeholder is the
                        // resting state (see ImageBlockRenderer).
                        "/board/elements/image_$id/url" to JsonNull.INSTANCE,
                        "/board/elements/image_$id/caption" to (turn.caption?.let { JsonPrimitive(it) } ?: JsonNull.INSTANCE),
                        "/board/elements/image_$id/query" to JsonPrimitive(turn.query ?: turn.content ?: ""),
                    ),
                )
            }

            "bullets" -> {
                if (turn.items.isNullOrEmpty()) return unchanged(boardChildren)
                val id = UUID.randomUUID().toString()
                appendLeaf(
                    boardChildren = boardChildren,
                    newComponent = A2uiComponent(
                        id = "bullets_$id",
                        component = "BulletsBlock",
                        properties = mapOf("items" to A2uiValue.PathRef("/board/elements/bullets_$id/items")),
                    ),
                    dataModelWrites = listOf(
                        "/board/elements/bullets_$id/items" to JsonArray().apply { turn.items.forEach { add(it) } },
                    ),
                )
            }

            "chart" -> {
                if (turn.labels.isNullOrEmpty() || turn.values.isNullOrEmpty()) return unchanged(boardChildren)
                val id = UUID.randomUUID().toString()
                appendLeaf(
                    boardChildren = boardChildren,
                    newComponent = A2uiComponent(
                        id = "chart_$id",
                        component = "ChartBlock",
                        properties = mapOf(
                            "chartType" to A2uiValue.Literal(JsonPrimitive(if (turn.chart_type == "line") "line" else "bar")),
                            "labels" to A2uiValue.PathRef("/board/elements/chart_$id/labels"),
                            "values" to A2uiValue.PathRef("/board/elements/chart_$id/values"),
                        ),
                    ),
                    dataModelWrites = listOf(
                        "/board/elements/chart_$id/labels" to JsonArray().apply { turn.labels.forEach { add(it) } },
                        "/board/elements/chart_$id/values" to JsonArray().apply { turn.values.forEach { add(it) } },
                    ),
                )
            }

            "explorable" -> {
                if (turn.expression.isNullOrBlank() || turn.params.isNullOrEmpty()) return unchanged(boardChildren)
                val id = UUID.randomUUID().toString()
                val paramsJson = JsonArray().apply {
                    turn.params.forEach { p ->
                        add(
                            JsonObject().apply {
                                addProperty("name", p.name ?: "")
                                p.min?.let { addProperty("min", it) }
                                p.max?.let { addProperty("max", it) }
                                p.initial?.let { addProperty("initial", it) }
                                p.step?.let { addProperty("step", it) }
                            },
                        )
                    }
                }
                appendLeaf(
                    boardChildren = boardChildren,
                    newComponent = A2uiComponent(
                        id = "explorable_$id",
                        component = "ExplorableBlock",
                        properties = mapOf(
                            "expression" to A2uiValue.PathRef("/board/elements/explorable_$id/expression"),
                            "prompt" to A2uiValue.PathRef("/board/elements/explorable_$id/prompt"),
                            "params" to A2uiValue.PathRef("/board/elements/explorable_$id/params"),
                        ),
                    ),
                    dataModelWrites = listOf(
                        "/board/elements/explorable_$id/expression" to JsonPrimitive(turn.expression),
                        "/board/elements/explorable_$id/prompt" to (turn.prompt?.let { JsonPrimitive(it) } ?: JsonNull.INSTANCE),
                        "/board/elements/explorable_$id/params" to paramsJson,
                    ),
                )
            }

            "highlight" -> {
                val term = turn.content?.trim().orEmpty()
                if (term.isEmpty()) return unchanged(boardChildren)
                val messages = mutableListOf<A2uiMessage>()
                // Mutate the most recently added board element's
                // highlightedTerm — harmless if that element isn't a
                // ChalkboardText (the property is simply unused by every
                // other renderer). Auto-clear is scheduled by
                // ClassroomEngine (a timing concern, not this stateless
                // bridge's job) via clearHighlight() below.
                boardChildren.lastOrNull()?.let { lastId ->
                    messages += A2uiMessage.UpdateDataModel(
                        SURFACE_ID,
                        "/board/elements/$lastId/highlightedTerm",
                        JsonPrimitive(term),
                    )
                }
                // ALSO push a standalone circled-spotlight element, per the
                // wire contract's documented "always additionally" behavior.
                val id = UUID.randomUUID().toString()
                val spotlightMutation = appendLeaf(
                    boardChildren = boardChildren,
                    newComponent = A2uiComponent(
                        id = "highlight_$id",
                        component = "HighlightSpotlight",
                        properties = mapOf("term" to A2uiValue.Literal(JsonPrimitive(term))),
                    ),
                    dataModelWrites = emptyList(),
                )
                BoardMutation(messages + spotlightMutation.messages, spotlightMutation.boardChildren)
            }

            else -> {
                // "write"/"draw"/absent — classify the free-text content
                // heuristically, same rule as the web reference.
                val content = turn.content?.trim().orEmpty()
                if (content.isEmpty()) return unchanged(boardChildren)
                val id = UUID.randomUUID().toString()
                when (classifyBoardContent(content)) {
                    BoardContentKind.MERMAID -> appendLeaf(
                        boardChildren, A2uiComponent("mermaid_$id", "MermaidBlock", mapOf("source" to A2uiValue.PathRef("/board/elements/mermaid_$id/source"))),
                        listOf("/board/elements/mermaid_$id/source" to JsonPrimitive(content)),
                    )
                    BoardContentKind.LATEX -> appendLeaf(
                        boardChildren, A2uiComponent("latex_$id", "LatexBlock", mapOf("latex" to A2uiValue.PathRef("/board/elements/latex_$id/latex"))),
                        listOf("/board/elements/latex_$id/latex" to JsonPrimitive(content)),
                    )
                    BoardContentKind.CODE -> appendLeaf(
                        boardChildren, A2uiComponent("code_$id", "CodeBlock", mapOf("code" to A2uiValue.PathRef("/board/elements/code_$id/code"))),
                        listOf("/board/elements/code_$id/code" to JsonPrimitive(content)),
                    )
                    BoardContentKind.CHALK -> appendLeaf(
                        boardChildren,
                        A2uiComponent(
                            "chalk_$id",
                            "ChalkboardText",
                            mapOf(
                                "text" to A2uiValue.PathRef("/board/elements/chalk_$id/text"),
                                "highlightedTerm" to A2uiValue.PathRef("/board/elements/chalk_$id/highlightedTerm"),
                            ),
                        ),
                        listOf(
                            "/board/elements/chalk_$id/text" to JsonPrimitive(content),
                            "/board/elements/chalk_$id/highlightedTerm" to JsonNull.INSTANCE,
                        ),
                    )
                }
            }
        }
    }

    /** Auto-clear for a `highlight` action's inline chalk-term glow, fired
     *  by ClassroomEngine ~5000ms after the highlight was set. */
    fun clearHighlight(elementId: String): A2uiMessage =
        A2uiMessage.UpdateDataModel(SURFACE_ID, "/board/elements/$elementId/highlightedTerm", JsonNull.INSTANCE)

    // ── Outgoing, board-content actions (A2uiAction → UserActionEnvelope) ──

    /**
     * Maps a renderer-originated A2uiAction — from the three board-content
     * components that carry an `action` property (ChoicePicker in the
     * user_prompt panel, QuizCard, TransferInput) — to the real backend's
     * `user_action` envelope. `action.name` is always one of the three
     * fixed routing keys set when ClassroomBridge built that component
     * above ("submitPrompt"/"submitQuiz"/"submitTransfer") — never a
     * backend-supplied value directly, so this `when` is exhaustive by
     * construction and the `else` branch only exists as a defensive
     * fallback against a future new component type forgetting to update
     * this table (a passthrough, not a silent data-loss path — every case
     * here is a literal transcription of the action table in the
     * implementation plan / DirectorTurn's doc comment).
     */
    fun actionToUserAction(action: A2uiAction, sessionId: String): UserActionEnvelope {
        val ctx = action.context
        fun str(key: String): String? = ctx[key]?.takeIf { it.isJsonPrimitive }?.asString

        return when (action.name) {
            "submitPrompt" -> UserActionEnvelope(
                session_id = sessionId,
                action_intent = "user_message",
                component_id = str("promptId") ?: action.sourceComponentId,
                timestamp = isoTimestampNow(),
                answer_data = mapOf("message" to (str("selectedLabel") ?: str("value"))),
            )

            "submitQuiz" -> UserActionEnvelope(
                session_id = sessionId,
                action_intent = "submit_answer",
                // action.sourceComponentId is the QuizCard's own id, which
                // — per the no-prefix rule in onComponentRender's QuizCard
                // branch — is exactly the backend's original component_id.
                component_id = action.sourceComponentId,
                timestamp = isoTimestampNow(),
                answer_data = mapOf(
                    "selected_option_id" to str("selectedOptionId"),
                    "selected_option_label" to str("selectedOptionLabel"),
                ),
            )

            "submitTransfer" -> UserActionEnvelope(
                session_id = sessionId,
                // The real per-component backend intent travels as a
                // separate "actionIntent" context key (see InputField's
                // properties above) rather than overloading action.name
                // itself, precisely so a custom backend intent is never
                // lost here.
                action_intent = str("actionIntent") ?: "submit_transfer",
                component_id = action.sourceComponentId,
                timestamp = isoTimestampNow(),
                answer_data = mapOf("response" to str("response")),
            )

            else -> UserActionEnvelope(
                session_id = sessionId,
                action_intent = action.name,
                component_id = action.sourceComponentId,
                timestamp = isoTimestampNow(),
                answer_data = null,
            )
        }
    }

    // ── Outgoing, chrome-originated actions ──────────────────────────────
    // These never flow through an A2uiAction — the buttons that trigger
    // them (Continue, Raise your hand / ask, Get help, Harder case) are
    // ClassroomChrome's own hand-authored Compose, not A2UI board content
    // (see the plan's Architecture section: chrome is never agent-authored,
    // so it was never routed through the generic protocol layer to begin
    // with). Kept here anyway, as direct envelope builders rather than
    // A2uiAction-shaped, so every outgoing wire shape in the whole feature
    // still lives in exactly one reviewable file.

    fun askQuestionAction(sessionId: String, text: String): UserActionEnvelope = UserActionEnvelope(
        session_id = sessionId,
        action_intent = "ask_question",
        component_id = "android_ask",
        timestamp = isoTimestampNow(),
        answer_data = mapOf("message" to text),
    )

    fun requestHintAction(sessionId: String, level: String): UserActionEnvelope = UserActionEnvelope(
        session_id = sessionId,
        action_intent = "request_hint",
        component_id = "android_hint",
        timestamp = isoTimestampNow(),
        answer_data = mapOf("hint_level" to level),
    )

    fun signalConfusedAction(sessionId: String): UserActionEnvelope = UserActionEnvelope(
        session_id = sessionId,
        action_intent = "request_hint",
        component_id = "android_signal",
        timestamp = isoTimestampNow(),
        answer_data = mapOf("hint_level" to "nudge"),
    )

    fun signalTooEasyAction(sessionId: String): UserActionEnvelope = UserActionEnvelope(
        session_id = sessionId,
        action_intent = "skip_ahead",
        component_id = "android_signal",
        timestamp = isoTimestampNow(),
        answer_data = null,
    )

    fun continueLessonAction(sessionId: String, nextActionIntent: String): UserActionEnvelope = UserActionEnvelope(
        session_id = sessionId,
        action_intent = nextActionIntent,
        component_id = "android_continue",
        timestamp = isoTimestampNow(),
        answer_data = null,
    )

    // ── Helpers ───────────────────────────────────────────────────────────

    private fun unchanged(boardChildren: List<String>) = BoardMutation(emptyList(), boardChildren)

    private fun captionMessages(speaker: String, text: String): List<A2uiMessage> {
        val captionValue = JsonObject().apply {
            addProperty("speaker", speaker)
            addProperty("text", text)
        }
        return listOf(
            A2uiMessage.UpdateDataModel(SURFACE_ID, "/caption", captionValue),
            A2uiMessage.UpdateDataModel(SURFACE_ID, "/activeSpeaker", JsonPrimitive(speaker)),
        )
    }

    private fun appendLeaf(
        boardChildren: List<String>,
        newComponent: A2uiComponent,
        dataModelWrites: List<Pair<String, JsonElement>>,
    ): BoardMutation {
        val newChildren = boardChildren + newComponent.id
        val boardColumn = A2uiComponent(BOARD_COLUMN_ID, "Column", children = A2uiChildren.Fixed(newChildren))
        val messages = mutableListOf<A2uiMessage>(
            A2uiMessage.UpdateComponents(SURFACE_ID, listOf(newComponent, boardColumn)),
        )
        dataModelWrites.forEach { (path, value) -> messages += A2uiMessage.UpdateDataModel(SURFACE_ID, path, value) }
        return BoardMutation(messages, newChildren)
    }

    private fun appendSummary(
        id: String,
        title: String,
        content: String?,
        items: List<String>,
        retrievalScheduled: Boolean,
        boardChildren: List<String>,
    ): BoardMutation = appendLeaf(
        boardChildren = boardChildren,
        newComponent = A2uiComponent(
            id = "summary_$id",
            component = "SummaryBlock",
            properties = mapOf(
                "title" to A2uiValue.PathRef("/board/elements/summary_$id/title"),
                "content" to A2uiValue.PathRef("/board/elements/summary_$id/content"),
                "items" to A2uiValue.PathRef("/board/elements/summary_$id/items"),
                "retrievalScheduled" to A2uiValue.PathRef("/board/elements/summary_$id/retrievalScheduled"),
            ),
        ),
        dataModelWrites = listOf(
            "/board/elements/summary_$id/title" to JsonPrimitive(title),
            "/board/elements/summary_$id/content" to (content?.let { JsonPrimitive(it) } ?: JsonNull.INSTANCE),
            "/board/elements/summary_$id/items" to JsonArray().apply { items.forEach { add(it) } },
            "/board/elements/summary_$id/retrievalScheduled" to JsonPrimitive(retrievalScheduled),
        ),
    )

    private fun appendSourceLine(labels: List<String>?, boardChildren: List<String>): BoardMutation {
        if (labels.isNullOrEmpty()) return unchanged(boardChildren)
        val id = UUID.randomUUID().toString()
        return appendLeaf(
            boardChildren = boardChildren,
            newComponent = A2uiComponent(
                id = "source_$id",
                component = "SourceLine",
                properties = mapOf("labels" to A2uiValue.PathRef("/board/elements/source_$id/labels")),
            ),
            dataModelWrites = listOf(
                "/board/elements/source_$id/labels" to JsonArray().apply { labels.forEach { add(it) } },
            ),
        )
    }

    private fun quizOptionsToJson(component: ClassroomComponent): JsonArray = JsonArray().apply {
        component.options?.forEach { option ->
            add(
                JsonObject().apply {
                    addProperty("id", option.id ?: "")
                    addProperty("label", option.label ?: "")
                    option.is_correct?.let { addProperty("is_correct", it) }
                    option.feedback_correct?.let { addProperty("feedback_correct", it) }
                    option.feedback_incorrect?.let { addProperty("feedback_incorrect", it) }
                },
            )
        }
    }

    /** Best-effort parse of a TeacherMessage's embedded JSON-array-of-turns
     *  string. Falls back to null (caller treats it as one plain speech
     *  turn) on any parse failure — LLM-generated JSON occasionally arrives
     *  malformed/truncated, and a lenient fallback beats crashing the
     *  classroom over one bad turn array, matching iOS's FallbackTurnParser
     *  precedent (see Sources/Views/Classroom/ActiveLessonAdapter.swift). */
    private fun parseTurnsLeniently(text: String): List<DirectorTurn>? {
        return try {
            val array = com.google.gson.JsonParser.parseString(text).asJsonArray
            val gson = com.google.gson.Gson()
            array.map { gson.fromJson(it, DirectorTurn::class.java) }
        } catch (e: Exception) {
            null
        }
    }

    private enum class BoardContentKind { MERMAID, LATEX, CODE, CHALK }

    private val MERMAID_PREFIX = Regex(
        "^(graph|flowchart|sequencediagram|classdiagram|statediagram|erdiagram|pie|mindmap|timeline|journey)\\b",
        RegexOption.IGNORE_CASE,
    )
    private val LATEX_SIGNAL = Regex(
        "\\\\(frac|sum|int|theta|alpha|beta|sqrt|cdot|times|pi|infty|approx|le|ge|neq)|\\^\\{|_\\{",
    )
    private val CODE_SIGNAL = Regex(
        "(def |function |=> |const |let |var |class |import |return |print\\(|console\\.|#include|public |;\\s*$)",
        RegexOption.MULTILINE,
    )

    /** Ported verbatim (same 4 rules, same order) from web's
     *  `classifyBoardContent()` in classroom-store.ts. */
    private fun classifyBoardContent(content: String): BoardContentKind {
        val firstLine = content.lineSequence().firstOrNull() ?: ""
        return when {
            MERMAID_PREFIX.containsMatchIn(firstLine) -> BoardContentKind.MERMAID
            LATEX_SIGNAL.containsMatchIn(content) -> BoardContentKind.LATEX
            content.contains('\n') && CODE_SIGNAL.containsMatchIn(content) -> BoardContentKind.CODE
            else -> BoardContentKind.CHALK
        }
    }
}
