package com.lyo.app.ui.screens.clips

import com.lyo.app.data.api.ClipDto

/**
 * What a creator's clips add up to.
 *
 * People need to see their numbers moving before they will believe there is
 * anything to build here, so this is the scoreboard — which makes it exactly
 * the place where a number must not be invented. A creator deciding whether
 * this is worth their time is the last person who should be shown a figure
 * the server never sent.
 *
 * Every count on [ClipDto] is nullable: views, likes, comments and shares all
 * arrive null when the backend has nothing to say. Summing them as zero would
 * silently understate a creator's reach and look exactly like a real total,
 * so each total carries how many clips actually reported it.
 *
 * Mirrors iOS `CreatorStats` and web `creator-stats.mjs`.
 */
object CreatorStats {

    /** The metrics a clip can report, in the order they are shown. */
    enum class Metric(val label: String) {
        Views("Views"),
        Likes("Likes"),
        Comments("Comments"),
        Shares("Shares"),
    }

    /**
     * One total across a creator's clips.
     *
     * [reporting] is the honest part: [value] is the sum of what was
     * reported, and [reporting] says how much of the library that covers.
     */
    data class Total(
        val metric: Metric,
        val value: Int,
        val reporting: Int,
        val clips: Int,
    ) {
        /**
         * Whether this total has anything behind it at all.
         *
         * False means no clip reported the figure. The surface shows that as
         * "Not reported" rather than 0, because a creator whose views are not
         * being counted needs to know that, not be told nobody watched.
         */
        val isReported: Boolean get() = reporting > 0

        /** Whether every clip reported this figure. */
        val isComplete: Boolean get() = clips > 0 && reporting == clips

        /** The qualifier shown under a partial total, or null when none. */
        val coverageNote: String?
            get() = if (!isReported || isComplete) null else "from $reporting of $clips clips"
    }

    /** Every total, plus the clip count — which is always known. */
    fun totals(clips: List<ClipDto>): Map<Metric, Total> =
        Metric.entries.associateWith { total(it, clips) }

    fun total(metric: Metric, clips: List<ClipDto>): Total {
        var value = 0
        var reporting = 0
        for (clip in clips) {
            val count = countOf(metric, clip) ?: continue
            value += count
            reporting += 1
        }
        return Total(metric = metric, value = value, reporting = reporting, clips = clips.size)
    }

    /** A count on one clip, or null when the clip did not report it. */
    private fun countOf(metric: Metric, clip: ClipDto): Int? = when (metric) {
        Metric.Views -> clip.viewCount
        Metric.Likes -> clip.likeCount
        Metric.Comments -> clip.commentCount
        Metric.Shares -> clip.shareCount
    }
}
