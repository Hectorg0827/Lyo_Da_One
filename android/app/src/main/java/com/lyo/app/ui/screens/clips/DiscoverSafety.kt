package com.lyo.app.ui.screens.clips

/**
 * Reporting a Discover video and blocking the person who posted it.
 *
 * Mirrors web `discover-report.mjs` and iOS `DiscoverSafety.swift`;
 * `scripts/verify-discover-safety-parity.mjs` holds the three to the same
 * reasons, labels and messages. A reported video leaves the reporter's feed
 * at once, and three reports from different learners hide it until a
 * moderator decides. A block (POST /api/v1/community/blocks) hides both
 * people from each other in Discover.
 */
object DiscoverSafety {

    /** A reason the API stores (POST /api/v1/clips/{id}/report), with its label. */
    data class Reason(val value: String, val label: String)

    val REPORT_REASONS = listOf(
        Reason("sexual_content", "Sexual or inappropriate"),
        Reason("violence", "Violent or dangerous"),
        Reason("harassment", "Hate or bullying"),
        Reason("spam", "Spam or misleading"),
        Reason("misinformation", "Wrong or false science"),
        Reason("copyright", "Copyright"),
        Reason("other", "Something else"),
    )

    /** The longest note the API accepts with a report. */
    const val NOTE_LIMIT = 1000

    /**
     * What a finished report or block came to. For a report, [succeeded]
     * means the video leaves the feed; for a block, the person is blocked.
     */
    data class Outcome(val succeeded: Boolean, val message: String)

    /** A learner cannot report their own video; with either id unknown the server decides. */
    fun canReport(ownerId: String?, viewerId: String?): Boolean {
        if (ownerId.isNullOrBlank() || viewerId.isNullOrBlank()) return true
        return ownerId != viewerId
    }

    /**
     * Blocking needs an owner who is someone else; with either id unknown it
     * is not offered. Library videos are uploaded by Lyo's own account and
     * credited to their source, so blocking that account would empty the
     * library: it is not offered there either.
     */
    fun canBlock(ownerId: String?, viewerId: String?, isLibrary: Boolean): Boolean {
        if (isLibrary || ownerId.isNullOrBlank() || viewerId.isNullOrBlank()) return false
        return ownerId != viewerId
    }

    /**
     * Reported (201) and already reported (200) take the video out of the
     * feed, as does 404: it is gone or already hidden. Anything else is a
     * failure the learner can retry, and the video stays.
     */
    fun reportOutcome(status: Int): Outcome = when (status) {
        200, 201 -> Outcome(true, "Thanks. We'll review this video.")
        404 -> Outcome(true, "This video is no longer available.")
        else -> Outcome(false, "Your report couldn't be sent. Please try again.")
    }

    /** Blocked (201) removes every video by that person; 404 means the account is gone. */
    fun blockOutcome(status: Int, name: String): Outcome = when (status) {
        200, 201 -> Outcome(true, "Blocked $name. You won't see each other's videos or comments.")
        404 -> Outcome(false, "This account no longer exists.")
        else -> Outcome(false, "Couldn't block this account. Please try again.")
    }

    /**
     * The pages to request for feed page [page] after [removed] loaded videos
     * left the feed by a report or a block. The server stops sending them, so
     * every later page starts that many places earlier; asking for the page
     * before too, and skipping duplicates, keeps none from being skipped.
     */
    fun pagesToFetch(page: Int, removed: Int, perPage: Int): List<Int> {
        val back = (maxOf(0, removed) + perPage - 1) / perPage
        val first = maxOf(1, page - back)
        return (first..maxOf(first, page)).toList()
    }
}
