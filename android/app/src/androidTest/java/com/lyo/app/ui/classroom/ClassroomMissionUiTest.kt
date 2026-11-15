package com.lyo.app.ui.classroom

import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.test.assertExists
import androidx.compose.ui.test.assertDoesNotExist
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performSemanticsAction
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Physical Compose input tests for staging Classroom starter missions.
 * These never connect to a real learner or submit grading evidence.
 */
@RunWith(AndroidJUnit4::class)
class ClassroomMissionUiTest {
    @get:Rule val compose = createComposeRule()

    @Test
    fun scienceMissionLetsLearnerControlVariablesAndEnterLiveLesson() {
        var entered = false
        compose.setContent {
            ClassroomMission(
                topic = "Science",
                liveLessonReady = true,
                onEnterLive = { entered = true },
            )
        }
        compose.onNodeWithText("Design a fair experiment").assertExists()
        compose.onNodeWithText("Enter live lesson").assertExists()
        compose.onNodeWithContentDescription("Water for Plant B in cups")
            .performSemanticsAction(SemanticsActions.SetProgress) { setProgress ->
                setProgress(2f)
            }
        compose.onNodeWithText("Fair setup!", substring = true).assertExists()
        compose.onNodeWithContentDescription("Sunlight for Plant B in hours")
            .performSemanticsAction(SemanticsActions.SetProgress) { setProgress ->
                setProgress(7f)
            }
        compose.onNodeWithText("Keep sunlight the same", substring = true).assertExists()
        compose.onNodeWithText("Enter live lesson").performClick()
        compose.runOnIdle { assertTrue(entered) }
    }

    @Test
    fun fractionMissionShowsLiveVisualResponseAndNoFalseGrade() {
        compose.setContent {
            ClassroomMission(topic = "Fractions", liveLessonReady = false)
        }
        compose.onNodeWithText("Build three quarters").assertExists()
        compose.onNodeWithText("Enter live lesson").assertDoesNotExist()
        compose.onNodeWithContentDescription("Number of shaded quarters")
            .performSemanticsAction(SemanticsActions.SetProgress) { setProgress ->
                setProgress(3f)
            }
        compose.onNodeWithText("You built 3/4", substring = true).assertExists()
        compose.onNodeWithText("Practice only, not graded.", substring = true).assertExists()
    }

    @Test
    fun genericStarterIsActionableAndCanHandoffWhenReady() {
        var interacted = false
        var entered = false
        compose.setContent {
            ClassroomMission(
                topic = "Music theory",
                liveLessonReady = true,
                onInteraction = { interacted = true },
                onEnterLive = { entered = true },
            )
        }
        compose.onNodeWithText("Try an example and explain why").performClick()
        compose.onNodeWithText("Good reasoning.", substring = true).assertExists()
        compose.onNodeWithText("Enter live lesson").performClick()
        compose.runOnIdle { assertTrue(interacted && entered) }
    }
}
