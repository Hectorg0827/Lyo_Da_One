package com.lyo.app.ui.classroom

import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.lyo.app.ui.classroom.a2ui.ChipState
import com.lyo.app.ui.classroom.a2ui.ClassroomChipRow
import com.lyo.app.ui.navigation.LyoBottomBar
import com.lyo.app.ui.navigation.Routes
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/** Instrumented UI smoke tests: tests real Compose clickable semantics. */
@RunWith(AndroidJUnit4::class)
class ClassroomNavigationUiTest {
    @get:Rule val compose = createComposeRule()

    @Test
    fun tappingSecondDuplicateLabelUsesSecondOptionIndex() {
        var selectedIndex = -1
        compose.setContent {
            ClassroomChipRow(
                options = listOf("2/3", "2/3"),
                stateFor = { _, _ -> ChipState.DEFAULT },
                enabledFor = { _, _ -> true },
                onSelect = { index, _ -> selectedIndex = index },
            )
        }

        val identicalChips = compose.onAllNodesWithText("2/3")
        identicalChips.assertCountEquals(2)
        identicalChips[1].performClick()
        compose.runOnIdle { assertEquals(1, selectedIndex) }
    }

    @Test
    fun bottomNavigationExposesDestinationNamesToTalkBack() {
        var selectedRoute: String? = null
        compose.setContent {
            LyoBottomBar(currentRoute = null) { selectedRoute = it }
        }

        for (destination in listOf("Focus", "Discover", "Ask Lyo", "Community", "Create")) {
            compose.onNodeWithContentDescription(destination).assertExists()
        }
        compose.onNodeWithContentDescription("Create").performClick()
        compose.runOnIdle { assertEquals(Routes.CREATE, selectedRoute) }
    }
}
