import Foundation

public enum LegacyLessonBlock: Identifiable, Equatable {
    public var id: UUID {
        switch self {
        case .text(let content): return UUID(uuidString: content.prefix(36).padding(toLength: 36, withPad: "0", startingAt: 0)) ?? UUID()
        case .quiz(let data): return UUID() // Placeholder: ideally derived from content
        case .testPrep(let data): return UUID()
        case .studyPlan(let data): return UUID()
        case .agentCard(let data): return UUID()
        case .cinematicHook(let data): return UUID()
        case .masteryMap(let data): return UUID()
        default: return UUID()
        }
    }
    
    // Actually, it's better to wrap in a struct or use a stored property if possible, 
    // but enum with associated values can't easily have a stored property in Swift.
    // I'll wrap it in a struct for better identity management.
    
    case text(String)
    case quiz(QuizData)
    case flashcard(FlashcardData)
    case flashcardSet(FlashcardSetData)
    case progress(ProgressData)
    case summary(SummaryData)
    case image(ImageData)
    case testPrep(TestPrepBlockData)
    case studyPlan(StudyPlanData)
    case agentCard(AgentCardData)
    case cinematicHook(CinematicHookData)
    case masteryMap(MasteryMapData)
    case customUI(String)
}

public struct IdentifiableLessonBlock: Identifiable, Equatable {
    public var id: String {
        // Simple stable ID based on block content
        return "\(block.hashValue)"
    }
    public let block: LegacyLessonBlock
}

extension LegacyLessonBlock: Hashable {
    public func hash(into hasher: inout Hasher) {
        switch self {
        case .text(let content): hasher.combine(content)
        case .quiz(let data): 
            hasher.combine("quiz")
            hasher.combine(data.question)
        case .flashcard(let data):
            hasher.combine("flashcard")
            hasher.combine(data.front)
        case .flashcardSet(let data):
            hasher.combine("flashcardSet")
            hasher.combine(data.title)
        case .progress(let data):
            hasher.combine("progress")
            hasher.combine(data.label)
        case .summary(let data):
            hasher.combine("summary")
            hasher.combine(data.title)
        case .image(let data):
            hasher.combine("image")
            hasher.combine(data.query)
        case .testPrep(let data):
            hasher.combine("testPrep")
            hasher.combine(data.topic)
        case .studyPlan(let data):
            hasher.combine("studyPlan")
            hasher.combine(data.title)
        case .agentCard(let data):
            hasher.combine("agentCard")
            hasher.combine(data.name)
            hasher.combine(data.status)
        case .cinematicHook(let data):
            hasher.combine("cinematicHook")
            hasher.combine(data.title)
        case .masteryMap(let data):
            hasher.combine("masteryMap")
            hasher.combine(data.courseTitle)
        case .customUI(let type):
            hasher.combine(type)
        }
    }
}


public struct QuizData: Equatable {
    public var type: String // multiple_choice, true_false, fill_blank
    public var question: String
    public var options: [String]
    public var correct: Int
    public var explanation: String
    public var hint: String?
    public var difficulty: String?
}

public struct FlashcardData: Equatable {
    public var front: String
    public var back: String
    public var tags: String?
}

public struct FlashcardSetData: Equatable {
    public var title: String
    public var cards: [FlashcardData]
}

public struct ImageData: Equatable {
    public var query: String
    public var caption: String
    public var style: String?
}

public struct ProgressData: Equatable {
    public var completed: Int
    public var total: Int
    public var label: String?
    public var sublabel: String?
}

public struct SummaryData: Equatable {
    public var title: String
    public var points: [String]
}

public struct CodeData: Equatable {
    public var language: String
    public var title: String?
    public var code: String
}

public struct ChecklistData: Equatable {
    public var title: String
    public var items: [String]
}

public struct DiagramBlockData: Equatable {
    public var type: String
    public var title: String
    public var nodes: [String]
}

public struct AudioData: Equatable {
    public var text: String
    public var language: String?
    public var speed: String?
}
public struct TestPrepBlockData: Equatable {
    public var topic: String
    public var date: Date?
    public var description: String?
    public var courses: [String]
}

public struct StudySession: Equatable, Identifiable {
    public var id = UUID()
    public var title: String
    public var description: String
    public var durationMinutes: Int
    public var date: Date
}

public struct StudyPlanData: Equatable {
    public var title: String
    public var examDate: Date?
    public var sessions: [StudySession]
}

public struct AgentCardData: Equatable {
    public var name: String
    public var role: String
    public var status: String
    public var message: String?
    public var icon: String? // SF Symbol name
}
    
public struct CinematicHookData: Equatable {
    public var title: String
    public var hook: String
    public var visualDescription: String?
    public var callToAction: String?
    public var mediaUrl: String?
}

public struct MasteryNode: Equatable, Identifiable {
    public var id = UUID()
    public var title: String
    public var status: String // locked, completed, in_progress
    public var masteryLevel: Double // 0.0 to 1.0
}

public struct MasteryMapData: Equatable {
    public var courseTitle: String
    public var nodes: [MasteryNode]
}
