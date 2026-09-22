package com.lyo.app.notifications

import org.junit.Assert.*
import org.junit.Test

class StudyReminderPolicyTest {
    @Test fun neverDisplayAfterLogoutOrWithoutConsent() {
        assertFalse(reminderMayDisplay(false, true, "42", "42"))
        assertFalse(reminderMayDisplay(true, false, "42", "42"))
    }
    @Test fun suppressPreviousAccountsAndMissingRecipient() {
        assertFalse(reminderMayDisplay(true, true, "42", "7"))
        assertFalse(reminderMayDisplay(true, true, "42", null))
        assertFalse(reminderMayDisplay(true, true, null, null))
        assertTrue(reminderMayDisplay(true, true, "42", "42"))
    }
}
