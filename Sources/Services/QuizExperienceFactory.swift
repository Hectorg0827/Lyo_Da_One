import Foundation

@MainActor
enum QuizExperienceFactory {
    enum Intent {
        case none
        case offer
        case create(ChatQuizMode)
    }

    static func classify(_ message: String) -> Intent {
        let text = normalized(message)

        if containsAny(text, ["review mistakes", "review my mistakes", "wrong answers", "what i got wrong", "missed questions"]) {
            return .create(.reviewMistakes)
        }
        if containsAny(text, ["beat rio", "challenge quiz", "challenge me", "quiz battle", "make it fun", "classroom challenge"]) {
            return .create(.classroomChallenge)
        }
        if containsAny(text, ["boss question", "harder quiz", "hard quiz", "final challenge", "make it harder", "make harder"]) {
            return .create(.bossRound)
        }
        if containsAny(text, ["confidence quiz", "am i ready", "do i understand", "test next week", "exam next week", "test tomorrow", "exam tomorrow"]) {
            return .create(.confidenceQuiz)
        }
        if containsAny(text, ["quiz me", "test me", "create a quiz", "make a quiz", "ask me questions", "help me practice", "practice questions", "quick quiz", "quick check", "5-question check", "5 question check"]) {
            return .create(.quickCheck)
        }

        if containsAny(text, ["i have a test", "i have an exam", "i'm confused", "im confused", "finished the class", "finished this lesson", "help me study", "prepare me"]) {
            return .offer
        }

        return .none
    }

    static func makeOfferMessage(for userMessage: String, recentMessages: [LyoMessage]) -> LyoMessage {
        let topic = inferTopic(from: userMessage, recentMessages: recentMessages)
        return LyoMessage(
            id: UUID().uuidString,
            content: "Want a quick check on \(topic), or should I make it feel more like a challenge?",
            isFromUser: false,
            timestamp: Date(),
            attachments: nil,
            actions: nil,
            status: .sent,
            contentTypes: [.suggestions(title: "Practice options", options: ["Quick 5-question check", "Challenge quiz", "Review mistakes"])]
        )
    }

    static func makeQuizMessage(
        for userMessage: String,
        mode requestedMode: ChatQuizMode,
        recentMessages: [LyoMessage]
    ) -> LyoMessage {
        let topic = inferTopic(from: userMessage, recentMessages: recentMessages)
        let deck = makeDeck(topic: topic, mode: requestedMode, recentMessages: recentMessages)
        return LyoMessage(
            id: UUID().uuidString,
            content: deck.intro,
            isFromUser: false,
            timestamp: Date(),
            attachments: nil,
            actions: nil,
            status: .sent,
            contentTypes: [.quizDeck(deck)]
        )
    }

    static func makeDeck(topic: String, mode: ChatQuizMode, recentMessages: [LyoMessage]) -> ChatQuizDeck {
        let terms = keyTerms(from: recentMessages, fallbackTopic: topic)
        let isPi = isPiGeometry(topic: topic, terms: terms)
        let selectedMode = normalizedMode(mode, topic: topic)
        let questions = isPi
            ? piGeometryQuestions(mode: selectedMode)
            : genericQuestions(topic: topic, terms: terms, mode: selectedMode)

        let shuffled = selectedMode == .reviewMistakes ? questions : questions.shuffled()
        let finalQuestions = Array(shuffled.prefix(selectedMode == .bossRound ? 4 : 5))
        let difficulty = selectedMode == .bossRound ? "Hard" : selectedMode == .confidenceQuiz ? "Adaptive" : "Beginner"
        let title = titleFor(topic: topic, mode: selectedMode)

        return ChatQuizDeck(
            title: title,
            subtitle: "\(finalQuestions.count) questions",
            mode: selectedMode,
            topic: topic,
            difficulty: difficulty,
            estimatedMinutes: max(2, finalQuestions.count / 2 + 1),
            xpReward: finalQuestions.count * 5,
            intro: introFor(topic: topic, mode: selectedMode),
            questions: finalQuestions,
            nextActions: nextActions(for: selectedMode)
        )
    }

    private static func normalizedMode(_ mode: ChatQuizMode, topic: String) -> ChatQuizMode {
        if mode == .bossRound { return .bossRound }
        return mode
    }

    private static func piGeometryQuestions(mode: ChatQuizMode) -> [ChatQuizQuestion] {
        [
            makeQuestion(
                kind: .multipleChoice,
                prompt: "What does pi represent?",
                correct: "The relationship between a circle's circumference and diameter",
                distractors: ["The radius of a circle", "The area of a square", "The number of sides in a triangle"],
                explanation: "Pi is the ratio of a circle's circumference to its diameter.",
                why: "That ratio is why pi appears whenever we measure circles.",
                classmate: mode == .classroomChallenge ? "I think it has something to do with the outside distance around the circle." : nil,
                confidence: mode == .confidenceQuiz
            ),
            makeQuestion(
                kind: .multipleChoice,
                prompt: "If a circle has diameter 10, about what is its circumference?",
                correct: "About 31.4",
                distractors: ["About 10", "About 20", "About 100"],
                explanation: "Circumference is pi times diameter, so 3.14 x 10 is about 31.4.",
                why: "This is the move you use for real circle measurement problems.",
                classmate: mode == .classroomChallenge ? "Rio is locking in the answer that uses diameter, not radius." : nil,
                confidence: mode == .confidenceQuiz
            ),
            makeQuestion(
                kind: .fixMistake,
                prompt: "Rio says every circle has a radius of 3.14 because pi is 3.14. What is wrong with that?",
                correct: "Pi is a ratio, not a radius length",
                distractors: ["Pi only works for squares", "Every circle has diameter 3.14", "Radius and circumference are always equal"],
                explanation: "Pi tells how circumference compares to diameter. A radius can be any size.",
                why: "Fixing this mistake separates memorizing pi from understanding pi.",
                classmate: mode == .classroomChallenge ? "Maya is unsure because 3.14 sounds like a measurement, but it is really a ratio." : nil,
                confidence: mode == .confidenceQuiz
            ),
            makeQuestion(
                kind: .multipleChoice,
                prompt: "Which formula uses diameter directly?",
                correct: "C = pi x d",
                distractors: ["C = d / pi", "A = d + pi", "C = pi + r"],
                explanation: "Circumference equals pi times diameter.",
                why: "Recognizing the right formula makes word problems faster.",
                classmate: mode == .classroomChallenge ? "Sam says the outside distance should scale with the distance across." : nil,
                confidence: mode == .confidenceQuiz
            ),
            makeQuestion(
                kind: .bossQuestion,
                prompt: "Boss question: a pizza has a diameter of 12 inches. About how far around is it?",
                correct: "About 37.7 inches",
                distractors: ["About 18.8 inches", "About 24 inches", "About 144 inches"],
                explanation: "Use C = pi x d. 3.14 x 12 = 37.68, so about 37.7 inches.",
                why: "This is pi in a real measurement situation.",
                classmate: mode == .classroomChallenge ? "Rio says he is going with circumference because the question asks how far around." : nil,
                confidence: mode == .confidenceQuiz
            )
        ]
    }

    private static func genericQuestions(topic: String, terms: [String], mode: ChatQuizMode) -> [ChatQuizQuestion] {
        let focus = terms.first ?? topic
        let second = terms.dropFirst().first ?? "the main idea"
        let third = terms.dropFirst(2).first ?? "an example"

        return [
            makeQuestion(
                prompt: "Which answer best captures the main idea of \(topic)?",
                correct: "It connects the key idea to how you would use it",
                distractors: ["It is only a vocabulary word", "It should be memorized without examples", "It never changes based on context"],
                explanation: "The strongest understanding connects the idea to use, examples, and reasoning.",
                why: "Lyo is checking whether you can work with the idea, not just repeat it.",
                classmate: mode == .classroomChallenge ? "Maya is choosing the answer that explains how the idea is used." : nil,
                confidence: mode == .confidenceQuiz
            ),
            makeQuestion(
                prompt: "In this conversation, why is \(focus) important?",
                correct: "It is one of the clues for understanding \(topic)",
                distractors: ["It is unrelated", "It only matters after the quiz", "It replaces every other concept"],
                explanation: "A key term matters because it helps organize the rest of the concept.",
                why: "Spotting key terms helps you study smarter from a conversation.",
                classmate: mode == .classroomChallenge ? "Sam thinks \(focus) is the anchor term here." : nil,
                confidence: mode == .confidenceQuiz
            ),
            makeQuestion(
                kind: .fixMistake,
                prompt: "Fix the mistake: Rio says \(topic) is just about memorizing \(second). What is the better answer?",
                correct: "Use \(second) with reasoning and examples",
                distractors: ["Ignore \(second)", "Memorize every sentence exactly", "Skip examples because they slow you down"],
                explanation: "Memorization can help, but learning sticks when the term is connected to reasoning and examples.",
                why: "This turns a weak answer into a teachable one.",
                classmate: mode == .classroomChallenge ? "Rio is close, but he is treating the topic like a flashcard only." : nil,
                confidence: mode == .confidenceQuiz
            ),
            makeQuestion(
                prompt: "What is the best next step if \(topic) feels confusing?",
                correct: "Try one small example and explain the reasoning",
                distractors: ["Reread everything without doing anything", "Jump straight to the hardest problem", "Avoid feedback"],
                explanation: "Small examples expose what you understand and what still needs work.",
                why: "That is how Lyo decides whether to reteach, quiz, or raise the difficulty.",
                classmate: mode == .classroomChallenge ? "Maya wants an example before the hard question." : nil,
                confidence: mode == .confidenceQuiz
            ),
            makeQuestion(
                kind: .bossQuestion,
                prompt: "Boss question: how would you explain \(topic) to someone using \(third)?",
                correct: "Define it, show the example, then explain why the example fits",
                distractors: ["Only list words", "Only say whether it is easy or hard", "Skip the why"],
                explanation: "A strong explanation has the idea, an example, and the reasoning that connects them.",
                why: "Teaching it back is one of the best checks for real understanding.",
                classmate: mode == .classroomChallenge ? "Sam says the why is the part that proves you understand it." : nil,
                confidence: true
            )
        ]
    }

    private static func makeQuestion(
        kind: ChatQuizQuestionKind = .multipleChoice,
        prompt: String,
        correct: String,
        distractors: [String],
        explanation: String,
        why: String,
        classmate: String? = nil,
        confidence: Bool = false
    ) -> ChatQuizQuestion {
        let all = ([correct] + distractors).shuffled()
        let correctIndex = all.firstIndex(of: correct) ?? 0
        return ChatQuizQuestion(
            kind: kind,
            question: prompt,
            choices: all,
            correctIndex: correctIndex,
            explanation: explanation,
            whyItMatters: why,
            correctReaction: "Nice. That is the idea.",
            incorrectReaction: "Almost. Look at the reasoning, not just the words.",
            classmateComment: classmate,
            asksConfidence: confidence
        )
    }

    private static func inferTopic(from message: String, recentMessages: [LyoMessage]) -> String {
        let lowered = normalized(message)
        let explicitPrefixes = [
            "quiz me on ", "test me on ", "create a quiz on ", "make a quiz on ",
            "create a quiz about ", "make a quiz about ", "practice ", "questions on ",
            "quiz on ", "quiz about "
        ]
        for prefix in explicitPrefixes where lowered.hasPrefix(prefix) {
            let raw = String(lowered.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            if !raw.isEmpty && raw != "this" { return raw.capitalized }
        }

        let recentText = recentMessages.suffix(8).map(\.content).joined(separator: " ")
        let recentLowered = normalized(recentText)
        if isPiGeometry(topic: lowered, terms: keyTerms(fromText: recentLowered, fallbackTopic: "")) {
            return "Pi and Geometry"
        }
        if let profileTopic = LearningProfileService.shared.current?.lastClassroomTopic, !profileTopic.isEmpty {
            return profileTopic
        }
        if let first = keyTerms(fromText: recentLowered, fallbackTopic: "").first {
            return first.capitalized
        }
        return "This Topic"
    }

    private static func keyTerms(from recentMessages: [LyoMessage], fallbackTopic: String) -> [String] {
        keyTerms(fromText: recentMessages.suffix(8).map(\.content).joined(separator: " "), fallbackTopic: fallbackTopic)
    }

    private static func keyTerms(fromText text: String, fallbackTopic: String) -> [String] {
        let stop: Set<String> = [
            "about", "after", "again", "because", "before", "being", "class", "could", "create", "every", "first", "going", "great", "learn", "lesson", "lyo", "make", "means", "might", "practice", "question", "really", "should", "something", "their", "there", "these", "thing", "think", "those", "through", "understand", "using", "where", "which", "would", "your", "youre"
        ]
        var counts: [String: Int] = [:]
        let cleaned = normalized(text)
            .replacingOccurrences(of: "[^a-z0-9 ]", with: " ", options: .regularExpression)
        for word in cleaned.split(separator: " ").map(String.init) {
            guard word.count >= 4 || word == "pi" else { continue }
            guard !stop.contains(word) else { continue }
            counts[word, default: 0] += 1
        }
        let ranked = counts.sorted { lhs, rhs in
            if lhs.value == rhs.value { return lhs.key < rhs.key }
            return lhs.value > rhs.value
        }.map(\.key)
        if ranked.isEmpty, !fallbackTopic.isEmpty { return [fallbackTopic] }
        return Array(ranked.prefix(5))
    }

    private static func isPiGeometry(topic: String, terms: [String]) -> Bool {
        let joined = (normalized(topic) + " " + terms.joined(separator: " ")).lowercased()
        return joined.contains(" pi") || joined == "pi" || joined.contains("circle") || joined.contains("geometry") || joined.contains("circumference") || joined.contains("diameter")
    }

    private static func titleFor(topic: String, mode: ChatQuizMode) -> String {
        switch mode {
        case .quickCheck: return "\(topic) Quick Quiz"
        case .classroomChallenge: return "Beat Rio: \(topic)"
        case .reviewMistakes: return "\(topic) Mistake Review"
        case .confidenceQuiz: return "\(topic) Confidence Check"
        case .bossRound: return "\(topic) Boss Round"
        }
    }

    private static func introFor(topic: String, mode: ChatQuizMode) -> String {
        switch mode {
        case .quickCheck:
            return "Absolutely. I made a quick \(topic) check based on what we have been discussing. One question at a time."
        case .classroomChallenge:
            return "Let's make it a classroom challenge. Rio and the class will weigh in, but you lock the answer."
        case .reviewMistakes:
            return "Let's turn the shaky parts into a short mistake-review round. The goal is to fix the reasoning, not just pick answers."
        case .confidenceQuiz:
            return "I made this as a confidence quiz. After each answer, tell me whether you guessed, felt unsure, or felt confident."
        case .bossRound:
            return "Boss round ready. Fewer questions, harder reasoning, and a final challenge."
        }
    }

    private static func nextActions(for mode: ChatQuizMode) -> [String] {
        switch mode {
        case .reviewMistakes:
            return ["Start Mini Lesson", "Give Me 3 Practice Problems", "Save to Study Stack"]
        case .classroomChallenge:
            return ["Rematch Rio", "Review Missed Questions", "Start Mini Class"]
        case .confidenceQuiz:
            return ["Review Low-Confidence Answers", "Make Flashcards", "Start Mini Lesson"]
        case .bossRound:
            return ["Try Another Boss Round", "Review Mistakes", "Save Mastery"]
        case .quickCheck:
            return ["Review Mistakes", "Make Flashcards", "Start Mini Lesson"]
        }
    }

    private static func normalized(_ text: String) -> String {
        text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func containsAny(_ text: String, _ needles: [String]) -> Bool {
        needles.contains { text.contains($0) }
    }
}
