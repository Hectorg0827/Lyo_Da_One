package com.lyo.app.ui.classroom.catalog

import org.junit.Assert.assertEquals
import org.junit.Test

class ClassroomMathTextTest {
    @Test fun fractionLessonUsesReadableOperators() {
        assertEquals("Goal: Find 4 × 2/5", readableClassroomMath("Goal: Find ${'$'}4 \\times \\frac{2}{5}${'$'}"))
    }
    @Test fun preservesCurrencyAndProse() {
        assertEquals("Costs ${'$'}4 per liter", readableClassroomMath("Costs ${'$'}4 per liter"))
    }
    @Test fun groupsCompoundNumerators() {
        assertEquals("(a + b)/c", readableClassroomMath("\\(\\frac{a + b}{c}\\)"))
    }
    @Test fun rawArrowsDoNotAppearAsLiteralTeXInTeacherProse() {
        assertEquals("Observe A → B", readableClassroomMath("""Observe A \rightarrow B"""))
        assertEquals("x ⟶ y", readableClassroomMath("""x \longrightarrow y"""))
    }

    @Test fun commonMathSymbolsRemainReadableWithoutNetworkAccess() {
        assertEquals("√(9) ≈ 3", readableClassroomMath("""\(\sqrt{9} \approx 3\)"""))
        assertEquals("α + β ≤ ∞", readableClassroomMath("""\(\alpha + \beta \leq \infty\)"""))
        assertEquals("a ⇒ b", readableClassroomMath("""\(a \Rightarrow b\)"""))
    }

    @Test fun convertsMultipleInlineExpressions() {
        assertEquals("4 groups of 2/5", readableClassroomMath("${'$'}4${'$'} groups of ${'$'}\\frac{2}{5}${'$'}"))
    }
}
