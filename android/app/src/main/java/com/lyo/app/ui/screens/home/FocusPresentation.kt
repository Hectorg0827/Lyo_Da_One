package com.lyo.app.ui.screens.home

import com.lyo.app.data.api.StackItemDto

/**
 * What Home is allowed to say about a learner's saved courses.
 *
 * Pure functions, no Compose and no network, for the same reason iOS keeps
 * `FocusPresentation.swift` and web keeps `focus-presentation.mjs`: these are
 * the decisions that decide whether the screen reports something nothing
 * measured, and a decision buried in a composable cannot be unit-tested,
 * while this can.
 *
 * The rule underneath all of them: a figure the app does not have is not a
 * zero, and an action label is not a measurement.
 */
object FocusPresentation {

    /** How far through a course the learner is, or why there is no answer. */
    sealed interface Progress {
        /** A real figure, 0..100, rounded for display only. */
        data class Measured(val percent: Int) : Progress

        /** Nothing usable to draw. Not zero. */
        data object Unknown : Progress
    }

    /**
     * What the card's primary button offers.
     *
     * A label for an action, not a claim about the learner: [Start] is what
     * the button says when no progress is recorded, which is not the same as
     * asserting the learner has done nothing.
     */
    enum class Action(val label: String) {
        Start("Start"),
        Resume("Resume"),
        Review("Review"),
    }

    /** What the back of a course card says about the course. */
    sealed interface Blurb {
        /** The description the backend sends with the stack item. */
        data class Description(val text: String) : Blurb

        /** No description; where the course stands is said instead. */
        data class Status(val text: String) : Blurb

        /** Neither. The card says so rather than filling the space. */
        data object None : Blurb
    }

    enum class Filter(val label: String) {
        All("All"),
        InProgress("In progress"),
        NotStarted("Not started"),
        Finished("Finished"),
    }

    /** The motifs a course's generated artwork can draw. Same order as iOS. */
    enum class Motif { Lattice, Speech, Curve, Staff, Grid, Orbit }

    // MARK: - Progress

    /**
     * The server sends `progress` as a 0..1 fraction. A value that is not
     * finite is unknown rather than zero: the screen must not draw an empty
     * bar and thereby assert the learner is at the start of a course whose
     * progress simply failed to arrive.
     */
    fun progressFor(item: StackItemDto): Progress {
        val raw = item.progress
        if (raw.isNaN() || raw.isInfinite()) return Progress.Unknown
        return Progress.Measured((raw.coerceIn(0f, 1f) * 100).toInt())
    }

    /** The percentage, or null when there is none. Never 0 as a stand-in. */
    fun percentFor(item: StackItemDto): Int? =
        (progressFor(item) as? Progress.Measured)?.percent

    /**
     * Has the learner finished this course?
     *
     * `status` is the server's own word, derived server-side from the same
     * progress figure (see `UpdateStackItemRequest`'s note), so it is
     * preferred over re-deriving the answer here.
     */
    fun isFinished(item: StackItemDto): Boolean {
        if (item.status == "completed") return true
        val progress = progressFor(item)
        return progress is Progress.Measured && progress.percent >= 100
    }

    fun actionFor(item: StackItemDto): Action {
        if (isFinished(item)) return Action.Review
        if (item.status == "in_progress" || item.status == "paused") return Action.Resume
        if (item.status == "not_started") return Action.Start
        val progress = progressFor(item)
        return if (progress is Progress.Measured && progress.percent > 0) Action.Resume else Action.Start
    }

    // MARK: - The back of the card

    /**
     * `description` comes straight from the stack item the backend already
     * sends and this screen previously dropped. When there is none, the card
     * says where the course stands rather than being given prose nothing
     * wrote.
     */
    fun blurbFor(item: StackItemDto): Blurb {
        val description = item.description?.trim()
        if (!description.isNullOrEmpty()) return Blurb.Description(description)
        val status = statusLabel(item.status)
        return if (status != null) Blurb.Status(status) else Blurb.None
    }

    fun statusLabel(status: String?): String? = when (status) {
        "not_started" -> "Saved — not started yet"
        "in_progress" -> "In progress"
        "paused" -> "Paused"
        "completed" -> "Finished"
        else -> null
    }

    // MARK: - Filtering

    fun matches(item: StackItemDto, filter: Filter): Boolean = when (filter) {
        Filter.All -> true
        Filter.Finished -> isFinished(item)
        Filter.InProgress -> !isFinished(item) && actionFor(item) == Action.Resume
        Filter.NotStarted -> !isFinished(item) && actionFor(item) == Action.Start
    }

    fun countFor(items: List<StackItemDto>, filter: Filter): Int =
        items.count { matches(it, filter) }

    // MARK: - Artwork

    /**
     * Which generated motif a course's artwork draws.
     *
     * Subject keywords first, so organic chemistry really does get bonds and
     * Spanish really does get speech arcs, then a deterministic fall-back so
     * two courses rarely look alike and one course never changes its art.
     * Identical to iOS `FocusPresentation.motif(forTitle:)` and web
     * `focus-presentation.mjs`, so the same course is drawn the same way on
     * all three platforms.
     */
    fun motifFor(title: String): Motif {
        val text = title.lowercase()
        for ((motif, keywords) in KEYWORD_TABLE) {
            if (keywords.any { text.contains(it) }) return motif
        }
        val seed = text.ifEmpty { "lyo" }
        val motifs = Motif.entries
        return motifs[(stableHash(seed) % motifs.size.toULong()).toInt()]
    }

    /** Ordered so a title matching more than one table wins the earlier entry. */
    private val KEYWORD_TABLE: List<Pair<Motif, List<String>>> = listOf(
        Motif.Lattice to listOf(
            "chem", "molecul", "organic", "biolog", "reaction", "atom", "physics", "protein", "cell",
        ),
        Motif.Speech to listOf(
            "spanish", "french", "german", "italian", "portuguese", "mandarin", "japanese", "korean",
            "arabic", "language", "conversation", "grammar", "vocabular", "speaking", "english",
        ),
        Motif.Curve to listOf(
            "statistic", "probabilit", "data", "regression", "analytic", "distribution", "machine learning",
        ),
        Motif.Staff to listOf(
            "music", "piano", "guitar", "harmony", "rhythm", "composition", "singing", "chord",
        ),
        Motif.Grid to listOf(
            "algebra", "calculus", "geometry", "math", "matrix", "vector", "trigonometr", "arithmetic",
            "series", "equation",
        ),
    )

    /**
     * FNV-1a over the lowercased title.
     *
     * A course's artwork must not change between launches, which rules out
     * `hashCode()` on anything whose hash is not specified to be stable. iOS
     * and web run the same algorithm over the same bytes, so all three land
     * on the same motif.
     */
    fun stableHash(text: String): ULong {
        var hash = 0xcbf29ce484222325UL
        for (byte in text.toByteArray(Charsets.UTF_8)) {
            hash = hash xor byte.toUByte().toULong()
            hash *= 0x100000001b3UL
        }
        return hash
    }
}
