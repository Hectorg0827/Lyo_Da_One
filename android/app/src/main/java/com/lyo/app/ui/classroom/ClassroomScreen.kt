package com.lyo.app.ui.classroom

import android.app.Activity
import android.content.pm.ActivityInfo
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import androidx.navigation.NavHostController
import com.lyo.app.data.a2ui.resolvePointer
import com.lyo.app.ui.classroom.a2ui.A2uiSurface
import com.lyo.app.ui.classroom.a2ui.RenderNode
import com.lyo.app.ui.theme.Background
import com.lyo.app.ui.theme.LyoRed
import com.lyo.app.ui.theme.TextSecondary

/**
 * The AI Classroom screen — entry point wired into LyoNavHost. Composes
 * ClassroomEngine (turn-queue/state), the A2UI-rendered board (the
 * genuinely dynamic, server-driven content), and hand-authored chrome
 * (ClassroomChrome.kt) around it, per the implementation plan's
 * Architecture section: chrome auto-hides Netflix/YouTube-style; the
 * board, the teacher's caption, and both mascots (Teacher badge + Lyo)
 * never do.
 *
 * `courseId` mirrors `RecentCourseStore.save()`'s pattern in LyoNavHost's
 * COURSE_DETAIL route — a real integration would also record classroom
 * entry there, left as a follow-up since it's not part of this feature's
 * own scope.
 */
@Composable
fun ClassroomScreen(nav: NavHostController, topic: String, courseId: String = topic) {
    val engine = remember(topic, courseId) { ClassroomEngine(topic = topic, sessionIdParam = courseId) }
    DisposableEffect(engine) {
        engine.start()
        onDispose { engine.dispose() }
    }

    // Netflix/YouTube-style classroom: default to landscape full-screen +
    // immersive (hidden) system bars, matching the web classroom's
    // behavior. Modeled directly on ChatScreen.kt's TextToSpeech
    // DisposableEffect shape: acquire in the effect body, capture the
    // ORIGINAL orientation before mutating so onDispose restores it
    // exactly rather than hardcoding a default (some other screen may
    // already have set a non-UNSPECIFIED orientation elsewhere in the app).
    val context = LocalContext.current
    val activity = context as? Activity
    DisposableEffect(Unit) {
        val originalOrientation = activity?.requestedOrientation
        activity?.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE
        val window = activity?.window
        val insetsController = window?.let { WindowInsetsControllerCompat(it, it.decorView) }
        insetsController?.systemBarsBehavior = WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
        insetsController?.hide(WindowInsetsCompat.Type.systemBars())
        onDispose {
            insetsController?.show(WindowInsetsCompat.Type.systemBars())
            activity?.requestedOrientation = originalOrientation ?: ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED
        }
    }

    var settingsOpen by remember { mutableStateOf(false) }
    var notebookOpen by remember { mutableStateOf(false) }
    // ClassroomPreferences.reducedMotion is a plain var (see its doc
    // comment — an in-memory singleton, not a Compose-observable one), so
    // the Switch needs its own observable copy to actually recompose on
    // toggle; this mirrors it into ClassroomPreferences on every change.
    var reducedMotionUi by remember { mutableStateOf(ClassroomPreferences.reducedMotion) }
    val chrome = rememberChromeVisibility(
        blockAutoHide = engine.hasActiveCheckpoint || settingsOpen || notebookOpen,
    )

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
                .pointerInput(Unit) { detectTapGestures { chrome.toggle() } },
        )

        Column(modifier = Modifier.fillMaxSize()) {
            AnimatedVisibility(visible = chrome.visible) {
                ClassroomTopBar(
                    topic = topic,
                    isPaused = engine.isPaused,
                    onBack = { nav.popBackStack() },
                    onTogglePause = { engine.togglePause(); chrome.poke() },
                    onToggleNotebook = { notebookOpen = !notebookOpen; settingsOpen = false; chrome.poke() },
                    onToggleSettings = { settingsOpen = !settingsOpen; notebookOpen = false; chrome.poke() },
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
                NotebookPanel(transcript = engine.transcript)
            }

            // The board — permanent, fills remaining space. Lyo's mascot
            // sits in its corner, addressed directly by id ("lyo_mascot")
            // rather than through the board_column subtree, since it's a
            // fixed always-on element, not board content that scrolls with
            // lesson history.
            Box(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxWidth(),
            ) {
                A2uiSurface(
                    state = engine.surface,
                    catalog = engine.catalog,
                    onAction = { action -> engine.onAction(action); chrome.poke() },
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(12.dp)
                        .verticalScroll(rememberScrollState()),
                )

                Box(
                    modifier = Modifier
                        .align(Alignment.BottomEnd)
                        .padding(12.dp),
                ) {
                    RenderNode(
                        componentId = "lyo_mascot",
                        state = engine.surface,
                        catalog = engine.catalog,
                        scopePath = "/",
                        onAction = { action -> engine.onAction(action) },
                    )
                }

                if (engine.status == "error") {
                    Text(
                        text = engine.errorMessage ?: "The classroom hit a snag.",
                        color = LyoRed,
                        style = MaterialTheme.typography.bodySmall,
                        modifier = Modifier
                            .align(Alignment.TopCenter)
                            .padding(8.dp),
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

            // Permanent — the teacher's spoken caption + Teacher badge,
            // never wrapped in the chrome AnimatedVisibility below.
            TeacherBadgeAndCaption(caption = engine.surface.dataModel.resolvePointer("/caption"))

            AnimatedVisibility(visible = chrome.visible) {
                BottomActionDock(
                    canContinue = engine.canContinue,
                    continueLabel = engine.continueLabel,
                    onContinue = { engine.continueLesson(); chrome.poke() },
                    onAskQuestion = { text -> engine.askQuestion(text); chrome.poke() },
                    onHint = { engine.requestHint("nudge"); chrome.poke() },
                    onTooEasy = { engine.signalTooEasy(); chrome.poke() },
                )
            }
        }
    }
}
