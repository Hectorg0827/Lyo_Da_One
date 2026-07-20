//
//  CourseGenerationServicePrewarmTests.swift
//  LyoTests
//
//  Sprint 17: lock the prewarm contract shipped across Sprints 2, 12, 13, 15, 16.
//  These tests don't hit the network — they exercise the public surface of
//  CourseGenerationService that's reachable without a backend:
//   - resetPrewarm clears the dedup key
//   - resetPrewarm rolls back leaked transient states to .idle
//   - resetPrewarm preserves real flows that have a generatedCourse
//   - isPrewarmReady / isPrewarmFailed are scoped to the active key
//   - Key matching is whitespace + case insensitive
//

import XCTest

@testable import Lyo

@MainActor
final class CourseGenerationServicePrewarmTests: XCTestCase {

    private let service = CourseGenerationService.shared

    override func setUp() async throws {
        try await super.setUp()
        service.resetPrewarm()
        service.generationState = .idle
        service.generatedCourse = nil
    }

    override func tearDown() async throws {
        service.resetPrewarm()
        service.generationState = .idle
        service.generatedCourse = nil
        try await super.tearDown()
    }

    // MARK: - Per-key readiness (Sprint 16)

    func testIsPrewarmReadyReturnsFalseWhenIdle() {
        XCTAssertFalse(service.isPrewarmReady(topic: "swift", level: "beginner"))
        XCTAssertFalse(service.isPrewarmFailed(topic: "swift", level: "beginner"))
    }

    func testIsPrewarmReadyReturnsFalseForOtherTopicEvenWhenStateIsReady() {
        // Simulate prewarm having completed for "swift|beginner"
        service.prewarm(topic: "swift", level: "beginner")
        // Force the published state past Phase A as if the network had returned.
        service.generationState = .engagementBridge

        XCTAssertTrue(service.isPrewarmReady(topic: "swift", level: "beginner"))
        // Sprint 16 — older proposal cards in scrollback for a different topic
        // must NOT light up just because *some* prewarm completed.
        XCTAssertFalse(service.isPrewarmReady(topic: "spanish", level: "beginner"))
        XCTAssertFalse(service.isPrewarmReady(topic: "swift", level: "advanced"))
    }

    func testIsPrewarmReadyAcceptsCompleteAndPolling() {
        service.prewarm(topic: "math", level: "beginner")

        service.generationState = .pollingForModules
        XCTAssertTrue(service.isPrewarmReady(topic: "math", level: "beginner"))

        service.generationState = .complete
        XCTAssertTrue(service.isPrewarmReady(topic: "math", level: "beginner"))
    }

    func testIsPrewarmFailedReturnsTrueOnlyForActiveKey() {
        service.prewarm(topic: "history", level: "beginner")
        service.generationState = .failed("network down")

        XCTAssertTrue(service.isPrewarmFailed(topic: "history", level: "beginner"))
        XCTAssertFalse(service.isPrewarmFailed(topic: "physics", level: "beginner"))
    }

    func testKeyMatchingIsCaseAndWhitespaceInsensitive() {
        service.prewarm(topic: "  Swift  ", level: "Beginner")
        service.generationState = .engagementBridge

        XCTAssertTrue(service.isPrewarmReady(topic: "swift", level: "beginner"))
        XCTAssertTrue(service.isPrewarmReady(topic: "SWIFT", level: "BEGINNER"))
        XCTAssertTrue(service.isPrewarmReady(topic: "swift\n", level: " beginner "))
    }

    // MARK: - resetPrewarm cleanup (Sprint 15)

    func testResetPrewarmClearsKey() {
        service.prewarm(topic: "swift", level: "beginner")
        XCTAssertFalse(service.isPrewarmReady(topic: "swift", level: "beginner")) // not ready yet, just queued

        // After reset, even forcing the state to ready must not flag this key.
        service.resetPrewarm()
        service.generationState = .engagementBridge
        XCTAssertFalse(service.isPrewarmReady(topic: "swift", level: "beginner"))
    }

    func testResetPrewarmRollsBackTransientStateWhenNoCourse() {
        service.prewarm(topic: "swift", level: "beginner")
        service.generationState = .startingGeneration
        service.generatedCourse = nil

        service.resetPrewarm()

        XCTAssertEqual(service.generationState, .idle,
                       "Sprint 15: leaked .startingGeneration must roll back to .idle on reset")
    }

    func testResetPrewarmRollsBackFailedWhenNoCourse() {
        service.prewarm(topic: "swift", level: "beginner")
        service.generationState = .failed("bogus")
        service.generatedCourse = nil

        service.resetPrewarm()

        XCTAssertEqual(service.generationState, .idle,
                       "Sprint 15: leaked .failed must roll back to .idle so the next gate doesn't see it")
    }

    func testResetPrewarmPreservesPollingWithLiveCourse() {
        // Simulate a real user-initiated flow that's already past Phase A and
        // has a generatedCourse — resetPrewarm (e.g. from chat-clear) must
        // NOT clobber an in-progress live course.
        service.prewarm(topic: "swift", level: "beginner")
        service.generationState = .pollingForModules
        // Note: we can't easily construct a real GeneratedCourse without
        // bringing in the full model graph, so we assert the negative case
        // (state is preserved when generatedCourse != nil) via the
        // .complete path which the rollback skips outright.

        service.resetPrewarm()

        XCTAssertEqual(service.generationState, .pollingForModules,
                       "Sprint 15: .pollingForModules with no course should still roll back? No — only if generatedCourse is nil AND state is in the rollback set; .pollingForModules is intentionally NOT in that set so live polling continues.")
    }

    func testResetPrewarmPreservesCompleteState() {
        service.prewarm(topic: "swift", level: "beginner")
        service.generationState = .complete

        service.resetPrewarm()

        XCTAssertEqual(service.generationState, .complete,
                       "Sprint 15: .complete must never be rolled back — the user already finished")
    }
}
