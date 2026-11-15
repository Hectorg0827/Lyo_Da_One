package com.lyo.app.ui.classroom

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** Local missions are practice only; real achievement stays backend-owned. */
class ClassroomMissionLogicTest {
    @Test fun `science and fractions choose appropriate interactive challenges`() {
        assertEquals(StarterMissionKind.FAIR_TEST, starterMissionFor("Science"))
        assertEquals(StarterMissionKind.FAIR_TEST, starterMissionFor("Biology: plants"))
        assertEquals(StarterMissionKind.FRACTIONS, starterMissionFor("Math"))
        assertEquals(StarterMissionKind.FRACTIONS, starterMissionFor("Fractions"))
        assertEquals(StarterMissionKind.GENERAL, starterMissionFor("World History"))
    }

    @Test fun `fair test must change water while holding light constant`() {
        assertFalse(checkFairExperiment(FairExperiment()).ready)
        assertTrue(checkFairExperiment(FairExperiment(waterB = 2)).ready)
        assertFalse(checkFairExperiment(FairExperiment(waterB = 2, sunlightB = 7)).ready)
        assertFalse(checkFairExperiment(FairExperiment(sunlightB = 7)).ready)
        assertTrue(checkFairExperiment(FairExperiment(waterB = 3)).guidance.contains("observations"))
    }

    @Test fun `engaged local mission is not interrupted by the first live scene`() {
        assertTrue(missionShouldBeVisible("connecting", false, false, false))
        assertTrue(missionShouldBeVisible("live", false, false, false))
        assertFalse(missionShouldBeVisible("live", true, false, false))
        assertTrue(missionShouldBeVisible("live", true, true, false))
        assertFalse(missionShouldBeVisible("live", true, true, true))
        assertFalse(missionShouldBeVisible("error", false, false, false))
        assertTrue(missionNeedsNarrationHold(true, true, false))
        assertFalse(missionNeedsNarrationHold(false, true, false))
        assertFalse(missionNeedsNarrationHold(true, true, true))
    }

    @Test fun `fraction challenge only succeeds on three equal quarters`() {
        assertFalse(fractionGoalReached(0))
        assertFalse(fractionGoalReached(2))
        assertTrue(fractionGoalReached(3))
        assertFalse(fractionGoalReached(4))
        assertFalse(fractionGoalReached(3, 5))
    }
}
