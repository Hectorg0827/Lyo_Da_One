import XCTest
@testable import Lyo

final class SDUIModelTests: XCTestCase {
    
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .useDefaultKeys
        return d
    }()
    
    // MARK: - SDUIComponent Flexible Key Decode
    
    func testDecodeWithComponentIdKey() throws {
        let json = """
        {
            "component_id": "c1",
            "type": "TeacherMessage",
            "content": "Hello class",
            "delay_ms": 100,
            "animation": "fade_in"
        }
        """.data(using: .utf8)!
        
        let component = try decoder.decode(SDUIComponent.self, from: json)
        XCTAssertEqual(component.id, "c1")
        XCTAssertEqual(component.type, .teacherMessage)
        XCTAssertEqual(component.content, "Hello class")
        XCTAssertEqual(component.delayMs, 100)
    }
    
    func testDecodeWithIdKey() throws {
        let json = """
        {
            "id": "c2",
            "type": "TextBlock",
            "content": "Some text",
            "delay_ms": 0,
            "animation": "slide_up"
        }
        """.data(using: .utf8)!
        
        let component = try decoder.decode(SDUIComponent.self, from: json)
        XCTAssertEqual(component.id, "c2")
        XCTAssertEqual(component.type, .textBlock)
        XCTAssertEqual(component.content, "Some text")
    }
    
    func testDecodeWithTextKeyFallback() throws {
        let json = """
        {
            "component_id": "c3",
            "type": "StudentPrompt",
            "text": "What do you think?",
            "delay_ms": 200,
            "animation": "bounce"
        }
        """.data(using: .utf8)!
        
        let component = try decoder.decode(SDUIComponent.self, from: json)
        XCTAssertEqual(component.content, "What do you think?")
        XCTAssertEqual(component.type, .studentPrompt)
    }
    
    func testDecodeWithLabelKeyFallback() throws {
        let json = """
        {
            "component_id": "c4",
            "type": "CTAButton",
            "label": "Continue",
            "delay_ms": 0,
            "animation": "fade_in",
            "action_intent": "next_scene"
        }
        """.data(using: .utf8)!
        
        let component = try decoder.decode(SDUIComponent.self, from: json)
        XCTAssertEqual(component.content, "Continue")
        XCTAssertEqual(component.type, .ctaButton)
        XCTAssertEqual(component.actionIntent, "next_scene")
    }
    
    func testDecodeWithNoContentKeyDefaultsToEmpty() throws {
        let json = """
        {
            "component_id": "c5",
            "type": "ProgressBar",
            "delay_ms": 0,
            "animation": "fade_in"
        }
        """.data(using: .utf8)!
        
        let component = try decoder.decode(SDUIComponent.self, from: json)
        XCTAssertEqual(component.content, "")
    }
    
    func testDecodeOptionalFieldsDefault() throws {
        let json = """
        {
            "component_id": "c6",
            "type": "TeacherMessage",
            "content": "Minimal"
        }
        """.data(using: .utf8)!
        
        let component = try decoder.decode(SDUIComponent.self, from: json)
        XCTAssertEqual(component.delayMs, 0)
        XCTAssertEqual(component.animation, "fade_in")
        XCTAssertNil(component.emotion)
        XCTAssertNil(component.studentName)
        XCTAssertNil(component.question)
        XCTAssertNil(component.options)
        XCTAssertNil(component.actionIntent)
        XCTAssertNil(component.actionPayload)
    }
    
    // MARK: - SDUIComponent Full Fields
    
    func testDecodeWithAllOptionalFields() throws {
        let json = """
        {
            "component_id": "c7",
            "type": "QuizCard",
            "content": "Question time",
            "delay_ms": 500,
            "animation": "pop",
            "emotion": "curious",
            "student_name": "Alex",
            "question": "What is 2+2?",
            "options": [{"id": "a", "label": "3"}, {"id": "b", "label": "4"}],
            "action_intent": "submit_quiz",
            "action_payload": {"quiz_id": "q1"}
        }
        """.data(using: .utf8)!
        
        let component = try decoder.decode(SDUIComponent.self, from: json)
        XCTAssertEqual(component.type, .quizCard)
        XCTAssertEqual(component.emotion, "curious")
        XCTAssertEqual(component.studentName, "Alex")
        XCTAssertEqual(component.question, "What is 2+2?")
        XCTAssertEqual(component.options?.count, 2)
        XCTAssertEqual(component.options?.first?.label, "3")
        XCTAssertEqual(component.actionIntent, "submit_quiz")
        XCTAssertEqual(component.actionPayload?["quiz_id"], "q1")
    }
    
    // MARK: - ComponentType Decode
    
    func testUnknownComponentTypeDecodesToUnknown() throws {
        let json = """
        {
            "component_id": "c8",
            "type": "FutureWidget",
            "content": "Forward compat"
        }
        """.data(using: .utf8)!
        
        let component = try decoder.decode(SDUIComponent.self, from: json)
        XCTAssertEqual(component.type, .unknown)
    }
    
    // MARK: - Encode → Decode roundtrip
    
    func testEncodeDecodeRoundtrip() throws {
        let json = """
        {
            "component_id": "rt1",
            "type": "TeacherMessage",
            "content": "Hello world",
            "delay_ms": 250,
            "animation": "slide_up",
            "emotion": "happy"
        }
        """.data(using: .utf8)!
        
        let decoded = try decoder.decode(SDUIComponent.self, from: json)
        let encoded = try JSONEncoder().encode(decoded)
        let roundtrip = try decoder.decode(SDUIComponent.self, from: encoded)
        
        XCTAssertEqual(decoded.id, roundtrip.id)
        XCTAssertEqual(decoded.type, roundtrip.type)
        XCTAssertEqual(decoded.content, roundtrip.content)
        XCTAssertEqual(decoded.delayMs, roundtrip.delayMs)
        XCTAssertEqual(decoded.emotion, roundtrip.emotion)
    }
    
    // MARK: - SDUIScene
    
    func testDecodeSceneWithSceneId() throws {
        let json = """
        {
            "scene_id": "s1",
            "scene_type": "lecture",
            "components": [
                {
                    "component_id": "c1",
                    "type": "TeacherMessage",
                    "content": "Welcome"
                }
            ]
        }
        """.data(using: .utf8)!
        
        let scene = try decoder.decode(SDUIScene.self, from: json)
        XCTAssertEqual(scene.id, "s1")
        XCTAssertEqual(scene.sceneType, "lecture")
        XCTAssertEqual(scene.components.count, 1)
    }
    
    func testDecodeSceneWithIdFallback() throws {
        let json = """
        {
            "id": "s2",
            "scene_type": "quiz",
            "components": []
        }
        """.data(using: .utf8)!
        
        let scene = try decoder.decode(SDUIScene.self, from: json)
        XCTAssertEqual(scene.id, "s2")
        XCTAssertEqual(scene.sceneType, "quiz")
        XCTAssertTrue(scene.components.isEmpty)
    }
    
    // MARK: - WebSocketEnvelope
    
    func testDecodeWebSocketEnvelopeWithType() throws {
        let json = """
        {
            "type": "scene_stream",
            "session_id": "abc123"
        }
        """.data(using: .utf8)!
        
        let envelope = try decoder.decode(WebSocketEnvelope.self, from: json)
        XCTAssertEqual(envelope.type, "scene_stream")
        XCTAssertEqual(envelope.sessionId, "abc123")
    }
    
    func testDecodeWebSocketEnvelopeWithEventTypeFallback() throws {
        let json = """
        {
            "event_type": "control",
            "session_id": "xyz"
        }
        """.data(using: .utf8)!
        
        let envelope = try decoder.decode(WebSocketEnvelope.self, from: json)
        XCTAssertEqual(envelope.type, "control")
    }
    
    func testDecodeWebSocketEnvelopeWithNoTypeDefaultsToUnknown() throws {
        let json = """
        {
            "session_id": "test"
        }
        """.data(using: .utf8)!
        
        let envelope = try decoder.decode(WebSocketEnvelope.self, from: json)
        XCTAssertEqual(envelope.type, "unknown")
    }
}
