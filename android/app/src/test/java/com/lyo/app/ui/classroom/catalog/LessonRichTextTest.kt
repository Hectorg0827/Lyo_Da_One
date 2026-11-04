package com.lyo.app.ui.classroom.catalog

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** Real regressions reported from the Samsung classroom's algebra lesson. */
class LessonRichTextTest {
    @Test fun recognizesInlineAndDisplayMathInsideDocuments() {
        assertTrue(containsLessonMath("For the equation " + "$" + "4x + 3 = 19" + "$" + ":"))
        assertTrue(containsLessonMath("$$" + "4x + 3 = 19" + "$$"))
        assertTrue(containsLessonMath("x + \\frac{3}{4} = \\frac{19}{4}"))
        assertFalse(containsLessonMath("What is the first inverse operation?"))
    }

    @Test fun richHtmlKeepsFormulasForKatexAndEscapesInjectedMarkup() {
        val html = buildRichLessonHtml("### Target Equation\n" + "$$" + "4x + 3 = 19" + "$$" + "\n**Subtract 3** <script>alert(1)</script>")
        assertTrue(html.contains("renderMathInElement"))
        assertTrue(html.contains("4x + 3 = 19"))
        assertTrue(html.contains("<strong>Subtract 3</strong>"))
        assertTrue(html.contains("&lt;script&gt;"))
        assertFalse(html.contains("### Target Equation"))
        assertFalse(html.contains("<script>alert(1)</script>"))
    }
}
