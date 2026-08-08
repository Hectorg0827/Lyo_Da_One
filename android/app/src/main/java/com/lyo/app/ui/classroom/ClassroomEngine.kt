package com.lyo.app.ui.classroom

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.lyo.app.data.a2ui.A2uiAction
import com.lyo.app.data.a2ui.A2uiMessage
import com.lyo.app.data.a2ui.A2uiSurfaceState
import com.lyo.app.data.a2ui.resolvePointer
import com.lyo.app.data.classroom.ClassroomComponent
import com.lyo.app.data.classroom.ClassroomServerEvent
import com.lyo.app.data.classroom.ClassroomSocketClient
import com.lyo.app.data.classroom.DirectorTurn
import com.lyo.app.ui.classroom.a2ui.BasicCatalog
import com.lyo.app.ui.classroom.a2ui.A2uiCatalog
import com.lyo.app.ui.classroom.catalog.ClassroomCatalog
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.util.ArrayDeque
import java.util.UUID

/** One line in the notebook drawer — the transcript, a byproduct of turn
 *  playback and outgoing actions alike (mirrors web's TranscriptItem /
 *  classroom-store.ts's pushTranscript). Never sent anywhere; purely a
 *  local scroll-back record for ClassroomChrome's NotebookPanel. */
data class TranscriptLine(val id: String, val speaker: String, val text: String)

/**
 * The turn-queue/pacing player and single source of truth ClassroomScreen
 * observes — a plain Kotlin class, instantiated via `remember { ... }`,
 * matching this app's established no-ViewModel convention (see the
 * implementation plan's Fact Set 1: no androidx.lifecycle.ViewModel exists
 * anywhere in this codebase). Owns:
 * - The A2uiSurfaceState the whole classroom UI renders from.
 * - The pending DirectorTurn queue and its sequential, paced playback
 *   (mirroring web/src/stores/classroom-store.ts's `playNext()`).
 * - The current `board_column` children list (ClassroomBridge is
 *   deliberately stateless — see that file's doc comment — so this class
 *   is what threads it through calls).
 * - Chrome-relevant derived flags ClassroomChrome reads directly.
 *
 * Lifecycle: `start()` from a `DisposableEffect(engine) { engine.start();
 * onDispose { engine.dispose() } }` in ClassroomScreen; never call start()
 * twice on the same instance.
 */
class ClassroomEngine(
    private val topic: String,
    sessionIdParam: String? = null,
    private val mode: String = "solo",
    private val durationMinutes: Int = 10,
    private val objective: String? = null,
    private val difficulty: String? = null,
) {
    val sessionId: String = sessionIdParam?.takeIf { it.isNotBlank() } ?: topic

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private var collectorJob: Job? = null
    private var playerJob: Job? = null
    private var promptTimeoutJob: Job? = null
    private var highlightClearJob: Job? = null

    val surface = A2uiSurfaceState(ClassroomBridge.SURFACE_ID)
    val catalog: A2uiCatalog = BasicCatalog + ClassroomCatalog

    private val turnQueue = ArrayDeque<DirectorTurn>()
    private var boardChildren: List<String> = emptyList()
    private var pendingErase = false

    var status by mutableStateOf("connecting"); private set
    var errorMessage by mutableStateOf<String?>(null); private set
    var isPaused by mutableStateOf(false); private set

    /**
     * True while a user_prompt is unanswered — the ONE checkpoint type
     * that actually pauses turn playback (QuizCard/InputField don't pause
     * the queue; they gate `canContinue` instead, via the CTAButton flow —
     * see the DirectorTurn table). ClassroomChrome reads this to block its
     * 3s auto-hide timer, per the Netflix/YouTube chrome spec.
     *
     * Tracked directly here, NOT derived from the data model: the prompt
     * panel's question/answer content is deliberately bound under a
     * persistent `/board/elements/$panelId/...` path so it survives as a
     * scroll-back transcript record (see ClassroomBridge's user_prompt
     * branch) — there is no transient `/prompt` object in the data model
     * to read a "still active" flag off of, by design.
     */
    var hasActiveCheckpoint by mutableStateOf(false); private set

    /** The notebook drawer's content — see TranscriptLine's doc comment. */
    val transcript = mutableStateListOf<TranscriptLine>()

    private fun pushTranscript(speaker: String, text: String) {
        if (text.isBlank()) return
        transcript += TranscriptLine(UUID.randomUUID().toString(), speaker, text)
    }

    val canContinue: Boolean
        get() = surface.dataModel.resolvePointer("/canContinue")
            ?.takeIf { it.isJsonPrimitive }?.asBoolean == true

    val continueLabel: String
        get() = surface.dataModel.resolvePointer("/continueLabel")
            ?.takeIf { it.isJsonPrimitive }?.asString ?: "Continue"

    private val nextActionIntent: String
        get() = surface.dataModel.resolvePointer("/nextActionIntent")
            ?.takeIf { it.isJsonPrimitive }?.asString ?: "continue"

    fun start() {
        surface.applyCreateSurface(ClassroomBridge.createInitialSurface())
        collectorJob = scope.launch {
            ClassroomSocketClient.events.collect { event -> handleServerEvent(event) }
        }
        ClassroomSocketClient.connect(
            topic = topic,
            sessionId = sessionId,
            mode = mode,
            durationMinutes = durationMinutes,
            reducedMotion = ClassroomPreferences.reducedMotion,
            objective = objective,
            difficulty = difficulty,
        )
    }

    fun dispose() {
        ClassroomSocketClient.disconnect()
        scope.cancel()
    }

    // ── Incoming ──────────────────────────────────────────────────────────

    /** Backend component_ids already processed — de-dupes the real
     *  backend's confirmed duplicate-delivery pattern (a scene's
     *  components arrive both embedded in scene_start AND individually via
     *  component_render; see ClassroomServerEvent's doc comment). Only
     *  components carrying a non-null component_id can be de-duped this
     *  way; ad-hoc/LLM-authored ones without an id are processed every
     *  time they arrive (the fast-welcome path relies on this — it has no
     *  duplicate component_render follow-up to de-dupe against anyway). */
    private val processedComponentIds = mutableSetOf<String>()

    private fun handleServerEvent(event: ClassroomServerEvent) {
        when (event) {
            is ClassroomServerEvent.ComponentRenderEvent -> {
                status = "live"
                processComponent(event.component)
            }

            is ClassroomServerEvent.SceneStartEvent -> {
                status = "live"
                // Lazy erase: don't clear the board the instant scene_start
                // arrives on its own — wait until real content actually
                // lands, so the board never flashes empty during ordinary
                // LLM latency between scenes. If this scene_start already
                // carries embedded components (the ad-hoc fast-welcome
                // shape, or the real welcome scene's inline array), that
                // content IS the next thing landing, so erase happens
                // immediately before rendering it, not deferred further.
                pendingErase = true
                event.components.forEach { processComponent(it) }
            }

            ClassroomServerEvent.SceneCompleteEvent -> Unit // no board effect; canContinue is driven by CTAButton
            ClassroomServerEvent.IgnoredEvent -> Unit // system_state / scene_update — acknowledged, nothing to act on yet

            is ClassroomServerEvent.ErrorEvent -> {
                status = "error"
                errorMessage = event.message ?: "The classroom hit a snag."
            }
        }
    }

    private fun processComponent(component: ClassroomComponent) {
        val id = component.component_id
        if (id != null) {
            if (id in processedComponentIds) return
            processedComponentIds += id
        }
        eraseIfPending()
        val turns = ClassroomBridge.extractTurns(component)
        if (turns != null) {
            turnQueue.addAll(turns)
            if (playerJob == null || playerJob?.isActive != true) startPlayer()
        } else {
            // Non-turn-based components (QuizCard, InputField, ExampleBlock,
            // LessonBlock, ProgressBar, CTAButton, Celebration) render
            // immediately — the wire contract never paces these.
            applyMutation(ClassroomBridge.onImmediateComponentRender(component, boardChildren))
        }
    }

    private fun eraseIfPending() {
        if (!pendingErase) return
        pendingErase = false
        applyMutation(ClassroomBridge.clearBoard())
    }

    private fun applyMutation(mutation: ClassroomBridge.BoardMutation) {
        boardChildren = mutation.boardChildren
        mutation.messages.forEach { applyMessage(it) }
    }

    private fun applyMessage(message: A2uiMessage) {
        when (message) {
            is A2uiMessage.CreateSurface -> surface.applyCreateSurface(message)
            is A2uiMessage.UpdateComponents -> surface.applyUpdateComponents(message)
            is A2uiMessage.UpdateDataModel -> surface.applyUpdateDataModel(message)
            is A2uiMessage.DeleteSurface -> Unit // surfaces aren't torn down mid-session
        }
    }

    // ── Turn-queue playback ──────────────────────────────────────────────

    private fun startPlayer() {
        playerJob = scope.launch { playNext() }
    }

    /**
     * Pulls one turn off the queue, applies it, then waits the turn's
     * pacing delay before recursing — EXCEPT for `user_prompt`, which
     * returns without recursing: playback stays paused until either
     * `submitPromptAnswer`/an A2uiAction resolves it, or its own
     * unanswered-timer fires (both call playNext() themselves to resume).
     * This mirrors classroom-store.ts's playNext() turn-by-turn, matching
     * its "pause on user_prompt, resume with the NEXT queued turn — never a
     * replay" rule exactly.
     */
    private suspend fun playNext() {
        if (isPaused) return // resumed explicitly by togglePause()
        val turn = turnQueue.poll() ?: return
        eraseIfPending()
        val mutation = ClassroomBridge.directorTurnToA2ui(turn, boardChildren)
        applyMutation(mutation)

        when (turn.type) {
            "speech", "user_prompt" -> pushTranscript(turn.speaker ?: "Teacher", turn.text.orEmpty())
            "session_end" -> pushTranscript(
                "Teacher",
                "🔔 Class dismissed." + (turn.homework?.let { " Homework: $it" } ?: ""),
            )
        }

        if (turn.type == "user_prompt") {
            hasActiveCheckpoint = true
            val beatSeconds = (turn.beat_seconds ?: 5.0) + 8.0
            promptTimeoutJob?.cancel()
            promptTimeoutJob = scope.launch {
                delay((beatSeconds * 1000).toLong())
                // Unanswered — a classmate jumps in, per the director's
                // script; release the checkpoint and resume, matching the
                // web reference's timeout behavior exactly. The panel
                // itself stays on the board unanswered (its ChoicePicker
                // remains tappable) — only playback resumes.
                hasActiveCheckpoint = false
                playNext()
            }
            return
        }

        if (turn.action == "highlight" && turn.type == "board") {
            scheduleHighlightClear()
        }

        delay(pacingDelayMs(turn))
        playNext()
    }

    private fun scheduleHighlightClear() {
        val elementId = boardChildren.dropLast(1).lastOrNull() ?: return // the chalk element highlighted, not the spotlight just appended
        highlightClearJob?.cancel()
        highlightClearJob = scope.launch {
            delay(5000)
            applyMessage(ClassroomBridge.clearHighlight(elementId))
        }
    }

    /** Per-turn-type pacing, ported from classroom-store.ts's playNext()
     *  setTimeout durations (see DirectorTurn's doc comment for the full
     *  table) plus the ~80ms inter-turn gap applied after every type. */
    private fun pacingDelayMs(turn: DirectorTurn): Long {
        val base = when (turn.type) {
            "speech" -> readingDurationMs(turn.text)
            "lyo_state" -> 0L
            "ambient" -> 0L
            "pause" -> (minOf(turn.seconds ?: 1.0, 5.0) * 1000).toLong()
            "board" -> when (turn.action) {
                "image" -> 1800L
                "bullets" -> (turn.items?.size ?: 0).let { (it * 700 + 800).coerceAtMost(4200) }.toLong()
                "chart" -> 2400L
                "explorable" -> 2000L
                "highlight" -> 1600L
                else -> 2400L // write/draw
            }
            else -> 400L // session_end and the synthetic source-attribution turn: brief, non-blocking
        }
        return base + 80L
    }

    /** No TTS integration in this v1 (see the implementation plan) — a
     *  character-count-based reading-pace stand-in, clamped to a sane
     *  range, so speech turns still feel roughly paced to their length
     *  rather than flashing by instantly or stalling on a long line. */
    private fun readingDurationMs(text: String?): Long {
        val length = text?.length ?: 0
        return (length * 45L).coerceIn(1200L, 4200L)
    }

    // ── Outgoing: board-content actions (from the A2UI renderer) ────────

    fun onAction(action: A2uiAction) {
        if (action.name == "submitPrompt") {
            promptTimeoutJob?.cancel()
            hasActiveCheckpoint = false
            val answer = action.context["selectedLabel"]?.takeIf { it.isJsonPrimitive }?.asString
                ?: action.context["value"]?.takeIf { it.isJsonPrimitive }?.asString
            answer?.let { pushTranscript("You", it) }
            // Close the open-response Send/"I'm not sure" buttons the
            // instant this fires, before the network round-trip — prevents
            // a double-tap from sending a duplicate answer (the chip/
            // ChoicePicker path already self-disables via its own
            // selectedId check and doesn't need this).
            action.context["promptId"]?.takeIf { it.isJsonPrimitive }?.asString?.let { promptId ->
                applyMessage(ClassroomBridge.closePromptPanel(promptId))
            }
        }
        ClassroomSocketClient.send(ClassroomBridge.actionToUserAction(action, sessionId))
        if (action.name == "submitPrompt") {
            scope.launch { playNext() }
        }
    }

    // ── Outgoing: chrome-originated actions ──────────────────────────────

    fun togglePause() {
        if (isPaused) {
            isPaused = false
            // If a user_prompt checkpoint is still active, do NOT
            // startPlayer() here — its promptTimeoutJob was cancelled below
            // when pausing, so the turn was never re-queued; the queue's
            // next item is genuinely whatever comes AFTER this still-
            // unanswered prompt. Blindly resuming would poll and play that
            // next turn while skipping past the prompt entirely. Playback
            // correctly resumes on its own once the learner answers
            // (onAction) — resuming pause here only needs to stop blocking
            // that path, not force advancement.
            if (!hasActiveCheckpoint) startPlayer()
        } else {
            isPaused = true
            playerJob?.cancel()
            promptTimeoutJob?.cancel()
        }
    }

    fun continueLesson() {
        ClassroomSocketClient.send(ClassroomBridge.continueLessonAction(sessionId, nextActionIntent))
    }

    fun askQuestion(text: String) {
        val trimmed = text.trim()
        if (trimmed.isEmpty()) return
        pushTranscript("You", "✋ $trimmed")
        ClassroomSocketClient.send(ClassroomBridge.askQuestionAction(sessionId, trimmed))
    }

    fun requestHint(level: String) {
        pushTranscript("You", "Requested a hint")
        ClassroomSocketClient.send(ClassroomBridge.requestHintAction(sessionId, level))
    }

    fun signalConfused() {
        pushTranscript("You", "Requested a small nudge")
        ClassroomSocketClient.send(ClassroomBridge.signalConfusedAction(sessionId))
    }

    fun signalTooEasy() {
        pushTranscript("You", "Requested a harder case")
        ClassroomSocketClient.send(ClassroomBridge.signalTooEasyAction(sessionId))
    }
}
