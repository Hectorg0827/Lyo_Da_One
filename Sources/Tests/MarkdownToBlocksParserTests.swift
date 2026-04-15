import XCTest
@testable import Lyo

@MainActor
final class MarkdownToBlocksParserTests: XCTestCase {
    
    // MARK: - Empty / Whitespace Input
    
    func testEmptyContentReturnsEmptyArray() {
        let blocks = LiveClassroomViewModel.parseMarkdownIntoBlocks(
            lessonId: "l1", title: nil, content: ""
        )
        XCTAssertTrue(blocks.isEmpty)
    }
    
    func testWhitespaceOnlyContentReturnsEmptyArray() {
        let blocks = LiveClassroomViewModel.parseMarkdownIntoBlocks(
            lessonId: "l1", title: nil, content: "   \n  \n   "
        )
        XCTAssertTrue(blocks.isEmpty)
    }
    
    // MARK: - Title Handling
    
    func testTitleCreatesHeadingBlock() {
        let blocks = LiveClassroomViewModel.parseMarkdownIntoBlocks(
            lessonId: "l1", title: "Introduction to Swift", content: "Some text."
        )
        XCTAssertGreaterThanOrEqual(blocks.count, 2)
        XCTAssertEqual(blocks[0].type, .heading)
        XCTAssertEqual(blocks[0].title, "Introduction to Swift")
        XCTAssertEqual(blocks[0].subtitle, "h2")
    }
    
    func testNilTitleSkipsHeading() {
        let blocks = LiveClassroomViewModel.parseMarkdownIntoBlocks(
            lessonId: "l1", title: nil, content: "Just a paragraph."
        )
        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0].type, .paragraph)
    }
    
    func testEmptyTitleSkipsHeading() {
        let blocks = LiveClassroomViewModel.parseMarkdownIntoBlocks(
            lessonId: "l1", title: "", content: "Just a paragraph."
        )
        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0].type, .paragraph)
    }
    
    // MARK: - Headings (# ## ###)
    
    func testH1Headed() {
        let blocks = LiveClassroomViewModel.parseMarkdownIntoBlocks(
            lessonId: "l1", title: nil, content: "# Big Heading"
        )
        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0].type, .heading)
        XCTAssertEqual(blocks[0].title, "Big Heading")
        XCTAssertEqual(blocks[0].subtitle, "h1")
    }
    
    func testH2Heading() {
        let blocks = LiveClassroomViewModel.parseMarkdownIntoBlocks(
            lessonId: "l1", title: nil, content: "## Medium Heading"
        )
        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0].type, .heading)
        XCTAssertEqual(blocks[0].title, "Medium Heading")
        XCTAssertEqual(blocks[0].subtitle, "h2")
    }
    
    func testH3Heading() {
        let blocks = LiveClassroomViewModel.parseMarkdownIntoBlocks(
            lessonId: "l1", title: nil, content: "### Small Heading"
        )
        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0].type, .heading)
        XCTAssertEqual(blocks[0].title, "Small Heading")
        XCTAssertEqual(blocks[0].subtitle, "h3")
    }
    
    // MARK: - Code Blocks
    
    func testFencedCodeBlock() {
        let md = """
        ```swift
        let x = 42
        print(x)
        ```
        """
        let blocks = LiveClassroomViewModel.parseMarkdownIntoBlocks(
            lessonId: "l1", title: nil, content: md
        )
        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0].type, .code)
        XCTAssertEqual(blocks[0].language, "swift")
        XCTAssertTrue(blocks[0].code?.contains("let x = 42") == true)
        XCTAssertTrue(blocks[0].code?.contains("print(x)") == true)
    }
    
    func testCodeBlockWithoutLanguage() {
        let md = """
        ```
        echo "hello"
        ```
        """
        let blocks = LiveClassroomViewModel.parseMarkdownIntoBlocks(
            lessonId: "l1", title: nil, content: md
        )
        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0].type, .code)
        XCTAssertNil(blocks[0].language)
    }
    
    // MARK: - Blockquotes / Callouts
    
    func testSingleBlockquote() {
        let md = "> This is important advice."
        let blocks = LiveClassroomViewModel.parseMarkdownIntoBlocks(
            lessonId: "l1", title: nil, content: md
        )
        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0].type, .callout)
        XCTAssertEqual(blocks[0].content, "This is important advice.")
    }
    
    func testMultiLineBlockquote() {
        let md = """
        > Line one
        > Line two
        > Line three
        """
        let blocks = LiveClassroomViewModel.parseMarkdownIntoBlocks(
            lessonId: "l1", title: nil, content: md
        )
        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0].type, .callout)
        XCTAssertEqual(blocks[0].content, "Line one\nLine two\nLine three")
    }
    
    // MARK: - Numbered Lists → stepByStep
    
    func testNumberedListCreatesStepByStep() {
        let md = """
        1. First step
        2. Second step
        3. Third step
        """
        let blocks = LiveClassroomViewModel.parseMarkdownIntoBlocks(
            lessonId: "l1", title: nil, content: md
        )
        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0].type, .stepByStep)
        XCTAssertTrue(blocks[0].content?.contains("1. First step") == true)
        XCTAssertTrue(blocks[0].content?.contains("3. Third step") == true)
    }
    
    // MARK: - Bullet Lists
    
    func testBulletList() {
        let md = """
        - Item A
        - Item B
        - Item C
        """
        let blocks = LiveClassroomViewModel.parseMarkdownIntoBlocks(
            lessonId: "l1", title: nil, content: md
        )
        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0].type, .paragraph)
        XCTAssertTrue(blocks[0].content?.contains("- Item A") == true)
    }
    
    // MARK: - Horizontal Rules
    
    func testHorizontalRuleIsSkipped() {
        let md = """
        Above
        
        ---
        
        Below
        """
        let blocks = LiveClassroomViewModel.parseMarkdownIntoBlocks(
            lessonId: "l1", title: nil, content: md
        )
        // Should have 2 paragraphs (above and below), hr is skipped
        XCTAssertEqual(blocks.count, 2)
        XCTAssertEqual(blocks[0].content, "Above")
        XCTAssertEqual(blocks[1].content, "Below")
    }
    
    // MARK: - Paragraphs
    
    func testMultipleLinesParagraph() {
        let md = """
        Line one of paragraph.
        Line two of same paragraph.
        """
        let blocks = LiveClassroomViewModel.parseMarkdownIntoBlocks(
            lessonId: "l1", title: nil, content: md
        )
        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0].type, .paragraph)
        XCTAssertTrue(blocks[0].content?.contains("Line one") == true)
        XCTAssertTrue(blocks[0].content?.contains("Line two") == true)
    }
    
    func testBlankLineSplitsParagraphs() {
        let md = """
        First paragraph.
        
        Second paragraph.
        """
        let blocks = LiveClassroomViewModel.parseMarkdownIntoBlocks(
            lessonId: "l1", title: nil, content: md
        )
        XCTAssertEqual(blocks.count, 2)
        XCTAssertEqual(blocks[0].content, "First paragraph.")
        XCTAssertEqual(blocks[1].content, "Second paragraph.")
    }
    
    // MARK: - Mixed Content
    
    func testComplexMixedMarkdown() {
        let md = """
        # Introduction
        
        This is the intro paragraph with some important details.
        
        ## Key Concepts
        
        > Remember: practice makes perfect
        
        ### Code Example
        
        ```python
        def hello():
            print("Hello!")
        ```
        
        1. First do this
        2. Then do that
        3. Finally check results
        """
        
        let blocks = LiveClassroomViewModel.parseMarkdownIntoBlocks(
            lessonId: "l1", title: "Test Lesson", content: md
        )
        
        // Title + h1 + paragraph + h2 + callout + h3 + code + stepByStep
        XCTAssertGreaterThanOrEqual(blocks.count, 7)
        
        // First block is the title heading
        XCTAssertEqual(blocks[0].type, .heading)
        XCTAssertEqual(blocks[0].title, "Test Lesson")
        
        // Find the code block
        let codeBlock = blocks.first { $0.type == .code }
        XCTAssertNotNil(codeBlock)
        XCTAssertEqual(codeBlock?.language, "python")
        XCTAssertTrue(codeBlock?.code?.contains("def hello():") == true)
        
        // Find the callout
        let calloutBlock = blocks.first { $0.type == .callout }
        XCTAssertNotNil(calloutBlock)
        XCTAssertTrue(calloutBlock?.content?.contains("practice makes perfect") == true)
        
        // Find step-by-step
        let stepsBlock = blocks.first { $0.type == .stepByStep }
        XCTAssertNotNil(stepsBlock)
    }
    
    // MARK: - Block ID Uniqueness
    
    func testAllBlockIdsAreUnique() {
        let md = """
        # Heading
        
        Paragraph one.
        
        Paragraph two.
        
        ```swift
        let x = 1
        ```
        
        > A callout
        """
        
        let blocks = LiveClassroomViewModel.parseMarkdownIntoBlocks(
            lessonId: "test", title: nil, content: md
        )
        
        let ids = blocks.map { $0.id }
        let uniqueIds = Set(ids)
        XCTAssertEqual(ids.count, uniqueIds.count, "All block IDs should be unique")
    }
    
    func testBlockIdsContainLessonId() {
        let blocks = LiveClassroomViewModel.parseMarkdownIntoBlocks(
            lessonId: "my_lesson_42", title: "Title", content: "Some content"
        )
        
        for block in blocks {
            XCTAssertTrue(block.id.hasPrefix("my_lesson_42_"),
                          "Block ID '\(block.id)' should start with lesson ID prefix")
        }
    }
    
    // MARK: - Edge Cases
    
    func testUnclosedCodeBlockHandledGracefully() {
        let md = """
        ```python
        x = 1
        y = 2
        """
        // Should not crash — collects lines until end
        let blocks = LiveClassroomViewModel.parseMarkdownIntoBlocks(
            lessonId: "l1", title: nil, content: md
        )
        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0].type, .code)
        XCTAssertTrue(blocks[0].code?.contains("x = 1") == true)
    }
    
    func testOnlyHeadingsNoContent() {
        let md = """
        # One
        ## Two
        ### Three
        """
        let blocks = LiveClassroomViewModel.parseMarkdownIntoBlocks(
            lessonId: "l1", title: nil, content: md
        )
        XCTAssertEqual(blocks.count, 3)
        XCTAssertTrue(blocks.allSatisfy { $0.type == .heading })
    }
    
    func testConsecutiveCodeBlocks() {
        let md = """
        ```swift
        let a = 1
        ```
        
        ```python
        b = 2
        ```
        """
        let blocks = LiveClassroomViewModel.parseMarkdownIntoBlocks(
            lessonId: "l1", title: nil, content: md
        )
        let codeBlocks = blocks.filter { $0.type == .code }
        XCTAssertEqual(codeBlocks.count, 2)
        XCTAssertEqual(codeBlocks[0].language, "swift")
        XCTAssertEqual(codeBlocks[1].language, "python")
    }
}
