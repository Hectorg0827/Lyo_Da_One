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
 * `libraryTotal` is the same idea one level up. The clips endpoint is paged,
 * so a creator with 120 clips is handed 50 and the sum over them is not their
 * total — it is the total of one page, and without this it would be labelled
 * complete.
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

    /**
     * Every total across the clips that arrived, measured against the library.
     *
     * [libraryTotal] is how many clips the creator has, which is not how many
     * arrived: the endpoint is paged. When it is larger than the page, the
     * totals are over the page and say so. When it is missing or smaller, the
     * page is all there is.
     */
    fun totals(clips: List<ClipDto>, libraryTotal: Int? = null): Map<Metric, Total> =
        Metric.entries.associateWith { total(it, clips, libraryTotal) }

    fun total(metric: Metric, clips: List<ClipDto>, libraryTotal: Int? = null): Total {
        var value = 0
        var reporting = 0
        for (clip in clips) {
            val count = countOf(metric, clip) ?: continue
            value += count
            reporting += 1
        }
        val library = maxOf(libraryTotal ?: clips.size, clips.size)
        return Total(metric = metric, value = value, reporting = reporting, clips = library)
    }

    /** A count on one clip, or null when the clip did not report it. */
    private fun countOf(metric: Metric, clip: ClipDto): Int? = when (metric) {
        Metric.Views -> clip.viewCount
        Metric.Likes -> clip.likeCount
        Metric.Comments -> clip.commentCount
        Metric.Shares -> clip.shareCount
    }
}
