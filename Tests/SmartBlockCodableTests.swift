import XCTest
@testable import Lyo

final class SmartBlockCodableTests: XCTestCase {
    
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()
    
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        return e
    }()
    
    // MARK: - Roundtrip
    
    func testTextBlockRoundtrip() throws {
        let block = SmartBlock(
            type: .text,
            subtype: "paragraph",
            content: .text(TextBlockPayload(text: "Hello", style: "paragraph"))
        )
        
        let data = try encoder.encode(block)
        let decoded = try decoder.decode(SmartBlock.self, from: data)
        
        XCTAssertEqual(decoded.type, .text)
        XCTAssertEqual(decoded.subtype, "paragraph")
        if case .text(let p) = decoded.content {
            XCTAssertEqual(p.text, "Hello")
        } else {
            XCTFail("Expected .text content")
        }
    }
    
    func testQuizBlockRoundtrip() throws {
        let block = SmartBlock(
            type: .quiz,
            subtype: "mcq",
            content: .quiz(QuizBlockPayload(
                question: "2+2?",
                options: [
                    QuizOptionPayload(id: "a", text: "3"),
                    QuizOptionPayload(id: "b", text: "4")
                ],
                correctIndex: 1,
                explanation: "Math"
            ))
        )
        
        let data = try encoder.encode(block)
        let decoded = try decoder.decode(SmartBlock.self, from: data)
        
        XCTAssertEqual(decoded.type, .quiz)
        if case .quiz(let p) = decoded.content {
            XCTAssertEqual(p.question, "2+2?")
            XCTAssertEqual(p.options.count, 2)
            XCTAssertEqual(p.correctIndex, 1)
        } else {
            XCTFail("Expected .quiz content")
        }
    }
    
    func testMasteryMapRoundtrip() throws {
        let block = SmartBlock(
            type: .masteryMap,
            content: .masteryMap(MasteryMapBlockPayload(
                title: "Python",
                nodes: [
                    MasteryNodePayload(nodeId: "n1", title: "Variables", status: "completed", masteryLevel: 1.0)
                ]
            ))
        )
        
        let data = try encoder.encode(block)
        let decoded = try decoder.decode(SmartBlock.self, from: data)
        
        XCTAssertEqual(decoded.type, .masteryMap)
        if case .masteryMap(let p) = decoded.content {
            XCTAssertEqual(p.title, "Python")
            XCTAssertEqual(p.nodes.count, 1)
            XCTAssertEqual(p.nodes[0].title, "Variables")
        } else {
            XCTFail("Expected .masteryMap content")
        }
    }
    
    // MARK: - Unknown Type Decode
    
    func testUnknownTypeDecodesToUnknown() throws {
        let json = """
        {
            "id": "test123",
            "schema_version": 1,
            "type": "futureWidget",
            "content": {"data": "something"}
        }
        """.data(using: .utf8)!
        
        let decoded = try decoder.decode(SmartBlock.self, from: json)
        
        XCTAssertEqual(decoded.type, .unknown)
        XCTAssertEqual(decoded.id, "test123")
        if case .unknown(let rawJSON) = decoded.content {
            XCTAssertNotNil(rawJSON["data"])
        } else {
            XCTFail("Expected .unknown content")
        }
    }
    
    // MARK: - Backend JSON Decode
    
    func testDecodesBackendSmartBlockJSON() throws {
        // Simulate JSON from Python SmartBlock schema (snake_case)
        let json = """
        {
            "id": "abc123",
            "schema_version": 1,
            "type": "code",
            "subtype": "snippet",
            "content": {
                "language": "python",
                "code": "print('hello')",
                "is_runnable": true
            }
        }
        """.data(using: .utf8)!
        
        let decoded = try decoder.decode(SmartBlock.self, from: json)
        
        XCTAssertEqual(decoded.type, .code)
        XCTAssertEqual(decoded.subtype, "snippet")
        if case .code(let p) = decoded.content {
            XCTAssertEqual(p.language, "python")
            XCTAssertEqual(p.code, "print('hello')")
        } else {
            XCTFail("Expected .code content")
        }
    }
    
    // MARK: - Schema Version
    
    func testMissingSchemaVersionDefaults() throws {
        let json = """
        {
            "type": "text",
            "content": {"text": "hi"}
        }
        """.data(using: .utf8)!
        
        let decoded = try decoder.decode(SmartBlock.self, from: json)
        XCTAssertEqual(decoded.schemaVersion, 1)
    }
    
    func testSchemaVersionPreserved() throws {
        let json = """
        {
            "schema_version": 2,
            "type": "text",
            "content": {"text": "hi"}
        }
        """.data(using: .utf8)!
        
        let decoded = try decoder.decode(SmartBlock.self, from: json)
        XCTAssertEqual(decoded.schemaVersion, 2)
    }
    
    // MARK: - FlashcardBlock
    
    func testFlashcardBlockRoundtrip() throws {
        let block = SmartBlock(
            type: .flashcard, subtype: "single",
            content: .flashcard(FlashcardBlockPayload(front: "Q", back: "A"))
        )
        let data = try encoder.encode(block)
        let decoded = try decoder.decode(SmartBlock.self, from: data)
        
        if case .flashcard(let p) = decoded.content {
            XCTAssertEqual(p.front, "Q")
            XCTAssertEqual(p.back, "A")
        } else {
            XCTFail("Expected .flashcard content")
        }
    }
    
    // MARK: - DataViz (Mermaid)
    
    func testDataVizMermaidRoundtrip() throws {
        let mermaid = "graph TD; A-->B; B-->C;"
        let block = SmartBlock(
            type: .dataViz, subtype: "diagram",
            content: .dataViz(DataVizBlockPayload(format: "mermaid", source: mermaid))
        )
        let data = try encoder.encode(block)
        let decoded = try decoder.decode(SmartBlock.self, from: data)
        
        if case .dataViz(let p) = decoded.content {
            XCTAssertEqual(p.format, "mermaid")
            XCTAssertEqual(p.source, mermaid)
        } else {
            XCTFail("Expected .dataViz content")
        }
    }
}
