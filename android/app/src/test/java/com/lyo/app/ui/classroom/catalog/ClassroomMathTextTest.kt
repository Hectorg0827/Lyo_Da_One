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
    @Test fun convertsMultipleInlineExpressions() {
        assertEquals("4 groups of 2/5", readableClassroomMath("${'$'}4${'$'} groups of ${'$'}\\frac{2}{5}${'$'}"))
    }

    @Test fun parsesInlineAndDisplayMathWithoutLosingProse() {
        val input = "A half is $\\frac{1}{2}$, and \\[x^2 + 1\\] is displayed."
        val runs = classroomMathRuns(input)
        assertEquals(5, runs.size)
        assertEquals("A half is ", runs[0].text)
        assertEquals("\\frac{1}{2}", runs[1].text)
        assertEquals(true, runs[1].formula)
        assertEquals(false, runs[1].display)
        assertEquals("x^2 + 1", runs[3].text)
        assertEquals(true, runs[3].display)
    }

    @Test fun keepsCurrencyAndUnmatchedDelimitersAsProse() {
        val input = "Costs $4 per liter and grows 10%"
        assertEquals(listOf(ClassroomMathRun(input, false)), classroomMathRuns(input))
        assertEquals(false, hasClassroomMath(input))
    }

    @Test fun recognizesDollarMathAndUnwrapsFormulaForTheRenderer() {
        assertEquals("\\frac{2}{3}", unwrapClassroomFormula("$$\\frac{2}{3}$$"))
        assertEquals("\\sqrt{9}", unwrapClassroomFormula("\\(\\sqrt{9}\\)"))
        assertEquals(true, hasClassroomMath("Solve ${')
    }

    @Test fun neverTreatsNonMathProseAsAFormula() {
        assertEquals(false, hasClassroomMath("Fractions are parts of a whole."))
        assertEquals("Fractions are parts of a whole.", unwrapClassroomFormula(" Fractions are parts of a whole. "))
    }

}
}x^2${')
    }

    @Test fun neverTreatsNonMathProseAsAFormula() {
        assertEquals(false, hasClassroomMath("Fractions are parts of a whole."))
        assertEquals("Fractions are parts of a whole.", unwrapClassroomFormula(" Fractions are parts of a whole. "))
    }

}
} today"))
    }

    @Test fun neverTreatsNonMathProseAsAFormula() {
        assertEquals(false, hasClassroomMath("Fractions are parts of a whole."))
        assertEquals("Fractions are parts of a whole.", unwrapClassroomFormula(" Fractions are parts of a whole. "))
    }

}
