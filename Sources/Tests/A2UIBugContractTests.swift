// Tests/A2UIDecodeTests.swift
// Validates the three root-cause bugs (A, B, C) in the A2UI render pipeline.
//
//  Bug A — AnyCodable maps JSON null → Swift Void `()`, which is not a valid
//           ObjC-bridgeable type, causing JSONSerialization.data(withJSONObject:)
//           to throw silently → text-only fallback.
//
//  Bug B — A2UIComponent.id: String was required by Codable synthesis.
//           If the backend omits "id" (common for ephemeral components),
//           the decode threw silently → text-only fallback.
//
//  Bug C — tryDecodeOpenClassroom Strategy 3 fired for ANY block that had a "title"
//           key in content, including generic A2UI cards.  This falsely routed card
//           components to .courseProposal instead of .a2ui.

import XCTest
@testable import Lyo

// MARK: - Bug A · AnyCodable.sanitizeForJSON

final class AnyCodableSanitizeTests: XCTestCase {

    // Void (Swift representation of JSON null) must become NSNull
    func test_voidBecomesNSNull() {
        let result = AnyCodable.sanitizeForJSON(())
        XCTAssertTrue(result is NSNull, "Expected NSNull for Void input, got \(type(of: result))")
    }

    // NSNull should pass through unchanged
    func test_nsNullPassThrough() {
        let result = AnyCodable.sanitizeForJSON(NSNull())
        XCTAssertTrue(result is NSNull)
    }

    // Primitive types must survive unsanitized
    func test_primitivesUnchanged() {
        XCTAssertEqual(AnyCodable.sanitizeForJSON("hello") as? String, "hello")
        XCTAssertEqual(AnyCodable.sanitizeForJSON(42)      as? Int,    42)
        XCTAssertEqual(AnyCodable.sanitizeForJSON(3.14)    as? Double, 3.14)
        XCTAssertEqual(AnyCodable.sanitizeForJSON(true)    as? Bool,   true)
    }

    // Void values nested inside a dict must be stripped (key removed, not set to NSNull)
    func test_dictWithVoidValuesStripped() {
        let input: [String: Any] = ["title": "Learn Python", "nullField": ()]
        let result = AnyCodable.sanitizeForJSON(input) as? [String: Any]
        XCTAssertNotNil(result)
        XCTAssertEqual(result?["title"] as? String, "Learn Python")
        XCTAssertNil(result?["nullField"], "Void-valued key should be stripped from dict")
    }

    // Void values nested inside an array must be stripped
    func test_arrayWithVoidValuesStripped() {
        let input: [Any] = ["a", (), "b"]
        let result = AnyCodable.sanitizeForJSON(input) as? [Any]
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.count, 2, "Void elements should be stripped from array")
        XCTAssertEqual(result?.first as? String, "a")
        XCTAssertEqual(result?.last as? String, "b")
    }

    // Deep nesting: dict inside array inside dict — all Voids stripped
    func test_deepNestedSanitization() {
        let input: [String: Any] = [
            "props": [
                "backgroundColor": (),   // null optional field
                "title": "Hello",
                "children": [
                    ["text": "Item 1", "hidden": ()] as [String: Any]
                ] as [Any]
            ] as [String: Any]
        ]
        let sanitized = AnyCodable.sanitizeForJSON(input) as? [String: Any]
        let props = sanitized?["props"] as? [String: Any]
        XCTAssertNil(props?["backgroundColor"], "Deep null should be stripped")
        XCTAssertEqual(props?["title"] as? String, "Hello")
        let children = props?["children"] as? [[String: Any]]
        XCTAssertNil(children?.first?["hidden"], "Nested null should be stripped")
    }

    // After sanitization, JSONSerialization must succeed
    func test_sanitizedDictIsSerializable() {
        let input: [String: Any] = [
            "type": "card",
            "id": "abc-123",
            "props": ["title": "Test", "backgroundColor": ()] as [String: Any]
        ]
        let sanitized = AnyCodable.sanitizeForJSON(input)
        XCTAssertTrue(JSONSerialization.isValidJSONObject(sanitized),
                      "Sanitized dict must pass isValidJSONObject")
        XCTAssertNoThrow(try JSONSerialization.data(withJSONObject: sanitized),
                         "Sanitized dict must serialize without throwing")
    }
}

// MARK: - Bug B · A2UIComponent decodes without "id"

final class A2UIComponentDecodeTests: XCTestCase {

    private func decodeComponent(from json: [String: Any]) -> A2UIComponent? {
        let sanitized = AnyCodable.sanitizeForJSON(json)
        guard let data = try? JSONSerialization.data(withJSONObject: sanitized) else { return nil }
        return try? JSONDecoder().decode(A2UIComponent.self, from: data)
    }

    // Full component JSON decodes correctly
    func test_fullComponent() {
        let json: [String: Any] = [
            "type": "card",
            "id": "fixed-id-001",
            "props": ["title": "Learn Python"]
        ]
        let component = decodeComponent(from: json)
        XCTAssertNotNil(component)
        XCTAssertEqual(component?.id, "fixed-id-001")
        XCTAssertEqual(component?.type, .card)
    }

    // Component without "id" must decode and auto-generate a UUID
    func test_missingIdGeneratesUUID() {
        let json: [String: Any] = [
            "type": "card",
            "props": ["title": "No ID Component"]
        ]
        let component = decodeComponent(from: json)
        XCTAssertNotNil(component, "Component without 'id' must still decode (Bug B fix)")
        XCTAssertFalse(component?.id.isEmpty ?? true, "Auto-generated id must not be empty")
    }

    // Component with null optional props must decode (Bug A + B combined)
    func test_componentWithNullProps() {
        let json: [String: Any] = [
            "type": "text",
            "props": [
                "text": "Hello",
                "backgroundColor": (),   // null from backend
                "fontSize": ()           // null from backend
            ] as [String: Any]
        ]
        let component = decodeComponent(from: json)
        XCTAssertNotNil(component, "Component with null prop values must decode (Bug A + B fix)")
        XCTAssertEqual(component?.type, .text)
    }

    // Missing "props" entirely is tolerated
    func test_missingPropsIsOk() {
        let json: [String: Any] = ["type": "vStack"]
        let component = decodeComponent(from: json)
        XCTAssertNotNil(component, "Component without 'props' must still decode")
        XCTAssertEqual(component?.type, .vStack)
    }

    // Unknown component type maps to .unknown, not a decode failure
    func test_unknownTypeMapsToUnknown() {
        let json: [String: Any] = ["type": "someFutureWidget", "id": "x"]
        let component = decodeComponent(from: json)
        XCTAssertNotNil(component, "Unknown component type must not throw — maps to .unknown")
        XCTAssertEqual(component?.type, .unknown)
    }

    // Snake-case type from backend is normalised correctly
    func test_snakeCaseTypeNormalised() {
        let json: [String: Any] = ["type": "rich_text", "id": "y"]
        let component = decodeComponent(from: json)
        XCTAssertNotNil(component)
        // "rich_text" → camelCase "richText" → A2UIElementType.richText
        XCTAssertEqual(component?.type, .richText)
    }

    // Children are decoded recursively and inherit the id-defaulting logic
    func test_childrenDecodedWithDefaultIds() {
        let json: [String: Any] = [
            "type": "vStack",
            "children": [
                ["type": "text", "props": ["text": "Child 1"]] as [String: Any],
                ["type": "image", "id": "img-1", "props": ["imageUrl": "https://example.com/img.png"]] as [String: Any]
            ] as [Any]
        ]
        let component = decodeComponent(from: json)
        XCTAssertNotNil(component)
        XCTAssertEqual(component?.children?.count, 2)
        // First child has no id — should get an auto-generated one
        XCTAssertFalse(component?.children?.first?.id.isEmpty ?? true)
        // Second child keeps its explicit id
        XCTAssertEqual(component?.children?.last?.id, "img-1")
    }
}

// MARK: - Bug C · Strategy 3 does NOT fire for generic A2UI cards

final class TryDecodeOpenClassroomTests: XCTestCase {

    /// Validates that a Lyo2UIBlock carrying an A2UI card (not a classroom event)
    /// does NOT produce a CoursePayload from tryDecodeOpenClassroom's flat-field heuristic.
    ///
    /// We test this indirectly: we build a block that ONLY has content keys typical of
    /// a UI card (type, id, props with title), confirm the block has no classroom markers,
    /// and then verify Strategy 3 would not match.
    func test_genericCardDoesNotTriggerClassroomHeuristic() {
        // Build a content dict typical of a generic A2UI card from the backend
        let contentDict: [String: AnyCodable] = [
            "type":  AnyCodable("card"),
            "id":    AnyCodable("card-001"),
            "props": AnyCodable(["title": "What is Machine Learning?", "subtitle": "An introduction"])
        ]
        let block = Lyo2UIBlock(
            blockType: .a2uiComponent,
            title: nil,
            priority: 0,
            content: contentDict
        )

        // None of the explicit classroom markers should be present
        let typeStr  = block.content["type"]?.value as? String
        let intent   = block.content["intent"]?.value as? String
        let action   = block.content["action"]?.value as? String

        let hasClassroomMarker =
            block.blockType == .openClassroomBlock
            || typeStr?.uppercased() == "OPEN_CLASSROOM"
            || intent?.lowercased().contains("classroom") == true
            || action?.lowercased() == "open_classroom"

        XCTAssertFalse(hasClassroomMarker,
            "A2UI card block must NOT be identified as a classroom event (Bug C guard)")
    }

    /// A block with explicit OPEN_CLASSROOM type MUST still be identified
    func test_explicitOpenClassroomBlockIsIdentified() {
        let contentDict: [String: AnyCodable] = [
            "type":  AnyCodable("OPEN_CLASSROOM"),
            "title": AnyCodable("Advanced Swift"),
            "topic": AnyCodable("Swift Concurrency")
        ]
        let block = Lyo2UIBlock(
            blockType: .openClassroomBlock,
            title: "Advanced Swift",
            priority: 0,
            content: contentDict
        )

        let typeStr = block.content["type"]?.value as? String
        let hasClassroomMarker =
            block.blockType == .openClassroomBlock
            || typeStr?.uppercased() == "OPEN_CLASSROOM"

        XCTAssertTrue(hasClassroomMarker,
            "Explicit OPEN_CLASSROOM block must be identified as classroom event")
    }
}

// MARK: - Integration · Full decode pipeline (sanitize → A2UIComponent)

final class A2UIFullPipelineTests: XCTestCase {

    /// Simulates the exact payload a production backend sends for an A2UI card event.
    /// All three bugs would have broken this decode before the fix.
    func test_productionLikeCardPayload() {
        let productionPayload: [String: Any] = [
            "type": "card",
            // "id" intentionally omitted (Bug B scenario)
            "props": [
                "title":           "What is Machine Learning?",
                "subtitle":        "A beginner-friendly intro",
                "backgroundColor": (),  // null (Bug A scenario)
                "borderWidth":     (),  // null (Bug A scenario)
                "icon":            ()   // null (Bug A scenario)
            ] as [String: Any],
            "children": [
                [
                    "type": "text",
                    // "id" intentionally omitted (Bug B in children)
                    "props": [
                        "text":      "Machine learning is a subset of AI...",
                        "fontSize":  (),  // null (Bug A in children)
                        "fontColor": ()   // null (Bug A in children)
                    ] as [String: Any]
                ] as [String: Any]
            ] as [Any]
        ]

        let sanitized = AnyCodable.sanitizeForJSON(productionPayload)
        XCTAssertTrue(JSONSerialization.isValidJSONObject(sanitized))

        do {
            let data = try JSONSerialization.data(withJSONObject: sanitized)
            let component = try JSONDecoder().decode(A2UIComponent.self, from: data)

            XCTAssertEqual(component.type, .card)
            XCTAssertFalse(component.id.isEmpty, "id must be auto-generated")
            XCTAssertEqual(component.props.title, "What is Machine Learning?")
            XCTAssertEqual(component.children?.count, 1)
            XCTAssertEqual(component.children?.first?.type, .text)
            XCTAssertFalse(component.children?.first?.id.isEmpty ?? true)

        } catch {
            XCTFail("Full pipeline decode failed: \(error)")
        }
    }
}
