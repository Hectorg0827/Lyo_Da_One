//
//  A2UIPipelineTests.swift
//  Lyo
//
//  Tests for the complete A2UI pipeline:
//   • snake_case ↔ camelCase type decoding
//   • SafeDecodable fault-isolation
//   • A2UIComponent round-trip Codable
//   • OpenClassroomCommand.CoursePayload construction
//   • GamificationService XP award
//

import XCTest
@testable import Lyo

// MARK: - A2UIElementType Decoding Tests

final class A2UIElementTypeDecodingTests: XCTestCase {

    private let decoder = JSONDecoder()

    // Backend sends "course_card" (snake_case) → iOS must decode as .courseCard
    func testSnakeCaseDecoding() throws {
        let data = Data(#""course_card""#.utf8)
        let result = try decoder.decode(A2UIElementType.self, from: data)
        XCTAssertEqual(result, .courseCard,
                       "snake_case 'course_card' must map to .courseCard")
    }

    // "completion_badge" → .completionBadge
    func testCompletionBadgeDecoding() throws {
        let data = Data(#""completion_badge""#.utf8)
        let result = try decoder.decode(A2UIElementType.self, from: data)
        XCTAssertEqual(result, .completionBadge)
    }

    // Already-camelCase value must pass through unchanged
    func testCamelCasePassthrough() throws {
        let data = Data(#""courseCard""#.utf8)
        let result = try decoder.decode(A2UIElementType.self, from: data)
        XCTAssertEqual(result, .courseCard)
    }

    // Completely unknown type must silently decode as .unknown (no throw)
    func testUnknownTypeDecodesAsUnknown() throws {
        let data = Data(#""totally_made_up_widget_xyz""#.utf8)
        let result = try decoder.decode(A2UIElementType.self, from: data)
        XCTAssertEqual(result, .unknown,
                       "Unrecognised type string must fall back to .unknown, not throw")
    }
}

// MARK: - SafeDecodable Fault Isolation Tests

final class SafeDecodableTests: XCTestCase {

    private let decoder = JSONDecoder()

    // A corrupt child in an array must not poison the healthy siblings
    func testSingleCorruptChildIsDropped() throws {
        // First element is missing the required "type" key → should decode as nil
        // Second element is valid → should decode successfully
        let json = #"""
        [
            {"props": {}},
            {"type": "course_card", "props": {"title": "Swift Basics"}}
        ]
        """#
        let items = try decoder.decode(
            [SafeDecodable<A2UIComponent>].self,
            from: Data(json.utf8)
        )
        let decoded = items.compactMap(\.value)
        XCTAssertEqual(decoded.count, 1,
                       "Corrupt child must be dropped; healthy sibling must survive")
        XCTAssertEqual(decoded[0].type, .courseCard)
    }

    // If all children are valid, nothing is dropped
    func testAllValidChildrenSurvive() throws {
        let json = #"""
        [
            {"type": "course_card",        "props": {}},
            {"type": "completion_badge",   "props": {}}
        ]
        """#
        let items = try decoder.decode(
            [SafeDecodable<A2UIComponent>].self,
            from: Data(json.utf8)
        )
        let decoded = items.compactMap(\.value)
        XCTAssertEqual(decoded.count, 2)
    }
}

// MARK: - A2UIComponent Round-Trip Codable Tests

final class A2UIComponentCodableTests: XCTestCase {

    func testComponentRoundTrip() throws {
        // Build a known component
        var props = A2UIProps()
        props.title = "Introduction to Swift"
        props.courseName = "iOS Development"
        let original = A2UIComponent(
            id: "test-id-001",
            type: .courseCard,
            props: props
        )

        // Encode → decode
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        let decoded = try JSONDecoder().decode(A2UIComponent.self, from: data)

        XCTAssertEqual(decoded.id, "test-id-001")
        XCTAssertEqual(decoded.type, .courseCard)
        XCTAssertEqual(decoded.props.title, "Introduction to Swift")
        XCTAssertEqual(decoded.props.courseName, "iOS Development")
    }

    // Backend JSON (snake_case type, no id) must decode without throwing
    func testBackendStyleJSONDecodes() throws {
        let json = #"""
        {
            "type": "course_card",
            "props": {
                "title": "Learn Python",
                "course_name": "Python Fundamentals",
                "level": "beginner",
                "estimated_duration": 120
            }
        }
        """#
        let component = try JSONDecoder().decode(
            A2UIComponent.self,
            from: Data(json.utf8)
        )
        XCTAssertEqual(component.type, .courseCard)
        XCTAssertFalse(component.id.isEmpty, "Missing id must be filled with generated UUID")
        XCTAssertEqual(component.props.title, "Learn Python")
    }
}

// MARK: - CoursePayload Construction Tests

final class CoursePayloadTests: XCTestCase {

    func testBasicPayloadConstruction() {
        let payload = CoursePayload(
            id: nil,
            title: "Swift Concurrency",
            topic: "async/await",
            level: "intermediate",
            language: nil,
            duration: "90 min",
            objectives: ["Understand async/await", "Use actors safely"]
        )
        XCTAssertEqual(payload.title, "Swift Concurrency")
        XCTAssertEqual(payload.topic, "async/await")
        XCTAssertEqual(payload.level, "intermediate")
        XCTAssertNil(payload.language)
        XCTAssertEqual(payload.duration, "90 min")
        XCTAssertEqual(payload.objectives.count, 2)
    }

    func testDefaultLevelFallback() {
        // Mirrors the logic in handleArtifactAction — nil level falls back to "beginner"
        let rawLevel: String? = nil
        let payload = CoursePayload(
            id: nil,
            title: "CSS Grid",
            topic: "Web layout",
            level: rawLevel ?? "beginner",
            language: nil,
            duration: nil,
            objectives: []
        )
        XCTAssertEqual(payload.level, "beginner")
    }
}

// MARK: - GamificationService XP Award Tests

@MainActor
final class GamificationXPTests: XCTestCase {

    func testAwardXPIncrementsTotal() {
        let svc = GamificationService.shared
        let before = svc.progress.totalXP
        svc.awardXP(amount: 100, reason: "Test award")
        XCTAssertEqual(svc.progress.totalXP, before + 100,
                       "awardXP must increment totalXP by the given amount")
    }

    func testMultipleAwardsAccumulate() {
        let svc = GamificationService.shared
        let before = svc.progress.totalXP
        svc.awardXP(amount: 25, reason: "Quiz correct answer")
        svc.awardXP(amount: 50, reason: "Course started")
        XCTAssertEqual(svc.progress.totalXP, before + 75)
    }

    func testZeroXPNoChange() {
        let svc = GamificationService.shared
        let before = svc.progress.totalXP
        svc.awardXP(amount: 0, reason: "No-op")
        XCTAssertEqual(svc.progress.totalXP, before)
    }
}
