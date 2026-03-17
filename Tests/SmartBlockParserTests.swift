import XCTest
@testable import Lyo

final class SmartBlockParserTests: XCTestCase {
    
    // MARK: - Basic Text Parsing
    
    func testPlainTextReturnsTextBlock() {
        let input = "Hello, I'm Lyo! Let me help you learn."
        let blocks = SmartBlockParser.parseResponse(input)
        
        XCTAssertEqual(blocks.count, 1)
        if case .text(let content) = blocks[0].block {
            XCTAssertEqual(content, input)
        } else {
            XCTFail("Expected .text block")
        }
    }
    
    // MARK: - Mastery Map Key-Value Format
    
    func testMasteryMapKeyValueFormat() {
        let input = """
        Here's your progress:
        :::mastery_map
        title: Python Basics
        nodes:
        - title: Variables
          status: completed
          mastery: 100%
        - title: Loops
          status: in_progress
          mastery: 50%
        :::
        Keep going!
        """
        
        let blocks = SmartBlockParser.parseResponse(input)
        
        // Should have 3 blocks: text, mastery_map, text
        XCTAssertGreaterThanOrEqual(blocks.count, 2, "Should have at least text + mastery_map blocks")
        
        // Find the mastery map block
        let masteryBlock = blocks.first { block in
            if case .masteryMap = block.block { return true }
            return false
        }
        
        XCTAssertNotNil(masteryBlock, "Should find a mastery_map block")
        
        if case .masteryMap(let data) = masteryBlock?.block {
            XCTAssertEqual(data.courseTitle, "Python Basics")
            XCTAssertGreaterThanOrEqual(data.nodes.count, 1, "Should parse at least one node")
        }
    }
    
    // MARK: - Mastery Map JSON Format (the bug case)
    
    func testMasteryMapJSONFormat() {
        let input = """
        :::mastery_map
        {
          "title": "Python Basics",
          "nodes": [
            {"id": "n1", "title": "Variables", "status": "completed"},
            {"id": "n2", "title": "Loops", "status": "in_progress"}
          ]
        }
        :::
        """
        
        let blocks = SmartBlockParser.parseResponse(input)
        
        let masteryBlock = blocks.first { block in
            if case .masteryMap = block.block { return true }
            return false
        }
        
        XCTAssertNotNil(masteryBlock, "Should parse JSON-format mastery_map without crashing")
        
        if case .masteryMap(let data) = masteryBlock?.block {
            XCTAssertEqual(data.courseTitle, "Python Basics")
            XCTAssertEqual(data.nodes.count, 2)
            XCTAssertEqual(data.nodes[0].title, "Variables")
            XCTAssertEqual(data.nodes[0].status, "completed")
            XCTAssertEqual(data.nodes[1].title, "Loops")
            XCTAssertEqual(data.nodes[1].status, "in_progress")
        } else {
            XCTFail("Expected .masteryMap block with valid data")
        }
    }
    
    // MARK: - Quiz Block
    
    func testQuizBlock() {
        let input = """
        :::quiz
        question: What is 2 + 2?
        options:
        - 3
        - 4
        - 5
        answer: 4
        explanation: Basic addition
        :::
        """
        
        let blocks = SmartBlockParser.parseResponse(input)
        
        let quizBlock = blocks.first { block in
            if case .quiz = block.block { return true }
            return false
        }
        
        XCTAssertNotNil(quizBlock, "Should parse quiz block")
        
        if case .quiz(let data) = quizBlock?.block {
            XCTAssertEqual(data.question, "What is 2 + 2?")
            XCTAssertEqual(data.options.count, 3)
            XCTAssertEqual(data.explanation, "Basic addition")
        }
    }
    
    // MARK: - Flashcard Block
    
    func testFlashcardBlock() {
        let input = """
        :::flashcard
        front: What is a variable?
        back: A named container for storing data values
        :::
        """
        
        let blocks = SmartBlockParser.parseResponse(input)
        
        let flashBlock = blocks.first { block in
            if case .flashcard = block.block { return true }
            return false
        }
        
        XCTAssertNotNil(flashBlock, "Should parse flashcard block")
        
        if case .flashcard(let data) = flashBlock?.block {
            XCTAssertEqual(data.front, "What is a variable?")
            XCTAssertEqual(data.back, "A named container for storing data values")
        }
    }
    
    // MARK: - Mixed Content
    
    func testMixedTextAndBlocks() {
        let input = """
        Let me explain variables!
        :::flashcard
        front: Variable
        back: A named storage location
        :::
        Now let's test your knowledge:
        :::quiz
        question: What stores data?
        options:
        - Variable
        - Function
        answer: Variable
        explanation: Variables store data values
        :::
        Great job!
        """
        
        let blocks = SmartBlockParser.parseResponse(input)
        
        // Should have 5 blocks: text, flashcard, text, quiz, text
        XCTAssertEqual(blocks.count, 5, "Should have 5 blocks: text, flashcard, text, quiz, text")
        
        if case .text = blocks[0].block { } else { XCTFail("Block 0 should be text") }
        if case .flashcard = blocks[1].block { } else { XCTFail("Block 1 should be flashcard") }
        if case .text = blocks[2].block { } else { XCTFail("Block 2 should be text") }
        if case .quiz = blocks[3].block { } else { XCTFail("Block 3 should be quiz") }
        if case .text = blocks[4].block { } else { XCTFail("Block 4 should be text") }
    }
    
    // MARK: - Empty Input
    
    func testEmptyInputReturnsNoBlocks() {
        let blocks = SmartBlockParser.parseResponse("")
        XCTAssertTrue(blocks.isEmpty)
    }
    
    // MARK: - Unknown Block Type
    
    func testUnknownBlockTypeReturnsCustomUI() {
        let input = """
        :::hologram
        content: some futuristic thing
        :::
        """
        
        let blocks = SmartBlockParser.parseResponse(input)
        
        let customBlock = blocks.first { block in
            if case .customUI = block.block { return true }
            return false
        }
        
        XCTAssertNotNil(customBlock, "Unknown block types should fall through to customUI")
    }
}
