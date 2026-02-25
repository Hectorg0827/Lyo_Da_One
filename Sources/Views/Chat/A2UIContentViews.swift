//
//  A2UIContentViews.swift
//  Lyo
//
//  Views for rendering A2UI protocol content (Course Roadmaps, Quizzes, Flashcards)
//  These are displayed inline within chat messages
//

import SwiftUI

// MARK: - Supporting Data Types

/// Data for quiz cards - local type to avoid conflicts
struct QuizData: Identifiable {
    let id: String
    let title: String
    let questions: [QuizQuestionData]
    
    init(id: String = UUID().uuidString, title: String, questions: [QuizQuestionData]) {
        self.id = id
        self.title = title
        self.questions = questions
    }
}

/// Single quiz question - local type
struct QuizQuestionData: Identifiable {
    let id: String
    let question: String
    let options: [String]
    let correctAnswer: String
    
    init(id: String = UUID().uuidString, question: String, options: [String], correctAnswer: String) {
        self.id = id
        self.question = question
        self.options = options
        self.correctAnswer = correctAnswer
    }
}

/// Data for flashcard stacks
struct FlashcardData: Identifiable {
    let id: String
    let title: String
    let cards: [FlashcardItem]
    
    init(id: String = UUID().uuidString, title: String, cards: [FlashcardItem]) {
        self.id = id
        self.title = title
        self.cards = cards
    }
}

/// Single flashcard item
struct FlashcardItem: Identifiable {
    let id: String
    let front: String
    let back: String
    
    init(id: String = UUID().uuidString, front: String, back: String) {
        self.id = id
        self.front = front
        self.back = back
    }
}

/// Course lesson for roadmap display
struct CourseLesson: Identifiable {
    let id: String
    let title: String
    let duration: String
    
    init(id: String = UUID().uuidString, title: String, duration: String) {
        self.id = id
        self.title = title
        self.duration = duration
    }
}

// MARK: - Course Roadmap Card

struct CourseRoadmapCardView: View {
    let course: CourseCreationData
    let onStart: ((CourseCreationData) -> Void)?
    
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "8B5CF6"), Color(hex: "3B82F6")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "book.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(course.title)
                        .font(.headline)
                        .foregroundColor(.white)
                        .lineLimit(2)
                    
                    HStack(spacing: 8) {
                        Label(course.level.capitalized, systemImage: "chart.bar.fill")
                        Label("\(course.modules.count) modules", systemImage: "rectangle.stack.fill")
                    }
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                
                // Expand/Collapse
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 32, height: 32)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
            }
            
            // Modules List (Expandable)
            if isExpanded {
                VStack(spacing: 12) {
                    ForEach(Array(course.modules.enumerated()), id: \.element.id) { index, module in
                        HStack(spacing: 12) {
                            // Module number
                            ZStack {
                                Circle()
                                    .fill(Color(hex: "8B5CF6").opacity(0.3))
                                    .frame(width: 28, height: 28)
                                
                                Text("\(index + 1)")
                                    .font(.caption.bold())
                                    .foregroundColor(Color(hex: "8B5CF6"))
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(module.title)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(.white)
                                
                                Text(module.description)
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.6))
                                    .lineLimit(2)
                            }
                            
                            Spacer()
                            
                            // Lesson count
                            Text("\(module.lessons.count) lessons")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding(.top, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            // Start Button
            Button {
                HapticManager.shared.playSuccess()
                onStart?(course)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 14))
                    
                    Text("Start Learning")
                        .font(.subheadline.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "8B5CF6"), Color(hex: "3B82F6")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: Color(hex: "8B5CF6").opacity(0.4), radius: 8, x: 0, y: 4)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(white: 0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [Color(hex: "8B5CF6").opacity(0.5), Color(hex: "3B82F6").opacity(0.5)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
    }
}

// MARK: - Quiz Card (A2UI inline variant)
// NOTE: The canonical QuizCardView is in Sources/Views/Cards/QuizCardView.swift

struct A2UIQuizCardView: View {
    let quiz: QuizData
    let onAnswer: ((String, Int) -> Void)?
    
    @State private var currentIndex = 0
    @State private var selectedAnswer: Int?
    @State private var showResult = false
    @State private var correctCount = 0
    
    private var currentQuestion: QuizQuestionData? {
        guard currentIndex < quiz.questions.count else { return nil }
        return quiz.questions[currentIndex]
    }
    
    private var isComplete: Bool {
        currentIndex >= quiz.questions.count
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "F59E0B"), Color(hex: "EF4444")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(quiz.title)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    if !isComplete {
                        Text("Question \(currentIndex + 1) of \(quiz.questions.count)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                
                Spacer()
                
                // Score
                if correctCount > 0 || isComplete {
                    Text("\(correctCount)/\(quiz.questions.count)")
                        .font(.headline)
                        .foregroundColor(.green)
                }
            }
            
            if isComplete {
                // Completion View
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.green)
                    
                    Text("Quiz Complete!")
                        .font(.title3.weight(.semibold))
                        .foregroundColor(.white)
                    
                    Text("You got \(correctCount) out of \(quiz.questions.count) correct")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                    
                    // Restart button
                    Button {
                        withAnimation {
                            currentIndex = 0
                            selectedAnswer = nil
                            showResult = false
                            correctCount = 0
                        }
                    } label: {
                        Text("Try Again")
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.1))
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else if let question = currentQuestion {
                // Question
                PremiumQuizView(
                    question: question.question,
                    options: question.options,
                    correctIndex: question.options.firstIndex(of: question.correctAnswer) ?? 0,
                    explanation: nil, // Add explanation if available in data
                    onAnswerSubmitted: { index, isCorrect in
                        if isCorrect {
                            correctCount += 1
                        }
                        showResult = true
                        selectedAnswer = index
                        onAnswer?(question.question, index)
                    }
                )
                
                // Next Button
                if showResult {
                    Button {
                        withAnimation {
                            currentIndex += 1
                            selectedAnswer = nil
                            showResult = false
                        }
                    } label: {
                        HStack {
                            Text(currentIndex == quiz.questions.count - 1 ? "See Results" : "Next Question")
                            Image(systemName: "arrow.right")
                        }
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(colors: [Color(hex: "F59E0B"), Color(hex: "EF4444")], startPoint: .leading, endPoint: .trailing)
                        )
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.top, 12)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(white: 0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Flashcards Card

struct FlashcardsCardView: View {
    let flashcards: FlashcardData
    @State private var currentIndex = 0
    
    private var currentCard: FlashcardItem? {
        guard currentIndex < flashcards.cards.count else { return nil }
        return flashcards.cards[currentIndex]
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "10B981"), Color(hex: "06B6D4")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "rectangle.on.rectangle.angled")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(flashcards.title)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text("Card \(currentIndex + 1) of \(flashcards.cards.count)")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
            }
            
            if let card = currentCard {
                PremiumFlashcardView(
                    front: card.front,
                    back: card.back,
                    hint: nil,
                    isMastered: false,
                    showMasteryButton: false
                )
                .frame(height: 250)
                
                // Navigation
                HStack {
                    Button {
                        withAnimation {
                            currentIndex = max(0, currentIndex - 1)
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.headline)
                            .padding(12)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .disabled(currentIndex == 0)
                    .opacity(currentIndex == 0 ? 0.3 : 1)
                    
                    Spacer()
                    
                    Text("\(currentIndex + 1) / \(flashcards.cards.count)")
                        .font(.caption.bold())
                        .foregroundColor(.white.opacity(0.6))
                    
                    Spacer()
                    
                    Button {
                        withAnimation {
                            currentIndex = min(flashcards.cards.count - 1, currentIndex + 1)
                        }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.headline)
                            .padding(12)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .disabled(currentIndex == flashcards.cards.count - 1)
                    .opacity(currentIndex == flashcards.cards.count - 1 ? 0.3 : 1)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(white: 0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
    }
}

// NOTE: CodeSnippetView is defined in Components/Classroom/ModuleCardView.swift - do not duplicate

// MARK: - Rich Card View

struct RichCardView: View {
    let title: String
    let content: String
    let imageURL: URL?
    let actions: [CardAction]
    let onAction: ((String) -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Image if present
            if let imageURL = imageURL {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 120)
                            .clipped()
                    case .failure:
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 120)
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundColor(.gray)
                            )
                    default:
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 120)
                            .overlay(ProgressView())
                    }
                }
                .cornerRadius(12, corners: [.topLeft, .topRight])
            }
            
            // Content
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(content)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(3)
                
                // Actions
                if !actions.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(actions) { action in
                            Button {
                                onAction?(action.id)
                            } label: {
                                Text(action.label)
                                    .font(.caption.bold())
                                    .foregroundColor(action.actionType == "primary" ? .white : .blue)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        action.actionType == "primary"
                                            ? AnyView(Color.blue)
                                            : AnyView(Color.clear)
                                    )
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Processing Indicator View

struct ProcessingIndicatorView: View {
    let step: String
    let progress: Double?
    
    @State private var frameIndex = 0
    private let frames = ["Mascot_Reading_1", "Mascot_Reading_2", "Mascot_Reading_3", "Mascot_Reading_4"]
    private let timer = Timer.publish(every: 0.2, on: .main, in: .common).autoconnect()
    
    var body: some View {
        HStack(spacing: 12) {
            // Mascot Animation
            ZStack {
                if let progress = progress {
                    // Show progress circular ring around mascot if progress exists
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 2)
                        .frame(width: 32, height: 32)
                    
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            LinearGradient(
                                colors: [Color(hex: "8B5CF6"), Color(hex: "3B83F6")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                        .frame(width: 32, height: 32)
                        .rotationEffect(.degrees(-90))
                }
                
                Image(frames[frameIndex])
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)
                    .clipShape(Circle())
            }
            .onReceive(timer) { _ in
                frameIndex = (frameIndex + 1) % frames.count
            }
            
            Text(step)
                .font(.subheadline.weight(.medium))
                .foregroundColor(.white.opacity(0.9))
            
            if progress == nil {
                // Subtle moving dots
                HStack(spacing: 2) {
                    ForEach(0..<3) { i in
                        Circle()
                            .fill(Color.white.opacity(0.6))
                            .frame(width: 3, height: 3)
                    }
                }
            }
            
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

// MARK: - Topic Selection View

struct TopicSelectionView: View {
    let title: String
    let topics: [TopicOption]
    let onSelect: (TopicOption) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
            
            FlowLayout(spacing: 8) {
                ForEach(topics) { topic in
                    Button {
                        onSelect(topic)
                    } label: {
                        HStack(spacing: 6) {
                            Text(topic.icon)
                            Text(topic.title)
                                .font(.subheadline.weight(.medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: topic.gradientColors?.map { Color(hex: $0) } ?? [Color.blue, Color.purple],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
        )
    }
}

// NOTE: InlineCourseCardView is defined in Components/AITutor/MessageBubbleView.swift
// NOTE: FlowLayout is defined in Components/Common/FlowLayout.swift
// NOTE: cornerRadius extension is defined in Utils/ShapeExtensions.swift

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 20) {
            CourseRoadmapCardView(
                course: CourseCreationData(
                    id: "1",
                    title: "Python for Beginners",
                    topic: "Python Programming",
                    level: "beginner",
                    modules: [
                        CourseModuleData(id: "1", title: "Getting Started", description: "Setup and basics"),
                        CourseModuleData(id: "2", title: "Data Types", description: "Variables and structures")
                    ]
                ),
                onStart: { _ in }
            )
            
            A2UIQuizCardView(
                quiz: QuizData(
                    title: "Python Basics Quiz",
                    questions: [
                        QuizQuestionData(id: "1", question: "What is Python?", options: ["A snake", "A programming language", "A movie", "A food"], correctAnswer: "A programming language")
                    ]
                ),
                onAnswer: { _, _ in }
            )
            
            FlashcardsCardView(
                flashcards: FlashcardData(
                    title: "Python Vocabulary",
                    cards: [
                        FlashcardItem(id: "1", front: "What is a variable?", back: "A container for storing data values")
                    ]
                )
            )
            
            ProcessingIndicatorView(step: "Generating course...", progress: nil)
        }
        .padding()
    }
    .background(Color.black)
}
