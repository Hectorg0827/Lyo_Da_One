package com.lyo.app.ui.classroom

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ClassroomNavigationPolicyTest {
    @Test fun forwardOnlyWhenBackendAllowsIt() {
        assertTrue(canAdvanceLiveLesson(false, true, false, false, false))
    }

    @Test fun neverResubmitOrSkipAnUnansweredCheckpoint() {
        assertFalse(canAdvanceLiveLesson(false, false, true, false, false))
        assertFalse(canAdvanceLiveLesson(false, true, true, false, false))
    }

    @Test fun historyAndErrorsCannotSendFreshNextEvents() {
        assertFalse(canAdvanceLiveLesson(true, true, false, false, false))
        assertFalse(canAdvanceLiveLesson(false, true, false, true, false))
        assertFalse(canAdvanceLiveLesson(false, true, false, false, true))
    }
    @Test fun recoveryBoardCanContinueWithoutResubmittingAnAnswer() {
        // The backend explicitly permits a fresh example after grading
        // failed; the visual Review/Paused label is not a local pause.
        assertTrue(canAdvanceLiveLesson(
            reviewingPast = false, canContinue = true,
            activeCheckpoint = false, failed = false, paused = false,
        ))
        assertFalse(canAdvanceLiveLesson(
            reviewingPast = false, canContinue = true,
            activeCheckpoint = false, failed = false, paused = false,
            awaitingResponse = true,
        ))
    }

}
