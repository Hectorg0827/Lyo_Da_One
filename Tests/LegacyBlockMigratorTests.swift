import XCTest
@testable import Lyo

final class LegacyBlockMigratorTests: XCTestCase {
    
    // MARK: - Text Block
    
    func testTextBlockMigratesToSmartBlock() {
        let legacy = LegacyLessonBlock.text("Hello world")
        let smart = LegacyBlockMigrator.migrate(legacy)
        
        XCTAssertEqual(smart.type, .text)
        XCTAssertEqual(smart.subtype, "paragraph")
        if case .text(let p) = smart.content {
            XCTAssertEqual(p.text, "Hello world")
        } else {
            XCTFail("Expected .text content")
        }
    }
    
    // MARK: - Quiz
    
    func testQuizMigratesToSmartBlock() {
        let quiz = QuizData(
            type: "multiple_choice",
            question: "What is 2+2?",
            options: ["3", "4", "5"],
            correct: 1,
            explanation: "Basic math"
        )
        let legacy = LegacyLessonBlock.quiz(quiz)
        let smart = LegacyBlockMigrator.migrate(legacy)
        
        XCTAssertEqual(smart.type, .quiz)
        XCTAssertEqual(smart.subtype, "mcq")
        if case .quiz(let p) = smart.content {
            XCTAssertEqual(p.question, "What is 2+2?")
            XCTAssertEqual(p.options.count, 3)
            XCTAssertEqual(p.correctIndex, 1)
            XCTAssertEqual(p.explanation, "Basic math")
        } else {
            XCTFail("Expected .quiz content")
        }
    }
    
    // MARK: - Flashcard
    
    func testFlashcardMigratesToSmartBlock() {
        let data = FlashcardData(front: "Q", back: "A", tags: "swift")
        let legacy = LegacyLessonBlock.flashcard(data)
        let smart = LegacyBlockMigrator.migrate(legacy)
        
        XCTAssertEqual(smart.type, .flashcard)
        XCTAssertEqual(smart.subtype, "single")
        if case .flashcard(let p) = smart.content {
            XCTAssertEqual(p.front, "Q")
            XCTAssertEqual(p.back, "A")
            XCTAssertEqual(p.tags, "swift")
        } else {
            XCTFail("Expected .flashcard content")
        }
    }
    
    // MARK: - FlashcardSet → Deck
    
    func testFlashcardSetMigratesToDeck() {
        let set = FlashcardSetData(title: "Deck", cards: [
            FlashcardData(front: "F1", back: "B1"),
            FlashcardData(front: "F2", back: "B2")
        ])
        let legacy = LegacyLessonBlock.flashcardSet(set)
        let smart = LegacyBlockMigrator.migrate(legacy)
        
        XCTAssertEqual(smart.type, .flashcard)
        XCTAssertEqual(smart.subtype, "deck")
        // Deck gets first card's content
        if case .flashcard(let p) = smart.content {
            XCTAssertEqual(p.front, "F1")
        } else {
            XCTFail("Expected .flashcard content")
        }
    }
    
    // MARK: - Progress
    
    func testProgressMigratesToSmartBlock() {
        let data = ProgressData(completed: 3, total: 10, label: "Lessons")
        let legacy = LegacyLessonBlock.progress(data)
        let smart = LegacyBlockMigrator.migrate(legacy)
        
        XCTAssertEqual(smart.type, .progress)
        if case .progress(let p) = smart.content {
            XCTAssertEqual(p.completed, 3)
            XCTAssertEqual(p.total, 10)
            XCTAssertEqual(p.label, "Lessons")
        } else {
            XCTFail("Expected .progress content")
        }
    }
    
    // MARK: - Summary → Text/Summary
    
    func testSummaryMigratesToText() {
        let data = SummaryData(title: "Key Points", points: ["A", "B"])
        let legacy = LegacyLessonBlock.summary(data)
        let smart = LegacyBlockMigrator.migrate(legacy)
        
        XCTAssertEqual(smart.type, .text)
        XCTAssertEqual(smart.subtype, "summary")
        if case .text(let p) = smart.content {
            XCTAssertTrue(p.text.contains("Key Points"))
        } else {
            XCTFail("Expected .text content")
        }
    }
    
    // MARK: - Image → Media
    
    func testImageMigratesToMedia() {
        let data = ImageData(query: "sunset", caption: "A sunset")
        let legacy = LegacyLessonBlock.image(data)
        let smart = LegacyBlockMigrator.migrate(legacy)
        
        XCTAssertEqual(smart.type, .media)
        XCTAssertEqual(smart.subtype, "image")
    }
    
    // MARK: - MasteryMap
    
    func testMasteryMapMigratesToSmartBlock() {
        let node = MasteryNode(title: "Variables", status: "completed", masteryLevel: 1.0)
        let data = MasteryMapData(courseTitle: "Python", nodes: [node])
        let legacy = LegacyLessonBlock.masteryMap(data)
        let smart = LegacyBlockMigrator.migrate(legacy)
        
        XCTAssertEqual(smart.type, .masteryMap)
        if case .masteryMap(let p) = smart.content {
            XCTAssertEqual(p.title, "Python")
            XCTAssertEqual(p.nodes.count, 1)
            XCTAssertEqual(p.nodes[0].title, "Variables")
            XCTAssertEqual(p.nodes[0].status, "completed")
        } else {
            XCTFail("Expected .masteryMap content")
        }
    }
    
    // MARK: - CustomUI → Unknown
    
    func testCustomUIMigratesToUnknown() {
        let legacy = LegacyLessonBlock.customUI("some_future_type")
        let smart = LegacyBlockMigrator.migrate(legacy)
        
        XCTAssertEqual(smart.type, .unknown)
    }
    
    // MARK: - CinematicHook → Text/Hook
    
    func testCinematicHookMigratesToHook() {
        let data = CinematicHookData(title: "Intro", hook: "Imagine a world...")
        let legacy = LegacyLessonBlock.cinematicHook(data)
        let smart = LegacyBlockMigrator.migrate(legacy)
        
        XCTAssertEqual(smart.type, .text)
        XCTAssertEqual(smart.subtype, "hook")
        if case .text(let p) = smart.content {
            XCTAssertTrue(p.text.contains("Imagine a world"))
        } else {
            XCTFail("Expected .text content")
        }
    }
    
    // MARK: - Batch Migration
    
    func testMigrateAllConvertsAll() {
        let blocks: [LegacyLessonBlock] = [
            .text("Hello"),
            .customUI("x")
        ]
        let results = LegacyBlockMigrator.migrateAll(blocks)
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0].type, .text)
        XCTAssertEqual(results[1].type, .unknown)
    }
    
    // MARK: - Schema Version
    
    func testMigratedBlocksHaveSchemaVersion1() {
        let smart = LegacyBlockMigrator.migrate(.text("test"))
        XCTAssertEqual(smart.schemaVersion, 1)
    }
}
