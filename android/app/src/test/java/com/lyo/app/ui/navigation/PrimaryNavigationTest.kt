package com.lyo.app.ui.navigation

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test

class PrimaryNavigationTest {
    @Test
    fun `primary tabs match approved Android order`() {
        assertEquals(
            listOf(Routes.HOME, Routes.DISCOVER, Routes.CHAT, Routes.COMMUNITY, Routes.CREATE),
            primaryTabRoutes,
        )
        assertEquals(5, primaryTabRoutes.distinct().size)
        // Profile stays reachable from Focus's account menu, never a sixth tab.
        assertFalse(Routes.PROFILE in primaryTabRoutes)
    }
}
