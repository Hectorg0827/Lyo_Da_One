package com.lyo.app.ui.classroom.catalog

import org.junit.Assert.assertEquals
import org.junit.Test

class WebViewBlockTest {
    @Test
    fun unwrapsMathDelimitersUsedByChatAndClassroom() {
        assertEquals("\\frac{1}{2}", normalizeKaTeXSource(" $\\frac{1}{2}$ "))
        assertEquals("x^2 + 1", normalizeKaTeXSource("$x^2 + 1$"))
        assertEquals("E=mc^2", normalizeKaTeXSource("\\[ E=mc^2 \\]"))
        assertEquals("a+b", normalizeKaTeXSource("\\( a+b \\)"))
    }

    @Test
    fun leavesUnwrappedAndUnmatchedSourceReadable() {
        assertEquals("x^2 + 1", normalizeKaTeXSource(" x^2 + 1 "))
        assertEquals("$unfinished", normalizeKaTeXSource("$unfinished"))
        assertEquals("\\frac{1}{2}", normalizeKaTeXSource("\\frac{1}{2}"))
    }
}
