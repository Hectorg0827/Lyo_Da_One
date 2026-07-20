import Foundation

// MARK: - Legacy Block Migrator

/// Converts old `LegacyLessonBlock` and `LiveLessonBlock` types into the unified `SmartBlock` format.
/// Used when displaying previously-cached content from `GeneratedContentStore`.
struct LegacyBlockMigrator {
    
    /// Convert a `LegacyLessonBlock` (13 cases from SmartBlockParser) to `SmartBlock`
    static func migrate(_ legacy: LegacyLessonBlock) -> SmartBlock {
        switch legacy {
        case .text(let content):
            return SmartBlock(
                type: .text,
                subtype: "paragraph",
                content: .text(TextBlockPayload(text: content))
            )
            
        case .quiz(let data):
            let options = data.options.enumerated().map { QuizOptionPayload(id: "\($0.offset)", text: $0.element) }
            return SmartBlock(
                type: .quiz,
                subtype: "mcq",
                content: .quiz(QuizBlockPayload(
                    question: data.question,
                    options: options,
                    correctIndex: data.correct,
                    explanation: data.explanation,
                    hint: data.hint
                ))
            )
            
        case .flashcard(let data):
            return SmartBlock(
                type: .flashcard,
                subtype: "single",
                content: .flashcard(FlashcardBlockPayload(
                    front: data.front,
                    back: data.back,
                    tags: data.tags
                ))
            )
            
        case .flashcardSet(let data):
            // Migrate first card; full deck needs array support
            let firstCard = data.cards.first
            return SmartBlock(
                type: .flashcard,
                subtype: "deck",
                content: .flashcard(FlashcardBlockPayload(
                    front: firstCard?.front ?? data.title,
                    back: firstCard?.back ?? ""
                ))
            )
            
        case .progress(let data):
            return SmartBlock(
                type: .progress,
                subtype: "checkpoint",
                content: .progress(ProgressBlockPayload(
                    completed: data.completed,
                    total: data.total,
                    label: data.label
                ))
            )
            
        case .summary(let data):
            let text = data.points.map { "• \($0)" }.joined(separator: "\n")
            return SmartBlock(
                type: .text,
                subtype: "summary",
                content: .text(TextBlockPayload(
                    text: "**\(data.title)**\n\n\(text)",
                    style: "summary"
                ))
            )
            
        case .image(let data):
            return SmartBlock(
                type: .media,
                subtype: "image",
                content: .media(MediaBlockPayload(
                    url: data.query,
                    caption: data.caption
                ))
            )
            
        case .testPrep(let data):
            let courses = data.courses.map { "• \($0)" }.joined(separator: "\n")
            return SmartBlock(
                type: .text,
                subtype: "callout",
                content: .text(TextBlockPayload(
                    text: "**Test Prep: \(data.topic)**\n\(data.description ?? "")\n\n\(courses)",
                    style: "callout"
                ))
            )
            
        case .studyPlan(let data):
            let items = data.sessions.map { InteractiveItem(label: $0.title, detail: $0.description) }
            return SmartBlock(
                type: .interactive,
                subtype: "stepByStep",
                content: .interactive(InteractiveBlockPayload(
                    items: items,
                    title: data.title
                ))
            )
            
        case .agentCard(let data):
            return SmartBlock(
                type: .text,
                subtype: "callout",
                content: .text(TextBlockPayload(
                    text: "**\(data.name)** — \(data.role)\n\(data.message ?? "")",
                    style: "callout"
                ))
            )
            
        case .cinematicHook(let data):
            return SmartBlock(
                type: .text,
                subtype: "hook",
                content: .text(TextBlockPayload(
                    text: "**\(data.title)**\n\n\(data.hook)",
                    style: "hook"
                ))
            )
            
        case .masteryMap(let data):
            let nodes = data.nodes.map {
                MasteryNodePayload(title: $0.title, status: $0.status, masteryLevel: $0.masteryLevel)
            }
            return SmartBlock(
                type: .masteryMap,
                content: .masteryMap(MasteryMapBlockPayload(
                    title: data.courseTitle,
                    nodes: nodes
                ))
            )
            
        case .customUI(let type):
            return SmartBlock(
                type: .unknown,
                content: .unknown(rawJSON: ["legacy_type": AnyCodable(type)])
            )
        }
    }
    
    /// Batch migrate an array of legacy blocks
    static func migrateAll(_ blocks: [LegacyLessonBlock]) -> [SmartBlock] {
        blocks.map { migrate($0) }
    }
    
    /// Batch migrate identified blocks
    static func migrateAll(_ blocks: [IdentifiableLessonBlock]) -> [SmartBlock] {
        blocks.map { migrate($0.block) }
    }
}
