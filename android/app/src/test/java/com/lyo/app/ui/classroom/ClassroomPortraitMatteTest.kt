package com.lyo.app.ui.classroom

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class ClassroomPortraitMatteTest {
    @Test fun removesAlternatingLightGrayAndWhiteBackground() {
        val white = 0xffffffff.toInt()
        val gray = 0xffdedede.toInt()
        val orange = 0xffff9d22.toInt()
        val width = 7
        val height = 7
        val pixels = IntArray(width * height) { i -> if (((i % width) + i / width) % 2 == 0) white else gray }
        for (y in 2..4) for (x in 2..4) pixels[y * width + x] = orange
        pixels[3 * width + 3] = white  // enclosed eye highlight
        val processed = removeConnectedLightBackdrop(pixels, width, height)
        assertEquals(0, processed[0] ushr 24)
        assertEquals(0, processed[1] ushr 24)
        assertEquals(0, processed[width] ushr 24)
        assertEquals(255, processed[2 * width + 2] ushr 24)
        assertEquals(255, processed[3 * width + 3] ushr 24)
    }

    @Test fun leavesColorfulEdgeAndDarkFeaturesUntouched() {
        val pixels = intArrayOf(
            0xffffffff.toInt(), 0xffededed.toInt(), 0xffffffff.toInt(),
            0xffeeeeee.toInt(), 0xff993300.toInt(), 0xffeeeeee.toInt(),
            0xffffffff.toInt(), 0xffeeeeee.toInt(), 0xffffffff.toInt(),
        )
        val actual = removeConnectedLightBackdrop(pixels, 3, 3)
        assertEquals(255, actual[4] ushr 24)
        assertTrue(actual.indices.filter { it != 4 }.all { actual[it] ushr 24 == 0 })
    }
}
