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
            presentationHint: .cinematic,
            content: AnyCodable(ConceptPayload(markdown: "Content", keyTakeaway: "Title")),
            mood: "suspense"
        )
        
        // When rendered
        let content = LyoAdapter.render(block)
        
        // Then it should have correct audio and haptics
        XCTAssertEqual(content.type, .cinematic)
        XCTAssertEqual(content.cinematic?.mood, "suspense")
        XCTAssertEqual(content.cinematic?.audioTrack, "ambient_suspense")
        XCTAssertEqual(content.cinematic?.hapticPattern, "medium")
    }
    
    // MARK: - Generative UI Tests
    
    func testLayoutMapping() {
        // Given an inline concept block
        let block = LyoBlock(
            id: "test2",
            type: .concept,
            role: .normal,
            presentationHint: .inline,
            content: AnyCodable(ConceptPayload(markdown: "Text", keyTakeaway: nil)),
            mood: "neutral"
        )
        
        let content = LyoAdapter.render(block)
        
        // Then layout should be standard
        XCTAssertEqual(content.layout, .standard)
        
        // Given a hero block NO takeaway (which normally renders as text but with hero layout)
        // Wait, LyoAdapter logic: if .hero AND takeaway -> Flashcard.
        // If .hero but NO takeaway -> Standard Text but with layout? 
        // Let's check logic:
        // default case in render sets layout: layout.
        // And `case .inline: layout = .standard`.
        // Let's test .hero presentation
        
        let heroBlock = LyoBlock(
            id: "test3",
            type: .concept,
            role: .normal,
            presentationHint: .hero,
            content: AnyCodable(ConceptPayload(markdown: "Text", keyTakeaway: nil)),
            mood: "neutral"
        )
        
        let heroContent = LyoAdapter.render(heroBlock)
        XCTAssertEqual(heroContent.layout, .hero)
    }
    
    // MARK: - Stream Processor Tests
    
    func testStreamProcessor() {
        let processor = LyoStreamProcessor()
        
        // Simulate a stream of two blocks coming in chunks
        let chunk1 = "{\"id\":\"1\", \"type\":\"con"
        let chunk2 = "cept\", \"role\":\"normal\", \"presentationHint\":\"inline\", "
        // Escape quotes in JSON string
        let contentJson = "\"content\": { \"markdown\": \"Hello\", \"keyTakeaway\": null }, \"mood\":\"neutral\" }"
        let chunk3 = contentJson
        let chunk4 = "\n{\"id\":\"2\", \"type\":\"quiz\", \"role\":\"assessment\", \"presentationHint\":\"inline\", \"content\": {\"question\":\"Q?\", \"options\":[], \"correctOptionId\":\"a\", \"explanation\":null}, \"mood\":\"neutral\"}"
        
        // 1. Incomplete chunk
        let result1 = processor.append(chunk1)
        XCTAssertTrue(result1.isEmpty)
        
        // 2. Still incomplete
        let result2 = processor.append(chunk2)
        XCTAssertTrue(result2.isEmpty)
        
        // 3. Complete first object
        let result3 = processor.append(chunk3)
        XCTAssertEqual(result3.count, 1)
        XCTAssertEqual(result3.first?.type, .text) // Concept -> Text
        
        // 4. Complete second object immediately
        let result4 = processor.append(chunk4)
        XCTAssertEqual(result4.count, 1)
        XCTAssertEqual(result4.first?.type, .quiz)
    }
}
