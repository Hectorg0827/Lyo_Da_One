package com.lyo.app.ui.classroom

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import kotlinx.coroutines.delay
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.Modifier
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.navigation.NavHostController
import com.lyo.app.data.StackRepository
import com.lyo.app.data.a2ui.resolvePointer
import com.lyo.app.data.classroom.ClassroomSavedSession
import com.lyo.app.data.classroom.ClassroomStallPhase
import com.lyo.app.ui.classroom.a2ui.A2uiSurface
import com.lyo.app.ui.screens.classroom.ClassroomVoicePlayer
import com.lyo.app.ui.theme.Background
import com.lyo.app.ui.theme.ClassroomTokens
import com.lyo.app.ui.theme.LyoRed
import com.lyo.app.ui.theme.TextSecondary

/**
 * The AI Classroom screen — entry point wired into LyoNavHost. Composes
 * ClassroomEngine (turn-queue/state), the A2UI-rendered board (the
 * genuinely dynamic, server-driven content), and hand-authored chrome
 * (ClassroomChrome.kt) around it, per the implementation plan's
 * Architecture section: chrome auto-hides Netflix/YouTube-style; the
 * board and Lyo's explanation
 * never do.
 *
 * `courseId` mirrors `RecentCourseStore.save()`'s pattern in LyoNavHost's
 * COURSE_DETAIL route — a real integration would also record classroom
 * entry there, left as a follow-up since it's not part of this feature's
 * own scope.
 */
@Composable
fun ClassroomScreen(
    nav: NavHostController,
    topic: String,
    courseId: String = topic,
    teachingMode: String = "solo",
    courseBacked: Boolean = true,
    reviewConceptId: String? = null,
) {
    val context = LocalContext.current
    // Restarting a lesson, or returning to an unfinished one, is a new engine
    // on a different server session — the server holds the learner's place
    // inside the session, so a session that cannot produce its next step
    // cannot be argued out of it. Bumping this key is what rebuilds it.
    var sessionAttempt by remember(topic, courseId) { mutableIntStateOf(0) }
    var resumeSeat by remember(topic, courseId) { mutableStateOf<ClassroomSavedSession?>(null) }
    // The teacher's server mode is selected only once at entry. Switching
    // visual modes later leaves this live session and graded evidence intact.
    val suggestedMode = ClassroomDisplayMode.fromTeachingMode(teachingMode)
    val preferredMode = remember(context, topic, courseId) {
        ClassroomPreferences.savedDisplayMode(context)
    }
    val initialMode = if (reviewConceptId != null) ClassroomDisplayMode.REVIEW else preferredMode
    var activeDisplayMode by remember(topic, courseId) {
        mutableStateOf<ClassroomDisplayMode?>(initialMode)
    }
    var showModePicker by remember(topic, courseId) { mutableStateOf(initialMode == null) }
    var rememberModeChoice by remember(topic, courseId) { mutableStateOf(true) }
    var backendTeachingMode by remember(topic, courseId) {
        mutableStateOf(if (reviewConceptId != null && teachingMode == "review") "review"
            else initialMode?.backendModeWhenStarting() ?: teachingMode)
    }

    // Keyed on the attempt too: engine.dispose() closes this player, so a
    // rebuilt engine inheriting the old one would teach in silence.
    val voicePlayer = remember(context, topic, courseId, backendTeachingMode, courseBacked, sessionAttempt) {
        ClassroomVoicePlayer(context)
    }
    val engine = remember(
        topic, courseId, backendTeachingMode, courseBacked, reviewConceptId, sessionAttempt,
    ) {
        ClassroomEngine(
            topic = topic,
            sessionIdParam = courseId,
            mode = backendTeachingMode,
            courseBacked = courseBacked,
            reviewConceptId = reviewConceptId,
            voicePlayer = voicePlayer,
            resume = resumeSeat != null,
            resumeSession = resumeSeat,
        )
    }
    DisposableEffect(engine, activeDisplayMode != null) {
        if (activeDisplayMode != null) engine.start()
        onDispose { if (activeDisplayMode != null) engine.dispose() }
    }
    LaunchedEffect(courseId, topic, courseBacked, activeDisplayMode) {
        if (activeDisplayMode != null && courseBacked) {
            StackRepository.upsertCourseOnStart(courseId, title = topic)
        }
    }

    var settingsOpen by remember { mutableStateOf(false) }
    var notebookOpen by remember { mutableStateOf(false) }
    // ClassroomPreferences.reducedMotion is a plain var (see its doc
    // comment — an in-memory singleton, not a Compose-observable one), so
    // the Switch needs its own observable copy to actually recompose on
    // toggle; this mirrors it into ClassroomPreferences on every change.
    var reducedMotionUi by remember { mutableStateOf(ClassroomPreferences.reducedMotion) }

    LaunchedEffect(notebookOpen) {
        if (notebookOpen) engine.refreshLearnerRecord()
    }

    // Lesson controls and progress remain visible; auto-hiding the header
    // left an empty strip and confused learners during interaction.
    val chrome = rememberChromeVisibility(blockAutoHide = true)
    // Recovery is an automatic temporary visual state; never overwrite the
    // learner's chosen mode or saved device preference on a network error.
    val isAutoRecovery = engine.stallPhase == ClassroomStallPhase.STALLED ||
        engine.status == "error" || engine.lessonRecovery
    val renderedMode = if (isAutoRecovery) ClassroomDisplayMode.REVIEW else activeDisplayMode
    // The companion appears only after a real Lyo contribution, then leaves.
    val lastLyoLine = engine.transcript.lastOrNull { it.speaker.equals("Lyo", ignoreCase = true) }
    var showFocusLyoTip by remember(topic, courseId) { mutableStateOf(false) }
    LaunchedEffect(lastLyoLine?.id) {
        if (lastLyoLine != null) {
            showFocusLyoTip = true
            delay(5_500L)
            showFocusLyoTip = false
        }
    }


    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Background),
    ) {
        // Background tap-catcher, drawn BEHIND everything below — Compose's
        // default hit-testing already gives every real button/board-content
        // element beneath it priority (a pointerInput on a parent only
        // receives a gesture that no descendant claimed first), so a tap
        // on empty background space toggles chrome and a tap on any real
        // control does not, with no extra "scope to background" plumbing
        // needed beyond z-order. NOTE (disclosed, not verified on-device):
        // the board's own verticalScroll may consume more of the gesture
        // stream than a plain click would on web/iOS's equivalent
        // e.target===e.currentTarget check — this needs real-device
        // confirmation, same as every other interaction nuance in this
        // Android build (see the implementation summary).
        Box(
            modifier = Modifier
                .fillMaxSize()
                .pointerInput(Unit) { detectTapGestures { chrome.poke() } },
        )

        Column(modifier = Modifier.fillMaxSize()) {
            AnimatedVisibility(visible = chrome.visible) {
                ClassroomTopBar(
                    topic = topic,
                    isPaused = engine.isPaused,
                    isVoiceEnabled = engine.isVoiceEnabled,
                    onBack = { nav.popBackStack() },
                    onTogglePause = { engine.togglePause(); chrome.poke() },
                    onToggleVoice = { engine.toggleVoice(); chrome.poke() },
                    onToggleNotebook = { notebookOpen = !notebookOpen; settingsOpen = false; chrome.poke() },
                    onToggleSettings = { settingsOpen = !settingsOpen; notebookOpen = false; chrome.poke() },
                    focusModeLabel = if (activeDisplayMode == ClassroomDisplayMode.SOLO) "Focus" else null,
                    onToggleMode = { showModePicker = true; chrome.poke() },
                )
            }

            // Independent of chrome.visible (matching web's settingsOpen/
            // notebookOpen panels, which stay open even if the rest of the
            // desk row would otherwise auto-hide) — blockAutoHide above
            // already keeps chrome.visible true the whole time either is
            // open, so this is never actually shown while the top bar
            // toggling it is hidden.
            if (settingsOpen) {
                SettingsPanel(
                    reducedMotion = reducedMotionUi,
                    onReducedMotionChange = {
                        reducedMotionUi = it
                        ClassroomPreferences.reducedMotion = it
                    },
                )
            }
            if (notebookOpen) {
                NotebookPanel(
                    transcript = engine.transcript,
                    learnerRecord = engine.learnerRecord,
                    learnerRecordLoading = engine.learnerRecordLoading,
                    learnerRecordFailed = engine.learnerRecordFailed,
                    currentConceptIds = engine.recordConcepts,
                )
            }

            activeDisplayMode?.takeIf { it != ClassroomDisplayMode.SOLO }?.let { current ->
                ClassroomModeSwitcher(current) { showModePicker = true }
            }
            // Three distinct presentations use the same teacher and live engine.
            renderedMode?.let { mode ->
                ClassroomModeHero(
                    mode = mode,
                    topic = topic,
                    caption = engine.surface.dataModel.resolvePointer("/caption"),
                    isPaused = engine.isPaused || isAutoRecovery,
                    onTranscript = { notebookOpen = true; settingsOpen = false; chrome.poke() },
                )
            }

            // Blackboard-first layout: the teacher and Lyo have compact identity
            // badges above, while the real, server-driven lesson owns the space.
            // The blackboard is the hero: own a dedicated title row and a
            // separately scrolling content viewport. Never draw the heading
            // over the dynamic A2UI lesson content.
            Column(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxWidth()
                    .padding(horizontal = 12.dp, vertical = 5.dp)
                    .background(
                        Brush.verticalGradient(
                            listOf(Color(0xFF182044), Color(0xFF121A3B), Color(0xFF0D1335)),
                        ),
                        RoundedCornerShape(22.dp),
                    )
                    .border(
                        1.dp,
                        ClassroomTokens.AccentPurple.copy(alpha = 0.65f),
                        RoundedCornerShape(22.dp),
                    ),
            ) {
                renderedMode?.let { mode ->
                    ClassroomBoardHeading(
                        mode = mode,
                        paused = engine.isPaused || isAutoRecovery,
                    )
                }
                Box(modifier = Modifier.weight(1f).fillMaxWidth()) {
                    if (isAutoRecovery && !engine.isReviewingPastStep &&
                        (engine.stallPhase == ClassroomStallPhase.STALLED || engine.status == "error")
                    ) {
                        StallRecoveryCard(
                            onAskAgain = {
                                if (engine.status == "error") {
                                    resumeSeat = null
                                    sessionAttempt += 1
                                } else engine.nudgeTeacher()
                                chrome.poke()
                            },
                            onStartOver = {
                                resumeSeat = null
                                sessionAttempt += 1
                                chrome.poke()
                            },
                        )
                    } else {
                    A2uiSurface(
                        state = engine.shownSurface,
                        catalog = engine.catalog,
                        onAction = { action ->
                            // Completed scenes may be inspected, not regraded.
                            if (!engine.isReviewingPastStep) engine.onAction(action)
                            chrome.poke()
                        },
                        modifier = Modifier
                            .fillMaxSize()
                            .verticalScroll(rememberScrollState())
                            .padding(start = 14.dp, end = 14.dp, bottom = 12.dp),
                    )

                    if (!engine.hasBoardContent) {
                        OpeningCard(
                            opening = engine.opening,
                            modifier = Modifier
                                .align(Alignment.TopCenter)
                                .padding(horizontal = 8.dp, vertical = 8.dp),
                        )
                    }
                    if (engine.status == "error") {
                        Text(
                            text = engine.errorMessage ?: "The classroom hit a snag.",
                            color = LyoRed,
                            style = MaterialTheme.typography.bodySmall,
                            modifier = Modifier
                                .align(Alignment.TopCenter)
                                .padding(horizontal = 16.dp, vertical = 8.dp),
                        )
                    } else if (engine.status == "connecting") {
                        Text(
                            text = "Preparing your classroom…",
                            color = TextSecondary,
                            style = MaterialTheme.typography.bodySmall,
                            modifier = Modifier.align(Alignment.Center),
                        )
                    }
                    }
                    if (activeDisplayMode == ClassroomDisplayMode.SOLO &&
                        !isAutoRecovery && !engine.isReviewingPastStep &&
                        showFocusLyoTip && lastLyoLine != null
                    ) {
                        FocusLyoTipOverlay(
                            message = lastLyoLine.text,
                            onDismiss = { showFocusLyoTip = false },
                            modifier = Modifier
                                .align(Alignment.BottomCenter)
                                .padding(horizontal = 10.dp, vertical = 8.dp),
                        )
                    }
                }
            }

            renderedMode?.takeIf { it != ClassroomDisplayMode.SOLO &&
                activeDisplayMode != ClassroomDisplayMode.SOLO }?.let { mode ->
                ClassroomModeCompanion(
                    mode = mode,
                    transcript = engine.transcript,
                    isReviewingPastStep = engine.isReviewingPastStep,
                    isGroupSession = backendTeachingMode == "classroom",
                )
            }

            // The step never arrived. The class says so, says it is not the
            // learner's fault, and gives them two things that actually move
            // it — asking again, and leaving the stuck session behind.
            if (engine.stallPhase != ClassroomStallPhase.STALLED) {
                engine.notice?.let { message ->
                    ClassroomNoticeCard(message = message, onDismiss = { engine.dismissNotice() })
                }
                engine.resumableSession?.takeIf { !engine.hasBoardContent }?.let { seat ->
                    ResumeOfferCard(onResume = {
                        resumeSeat = seat
                        sessionAttempt += 1
                        chrome.poke()
                    })
                }
            }

            if (activeDisplayMode == ClassroomDisplayMode.SOLO) {
                FocusStepNavigation(engine)
            } else if (activeDisplayMode != null) {
                ClassroomStepNavigation(engine)
            }
            AnimatedVisibility(visible = !engine.isReviewingPastStep && (chrome.visible || engine.canContinue)) {
                BottomActionDock(
                    canContinue = engine.canContinue && activeDisplayMode != ClassroomDisplayMode.SOLO,
                    continueLabel = engine.continueLabel,
                    onContinue = { engine.continueLesson(); chrome.poke() },
                    onAskQuestion = { text -> engine.askQuestion(text); chrome.poke() },
                    onHint = { engine.requestHint("nudge"); chrome.poke() },
                    onTooEasy = { engine.signalTooEasy(); chrome.poke() },
                )
            }
        }
        if (showModePicker) {
            ClassroomModePicker(
                current = activeDisplayMode,
                canDismiss = activeDisplayMode != null,
                suggested = suggestedMode,
                rememberChoice = rememberModeChoice,
                onRememberChoiceChange = { rememberModeChoice = it },
                onChoose = { selected ->
                    if (activeDisplayMode == null) {
                        // Backend mode is chosen before opening the socket.
                        // A later UI mode change does not restart the class.
                        backendTeachingMode = if (teachingMode == "review" && reviewConceptId != null)
                            "review" else selected.backendModeWhenStarting()
                    }
                    if (selected == ClassroomDisplayMode.REVIEW && !engine.isReviewingPastStep) {
                        engine.previousStep()
                    } else if (activeDisplayMode == ClassroomDisplayMode.REVIEW &&
                        selected != ClassroomDisplayMode.REVIEW
                    ) {
                        engine.returnToLiveStep()
                    }
                    activeDisplayMode = selected
                    if (rememberModeChoice) ClassroomPreferences.saveDisplayMode(context, selected)
                    else ClassroomPreferences.saveDisplayMode(context, null)
                    showModePicker = false
                },
                onDismiss = { showModePicker = false },
            )
        }
    }
}
