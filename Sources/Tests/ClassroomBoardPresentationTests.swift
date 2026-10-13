import XCTest
@testable import Lyo

@MainActor
final class ClassroomBoardPresentationTests: XCTestCase {
    func testStructuredToolsDecodeWithoutLosingCodeIndentation() throws {
        let data = Data(#"{"version":1,"blocks":[{"kind":"steps","items":["Subtract 5","Divide by 3"]},{"kind":"code","language":"python","text":"    return total"},{"kind":"table","headers":["Term","Meaning"],"rows":[["Bonjour","Hello"]]}]}"#.utf8)
        let document = try JSONDecoder().decode(ClassroomBoardDocument.self, from: data)
        XCTAssertTrue(document.isValid)
        XCTAssertEqual(document.blocks[1].text, "    return total")
        XCTAssertEqual(try JSONDecoder().decode(ClassroomBoardDocument.self, from: JSONEncoder().encode(document)), document)
    }

    func testMalformedDocumentRetainsCompleteExampleFallback() throws {
        let data = Data(#"{"component_id":"example","type":"ExampleBlock","title":"Observe","content":"Complete teaching content.","board_document":{"version":1,"blocks":[{"kind":"table","headers":["A","B"],"rows":[["A only"]]}]}}"#.utf8)
        let example = try JSONDecoder().decode(SDUIComponent.self, from: data)
        XCTAssertNil(example.boardDocument)
        XCTAssertEqual(example.content, "Complete teaching content.")
        XCTAssertEqual(example.resolvedPresentationRole, "board")
    }

    func testAdapterSeparatesExplanationBoardReferenceAndRecovery() throws {
        let components = [
            SDUIComponent(id: "teacher", type: .teacherMessage, content: "Follow the transformation."),
            SDUIComponent(id: "board:step", type: .exampleBlock, content: "1. Observe\n2. Explain", presentationRole: "board"),
            SDUIComponent(id: "classroom-board-memory", type: .exampleBlock, content: "Earlier anchor"),
            SDUIComponent(id: "classroom-recovery/notice", type: .exampleBlock, content: "Retry to carry on."),
            SDUIComponent(id: "retry", type: .ctaButton, content: "Retry this step", actionIntent: "retry"),
        ]
        let step = try XCTUnwrap(ActiveLessonAdapter.steps(from: components).last)
        XCTAssertEqual(step.teachingText, "Follow the transformation.")
        XCTAssertTrue(step.teachingExamples.isEmpty)
        XCTAssertEqual(step.workspaceComponents.map(\.resolvedPresentationRole), ["board", "reference", "recovery"])
        XCTAssertEqual(step.primaryActionIntent, "retry")
        XCTAssertEqual(step.primaryActionComponentId, "retry")
    }
}
