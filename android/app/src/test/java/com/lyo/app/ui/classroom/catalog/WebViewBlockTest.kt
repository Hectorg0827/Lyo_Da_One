package com.lyo.app.ui.classroom.catalog

import org.junit.Assert.assertEquals
import org.junit.Test

class WebViewBlockTest {
    private val inline = "$"
    private val display = inline + inline

    @Test
    fun unwrapsMathDelimitersUsedByChatAndClassroom() {
        assertEquals("\\frac{1}{2}", normalizeKaTeXSource(" " + display + "\\frac{1}{2}" + display + " "))
        assertEquals("x^2 + 1", normalizeKaTeXSource(inline + "x^2 + 1" + inline))
        assertEquals("E=mc^2", normalizeKaTeXSource("\\[ E=mc^2 \\]"))
        assertEquals("a+b", normalizeKaTeXSource("\\( a+b \\)"))
    }

    @Test
    fun leavesUnwrappedAndUnmatchedSourceReadable() {
        assertEquals("x^2 + 1", normalizeKaTeXSource(" x^2 + 1 "))
        assertEquals(display + "unfinished", normalizeKaTeXSource(display + "unfinished"))
        assertEquals("\\frac{1}{2}", normalizeKaTeXSource("\\frac{1}{2}"))
    }
}
