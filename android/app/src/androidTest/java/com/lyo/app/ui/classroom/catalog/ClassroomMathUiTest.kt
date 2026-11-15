package com.lyo.app.ui.classroom.catalog

import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.lyo.app.ui.components.MarkdownText
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/** Real Compose semantics: readable teaching math, literal code preserved. */
@RunWith(AndroidJUnit4::class)
class ClassroomMathUiTest {
    @get:Rule val compose = createComposeRule()

    @Test
    fun textbookMathInMarkdownIsReadableWithoutRawLatexCommands() {
        compose.setContent {
            MarkdownText(markdown = """Solve \(\sqrt{9} \approx 3\) then \(\alpha \rightarrow \beta\).""")
        }
        compose.onNodeWithText("Solve √(9) ≈ 3 then α → β.", substring = true).assertExists()
    }

    @Test
    fun inlineCodeRemainsLiteralWhileOtherTextIsNormalized() {
        compose.setContent {
            MarkdownText(markdown = """**4 \times 2** and `code \rightarrow`""")
        }
        compose.onNodeWithText("""4 × 2 and code \rightarrow""", substring = true).assertExists()
    }
}
