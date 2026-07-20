import Foundation

enum ChatQuizMode: String, Codable, Equatable {
    case quickCheck = "quick_check"
    case classroomChallenge = "classroom_challenge"
    case reviewMistakes = "review_mistakes"
    case confidenceQuiz = "confidence_quiz"
    case bossRound = "boss_round"

    var displayName: String {
        switch self {
        case .quickCheck: return "Quick Quiz"
        case .classroomChallenge: return "Classroom Challenge"
        case .reviewMistakes: return "Review Mistakes"
        case .confidenceQuiz: return "Confidence Quiz"
        case .bossRound: return "Boss Round"
        }
    }
}

enum ChatQuizQuestionKind: String, Codable, Equatable {
    case multipleChoice = "multiple_choice"
    case fixMistake = "fix_mistake"
    case bossQuestion = "boss_question"
}

struct ChatQuizDeck: Codable, Equatable, Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let mode: ChatQuizMode
    let topic: String
    let difficulty: String
    let estimatedMinutes: Int
    let xpReward: Int
    let intro: String
    let questions: [ChatQuizQuestion]
    let nextActions: [String]

    init(
        id: String = UUID().uuidString,
        title: String,
        subtitle: String,
        mode: ChatQuizMode,
        topic: String,
        difficulty: String,
        estimatedMinutes: Int,
        xpReward: Int,
        intro: String,
        questions: [ChatQuizQuestion],
        nextActions: [String]
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.mode = mode
        self.topic = topic
        self.difficulty = difficulty
        self.estimatedMinutes = estimatedMinutes
        self.xpReward = xpReward
        self.intro = intro
        self.questions = questions
        self.nextActions = nextActions
    }
}

struct ChatQuizQuestion: Codable, Equatable, Identifiable {
    let id: String
    let kind: ChatQuizQuestionKind
    let question: String
    let choices: [String]
    let correctIndex: Int
    let explanation: String
    let whyItMatters: String
    let correctReaction: String
    let incorrectReaction: String
    let classmateComment: String?
    let asksConfidence: Bool

    init(
        id: String = UUID().uuidString,
        kind: ChatQuizQuestionKind = .multipleChoice,
        question: String,
        choices: [String],
        correctIndex: Int,
        explanation: String,
        whyItMatters: String,
        correctReaction: String,
        incorrectReaction: String,
        classmateComment: String? = nil,
        asksConfidence: Bool = false
    ) {
        self.id = id
        self.kind = kind
        self.question = question
        self.choices = choices
        self.correctIndex = correctIndex
        self.explanation = explanation
        self.whyItMatters = whyItMatters
        self.correctReaction = correctReaction
        self.incorrectReaction = incorrectReaction
        self.classmateComment = classmateComment
        self.asksConfidence = asksConfidence
    }
}
