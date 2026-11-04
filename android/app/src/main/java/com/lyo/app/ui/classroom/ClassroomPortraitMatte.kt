package com.lyo.app.ui.classroom

/**
 * The original teacher PNGs are RGB images with a *baked-in checkerboard*,
 * not alpha-transparent artwork. Key out only connected light neutral pixels
 * from the outer border. This leaves white eyes and interior highlights
 * untouched while removing both the white and pale gray squares.
 *
 * Pure Kotlin for JVM regression testing; one pass per cached portrait.
 */
internal fun removeConnectedLightBackdrop(source: IntArray, width: Int, height: Int): IntArray {
    require(width > 0 && height > 0 && source.size == width * height)
    val pixels = source.copyOf()
    val visited = BooleanArray(pixels.size)
    val fringe = BooleanArray(pixels.size)
    val queue = IntArray(pixels.size)
    var end = 0
    var head = 0

    fun backgroundCandidate(pixel: Int): Boolean {
        val r = (pixel ushr 16) and 255
        val g = (pixel ushr 8) and 255
        val b = pixel and 255
        val low = minOf(r, g, b)
        val high = maxOf(r, g, b)
        return low >= 198 && high - low <= 34
    }

    fun enqueue(index: Int) {
        if (visited[index] || !backgroundCandidate(pixels[index])) return
        visited[index] = true
        queue[end++] = index
    }

    for (x in 0 until width) {
        enqueue(x)
        enqueue((height - 1) * width + x)
    }
    for (y in 0 until height) {
        enqueue(y * width)
        enqueue(y * width + width - 1)
    }

    while (head < end) {
        val i = queue[head++]
        val x = i % width
        val y = i / width
        if (x > 0) enqueue(i - 1)
        if (x < width - 1) enqueue(i + 1)
        if (y > 0) enqueue(i - width)
        if (y < height - 1) enqueue(i + width)
    }

    // Strip both alternating checkerboard tones. An edge-connected mask
    // deliberately cannot reach the whites of the teacher's eyes.
    for (i in 0 until end) {
        val p = queue[i]
        pixels[p] = pixels[p] and 0x00ffffff
        val x = p % width
        val y = p / width
        if (x > 0) fringe[p - 1] = true
        if (x + 1 < width) fringe[p + 1] = true
        if (y > 0) fringe[p - width] = true
        if (y + 1 < height) fringe[p + width] = true
    }

    // Reduce residual light-neutral anti-aliased fringe at the mascot edge.
    for (i in pixels.indices) {
        if (!fringe[i] || visited[i]) continue
        val pixel = pixels[i]
        val r = (pixel ushr 16) and 255
        val g = (pixel ushr 8) and 255
        val b = pixel and 255
        val low = minOf(r, g, b)
        val high = maxOf(r, g, b)
        if (low >= 170 && high - low < 55) {
            val alpha = ((pixel ushr 24) and 255) * (215 - low).coerceIn(0, 45) / 45
            pixels[i] = (alpha shl 24) or (pixel and 0x00ffffff)
        }
    }
    return pixels
}
