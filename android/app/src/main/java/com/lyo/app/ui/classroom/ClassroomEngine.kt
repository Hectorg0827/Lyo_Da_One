package com.lyo.app.ui.classroom

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.lyo.app.data.StackRepository
import com.lyo.app.data.api.ApiClient
import com.lyo.app.data.api.LearnerEvidenceRecordDto
import com.lyo.app.data.a2ui.A2uiAction
import com.lyo.app.data.a2ui.A2uiMessage
import com.lyo.app.data.a2ui.A2uiSurfaceState
import com.lyo.app.data.a2ui.resolvePointer
import com.lyo.app.data.classroom.ClassroomComponent
import com.lyo.app.data.classroom.ClassroomOpening
import com.lyo.app.data.classroom.ClassroomSavedSession
import com.lyo.app.data.classroom.ClassroomServerEvent
import com.lyo.app.data.classroom.ClassroomSessionContract
import com.lyo.app.data.classroom.ClassroomSessionStore
import com.lyo.app.data.classroom.ClassroomSocketClient
import com.lyo.app.data.classroom.ClassroomStallPhase
import com.lyo.app.data.classroom.DirectorTurn
import com.lyo.app.ui.classroom.a2ui.BasicCatalog
import com.lyo.app.ui.classroom.a2ui.A2uiCatalog
import com.lyo.app.ui.classroom.catalog.ClassroomCatalog
import com.lyo.app.ui.screens.classroom.ClassroomVoicePlayer
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withTimeoutOrNull
import kotlin.coroutines.resume
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
    private val courseBacked: Boolean = true,
    private val reviewConceptId: String? = null,
    private val voicePlayer: ClassroomVoicePlayer? = null,
    private val resume: Boolean = false,
    /**
     * Which seat to resume, when it is not simply the last one stored.
     * Starting a class overwrites that stored record, so by the time the
     * learner reads "pick up where you left off" the storage no longer holds
     * the session the offer is about — it has to be carried.
     */
    private val resumeSession: ClassroomSavedSession? = null,
) {
    /**
     * The course this class belongs to, which is what Stacks progress is
     * filed under. Kept apart from the session id so starting a lesson over
     * does not start the learner's progress over with it.
     */
    val courseId: String = sessionIdParam?.takeIf { it.isNotBlank() } ?: topic

    private val courseKey: String =
        ClassroomSessionContract.courseKey(courseId, topic)

    /**
     * Which session this is. The course's history decides whether this is a
     * new class or the old one carried on — opening a topic a second time
     * used to hand back the session the learner left, mid-unit, with no
     * opening and no way to ask for a clean start.
     */
    private val sessionStart = ClassroomSessionContract.sessionStart(
        courseKey = courseKey,
        saved = resumeSession ?: ClassroomSessionStore.saved(courseKey),
        resume = resume,
    )

    /** The id the live teaching session is keyed by server-side. */
    val sessionId: String = sessionStart.sessionId

    /** True when this class picked up a session the learner had started. */
    val resumedSession: Boolean = sessionStart.resumed

    /** A session the learner could still return to, if they want it. */
    val resumableSession: ClassroomSavedSession? =
        ClassroomSessionStore.saved(courseKey)
            ?.takeIf { !sessionStart.resumed && ClassroomSessionContract.canResume(it) }

    /**
     * The cover page: what this class is, before any of it is taught. Built
     * from the request this screen just made, so it is on screen in the time
     * it takes to open a socket rather than after a generation.
     */
    val opening: ClassroomOpening = ClassroomSessionContract.opening(
        topic = topic,
        objective = objective,
        durationMinutes = durationMinutes,
        difficulty = difficulty,
        mode = mode,
        resumed = sessionStart.resumed,
    )

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private var collectorJob: Job? = null
    private var playerJob: Job? = null
    private var promptTimeoutJob: Job? = null
    private var highlightClearJob: Job? = null
    private var activitySaveJob: Job? = null
    private val activityUpdates = mutableMapOf<String, A2uiAction>()

    val surface = A2uiSurfaceState(ClassroomBridge.SURFACE_ID)
    val catalog: A2uiCatalog = BasicCatalog + ClassroomCatalog

    private val turnQueue = ArrayDeque<DirectorTurn>()
    private var boardChildren: List<String> = emptyList()
    private var pendingErase = false

    var status by mutableStateOf("connecting"); private set
    var errorMessage by mutableStateOf<String?>(null); private set

    /**
     * How far past "the next step is coming" the current wait has gone.
     *
     * Waiting is the one classroom state with no natural end: every other one
     * is left by something the learner or the teacher does, so when a
     * generation fails the class does not break, it simply stops, with a
     * board that never changes again.
     */
    var stallPhase by mutableStateOf(ClassroomStallPhase.NONE); private set

    /**
     * Something the classroom reported and is carrying on from. Distinct from
     * [errorMessage], which means the class itself is over.
     */
    var notice by mutableStateOf<String?>(null); private set

    /** True while the class is waiting on a step from the teaching engine. */
    private var awaitingStep = true
    private var waitingSince: Long? = null
    private var stallNudged = false
    private var stallJob: Job? = null
    var isPaused by mutableStateOf(false); private set
    var isVoiceEnabled by mutableStateOf(true); private set
    private var voiceLanguage: String = "auto"

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

    /**
     * True once the teacher has put anything on the board, and true from then
     * on.
     *
     * The cover page and the resume offer used to key off `transcript`, which
     * only grows when something is *said*. A scene whose first component is a
     * QuizCard, InputField or LessonBlock renders straight to the board
     * without a transcript line, so the cover page stayed drawn on top of a
     * live board and could cover the learner's first checkpoint.
     *
     * A latch rather than a live reading of the board: `clearBoard()` empties
     * it between scenes, and a cover page that reappeared mid-lesson every
     * time the teacher wiped the board would be worse than the bug it fixes.
     */
    var hasBoardContent by mutableStateOf(false); private set

    /** Server-owned evidence only. Never derived from transcript or local UI state. */
    var learnerRecord by mutableStateOf<LearnerEvidenceRecordDto?>(null); private set
    var learnerRecordLoading by mutableStateOf(false); private set
    var learnerRecordFailed by mutableStateOf(false); private set
    var recordConcepts by mutableStateOf<List<String>>(emptyList()); private set

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
        // Recorded after resumableSession read the previous entry, so the
        // seat being offered back is the old one and not this class.
        ClassroomSessionStore.save(
            ClassroomSavedSession(sessionId, System.currentTimeMillis(), sessionStart.generation),
            courseKey,
        )
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
            courseId = courseId.takeIf { courseBacked },
            reviewConceptId = reviewConceptId,
        )
        startStallWatch()
    }

    fun dispose() {
        flushActivities()
        stallJob?.cancel()
        stallJob = null
        voicePlayer?.close()
        ClassroomSocketClient.disconnect()
        scope.cancel()
    }

    fun refreshLearnerRecord() {
        if (learnerRecordLoading) return
        learnerRecordLoading = true
        scope.launch {
            try {
                learnerRecord = ApiClient.api.learnerEvidenceRecord()
                learnerRecordFailed = false
            } catch (_: Exception) {
                // A failed read is not an empty learner record.
                learnerRecordFailed = true
            } finally {
                learnerRecordLoading = false
            }
        }
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
                clearWait()
                processComponent(event.component)
            }

            is ClassroomServerEvent.SceneStartEvent -> {
                stopNarration()
                processedComponentIds.clear()
                hasActiveCheckpoint = false
                status = "live"
                recordConcepts = event.metadata?.target_concepts.orEmpty()
                // Lazy erase: don't clear the board the instant scene_start
                // arrives on its own — wait until real content actually
                // lands, so the board never flashes empty during ordinary
                // LLM latency between scenes. If this scene_start already
                // carries embedded components (the ad-hoc fast-welcome
                // shape, or the real welcome scene's inline array), that
                // content IS the next thing landing, so erase happens
                // immediately before rendering it, not deferred further.
                pendingErase = true
                clearWait()
                event.components.forEach { processComponent(it) }
            }

            ClassroomServerEvent.SceneCompleteEvent -> Unit // no board effect; canContinue is driven by CTAButton
            ClassroomServerEvent.IgnoredEvent -> Unit // system_state / scene_update — acknowledged, nothing to act on yet

            is ClassroomServerEvent.ErrorEvent -> {
                // The classroom saying something went wrong is not the same
                // as the class being over. Only a failure that stops the
                // class running ends it; everything else is a notice beside
                // a lesson the learner can still finish.
                if (event.fatal) {
                    status = "error"
                    errorMessage = event.message ?: "The classroom hit a snag."
                } else {
                    notice = event.message ?: "The classroom hit a snag."
                }
            }
        }
    }

    // ── The watchdog ──────────────────────────────────────────────────────

    /**
     * One tick of the wait watchdog.
     *
     * A wait that is merely slow is said out loud and left alone. A wait that
     * passes the recovery threshold is asked after once, with `continue` —
     * the one intent that cannot be mistaken for a second answer — and only
     * if that second wait also runs out does the class admit the step is not
     * coming and put recovery controls in front of the learner.
     *
     * It ticks rather than arming a timer at each of the places a wait
     * begins: a wait that started without arming its own timer is exactly the
     * wait nobody would notice was never ending.
     */
    private fun startStallWatch() {
        stallJob?.cancel()
        stallJob = scope.launch {
            while (true) {
                delay(STALL_TICK_MS)
                stallTick(System.currentTimeMillis())
            }
        }
    }

    internal fun stallTick(now: Long) {
        // Not `status == "live"`. Android only reaches "live" when the first
        // server event arrives, so requiring it made the watchdog blind to
        // exactly the wait it matters most for: a socket that opens and then
        // never produces an opening scene. The learner sat on "Preparing your
        // classroom…" with no recovery controls, for ever. An errored session
        // has its own banner and is the only state with nothing to wait for.
        if (!awaitingStep || status == "error" || isPaused || hasActiveCheckpoint) {
            waitingSince = null
            stallNudged = false
            if (stallPhase != ClassroomStallPhase.NONE) stallPhase = ClassroomStallPhase.NONE
            return
        }
        val since = waitingSince
        if (since == null) {
            waitingSince = now
            return
        }
        val waited = now - since
        if (waited >= ClassroomSessionContract.STALL_RECOVERY_MS) {
            if (!stallNudged) {
                // One unprompted ask, then the learner decides. Resending the
                // learner's own answer here would risk grading it twice, so
                // the nudge is always `continue`.
                stallNudged = true
                waitingSince = now
                val sent = ClassroomSocketClient.send(
                    ClassroomBridge.continueLessonAction(sessionId, "continue", "android_continue"),
                )
                stallPhase =
                    if (sent) ClassroomStallPhase.SLOW else ClassroomStallPhase.STALLED
                return
            }
            if (stallPhase != ClassroomStallPhase.STALLED) {
                stallPhase = ClassroomStallPhase.STALLED
            }
            return
        }
        if (waited >= ClassroomSessionContract.STALL_NOTICE_MS &&
            stallPhase == ClassroomStallPhase.NONE
        ) {
            stallPhase = ClassroomStallPhase.SLOW
        }
    }

    /** The class is waiting on the engine again. */
    private fun beginWait() {
        awaitingStep = true
        waitingSince = System.currentTimeMillis()
        stallNudged = false
        if (stallPhase != ClassroomStallPhase.NONE) stallPhase = ClassroomStallPhase.NONE
    }

    /** Content arrived: the wait is over now, not on the next tick. */
    private fun clearWait() {
        awaitingStep = false
        waitingSince = null
        stallNudged = false
        if (stallPhase != ClassroomStallPhase.NONE) stallPhase = ClassroomStallPhase.NONE
    }

    // ── Recovery ──────────────────────────────────────────────────────────

    /**
     * The step did not come; ask for it again.
     *
     * Always `continue`, never the learner's own submission replayed. A
     * resent answer is a second answer as far as the grader is concerned, and
     * a learner who waited out a slow network must not pay for it with a
     * duplicate attempt on their record.
     */
    fun nudgeTeacher() {
        notice = null
        val sent = ClassroomSocketClient.send(
            ClassroomBridge.continueLessonAction(sessionId, "continue", "android_continue"),
        )
        if (!sent) return
        awaitingStep = true
        waitingSince = System.currentTimeMillis()
        stallNudged = true
        stallPhase = ClassroomStallPhase.SLOW
    }

    fun dismissNotice() {
        notice = null
    }

    private companion object {
        const val STALL_TICK_MS = 1000L
    }

    private fun processComponent(component: ClassroomComponent) {
        component.language_code?.takeIf { it.isNotBlank() }?.let { voiceLanguage = it }
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
            if (component.type == "ProgressBar") syncStackProgress(component)
        }
    }

    /** Mirrors the backend's own authoritative mastery-progress signal
     *  (ProgressBar's current/total — the same fields ClassroomBridge
     *  already reads for the on-screen bar) into the course's Stacks
     *  entry, so "Your Stacks" on the Focus/Home tab stays live without
     *  a separate polling mechanism. `sessionId` is the real course id
     *  once this screen was entered via Routes.classroom(topic, courseId)
     *  — see LyoNavHost — so no extra field is needed here. Fire-and-
     *  forget: StackRepository is itself resilient (never throws), and a
     *  failed sync must never interrupt turn playback. */
    private fun syncStackProgress(component: ClassroomComponent) {
        if (!courseBacked) return
        val total = (component.total ?: 1).coerceAtLeast(1)
        val current = (component.current ?: 0).coerceIn(0, total)
        scope.launch {
            StackRepository.updateCourseProgress(courseId, current.toFloat() / total.toFloat())
        }
    }

    private fun eraseIfPending() {
        if (!pendingErase) return
        pendingErase = false
        applyMutation(ClassroomBridge.clearBoard())
    }

    private fun applyMutation(mutation: ClassroomBridge.BoardMutation) {
        boardChildren = mutation.boardChildren
        if (boardChildren.isNotEmpty()) hasBoardContent = true
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

    private fun stopNarration() {
        playerJob?.cancel()
        playerJob = null
        promptTimeoutJob?.cancel()
        turnQueue.clear()
        voicePlayer?.stop()
    }

    private fun startPlayer() {
        playerJob = scope.launch { playNext() }
    }

    /**
     * Pulls one turn off the queue, applies it, then waits the turn's
     * pacing delay before recursing — EXCEPT for `user_prompt`, which
     * returns without recursing: playback stays paused until an explicit
     * learner answer or skip. Voiced speech waits for actual completion.
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
            "speech", "user_prompt" -> {
                val spoken = turn.text.orEmpty()
                pushTranscript(turn.speaker ?: "Teacher", spoken)
                if (isVoiceEnabled && spoken.isNotBlank()) {
                    if (turn.type == "speech" && voicePlayer != null) {
                        // Advance on actual audio completion, never on a reading
                        // estimate that can cut a slow response off mid-sentence.
                        withTimeoutOrNull(180_000L) {
                            suspendCancellableCoroutine<Unit> { continuation ->
                                voicePlayer.play(spoken, voiceLanguage) {
                                    if (continuation.isActive) continuation.resume(Unit)
                                }
                                continuation.invokeOnCancellation { voicePlayer.stop() }
                            }
                        }
                    } else {
                        voicePlayer?.play(spoken, voiceLanguage)
                    }
                }
            }
            "session_end" -> {
                // The class reached its end, so its seat stops being an
                // unfinished one however recently it was started.
                ClassroomSessionStore.markFinished(sessionId, courseKey)
                pushTranscript(
                    "Teacher",
                    "🔔 Class dismissed." + (turn.homework?.let { " Homework: $it" } ?: ""),
                )
            }
        }

        if (turn.type == "user_prompt") {
            hasActiveCheckpoint = true
            promptTimeoutJob?.cancel()
            // The learner owns the floor until an explicit answer or skip.
            // Silence is never permission to advance or invent a response.
            return
        }

        if (turn.action == "highlight" && turn.type == "board") {
            scheduleHighlightClear()
        }

        if (!(turn.type == "speech" && isVoiceEnabled && voicePlayer != null)) {
            delay(pacingDelayMs(turn))
        }
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
            "board" -> 0L // The board stays visible while narration explains it.
            else -> 400L // session_end and the synthetic source-attribution turn: brief, non-blocking
        }
        return base + 80L
    }

    /** Keep the paced director queue from cutting off shared teacher audio.
     *  160–175 wpm is a normal explanatory speaking rate; the player may use
     *  a provider voice or the device fallback, so use a conservative bounded
     *  estimate instead of provider-specific duration metadata. */
    private fun readingDurationMs(text: String?): Long {
        val words = text?.trim()?.split(Regex("\\s+"))?.count { it.isNotBlank() } ?: 0
        return (words * 360L).coerceIn(1200L, 24_000L)
    }

    // ── Outgoing: board-content actions (from the A2UI renderer) ────────

    fun onAction(action: A2uiAction) {
        if (action.name != "update_activity") stopNarration()
        if (action.name == "update_activity") {
            activityUpdates[action.sourceComponentId] = action
            activitySaveJob?.cancel()
            activitySaveJob = scope.launch { delay(200); flushActivities() }
            return
        }
        flushActivities()
        val sent = ClassroomSocketClient.send(
            ClassroomBridge.actionToUserAction(action, sessionId),
        )
        if (!sent) return
        if (action.name == "submitPrompt") {
            promptTimeoutJob?.cancel()
            hasActiveCheckpoint = false
            val answer = action.context["selectedLabel"]?.takeIf { it.isJsonPrimitive }?.asString
                ?: action.context["value"]?.takeIf { it.isJsonPrimitive }?.asString
            answer?.let { pushTranscript("You", it) }
            action.context["promptId"]?.takeIf { it.isJsonPrimitive }?.asString?.let { promptId ->
                applyMessage(ClassroomBridge.closePromptPanel(promptId))
            }
            // Wait for the server response; old queued teaching is obsolete.
            beginWait()
        }
    }

    // ── Outgoing: chrome-originated actions ──────────────────────────────

    fun toggleVoice() {
        isVoiceEnabled = !isVoiceEnabled
        voicePlayer?.setEnabled(isVoiceEnabled)
        if (!isVoiceEnabled) {
            playerJob?.cancel()
            playerJob = null
            if (!hasActiveCheckpoint && !isPaused) startPlayer()
        }
    }

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
            voicePlayer?.stop()
            playerJob?.cancel()
            promptTimeoutJob?.cancel()
        }
    }

    fun continueLesson() {
        stopNarration()
        flushActivities()
        val componentId = surface.dataModel.resolvePointer("/nextActionComponentId")?.takeIf { it.isJsonPrimitive }?.asString ?: "android_continue"
        if (ClassroomSocketClient.send(
                ClassroomBridge.continueLessonAction(sessionId, nextActionIntent, componentId),
            )
        ) {
            beginWait()
        }
    }

    private fun flushActivities() {
        activitySaveJob?.cancel()
        activitySaveJob = null
        val updates = activityUpdates.values.toList()
        activityUpdates.clear()
        updates.forEach { ClassroomSocketClient.send(ClassroomBridge.actionToUserAction(it, sessionId)) }
    }

    fun askQuestion(text: String) {
        stopNarration()
        flushActivities()
        val trimmed = text.trim()
        if (trimmed.isEmpty()) return
        if (ClassroomSocketClient.send(ClassroomBridge.askQuestionAction(sessionId, trimmed))) {
            pushTranscript("You", "✋ $trimmed")
            beginWait()
        }
    }

    fun requestHint(level: String) {
        stopNarration()
        flushActivities()
        if (ClassroomSocketClient.send(ClassroomBridge.requestHintAction(sessionId, level))) {
            pushTranscript("You", "Requested a hint")
            beginWait()
        }
    }

    fun signalConfused() {
        stopNarration()
        flushActivities()
        if (ClassroomSocketClient.send(ClassroomBridge.signalConfusedAction(sessionId))) {
            pushTranscript("You", "Requested a small nudge")
            beginWait()
        }
    }

    fun signalTooEasy() {
        stopNarration()
        flushActivities()
        if (ClassroomSocketClient.send(ClassroomBridge.signalTooEasyAction(sessionId))) {
            pushTranscript("You", "Requested a harder case")
            beginWait()
        }
    }
}
