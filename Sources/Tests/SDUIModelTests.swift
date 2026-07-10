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

    // MARK: - Production Backend Format (full Pydantic .dict() output)

    /// Mirrors the actual SceneStreamPayload sent by the backend's WebSocketManager.
    /// Source: lyo_app/ai_classroom/sdui_models.py::SceneStreamPayload + Scene + TeacherMessage.
    func testDecodeProductionScenePayload() throws {
        let json = """
        {
            "event_type": "scene_start",
            "timestamp": "2026-05-06T03:29:42.581025",
            "session_id": "Calligraphy",
            "user_id": "guest_session",
            "data": {},
            "room_id": null,
            "priority": 0,
            "scene": {
                "scene_id": "lifecycle_abc123",
                "scene_type": "instruction",
                "components": [
                    {
                        "component_id": "tm_1",
                        "type": "TeacherMessage",
                        "priority": 0,
                        "animation": "fade_in",
                        "delay_ms": 0,
                        "duration_ms": null,
                        "accessibility_label": null,
                        "language_code": "en-US",
                        "show_if": null,
                        "text": "Calligraphy is the art of beautiful writing. In Eastern traditions, it is considered a meditative practice that connects the writer to centuries of artistic heritage.",
                        "emotion": "encouraging",
                        "audio_mood": "calm",
                        "audio_url": null,
                        "avatar_expression": null,
                        "background_color": "#F8F9FA",
                        "concept_tags": ["calligraphy", "art", "meditation"],
                        "difficulty_level": "beginner"
                    }
                ],
                "metadata": {
                    "concept_tags": ["calligraphy"],
                    "difficulty_level": "beginner",
                    "estimated_duration_seconds": 45
                },
                "trigger_conditions": {"trigger_id": "t-1"},
                "next_scene_id": null,
                "fallback_scene_id": null
            },
            "is_final": false,
            "component_count": 1,
            "prefetch_assets": [],
            "next_scene_preview": null
        }
        """.data(using: .utf8)!

        let envelope = try decoder.decode(WebSocketEnvelope.self, from: json)
        XCTAssertEqual(envelope.type, "scene_start")
        XCTAssertEqual(envelope.sessionId, "Calligraphy")

        // Same path the LivingClassroomService uses to extract the scene
        let rootObj = try JSONSerialization.jsonObject(with: json) as! [String: Any]
        let sceneDict = rootObj["scene"] as! [String: Any]
        let sceneData = try JSONSerialization.data(withJSONObject: sceneDict)
        let scene = try decoder.decode(SDUIScene.self, from: sceneData)

        XCTAssertEqual(scene.id, "lifecycle_abc123")
        XCTAssertEqual(scene.sceneType, "instruction")
        XCTAssertEqual(scene.components.count, 1)

        let comp = scene.components[0]
        XCTAssertEqual(comp.id, "tm_1")
        XCTAssertEqual(comp.type, .teacherMessage)
        XCTAssertTrue(comp.content.contains("Calligraphy"))
        XCTAssertEqual(comp.animation, "fade_in")
        XCTAssertEqual(comp.emotion, "encouraging")
    }

    /// Mirrors a real ComponentRenderPayload streamed progressively after scene_start.
    func testDecodeProductionComponentRenderPayload() throws {
        let json = """
        {
            "event_type": "component_render",
            "timestamp": "2026-05-06T03:29:43.100000",
            "session_id": "Calligraphy",
            "user_id": "guest_session",
            "data": {},
            "component": {
                "component_id": "cta_1",
                "type": "CTAButton",
                "priority": 0,
                "animation": "fade_in",
                "delay_ms": 1500,
                "label": "Continue learning",
                "action_intent": "continue",
                "action_payload": {"next_lesson": "1"}
            },
            "render_immediately": false,
            "delay_after_previous_ms": 1500,
            "transition_duration_ms": 300
        }
        """.data(using: .utf8)!

        let rootObj = try JSONSerialization.jsonObject(with: json) as! [String: Any]
        let componentObj = rootObj["component"] as! [String: Any]
        let componentData = try JSONSerialization.data(withJSONObject: componentObj)
        let comp = try decoder.decode(SDUIComponent.self, from: componentData)

        XCTAssertEqual(comp.id, "cta_1")
        XCTAssertEqual(comp.type, .ctaButton)
        XCTAssertEqual(comp.content, "Continue learning")
        XCTAssertEqual(comp.actionIntent, "continue")
        XCTAssertEqual(comp.delayMs, 1500)
    }

    /// Backend types not yet rendered by iOS should still decode (.unknown) without crashing.
    func testDecodeUnsupportedBackendTypesAsUnknown() throws {
        let unsupportedTypes = [
            "ChatBubble",
            "InputField",
            "Celebration",
            "TypingIndicator",
            "ReflectionPrompt",
            "ExampleBlock"
        ]

        for typeName in unsupportedTypes {
            let json = """
            {
                "component_id": "x_\(typeName)",
                "type": "\(typeName)",
                "text": "Sample \(typeName) content",
                "delay_ms": 0,
                "animation": "fade_in"
            }
            """.data(using: .utf8)!

            let comp = try decoder.decode(SDUIComponent.self, from: json)
            XCTAssertEqual(comp.type, .unknown, "\(typeName) should decode to .unknown")
            XCTAssertEqual(comp.content, "Sample \(typeName) content",
                           "\(typeName) text content must still decode so fallback view shows it")
        }
    }

    /// LessonBlock pass-through for the BlockRendererView pipeline.
    /// Backend wraps a LiveLessonBlock-shaped dict inside `block_type` + `block`.
    func testDecodeLessonBlockComponent() throws {
        let json = """
        {
            "component_id": "lb_diagram_1",
            "type": "LessonBlock",
            "delay_ms": 800,
            "animation": "fade_in",
            "block_type": "diagram",
            "block": {
                "title": "Photosynthesis flow",
                "content": "How plants convert light to glucose",
                "mermaid": "graph LR; Sun[Sunlight]-->Leaf; CO2-->Leaf; Water-->Leaf; Leaf-->Glucose; Leaf-->Oxygen"
            }
        }
        """.data(using: .utf8)!

        let comp = try decoder.decode(SDUIComponent.self, from: json)
        XCTAssertEqual(comp.type, .lessonBlock)
        XCTAssertEqual(comp.id, "lb_diagram_1")
        XCTAssertNotNil(comp.lessonBlock, "lessonBlock must be populated for LessonBlock type")
        XCTAssertEqual(comp.lessonBlock?.type, .diagram)
        XCTAssertEqual(comp.lessonBlock?.title, "Photosynthesis flow")
        XCTAssertNotNil(comp.lessonBlock?.mermaid)
    }

    /// Verify a math LessonBlock (latex) decodes intact.
    func testDecodeLessonBlockMath() throws {
        let json = """
        {
            "component_id": "lb_math_1",
            "type": "LessonBlock",
            "delay_ms": 0,
            "animation": "fade_in",
            "block_type": "math",
            "block": {
                "title": "Light reaction",
                "latex": "6CO_2 + 6H_2O \\\\rightarrow C_6H_{12}O_6 + 6O_2"
            }
        }
        """.data(using: .utf8)!

        let comp = try decoder.decode(SDUIComponent.self, from: json)
        XCTAssertEqual(comp.type, .lessonBlock)
        XCTAssertEqual(comp.lessonBlock?.type, .math)
        XCTAssertNotNil(comp.lessonBlock?.latex)
    }

    /// Fallback scene from process_trigger's except block — must render so user isn't stuck.
    func testDecodeLifecycleFallbackScene() throws {
        let json = """
        {
            "event_type": "scene_start",
            "session_id": "Calligraphy",
            "scene": {
                "scene_id": "fallback_xyz",
                "scene_type": "instruction",
                "components": [
                    {
                        "component_id": "fb_1",
                        "type": "TeacherMessage",
                        "text": "Let's continue with your learning journey.",
                        "emotion": "encouraging",
                        "audio_mood": "calm",
                        "animation": "fade_in",
                        "delay_ms": 0
                    }
                ]
            },
            "component_count": 1,
            "is_final": true
        }
        """.data(using: .utf8)!

        let rootObj = try JSONSerialization.jsonObject(with: json) as! [String: Any]
        let sceneDict = rootObj["scene"] as! [String: Any]
        let sceneData = try JSONSerialization.data(withJSONObject: sceneDict)
        let scene = try decoder.decode(SDUIScene.self, from: sceneData)

        XCTAssertEqual(scene.components.count, 1)
        XCTAssertEqual(scene.components[0].type, .teacherMessage)
        XCTAssertEqual(scene.components[0].content, "Let's continue with your learning journey.")
    }
}
