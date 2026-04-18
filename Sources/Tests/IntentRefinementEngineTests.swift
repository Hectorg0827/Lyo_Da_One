//
//  IntentRefinementEngineTests.swift
//  LyoTests
//
//  Sprint 7: lock in the slot-filling FSM behavior shipped in Sprints 1–5.
//  These are pure-Swift unit tests — no network, no UI. They cover:
//   - Non-course messages pass through without refinement.
//   - Ambiguous topics trigger a scope chip prompt.
//   - A message that already encodes scope + level ships in one shot.
//   - Two-round chip flow lands on .ready.
//   - The 2-round cap defaults to beginner instead of looping.
//   - Cancellation words mid-flow reset to .notACourseRequest.
//

import XCTest

@testable import Lyo

@MainActor
final class IntentRefinementEngineTests: XCTestCase {

    private let engine = IntentRefinementEngine.shared

    override func setUp() async throws {
        try await super.setUp()
        // Wipe the cached LearnerProfile so prior-proficiency hints don't
        // make a test pass for the wrong reason. The store is a singleton
        // that loads from UserDefaults at init time, so we must also reset
        // the in-memory profile (clearing the key alone won't take effect).
        UserDefaults.standard.removeObject(forKey: "lyo.learnerProfile.v1")
        LearnerProfileStore.shared.update { $0 = LearnerProfile() }
        engine.reset()
    }

    override func tearDown() async throws {
        engine.reset()
        LearnerProfileStore.shared.update { $0 = LearnerProfile() }
        UserDefaults.standard.removeObject(forKey: "lyo.learnerProfile.v1")
        try await super.tearDown()
    }

    // MARK: - Pass-through

    func testGreetingIsNotACourseRequest() {
        switch engine.process(message: "hey there") {
        case .notACourseRequest:
            break
        default:
            XCTFail("Greeting should not trigger refinement")
        }
    }

    func testEmptyMessageIsNotACourseRequest() {
        switch engine.process(message: "   ") {
        case .notACourseRequest:
            break
        default:
            XCTFail("Empty message should not trigger refinement")
        }
    }

    // MARK: - Ambiguous topic → scope chips

    func testAmbiguousPythonAsksForScope() {
        // "create a course on " matches a courseCreation indicator AND is a
        // recognised prefix that gets stripped → extractedTopic = "python".
        let outcome = engine.process(message: "create a course on python")
        guard case .needsClarification(let prompt) = outcome else {
            return XCTFail("Expected scope clarification, got \(outcome)")
        }
        XCTAssertEqual(prompt.dimension, .scope)
        XCTAssertTrue(
            prompt.chips.contains("Python basics"),
            "Python scope chips should include 'Python basics', got \(prompt.chips)")
    }

    func testAmbiguousAlgebraAsksForScope() {
        let outcome = engine.process(message: "create a course on algebra")
        guard case .needsClarification(let prompt) = outcome else {
            return XCTFail("Expected scope clarification, got \(outcome)")
        }
        XCTAssertEqual(prompt.dimension, .scope)
        XCTAssertTrue(
            prompt.chips.contains(where: { $0.localizedCaseInsensitiveContains("algebra") }))
    }

    func testAmbiguousSpanishAsksForScope() {
        let outcome = engine.process(message: "create a course on spanish")
        guard case .needsClarification(let prompt) = outcome else {
            return XCTFail("Expected scope clarification, got \(outcome)")
        }
        XCTAssertEqual(prompt.dimension, .scope)
        XCTAssertFalse(prompt.chips.isEmpty)
    }

    // MARK: - Already-disambiguated messages skip the scope round

    func testMessageMentioningTravelSpanishSkipsScopePrompt() {
        // Free-form message that already names one of the scope chips → no scope round.
        let outcome = engine.process(message: "create a course on travel spanish")
        switch outcome {
        case .needsClarification(let prompt):
            XCTAssertEqual(
                prompt.dimension, .level,
                "Already-disambiguated topic should jump straight to the level question")
        case .ready:
            // Acceptable: if a future heuristic infers level. Don't fail.
            break
        default:
            XCTFail("Unexpected outcome: \(outcome)")
        }
    }

    // MARK: - One-shot ready (scope already disambiguated + explicit beginner)

    func testFullySpecifiedRequestShipsInOneShot() {
        let outcome = engine.process(message: "create a course on python basics for beginners")
        guard case .ready(let refined) = outcome else {
            return XCTFail("Fully-specified request should be .ready, got \(outcome)")
        }
        XCTAssertEqual(refined.level, .beginner)
        XCTAssertTrue(refined.normalizedTopic.contains("python"))
    }

    // MARK: - Two-round chip flow

    func testAlgebraScopeThenLevelLandsOnReady() {
        // Round 1: ambiguous topic
        guard
            case .needsClarification(let scopePrompt) = engine.process(
                message: "create a course on algebra")
        else {
            return XCTFail("Round 1 should be a scope clarification")
        }
        XCTAssertEqual(scopePrompt.dimension, .scope)

        // Round 2: user taps a chip → fills scope, engine asks for level
        guard case .needsClarification(let levelPrompt) = engine.process(message: "Algebra 1")
        else {
            return XCTFail("Round 2 should be a level clarification")
        }
        XCTAssertEqual(levelPrompt.dimension, .level)

        // Round 3: user picks a level chip → ready
        guard case .ready(let refined) = engine.process(message: "I'm new to this") else {
            return XCTFail("Round 3 should be .ready")
        }
        XCTAssertEqual(refined.level, .beginner)
        XCTAssertTrue(refined.normalizedTopic.contains("algebra"))
    }

    // MARK: - Two-round cap (no infinite loops)

    func testTwoRoundCapDefaultsToBeginnerInsteadOfLooping() {
        // Round 1: ambiguous algebra → scope prompt
        guard case .needsClarification = engine.process(message: "create a course on algebra")
        else {
            return XCTFail("Round 1 should be scope clarification")
        }
        // Round 2: garbage answer → engine fills scope = "Asdf", asks for level
        guard case .needsClarification = engine.process(message: "asdf") else {
            return XCTFail("Round 2 should still be a clarification (level)")
        }
        // Round 3: more garbage → cap reached, must NOT ask a 3rd time
        let outcome = engine.process(message: "qwerty")
        switch outcome {
        case .ready(let refined):
            XCTAssertEqual(
                refined.level, .beginner,
                "Cap-reached fallback should default the level to .beginner")
        default:
            XCTFail("After 2 rounds the engine must ship .ready, got \(outcome)")
        }
    }

    // MARK: - Cancellation

    func testCancellationMidFlowResetsToNotACourseRequest() {
        // Start a refinement
        guard case .needsClarification = engine.process(message: "create a course on algebra")
        else {
            return XCTFail("Should have entered clarification state")
        }
        // User bails
        switch engine.process(message: "nevermind") {
        case .notACourseRequest:
            break
        default:
            XCTFail("Cancellation word should reset to .notACourseRequest")
        }
        // Subsequent fresh greeting should also still be a non-course message
        // (i.e. internal state really was cleared).
        switch engine.process(message: "hi") {
        case .notACourseRequest:
            break
        default:
            XCTFail("After reset, greeting should be .notACourseRequest")
        }
    }
}
