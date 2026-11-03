package com.lyo.app.ui.classroom

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test

class ClassroomDisplayModeTest {
    @Test fun routeModesMapToVisualModes() {
        assertEquals(ClassroomDisplayMode.SOLO, ClassroomDisplayMode.fromTeachingMode("solo"))
        assertEquals(ClassroomDisplayMode.CLASSROOM, ClassroomDisplayMode.fromTeachingMode("classroom"))
        assertEquals(ClassroomDisplayMode.REVIEW, ClassroomDisplayMode.fromTeachingMode("review"))
    }

    @Test fun selectableReviewDoesNotClaimUnsupportedBackendSessionType() {
        assertEquals("solo", ClassroomDisplayMode.REVIEW.backendModeWhenStarting())
        assertEquals("classroom", ClassroomDisplayMode.CLASSROOM.backendModeWhenStarting())
        assertEquals("solo", ClassroomDisplayMode.SOLO.backendModeWhenStarting())
    }

    @Test fun eachModeIsUserSelectableAndHasDescriptiveCopy() {
        assertEquals(3, ClassroomDisplayMode.entries.size)
        ClassroomDisplayMode.entries.forEach {
            assertFalse(it.label.isBlank())
            assertFalse(it.description.isBlank())
        }
    }
}
