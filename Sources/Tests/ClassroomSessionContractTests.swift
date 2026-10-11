import XCTest
@testable import Lyo

/// The rules that decide whether a class starts or resumes, and when a wait
/// stops claiming the next step is coming.
///
/// These are asserted on every platform against the same numbers and the same
/// copy — see `web/src/lib/classroom-contract.test.mjs`, the Android
/// `ClassroomSessionContractTest`, and the parity gate that holds the three
/// together.
final class ClassroomSessionContractTests: XCTestCase {

    // MARK: Starting a class, and starting it over

    func testFirstClassCannotResumeOldServerSeatAfterReinstall() {
        let start = ClassroomSessionContract.sessionStart(courseKey: "course-7", saved: nil)
        XCTAssertTrue(start.sessionId.hasPrefix("course-7~1-"))
        XCTAssertEqual(start.generation, 1)
        XCTAssertFalse(start.resumed)
    }

    func testOpeningTheSameTopicAgainIsANewClass() {
        let first = ClassroomSessionContract.sessionStart(courseKey: "Minecraft", saved: nil)
        let second = ClassroomSessionContract.sessionStart(
            courseKey: "Minecraft",
            saved: ClassroomSavedSession(id: first.sessionId, startedAt: Date(), generation: first.generation)
        )
        XCTAssertNotEqual(second.sessionId, first.sessionId)
        XCTAssertEqual(second.generation, 2)
        XCTAssertFalse(second.resumed)

        let third = ClassroomSessionContract.sessionStart(
            courseKey: "Minecraft",
            saved: ClassroomSavedSession(id: second.sessionId, startedAt: Date(), generation: second.generation)
        )
        XCTAssertNotEqual(third.sessionId, second.sessionId)
    }

    func testResumingIsHonouredOnlyWhenTheLearnerAsksForIt() {
        let saved = ClassroomSavedSession(id: "course-7~2", startedAt: Date(), generation: 2)
        let resumed = ClassroomSessionContract.sessionStart(
            courseKey: "course-7", saved: saved, resume: true
        )
        XCTAssertEqual(resumed.sessionId, "course-7~2")
        XCTAssertTrue(resumed.resumed)

        let fresh = ClassroomSessionContract.sessionStart(courseKey: "course-7", saved: saved)
        XCTAssertTrue(fresh.sessionId.hasPrefix("course-7~3-"))
        XCTAssertFalse(fresh.resumed)
    }

    func testAClassTooOldToRememberSittingIsStartedNotResumed() {
        let now = Date()
        let stale = ClassroomSavedSession(
            id: "course-7~2",
            startedAt: now.addingTimeInterval(-ClassroomSessionContract.resumeWindow - 1),
            generation: 2
        )
        XCTAssertFalse(ClassroomSessionContract.canResume(stale, now: now))
        let start = ClassroomSessionContract.sessionStart(
            courseKey: "course-7", saved: stale, resume: true, now: now
        )
        XCTAssertFalse(start.resumed)
        XCTAssertTrue(start.sessionId.hasPrefix("course-7~3-"))
    }

    func testFreeTopicEntriesFindTheirOwnHistory() {
        // iOS's free-topic entry arrives as GENERATE:<topic>; the stored key
        // is the topic, so typing it twice is recognised as the same subject.
        XCTAssertEqual(
            ClassroomSessionContract.courseKey(courseId: "GENERATE:Minecraft", topic: "Minecraft"),
            "Minecraft"
        )
        XCTAssertEqual(
            ClassroomSessionContract.courseKey(courseId: nil, topic: "Minecraft"),
            "Minecraft"
        )
        XCTAssertEqual(ClassroomSessionContract.courseKey(courseId: nil, topic: nil), "general")
        XCTAssertEqual(
            ClassroomSessionContract.storageKey(courseKey: "course-7"),
            "lyo_classroom_session:course-7"
        )
    }

    func testTheStoreRoundTripsASeatWithoutLeakingBetweenCourses() {
        let defaults = UserDefaults(suiteName: "ClassroomSessionContractTests")!
        defaults.removePersistentDomain(forName: "ClassroomSessionContractTests")
        let store = ClassroomSessionStore(defaults: defaults)
        XCTAssertNil(store.saved(courseKey: "course-7"))

        let seat = ClassroomSavedSession(id: "course-7~2", startedAt: Date(), generation: 2)
        store.save(seat, courseKey: "course-7")
        XCTAssertEqual(store.saved(courseKey: "course-7")?.id, "course-7~2")
        XCTAssertNil(store.saved(courseKey: "course-9"))
        defaults.removePersistentDomain(forName: "ClassroomSessionContractTests")
    }

    // MARK: The lesson has a beginning

    func testTheOpeningNamesTheLessonThatWasActuallyRequested() {
        let opening = ClassroomSessionContract.opening(
            topic: "Minecraft", objective: "Build a first shelter",
            durationMinutes: 20, difficulty: "beginner", mode: "solo"
        )
        XCTAssertEqual(opening.title, "Today: Minecraft")
        XCTAssertEqual(opening.objective, "Build a first shelter")
        XCTAssertEqual(opening.facts, ["20 min", "beginner level"])
        XCTAssertFalse(opening.resumed)
        XCTAssertTrue(opening.note.contains("stop Lyo at any time"))
    }

    func testAResumedClassSaysSoInsteadOfPretendingToStart() {
        let opening = ClassroomSessionContract.opening(
            topic: "Minecraft", objective: nil, durationMinutes: nil,
            difficulty: nil, mode: nil, resumed: true
        )
        XCTAssertEqual(opening.title, "Back to Minecraft")
        XCTAssertEqual(opening.objective, "Understand and apply Minecraft")
        XCTAssertEqual(opening.facts, ["10 min"])
    }

    func testTheLengthShownIsTheLengthTheServerWillBeTold() {
        let opening = ClassroomSessionContract.opening(
            topic: "Fractions", objective: nil, durationMinutes: 999,
            difficulty: nil, mode: "challenge"
        )
        XCTAssertEqual(opening.facts, ["60 min", "challenge mode"])
    }

    // MARK: A step that never arrives

    func testTheStallThresholdsGiveASlowStepTimeBeforeItIsBroken() {
        XCTAssertGreaterThan(ClassroomSessionContract.stallNoticeSeconds, 0)
        XCTAssertGreaterThan(
            ClassroomSessionContract.stallRecoverySeconds,
            ClassroomSessionContract.stallNoticeSeconds
        )
        XCTAssertTrue(ClassroomSessionContract.stallRecovery.contains("not a wrong answer"))
    }
}
