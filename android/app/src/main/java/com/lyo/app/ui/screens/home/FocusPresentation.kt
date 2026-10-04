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

    // MARK: - The deck

    /**
     * One of the cards stacked behind the top of a collapsed deck.
     *
     * The figures are a shared table rather than a formula because iOS, web
     * and Android all draw this deck, and a table is the only version of
     * "11dp down, 95% the size" that cannot quietly drift between three
     * codebases. [FocusPresentationTest] pins them, as do the Swift and
     * JavaScript suites.
     */
    data class DeckLayer(
        /** 1 is the card directly behind the top one. */
        val depth: Int,
        /** Density-independent pixels below the top card's own top edge. */
        val offset: Float,
        val scale: Float,
        val opacity: Float,
    )

    /**
     * Whether a deck of this many cards has anything to open.
     *
     * One card is not a deck. The screen has to ask this on every
     * composition, not once: a filter can narrow an open deck down to a
     * single course, and a deck left open over one card is a lone narrowed
     * card in a LazyRow with no control to close it.
     */
    fun deckCanOpen(cardCount: Int): Boolean = cardCount > 1

    /** Peek cards drawn behind the top one, at most. */
    const val DECK_PEEK_LIMIT = 2

    /**
     * How much of the next card shows past the right edge of the current one.
     *
     * An opened deck scrolls sideways, and a card the full width of the
     * screen would put every course after the first behind a swipe nothing
     * signals — the exact thing this screen was rebuilt to stop doing. So
     * each card gives up this much room and the next one's edge stays
     * visible.
     */
    const val DECK_NEXT_CARD_PEEK = 34f

    /** The gap between cards in an opened deck. */
    const val DECK_CARD_GAP = 12f

    /**
     * How wide one card is, in an opened deck inside a container this wide.
     *
     * The next card starts one gap later, so exactly [DECK_NEXT_CARD_PEEK] of
     * it is showing. Zero for a container too narrow to hold a card and the
     * peek both, because a negative width is not a card.
     */
    fun deckCardWidth(containerWidth: Float): Float {
        if (containerWidth <= 0f) return 0f
        return maxOf(containerWidth - DECK_NEXT_CARD_PEEK - DECK_CARD_GAP, 0f)
    }

    private val DECK_OFFSETS = listOf(11f, 20f)
    private val DECK_SCALES = listOf(0.95f, 0.9f)
    private val DECK_OPACITIES = listOf(0.72f, 0.46f)
    private const val DECK_STAGGER_STEP = 35
    private const val DECK_STAGGER_LIMIT = 8

    /**
     * The peek cards behind the top card of a collapsed deck.
     *
     * Two at most, however many courses are saved: a third layer costs pixels
     * and carries no information, and the real number is written on the
     * control beneath the deck instead. A learner with one saved course gets
     * no layers, so they never have to open anything to reach it.
     */
    fun deckLayers(cardCount: Int): List<DeckLayer> {
        if (cardCount <= 1) return emptyList()
        val peek = minOf(cardCount - 1, DECK_PEEK_LIMIT)
        return (1..peek).map { depth ->
            DeckLayer(
                depth = depth,
                offset = DECK_OFFSETS[depth - 1],
                scale = DECK_SCALES[depth - 1],
                opacity = DECK_OPACITIES[depth - 1],
            )
        }
    }

    /**
     * What the control under a collapsed deck says.
     *
     * It counts the courses the deck is really holding back — the list's own
     * length, less the card already on top — and not the peek cards drawn,
     * which stop at two. A deck that drew two layers over twelve courses and
     * said "2 more" would be understating the learner's own library. Null
     * when nothing is hidden.
     */
    fun deckMoreLabel(cardCount: Int): String? {
        if (cardCount <= 1) return null
        val hidden = cardCount - 1
        return if (hidden == 1) "1 more course" else "$hidden more courses"
    }

    /**
     * How long the card at [index] waits before it slides into place, in ms.
     *
     * Whole milliseconds rather than fractional seconds, so three languages'
     * floating point cannot disagree about the timing. Capped, so a learner
     * with forty saved courses is not watching cards arrive for a second and
     * a half.
     */
    fun deckStaggerMilliseconds(index: Int): Int {
        if (index <= 0) return 0
        return DECK_STAGGER_STEP * minOf(index, DECK_STAGGER_LIMIT)
    }

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
