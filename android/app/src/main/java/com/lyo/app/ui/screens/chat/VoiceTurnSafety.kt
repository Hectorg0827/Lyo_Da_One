package com.lyo.app.ui.screens.chat

/**
 * Conservative speech barge-in policy.
 *
 * The Android speech service also hears the device speaker. An unrelated
 * one-off partial (or even an unrelated final result) is not proof that the
 * learner interrupted. During playback a candidate must be stable across
 * two non-echo partial hypotheses before the assistant yields the floor.
 */
internal object VoiceTurnSafety {
    private fun normalized(value: String): String = value.lowercase()
        .replace(Regex("[^\\p{L}\\p{N}\\s]"), " ")
        .replace(Regex("\\s+"), " ")
        .trim()

    fun isLikelyEcho(heard: String, spoken: String): Boolean {
        val a = normalized(heard)
        val b = normalized(spoken)
        if (a.isBlank() || b.isBlank()) return false
        if (a.length >= 12 && b.contains(a)) return true
        if (b.length >= 12 && a.contains(b)) return true
        val aWords = a.split(" ").filter { it.isNotBlank() }.toSet()
        val bWords = b.split(" ").filter { it.isNotBlank() }.toSet()
        val overlap = aWords.intersect(bWords).size
        return overlap.toFloat() / maxOf(1, minOf(aWords.size, bWords.size)).toFloat() >= 0.82f
    }

    fun confirmationCount(previous: String, count: Int, partial: String): Int {
        val current = partial.trim()
        if (current.length < 9 || current.split(Regex("\\s+")).size < 2) return 0
        return if (previous.isNotBlank() && (
            current.startsWith(previous, ignoreCase = true) ||
                previous.startsWith(current, ignoreCase = true)
        )) count + 1 else 1
    }

    fun shouldSubmitFinal(
        heard: String,
        assistantText: String,
        assistantAudible: Boolean,
        confirmedDuringPlayback: Boolean,
    ): Boolean {
        if (heard.isBlank() || isLikelyEcho(heard, assistantText)) return false
        return !assistantAudible || confirmedDuringPlayback
    }

    /**
     * A brief natural gap between queued spoken thoughts. The caller must not
     * enqueue one after the last clip, so listening resumes without dead air.
     */
    fun pauseAfterSegmentMs(previousSegment: String): Long {
        val end = previousSegment.trim().trimEnd {
            it == '"' || it == '”' || it == ')' || it == '’' || it.code == 39
        }.lastOrNull()
        return when (end) {
            '?', '!' -> 170L
            '.' -> 125L
            ',', ';', ':' -> 80L
            else -> 0L
        }
    }
}
