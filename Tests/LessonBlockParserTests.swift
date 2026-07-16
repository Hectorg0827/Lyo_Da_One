import XCTest
@testable import Lyo

final class LessonBlockParserTests: XCTestCase {
    
    // MARK: - Markdown Parsing Tests
    
    func testParseMarkdownHeaders() {
        let markdown = """
        # Heading 1
        ## Heading 2
        ### Heading 3
        """
        let blocks = LessonBlockParser.parseFromMarkdown(markdown)
        
        XCTAssertEqual(blocks.count, 3)
        XCTAssertEqual(blocks[0].type, .heading)
        XCTAssertEqual(blocks[0].title, "Heading 1")
        XCTAssertEqual(blocks[1].type, .heading)
        XCTAssertEqual(blocks[1].title, "Heading 2")
        XCTAssertEqual(blocks[2].type, .heading)
        XCTAssertEqual(blocks[2].title, "Heading 3")
    }
    
    func testParseMarkdownParagraphs() {
        let markdown = """
        This is first paragraph.
        
        This is second paragraph.
        """
        let blocks = LessonBlockParser.parseFromMarkdown(markdown)
        
        XCTAssertEqual(blocks.count, 2)
        XCTAssertEqual(blocks[0].type, .paragraph)
        XCTAssertEqual(blocks[0].content, "This is first paragraph.")
    }
    
    func testParseMarkdownImages() {
        let markdown = "![Cool Image](https://example.com/image.png)"
        let blocks = LessonBlockParser.parseFromMarkdown(markdown)
        
        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0].type, .image)
        XCTAssertEqual(blocks[0].imageURL?.absoluteString, "https://example.com/image.png")
        XCTAssertEqual(blocks[0].altText, "Cool Image")
    }
    
    func testParseMarkdownCodeBlocks() {
        let markdown = """
        ```swift
        let x = 10
        ```
        """
        let blocks = LessonBlockParser.parseFromMarkdown(markdown)
        
        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0].type, .code)
        XCTAssertEqual(blocks[0].language, "swift")
        XCTAssertEqual(blocks[0].code, "let x = 10")
    }
    
    // MARK: - JSON Parsing Tests
    
    func testParseJSONBlocksArray() throws {
        let json = """
        [
            {
                "id": "b1",
                "type": "text",
                "content": "Hello World"
            },
            {
                "id": "b2",
                "type": "quiz_mcq",
                "question": "1+1?",
                "options": ["1", "2"],
                "correct_index": 1
            }
        ]
        """.data(using: .utf8)!
        
        let blocks = LessonBlockParser.parse(from: json)
        
        XCTAssertEqual(blocks.count, 2)
        XCTAssertEqual(blocks[0].id, "b1")
        XCTAssertEqual(blocks[0].type, .text)
        XCTAssertEqual(blocks[1].type, .quizMcq)
        XCTAssertEqual(blocks[1].question, "1+1?")
    }
    
    func testParseJSONWrappedBlocks() throws {
        let json = """
        {
            "blocks": [
                { "type": "paragraph", "content": "Sample" }
            ]
        }
        """.data(using: .utf8)!
        
        let blocks = LessonBlockParser.parse(from: json)
        
        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0].type, .paragraph)
        XCTAssertEqual(blocks[0].content, "Sample")
    }
    
    func testParsingNormalization() throws {
        let json = """
        {
            "type": "QUIZ-MCQ",
            "content": "Normalized Test"
        }
        """.data(using: .utf8)!
        
        let blocks = LessonBlockParser.parse(from: json)
        
        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0].type, .quizMcq)
    }
    
    func testErrorFallback() {
        let invalidData = "invalid json".data(using: .utf8)!
        let blocks = LessonBlockParser.parse(from: invalidData)
        
        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0].type, .callout)
        XCTAssertTrue(blocks[0].title?.contains("Error") ?? false)
    }
}
