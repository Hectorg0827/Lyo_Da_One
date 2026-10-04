import XCTest
@testable import Lyo

// The decisions the Focus tab makes about a learner's saved courses, driven
// directly rather than through a SwiftUI body — for the same reason
// `TestPrepPresentationTests` exists next door. Nobody in this workstream can
// tap through the iOS build, so a test reaching the decision is the only
// verification this logic gets.
//
// The rule being defended throughout: a figure the app does not have is not a
// zero, and an action label is not a measurement.

private func course(
    title: String = "A course",
    subtitle: String? = nil,
    courseDescription: String? = nil,
    progress: Double? = nil,
    lessonCount: Int? = nil,
    completedLessons: Int? = nil,
    updatedAt: Date = Date()
) -> UIStackItem {
    UIStackItem(
        type: .course,
        title: title,
        subtitle: subtitle,
        courseDescription: courseDescription,
        updatedAt: updatedAt,
        progress: progress,
        courseId: "course-1",
        lessonCount: lessonCount,
        completedLessons: completedLessons
    )
}

final class FocusProgressTests: XCTestCase {

    func testLessonCountsWinWhenBothAreKnown() {
        let item = course(progress: 0.5, lessonCount: 18, completedLessons: 11)
        XCTAssertEqual(FocusPresentation.progress(for: item), .lessons(total: 18, completed: 11))
    }

    func testCompletedLessonsAreDerivedFromTheFractionWhenAbsent() {
        let item = course(progress: 0.5, lessonCount: 18)
        XCTAssertEqual(FocusPresentation.progress(for: item), .lessons(total: 18, completed: 9))
    }

    /// The whole point of the type. A known total with an unknown position is
    /// not a course the learner has not started — it is a course the app has
    /// not synced, and an empty track would assert the former.
    func testKnownTotalWithNoPositionIsUnknownRatherThanZero() {
        let item = course(lessonCount: 18)
        XCTAssertEqual(FocusPresentation.progress(for: item), .unknown)
        XCTAssertNil(FocusPresentation.percentComplete(for: item))
    }

    func testNoFiguresAtAllIsUnknown() {
        XCTAssertEqual(FocusPresentation.progress(for: course()), .unknown)
        XCTAssertNil(FocusPresentation.percentComplete(for: course()))
    }

    func testFractionIsUsedWhenNoLessonCountExists() {
        XCTAssertEqual(FocusPresentation.progress(for: course(progress: 0.34)), .fraction(0.34))
        XCTAssertEqual(FocusPresentation.percentComplete(for: course(progress: 0.34)), 34)
    }

    func testOutOfRangeFiguresAreClamped() {
        XCTAssertEqual(FocusPresentation.progress(for: course(progress: 1.8)), .fraction(1))
        XCTAssertEqual(FocusPresentation.progress(for: course(progress: -0.4)), .fraction(0))
        XCTAssertEqual(
            FocusPresentation.progress(for: course(lessonCount: 10, completedLessons: 44)),
            .lessons(total: 10, completed: 10)
        )
    }

    func testCompletionRequiresAFigureThatReachesTheEnd() {
        XCTAssertTrue(FocusPresentation.isFinished(course(progress: 1)))
        XCTAssertTrue(FocusPresentation.isFinished(course(lessonCount: 9, completedLessons: 9)))
        XCTAssertFalse(FocusPresentation.isFinished(course(progress: 0.99)))
        // Unknown is not finished, however tempting a default would be.
        XCTAssertFalse(FocusPresentation.isFinished(course()))
    }
}

final class FocusActionTests: XCTestCase {

    func testActionReflectsWhereTheLearnerIs() {
        XCTAssertEqual(FocusPresentation.action(for: course(progress: 0.4)), .resume)
        XCTAssertEqual(FocusPresentation.action(for: course(progress: 0)), .start)
        XCTAssertEqual(FocusPresentation.action(for: course(progress: 1)), .review)
        XCTAssertEqual(
            FocusPresentation.action(for: course(lessonCount: 12, completedLessons: 3)),
            .resume
        )
    }

    /// `.start` on an unmeasured course is a label for a button, not a claim
    /// that the learner has done nothing — which is why the card still draws
    /// no progress figure for it.
    func testUnknownProgressOffersStartWithoutAssertingZero() {
        let item = course()
        XCTAssertEqual(FocusPresentation.action(for: item), .start)
        XCTAssertEqual(FocusPresentation.progress(for: item), .unknown)
    }

    func testTitles() {
        XCTAssertEqual(FocusCourseAction.start.title, "Start")
        XCTAssertEqual(FocusCourseAction.resume.title, "Resume")
        XCTAssertEqual(FocusCourseAction.review.title, "Review")
    }
}

final class FocusFilterTests: XCTestCase {

    func testEachFilterCatchesWhatItSays() {
        let started = course(progress: 0.5)
        let fresh = course(progress: 0)
        let done = course(progress: 1)

        XCTAssertTrue(FocusPresentation.matches(started, filter: .inProgress))
        XCTAssertFalse(FocusPresentation.matches(started, filter: .notStarted))
        XCTAssertFalse(FocusPresentation.matches(started, filter: .finished))

        XCTAssertTrue(FocusPresentation.matches(fresh, filter: .notStarted))
        XCTAssertTrue(FocusPresentation.matches(done, filter: .finished))
        XCTAssertFalse(FocusPresentation.matches(done, filter: .inProgress))

        for item in [started, fresh, done] {
            XCTAssertTrue(FocusPresentation.matches(item, filter: .all))
        }
    }

    /// An unmeasured course must still be reachable from a filter, or it is
    /// invisible everywhere except "All".
    func testUnmeasuredCoursesAreReachable() {
        XCTAssertTrue(FocusPresentation.matches(course(), filter: .notStarted))
        XCTAssertTrue(FocusPresentation.matches(course(), filter: .all))
    }

    func testCoursesAreNewestFirstAndMustBeAbleToOpen() {
        let now = Date()
        let old = UIStackItem(
            type: .course, title: "Old", updatedAt: now.addingTimeInterval(-9000), courseId: "a"
        )
        let recent = UIStackItem(
            type: .course, title: "Recent", updatedAt: now, courseId: "b"
        )
        // No course id: tapping it has nowhere to go, so it is not a card.
        let unopenable = UIStackItem(type: .course, title: "Broken", updatedAt: now, courseId: "   ")
        let chat = UIStackItem(type: .chat, title: "A chat", updatedAt: now, courseId: "c")

        let result = FocusPresentation.courses(in: [old, unopenable, chat, recent])
        XCTAssertEqual(result.map(\.title), ["Recent", "Old"])
    }
}

final class FocusBlurbTests: XCTestCase {

    func testTheDescriptionWinsWhenTheCourseHasOne() {
        let item = course(
            subtitle: "Lesson 11",
            courseDescription: "Electron pushing, then synthesis."
        )
        XCTAssertEqual(
            FocusPresentation.blurb(for: item),
            .description("Electron pushing, then synthesis.")
        )
    }

    /// Still the ordinary case for a course generated in chat: those carry
    /// objectives, not prose, so nothing populates the description.
    func testTheSubtitleStandsInWhenNoDescriptionExists() {
        let item = course(subtitle: "Lesson 11 · E1 vs E2")
        XCTAssertEqual(
            FocusPresentation.blurb(for: item),
            .subtitle("Lesson 11 · E1 vs E2")
        )
    }

    func testWhitespaceCountsAsAbsent() {
        let item = course(subtitle: "   ", courseDescription: "\n ")
        XCTAssertEqual(FocusPresentation.blurb(for: item), .none)
    }

    func testNeitherSaysSoRatherThanFillingTheSpace() {
        XCTAssertEqual(FocusPresentation.blurb(for: course()), .none)
    }

    func testADescriptionIsTrimmedBeforeItIsShown() {
        let item = course(courseDescription: "  Vector spaces before matrices.\n")
        XCTAssertEqual(
            FocusPresentation.blurb(for: item),
            .description("Vector spaces before matrices.")
        )
    }
}

final class FocusWeakConceptTests: XCTestCase {

    private func struggle(
        _ topic: String,
        frequency: Int = 1,
        resolved: Bool = false,
        daysAgo: Int = 0
    ) -> StruggleItem {
        StruggleItem(
            id: topic,
            topic: topic,
            firstOccurred: Date().addingTimeInterval(TimeInterval(-86_400 * daysAgo)),
            frequency: frequency,
            resolved: resolved
        )
    }

    func testMostFrequentFirstAndResolvedDropped() {
        let concepts = FocusPresentation.weakConcepts([
            struggle("Titration curves", frequency: 2),
            struggle("Long division", frequency: 9, resolved: true),
            struggle("E2 elimination", frequency: 5),
            struggle("Subjunctive mood", frequency: 3)
        ])
        XCTAssertEqual(concepts, ["E2 elimination", "Subjunctive mood", "Titration curves"])
    }

    func testDuplicatesCollapseIgnoringCase() {
        let concepts = FocusPresentation.weakConcepts([
            struggle("E2 elimination", frequency: 4),
            struggle("e2 ELIMINATION", frequency: 3),
            struggle("Titration", frequency: 2)
        ])
        XCTAssertEqual(concepts, ["E2 elimination", "Titration"])
    }

    func testBlankTopicsAreDroppedAndTheLimitHolds() {
        let concepts = FocusPresentation.weakConcepts([
            struggle("  ", frequency: 9),
            struggle("One", frequency: 5),
            struggle("Two", frequency: 4),
            struggle("Three", frequency: 3),
            struggle("Four", frequency: 2)
        ])
        XCTAssertEqual(concepts, ["One", "Two", "Three"])
    }

    /// Nothing recorded means the row is hidden, not filled with guesses.
    func testNoStrugglesMeansNoChips() {
        XCTAssertTrue(FocusPresentation.weakConcepts([]).isEmpty)
        XCTAssertTrue(FocusPresentation.weakConcepts([struggle("Done", resolved: true)]).isEmpty)
    }
}

final class FocusArtworkTests: XCTestCase {

    func testSubjectKeywordsPickTheMatchingMotif() {
        XCTAssertEqual(FocusPresentation.motif(forTitle: "Organic Chemistry: Reaction Mechanisms"), .lattice)
        XCTAssertEqual(FocusPresentation.motif(forTitle: "Spanish B1 Conversation"), .speech)
        XCTAssertEqual(FocusPresentation.motif(forTitle: "Introduction to Statistics"), .curve)
        XCTAssertEqual(FocusPresentation.motif(forTitle: "Music Theory Basics"), .staff)
        XCTAssertEqual(FocusPresentation.motif(forTitle: "Linear Algebra Done Right"), .grid)
    }

    func testMatchingIsCaseInsensitive() {
        XCTAssertEqual(FocusPresentation.motif(forTitle: "ORGANIC CHEMISTRY"), .lattice)
    }

    /// The reason this uses FNV-1a rather than `hashValue`: Swift seeds its own
    /// hashing per process, so a course would repaint itself on every launch.
    func testTheFallbackIsStableAcrossCalls() {
        let title = "Beekeeping for beginners"
        let first = FocusPresentation.motif(forTitle: title)
        XCTAssertEqual(first, FocusPresentation.motif(forTitle: title))
        XCTAssertEqual(
            FocusPresentation.stableHash("Beekeeping for beginners"),
            FocusPresentation.stableHash("Beekeeping for beginners")
        )
    }

    func testDifferentTitlesHashDifferently() {
        XCTAssertNotEqual(FocusPresentation.stableHash("one"), FocusPresentation.stableHash("two"))
    }

    func testAnEmptyTitleStillGetsArt() {
        XCTAssertTrue(FocusArtMotif.allCases.contains(FocusPresentation.motif(forTitle: "")))
    }
}


// MARK: - Persisting the new field
//
// `UIStackStore` keeps this list as JSON in UserDefaults, and its loader
// discards the entire stack if decoding throws. A required field added to
// `UIStackItem` would therefore erase every saved course on the first launch
// after an update — so these two tests exist to keep `courseDescription`
// optional in practice as well as in the declaration.

final class UIStackItemDescriptionCodingTests: XCTestCase {

    func testACardSavedBeforeThisFieldExistedStillDecodes() throws {
        // Exactly what an older build wrote: no `courseDescription` key.
        let legacy = """
        {"id":"abc","type":"course","title":"Organic Chemistry","subtitle":"Lesson 11",
         "updatedAt":765432100,"progress":0.62,"courseId":"course-1","lessonCount":18}
        """.data(using: .utf8)!

        let item = try JSONDecoder().decode(UIStackItem.self, from: legacy)

        XCTAssertEqual(item.title, "Organic Chemistry")
        XCTAssertEqual(item.lessonCount, 18)
        XCTAssertNil(item.courseDescription)
        // And it degrades to the documented fallback rather than to nothing.
        XCTAssertEqual(FocusPresentation.blurb(for: item), .subtitle("Lesson 11"))
    }

    func testTheFieldSurvivesARoundTrip() throws {
        let original = UIStackItem(
            type: .course,
            title: "Linear Algebra Done Right",
            courseDescription: "Vector spaces before matrices.",
            courseId: "course-9"
        )
        let data = try JSONEncoder().encode([original])
        let restored = try JSONDecoder().decode([UIStackItem].self, from: data)

        XCTAssertEqual(restored.first?.courseDescription, "Vector spaces before matrices.")
    }
}

final class UIStackStoreDescriptionCleaningTests: XCTestCase {

    /// The server sends null for a course nobody described and "" for one whose
    /// description was cleared. Both mean "no description", and neither should
    /// reach a card as an empty paragraph.
    func testBlankServerDescriptionsAreTreatedAsAbsent() {
        XCTAssertNil(UIStackStore.cleaned(nil))
        XCTAssertNil(UIStackStore.cleaned(""))
        XCTAssertNil(UIStackStore.cleaned("   \n  "))
    }

    func testARealDescriptionIsKeptAndTrimmed() {
        XCTAssertEqual(UIStackStore.cleaned("  Convergence tests.  "), "Convergence tests.")
    }
}

// MARK: - Keeping a description once we have one
//
// A description only ever arrives from `mergeCourseStacksFromBackend`. Every
// other write to a course card goes through `upsertCourse` — opening the
// course, a progress refresh, a title change — and none of those callers knows
// the description. If they overwrote the field instead of preserving it, the
// first time a learner opened a synced course its description would vanish,
// which is the kind of regression that looks like a simplification in review:
// `courseDescription ?? existing?.courseDescription` reads like a redundant
// coalesce until you know where the value comes from.

@MainActor
final class UIStackStoreDescriptionPreservationTests: XCTestCase {

    /// `GENERATE:` ids keep this offline: `syncCourseUpsertToBackend` skips
    /// them, so the store never reaches for the network. The preservation rule
    /// itself does not care about the id.
    private let courseId = "GENERATE:vector-spaces"

    private func makeStore() throws -> (UIStackStore, () -> Void) {
        let suiteName = "UIStackStoreDescriptionPreservationTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        return (
            UIStackStore(defaults: defaults),
            { defaults.removePersistentDomain(forName: suiteName) }
        )
    }

    func testAnUpsertThatDoesNotKnowTheDescriptionKeepsIt() throws {
        let (store, cleanUp) = try makeStore()
        defer { cleanUp() }

        store.upsertCourse(
            courseId: courseId,
            title: "Linear Algebra Done Right",
            courseDescription: "Vector spaces before matrices."
        )

        // What opening the course looks like: the same card, with progress to
        // record and no description to hand over.
        store.upsertCourse(
            courseId: courseId,
            title: "Linear Algebra Done Right",
            progress: 0.4
        )

        let card = try XCTUnwrap(store.items.first { $0.courseId == courseId })
        XCTAssertEqual(card.courseDescription, "Vector spaces before matrices.")
        XCTAssertEqual(card.progress, 0.4)
        // The card still shows prose rather than falling back.
        XCTAssertEqual(
            FocusPresentation.blurb(for: card),
            .description("Vector spaces before matrices.")
        )
    }

    /// Preserving must not mean freezing: a caller that does know a newer
    /// description — the backend merge, after the course was re-described —
    /// still replaces it.
    func testAnUpsertThatKnowsADescriptionReplacesTheStoredOne() throws {
        let (store, cleanUp) = try makeStore()
        defer { cleanUp() }

        store.upsertCourse(
            courseId: courseId,
            title: "Linear Algebra Done Right",
            courseDescription: "An older description."
        )
        store.upsertCourse(
            courseId: courseId,
            title: "Linear Algebra Done Right",
            courseDescription: "Vector spaces before matrices."
        )

        let card = try XCTUnwrap(store.items.first { $0.courseId == courseId })
        XCTAssertEqual(card.courseDescription, "Vector spaces before matrices.")
    }

    /// The store writes to UserDefaults on every change, so the preserved
    /// value has to survive the encode/decode too — not just live in memory.
    func testAPreservedDescriptionSurvivesTheReload() throws {
        let suiteName = "UIStackStoreDescriptionPreservationTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = UIStackStore(defaults: defaults)
        store.upsertCourse(
            courseId: courseId,
            title: "Linear Algebra Done Right",
            courseDescription: "Vector spaces before matrices."
        )
        store.upsertCourse(courseId: courseId, title: "Linear Algebra Done Right", progress: 0.4)

        let restored = UIStackStore(defaults: defaults)
        XCTAssertEqual(
            restored.items.first { $0.courseId == courseId }?.courseDescription,
            "Vector spaces before matrices."
        )
    }
}

// MARK: - The deck

/// The collapsed card deck's geometry and its count.
///
/// Three platforms draw this deck from the same table, so these values are a
/// cross-platform contract, not an implementation detail: the matching Kotlin
/// and JavaScript suites assert the same numbers. The count label matters for
/// a second reason — it is a figure shown to a learner about their own
/// library, so it has to be the real one.
final class FocusDeckTests: XCTestCase {

    func testASingleCourseHasNoDeckToOpen() {
        XCTAssertTrue(FocusPresentation.deckLayers(cardCount: 1).isEmpty)
        XCTAssertNil(FocusPresentation.deckMoreLabel(cardCount: 1))
    }

    func testAnEmptyListHasNoDeck() {
        XCTAssertTrue(FocusPresentation.deckLayers(cardCount: 0).isEmpty)
        XCTAssertNil(FocusPresentation.deckMoreLabel(cardCount: 0))
    }

    func testTwoCoursesDrawOnePeekCard() {
        let layers = FocusPresentation.deckLayers(cardCount: 2)
        XCTAssertEqual(layers.count, 1)
        XCTAssertEqual(layers[0].depth, 1)
        XCTAssertEqual(layers[0].offset, 11)
        XCTAssertEqual(layers[0].scale, 0.95)
        XCTAssertEqual(layers[0].opacity, 0.72)
    }

    func testThreeCoursesDrawTwoPeekCards() {
        let layers = FocusPresentation.deckLayers(cardCount: 3)
        XCTAssertEqual(layers.map(\.depth), [1, 2])
        XCTAssertEqual(layers.map(\.offset), [11, 20])
        XCTAssertEqual(layers.map(\.scale), [0.95, 0.9])
        XCTAssertEqual(layers.map(\.opacity), [0.72, 0.46])
    }

    /// The drawn layers stop at two; the count below the deck does not.
    func testTheDeckStopsAtTwoPeekCardsHoweverManyCoursesAreSaved() {
        XCTAssertEqual(FocusPresentation.deckLayers(cardCount: 4).count, 2)
        XCTAssertEqual(FocusPresentation.deckLayers(cardCount: 40).count, 2)
        XCTAssertEqual(FocusPresentation.deckPeekLimit, 2)
    }

    /// The label counts the learner's courses, not the cards on screen. A deck
    /// drawing two layers over twelve courses still says eleven are waiting.
    func testTheLabelCountsEveryHiddenCourseNotJustTheOnesDrawn() {
        XCTAssertEqual(FocusPresentation.deckMoreLabel(cardCount: 2), "1 more course")
        XCTAssertEqual(FocusPresentation.deckMoreLabel(cardCount: 3), "2 more courses")
        XCTAssertEqual(FocusPresentation.deckMoreLabel(cardCount: 12), "11 more courses")
    }

    func testTheFirstCardArrivesWithNoDelay() {
        XCTAssertEqual(FocusPresentation.deckStaggerMilliseconds(index: 0), 0)
        XCTAssertEqual(FocusPresentation.deckStaggerMilliseconds(index: -3), 0)
    }

    func testTheStaggerStepsAndThenStops() {
        XCTAssertEqual(FocusPresentation.deckStaggerMilliseconds(index: 1), 35)
        XCTAssertEqual(FocusPresentation.deckStaggerMilliseconds(index: 3), 105)
        XCTAssertEqual(FocusPresentation.deckStaggerMilliseconds(index: 8), 280)
        // Capped: forty saved courses must not mean a 1.4s wait for the list.
        XCTAssertEqual(FocusPresentation.deckStaggerMilliseconds(index: 40), 280)
    }
}
