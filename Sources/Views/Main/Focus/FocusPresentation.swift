import Foundation

// MARK: - Focus presentation rules
//
// What the Focus tab is allowed to say about a learner's saved courses.
//
// Pure functions, no view and no network, for the same reason
// `TestPrepPresentation` exists one folder over: these are the decisions that
// decide whether the screen reports something nothing measured, and a decision
// buried in a SwiftUI body cannot be unit-tested, while this can.
//
// The rule underneath all of them is the one the rest of the app already
// keeps: a figure the app does not have is not a zero. `UIStackItem.progress`
// and `lessonCount` are both optional, and a saved course that has never been
// opened is one `nil` away from a course whose progress failed to sync.

/// How far through a course the learner is, or why there is no answer.
enum FocusCourseProgress: Equatable {
    /// Lesson counts are known, so the card can draw one tick per lesson.
    case lessons(total: Int, completed: Int)
    /// Only a 0...1 fraction is known, so the card draws a plain bar.
    case fraction(Double)
    /// Nothing usable to draw. Not zero.
    case unknown
}

/// What the card's primary button does.
///
/// This is a label for an action, not a claim about the learner: `.start` is
/// what the button offers when no progress is recorded, which is not the same
/// as asserting the learner has done nothing.
enum FocusCourseAction: Equatable {
    case start
    case resume
    case review

    var title: String {
        switch self {
        case .start: return "Start"
        case .resume: return "Resume"
        case .review: return "Review"
        }
    }
}

/// What the back of a course card can say about itself.
enum FocusCourseBlurb: Equatable {
    /// A real description, from the course record.
    case description(String)
    /// No description exists; the stack's own subtitle is shown instead.
    case subtitle(String)
    /// Neither. The card says so rather than filling the space.
    case none
}

/// Which generated motif a course's artwork draws.
enum FocusArtMotif: String, Equatable, CaseIterable {
    case lattice   // bonds and rings — chemistry, biology, physical sciences
    case speech    // arcs and a waveform — languages, conversation
    case curve     // a distribution and scatter — statistics, data
    case staff     // staves and noteheads — music
    case grid      // axes and vectors — algebra, calculus, geometry
    case orbit     // concentric paths — everything else
}

enum FocusPresentation {

    // MARK: - Progress

    /// How much of a course is done.
    ///
    /// Lesson counts win when they exist, because one tick per lesson is both
    /// more precise and more useful than a percentage. When the total is known
    /// but the position is not, the answer is `.unknown` rather than
    /// `completed: 0`: the app knows how long the course is, not where the
    /// learner is in it, and drawing an empty track would assert the latter.
    static func progress(for item: UIStackItem) -> FocusCourseProgress {
        if let total = item.lessonCount, total > 0 {
            if let completed = item.completedLessons {
                return .lessons(total: total, completed: clamp(completed, to: total))
            }
            if let fraction = item.progress {
                let completed = Int((clamp(fraction) * Double(total)).rounded())
                return .lessons(total: total, completed: clamp(completed, to: total))
            }
            return .unknown
        }
        if let fraction = item.progress {
            return .fraction(clamp(fraction))
        }
        return .unknown
    }

    /// Whole-course completion as a percentage, when there is one to give.
    ///
    /// Returns nil rather than 0 for a course with no recorded progress, so a
    /// caller cannot accidentally render "0%" for something unmeasured.
    static func percentComplete(for item: UIStackItem) -> Int? {
        switch progress(for: item) {
        case let .lessons(total, completed):
            guard total > 0 else { return nil }
            return Int((Double(completed) / Double(total) * 100).rounded())
        case let .fraction(value):
            return Int((value * 100).rounded())
        case .unknown:
            return nil
        }
    }

    /// Whether the learner has finished this course.
    ///
    /// Requires a figure that actually reaches the end. A missing figure is
    /// not a finished course.
    static func isFinished(_ item: UIStackItem) -> Bool {
        switch progress(for: item) {
        case let .lessons(total, completed): return total > 0 && completed >= total
        case let .fraction(value): return value >= 1
        case .unknown: return false
        }
    }

    /// What the primary button on the card offers.
    static func action(for item: UIStackItem) -> FocusCourseAction {
        if isFinished(item) { return .review }
        switch progress(for: item) {
        case let .lessons(_, completed): return completed > 0 ? .resume : .start
        case let .fraction(value): return value > 0 ? .resume : .start
        case .unknown: return .start
        }
    }

    // MARK: - Filtering

    /// The filters offered above the stack.
    enum Filter: String, Equatable, CaseIterable, Identifiable {
        case all
        case inProgress
        case notStarted
        case finished

        var id: String { rawValue }

        var title: String {
            switch self {
            case .all: return "All"
            case .inProgress: return "In progress"
            case .notStarted: return "Not started"
            case .finished: return "Finished"
            }
        }
    }

    /// Does this course belong under that filter?
    ///
    /// A course whose progress is unknown counts as not started for filtering,
    /// because the alternative is hiding it from every filter but `.all`. The
    /// card itself still declines to draw a figure for it.
    static func matches(_ item: UIStackItem, filter: Filter) -> Bool {
        switch filter {
        case .all:
            return true
        case .finished:
            return isFinished(item)
        case .inProgress:
            return !isFinished(item) && action(for: item) == .resume
        case .notStarted:
            return !isFinished(item) && action(for: item) == .start
        }
    }

    /// Saved courses, newest first, with anything that cannot open removed.
    ///
    /// A card with no course id has nowhere to go when tapped, so it is not a
    /// card. This mirrors what the previous Focus screen already did.
    static func courses(in items: [UIStackItem]) -> [UIStackItem] {
        items
            .filter { $0.type == .course }
            .filter { !(($0.courseId ?? "").trimmingCharacters(in: .whitespacesAndNewlines)).isEmpty }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    // MARK: - The deck

    /// One of the cards stacked behind the top of a collapsed deck.
    ///
    /// The figures are a shared table rather than a formula because iOS, web
    /// and Android all draw this deck, and a table is the only version of
    /// "11 points down, 95% the size" that cannot quietly drift between three
    /// codebases. `FocusPresentationTests` pins them.
    struct DeckLayer: Equatable, Identifiable {
        /// 1 is the card directly behind the top one.
        let depth: Int
        /// Points below the top card's own top edge.
        let offset: Double
        let scale: Double
        let opacity: Double

        var id: Int { depth }
    }

    /// The peek cards behind the top card of a collapsed deck.
    ///
    /// Two at most, however many courses are saved: a third layer costs
    /// pixels and carries no information, and the real number is written on
    /// the control beneath the deck instead. A learner with one saved course
    /// gets no layers, so they never have to open anything.
    static func deckLayers(cardCount: Int) -> [DeckLayer] {
        guard cardCount > 1 else { return [] }
        let peek = min(cardCount - 1, deckPeekLimit)
        return (1...peek).map { depth in
            DeckLayer(
                depth: depth,
                offset: deckOffsets[depth - 1],
                scale: deckScales[depth - 1],
                opacity: deckOpacities[depth - 1]
            )
        }
    }

    /// What the control under a collapsed deck says.
    ///
    /// It counts the courses the deck is really holding back — the list's own
    /// length, less the card already on top — and not the peek cards drawn,
    /// which stop at two. A deck that drew two layers over twelve courses and
    /// said "2 more" would be understating the learner's own library.
    static func deckMoreLabel(cardCount: Int) -> String? {
        guard cardCount > 1 else { return nil }
        let hidden = cardCount - 1
        return hidden == 1 ? "1 more course" : "\(hidden) more courses"
    }

    /// How long the card at `index` waits before it slides into place, in ms.
    ///
    /// Whole milliseconds rather than fractional seconds, so three languages'
    /// floating point cannot disagree about the timing. Capped, so a learner
    /// with forty saved courses is not watching cards arrive for a second and
    /// a half.
    static func deckStaggerMilliseconds(index: Int) -> Int {
        guard index > 0 else { return 0 }
        return deckStaggerStep * min(index, deckStaggerLimit)
    }

    /// How much of the next card shows past the right edge of the current one.
    ///
    /// An opened deck scrolls sideways, and a card the full width of the
    /// screen would put every course after the first behind a swipe nothing
    /// signals — which is the exact thing this screen was rebuilt to stop
    /// doing. So each card gives up this much room and the next one's edge
    /// stays visible.
    static let deckNextCardPeek: Double = 34

    /// The gap between cards in an opened deck.
    static let deckCardGap: Double = 12

    /// How wide one card is, in an opened deck inside a container this wide.
    ///
    /// The next card starts one gap later, so exactly `deckNextCardPeek` of
    /// it is showing. Zero for a container too narrow to hold a card and the
    /// peek both, because a negative width is not a card.
    static func deckCardWidth(containerWidth: Double) -> Double {
        guard containerWidth > 0 else { return 0 }
        return max(containerWidth - deckNextCardPeek - deckCardGap, 0)
    }

    /// Peek cards drawn behind the top one, at most.
    static let deckPeekLimit = 2

    private static let deckOffsets: [Double] = [11, 20]
    private static let deckScales: [Double] = [0.95, 0.9]
    private static let deckOpacities: [Double] = [0.72, 0.46]
    private static let deckStaggerStep = 35
    private static let deckStaggerLimit = 8

    // MARK: - The back of the card

    /// What the back of a course card says about the course.
    ///
    /// `UIStackItem.courseDescription` is populated from the backend stack
    /// item, which is the only real description the app receives: a course
    /// generated in chat carries `objectives`, not prose. So the fallback
    /// stands — the subtitle the stack does carry, usually the lesson the
    /// learner stopped on — and when there is neither, the card says so.
    /// Nothing here writes prose on the course's behalf.
    static func blurb(for item: UIStackItem) -> FocusCourseBlurb {
        if let text = trimmed(item.courseDescription) {
            return .description(text)
        }
        if let subtitle = trimmed(item.subtitle) {
            return .subtitle(subtitle)
        }
        return .none
    }

    // MARK: - Weak concepts

    /// Concepts worth a focused review, for the chips on the create card.
    ///
    /// Drawn from the learner's recorded struggles, the same source
    /// `CourseGenerationService.generateSmartReview` already builds review
    /// courses from — so a chip offers a course the app can actually produce.
    /// Resolved struggles are dropped, the most frequent come first, and
    /// duplicates that differ only in case collapse.
    static func weakConcepts(_ struggles: [StruggleItem], limit: Int = 3) -> [String] {
        var seen = Set<String>()
        var out: [String] = []

        let ordered = struggles
            .filter { !$0.resolved }
            .map { ($0, $0.topic.trimmingCharacters(in: .whitespacesAndNewlines)) }
            .filter { !$0.1.isEmpty }
            .sorted { left, right in
                if left.0.frequency != right.0.frequency { return left.0.frequency > right.0.frequency }
                return left.0.firstOccurred > right.0.firstOccurred
            }

        for (_, topic) in ordered {
            let key = topic.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            out.append(topic)
            if out.count == limit { break }
        }
        return out
    }

    // MARK: - Artwork

    /// Which motif a course's generated artwork draws.
    ///
    /// Subject keywords first, so organic chemistry really does get bonds and
    /// Spanish really does get speech arcs, then a deterministic fall-back so
    /// two courses rarely look alike and one course never changes its art.
    static func motif(forTitle title: String) -> FocusArtMotif {
        let text = title.lowercased()

        for (motif, keywords) in keywordTable {
            if keywords.contains(where: { text.contains($0) }) { return motif }
        }

        let pool = FocusArtMotif.allCases
        let index = Int(stableHash(text.isEmpty ? "lyo" : text) % UInt64(pool.count))
        return pool[index]
    }

    /// Ordered so a title matching more than one table wins the earlier entry.
    private static let keywordTable: [(FocusArtMotif, [String])] = [
        (.lattice, ["chem", "molecul", "organic", "biolog", "reaction", "atom", "physics", "protein", "cell"]),
        (.speech, ["spanish", "french", "german", "italian", "portuguese", "mandarin", "japanese", "korean",
                   "arabic", "language", "conversation", "grammar", "vocabular", "speaking", "english"]),
        (.curve, ["statistic", "probabilit", "data", "regression", "analytic", "distribution", "machine learning"]),
        (.staff, ["music", "piano", "guitar", "harmony", "rhythm", "composition", "singing", "chord"]),
        (.grid, ["algebra", "calculus", "geometry", "math", "matrix", "vector", "trigonometr", "arithmetic",
                 "series", "equation"])
    ]

    /// A hash that is the same on every launch.
    ///
    /// Swift's own `hashValue` is seeded per process, so using it here would
    /// repaint a course's artwork every time the app restarted. FNV-1a is
    /// stable, which is the only property this needs.
    static func stableHash(_ string: String) -> UInt64 {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        return hash
    }

    // MARK: -

    private static func trimmed(_ text: String?) -> String? {
        guard let value = text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else {
            return nil
        }
        return value
    }

    private static func clamp(_ value: Double) -> Double { min(max(value, 0), 1) }

    private static func clamp(_ value: Int, to total: Int) -> Int { min(max(value, 0), total) }
}
