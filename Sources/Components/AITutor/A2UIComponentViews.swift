//
//  A2UIComponentViews.swift
//  Lyo
//
//  Created by Lyo Team.
//  UI Components for A2UI (AI-to-UI) rendering in Chat
//

import SwiftUI

// MARK: - Data Models

struct QuizData: Identifiable, Equatable {
    let id = UUID().uuidString
    let title: String
    let questions: [QuizQuestionData]
}

struct QuizQuestionData: Identifiable, Equatable {
    let id: String
    let question: String
    let options: [String]
    let correctAnswer: String
}

struct FlashcardItem: Identifiable, Equatable {
    let id: String
    let front: String
    let back: String
}

// MARK: - Views

struct CourseRoadmapCardView: View {
    let course: CourseCreationData
    var onStart: ((CourseCreationData) -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "map")
                    .foregroundStyle(.blue)
                Text("Course Roadmap")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
            }
            
            Text(course.title)
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(course.modules) { module in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "circle.fill") // Milestone dot
                            .font(.system(size: 8))
                            .foregroundStyle(.blue.opacity(0.5))
                            .padding(.top, 6)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(module.title)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            if !module.description.isEmpty {
                                Text(module.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 8)
            .padding(.leading, 4)
            
            Button(action: { onStart?(course) }) {
                HStack {
                    Text("Start Course")
                    Image(systemName: "arrow.right")
                }
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.blue.opacity(0.1), lineWidth: 1)
        )
    }
}

struct QuizCardView: View {
    let quiz: QuizData
    var onAnswer: ((String, Int) -> Void)?
    
    @State private var currentQuestionIndex = 0
    @State private var selectedOptionIndex: Int?
    @State private var isAnswered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundStyle(.purple)
                Text(quiz.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                Text("\(currentQuestionIndex + 1)/\(quiz.questions.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            if currentQuestionIndex < quiz.questions.count {
                let question = quiz.questions[currentQuestionIndex]
                Text(question.question)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                
                VStack(spacing: 8) {
                    ForEach(Array(question.options.enumerated()), id: \.offset) { index, option in
                        Button(action: {
                            if !isAnswered {
                                selectedOptionIndex = index
                                isAnswered = true
                                onAnswer?(question.question, index)
                                
                                // Delay for next question
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                    if currentQuestionIndex < quiz.questions.count - 1 {
                                        currentQuestionIndex += 1
                                        selectedOptionIndex = nil
                                        isAnswered = false
                                    }
                                }
                            }
                        }) {
                            HStack {
                                Text(option)
                                    .font(.body)
                                    .multilineTextAlignment(.leading)
                                Spacer()
                                if isAnswered && selectedOptionIndex == index {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.white)
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                optionBackground(for: index)
                            )
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                        .disabled(isAnswered)
                    }
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.green)
                    Text("Quiz Completed!")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }
    
    private func optionBackground(for index: Int) -> Color {
        if isAnswered && selectedOptionIndex == index {
            return Color.blue
        }
        return Color(.tertiarySystemBackground)
    }
}

struct FlashcardsCardView: View {
    let title: String
    let cards: [FlashcardItem]
    
    @State private var currentIndex = 0
    @State private var isFlipped = false
    @State private var offset: CGSize = .zero
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "rectangle.on.rectangle.angled")
                    .foregroundStyle(.orange)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                Text("\(currentIndex + 1)/\(cards.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            
            if !cards.isEmpty {
                ZStack {
                    // Face Side
                    A2UICardFace(text: cards[currentIndex].front, color: .blue)
                        .opacity(isFlipped ? 0 : 1)
                        .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
                    
                    // Back Side
                    A2UICardFace(text: cards[currentIndex].back, color: .orange)
                        .opacity(isFlipped ? 1 : 0)
                        .rotation3DEffect(.degrees(isFlipped ? 0 : -180), axis: (x: 0, y: 1, z: 0))
                }
                .frame(height: 180)
                .onTapGesture {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                        isFlipped.toggle()
                    }
                }
                .offset(x: offset.width)
                .gesture(
                    DragGesture()
                        .onChanged { gesture in
                            offset = gesture.translation
                        }
                        .onEnded { gesture in
                            if gesture.translation.width < -50 && currentIndex < cards.count - 1 {
                                // Swipe Left (Next)
                                offset = .init(width: -500, height: 0)
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    currentIndex += 1
                                    isFlipped = false
                                    offset = .zero
                                }
                            } else if gesture.translation.width > 50 && currentIndex > 0 {
                                // Swipe Right (Prev)
                                offset = .init(width: 500, height: 0)
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    currentIndex -= 1
                                    isFlipped = false
                                    offset = .zero
                                }
                            } else {
                                offset = .zero
                            }
                        }
                )
                
                HStack {
                    Text("Tap to flip • Swipe to navigate")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("No flashcards available")
                    .padding()
            }
        }
        .padding(.vertical)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }
}

private struct A2UICardFace: View {
    let text: String
    let color: Color
    
    var body: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(color)
            .overlay(
                Text(text)
                    .font(.title3)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)
                    .padding()
            )
            .shadow(radius: 4, y: 2)
    }
}

struct RichCardView: View {
    let title: String
    let bodyText: String
    let imageURL: URL?
    let actions: [CardAction]?
    var onAction: ((String) -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let url = imageURL {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Rectangle().fill(Color.gray.opacity(0.2))
                }
                .frame(height: 160)
                .clipped()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.headline)
                
                Text(bodyText)
                    .font(.body)
                    .foregroundStyle(.secondary)
                
                if let actions = actions {
                    HStack {
                        ForEach(actions) { action in
                            Button(action.label) {
                                onAction?(action.id)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.blue)
                        }
                    }
                    .padding(.top, 8)
                }
            }
            .padding()
        }
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.gray.opacity(0.1), lineWidth: 1)
        )
    }
}

struct ProcessingIndicatorView: View {
    let step: String
    let progress: Double?
    
    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
                .scaleEffect(0.8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(step)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if let p = progress {
                    ProgressView(value: p)
                        .progressViewStyle(LinearProgressViewStyle())
                        .frame(height: 2)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct TopicSelectionView: View {
    let title: String
    let topics: [TopicOption]
    var onSelect: ((String) -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            
            VStack(spacing: 8) {
                ForEach(topics) { topic in
                    Button(action: { onSelect?(topic.id) }) {
                        HStack {
                            Image(systemName: topic.icon)
                                .font(.system(size: 20))
                                .frame(width: 30)
                                .foregroundStyle(.blue)
                            
                            VStack(alignment: .leading) {
                                Text(topic.title)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                            }
                            
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding()
                        .background(Color(.tertiarySystemGroupedBackground))
                        .cornerRadius(12)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }
}
