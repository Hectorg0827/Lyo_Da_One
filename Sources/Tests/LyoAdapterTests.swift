import XCTest
@testable import Lyo

class LyoAdapterTests: XCTestCase {
    
    // MARK: - AI Director Tests
    
    func testCinematicMoodMapping() {
        // Given a block with "suspense" mood
        let block = LyoBlock(
            id: "test1",
            type: .concept,
            role: .hook, // Triggers cinematic
            content: AnyCodable(ConceptPayload(kind: "concept", markdown: "Content", keyTakeaway: "Title")),
            presentationHint: .cinematic,
            requiresInteraction: nil,
            interactionId: nil,
            mood: "suspense"
        )
        
        // When rendered
        let content = LyoAdapter.render(block)
        
        // Then it should have correct audio and haptics
        XCTAssertEqual(content.type, A2UIContentType.cinematic)
        XCTAssertEqual(content.cinematic?.mood, "suspense")
        XCTAssertEqual(content.cinematic?.audioTrack, "ambient_suspense")
        XCTAssertEqual(content.cinematic?.hapticPattern, "medium")
        XCTAssertEqual(content.layout, A2UILayout.overlay)
    }
    
    // MARK: - Generative UI Tests
    
    func testLayoutMapping() {
        // Given an inline concept block
        let block = LyoBlock(
            id: "test2",
            type: .concept,
            role: .normal,
            content: AnyCodable(ConceptPayload(kind: "concept", markdown: "Text", keyTakeaway: nil)),
            presentationHint: .inline,
            requiresInteraction: nil,
            interactionId: nil,
            mood: "neutral"
        )
        
        let content = LyoAdapter.render(block)
        
        // Then type should be text and layout should be standard
        XCTAssertEqual(content.type, A2UIContentType.text)
        XCTAssertEqual(content.layout, A2UILayout.standard)
        
        // Given a hero block NO takeaway (which normally renders as text but with hero layout)
        
        let heroBlock = LyoBlock(
            id: "test3",
            type: .concept,
            role: .normal,
            content: AnyCodable(ConceptPayload(kind: "concept", markdown: "Text", keyTakeaway: nil)),
            presentationHint: .hero,
            requiresInteraction: nil,
            interactionId: nil,
            mood: "neutral"
        )
        
        let heroContent = LyoAdapter.render(heroBlock)
        XCTAssertEqual(heroContent.type, A2UIContentType.text)
        XCTAssertEqual(heroContent.layout, A2UILayout.hero)
    }
    
    // MARK: - Stream Processor Tests
    
    func testStreamProcessor() {
        let processor = LyoStreamProcessor()
        
        // Simulate a stream of two blocks coming in chunks
        // NOTE: JSON keys must use snake_case to match LyoBlock CodingKeys
        let chunk1 = "{\"id\":\"1\", \"type\":\"con"
        let chunk2 = "cept\", \"role\":\"normal\", \"presentation_hint\":\"inline\", "
        // Escape quotes in JSON string
        let contentJson = "\"content\": { \"kind\": \"concept\", \"markdown\": \"Hello\", \"key_takeaway\": null }, \"mood\":\"neutral\" }"
        let chunk3 = contentJson
        let chunk4 = "\n{\"id\":\"2\", \"type\":\"quiz\", \"role\":\"assessment\", \"presentation_hint\":\"inline\", \"content\": {\"kind\":\"quiz\", \"question\":\"Q?\", \"options\":[{\"id\":\"a\",\"text\":\"Yes\"}], \"correct_option_id\":\"a\", \"explanation\":null}, \"mood\":\"neutral\"}"
        
        // 1. Incomplete chunk
        let result1 = processor.append(chunk1)
        XCTAssertTrue(result1.isEmpty)
        
        // 2. Still incomplete
        let result2 = processor.append(chunk2)
        XCTAssertTrue(result2.isEmpty)
        
        // 3. Complete first object
        let result3 = processor.append(chunk3)
        XCTAssertEqual(result3.count, 1)
        XCTAssertEqual(result3.first?.type, A2UIContentType.text) // Concept -> Text
        
        // 4. Complete second object immediately
        let result4 = processor.append(chunk4)
        XCTAssertEqual(result4.count, 1)
        XCTAssertEqual(result4.first?.type, A2UIContentType.quiz)
    }
}
