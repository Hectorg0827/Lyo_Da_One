//
//  TestPrepOrchestrator.swift
//  Lyo
//
//  Drives the multi-turn test prep conversation flow:
//  intent detection → funnel questions → plan generation → sequential bubble delivery
//

import Foundation
import Combine
import os

// MARK: - Orchestrator

@MainActor
final class TestPrepOrchestrator: ObservableObject {
    static let shared = TestPrepOrchestrator()

    @Published private(set) var state: OrchestratorState = .idle
    @Published private(set) var pendingContent: TestPrepContent?

    // MARK: - State Machine

    enum OrchestratorState: Equatable {
        case idle
        case detectingIntent(rawPhrase: String)
        case gatheringInfo(phase: FunnelPhase, gathered: TestPrepIntentInfo)
        case generatingPlan
        case deliveryPhase(TestPrepDeliveryPhase)
        case active(TestPrepContent)

        static func == (lhs: OrchestratorState, rhs: OrchestratorState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle): return true
            case (.generatingPlan, .generatingPlan): return true
            case (.detectingIntent(let a), .detectingIntent(let b)): return a == b
            case (.gatheringInfo(let p1, _), .gatheringInfo(let p2, _)): return p1 == p2
            case (.deliveryPhase(let a), .deliveryPhase(let b)): return a == b
            case (.active(let a), .active(let b)): return a.id == b.id
            default: return false
            }
        }
    }

    enum FunnelPhase: Int, Equatable, CaseIterable {
        case subject = 1
        case testType = 2
        case testDate = 3
        case confidence = 4
        case studyHours = 5
        case materials = 6
    }

    enum TestPrepDeliveryPhase: Equatable {
        case studyPlan
        case flashcards
        case practiceQuiz
        case progressCard
    }

    private let testPrepService = TestPrepService.shared
    private var generationTask: Task<Void, Never>?

    private init() {}

    // MARK: - Entry Points

    func handleIntent(rawPhrase: String, in chatService: UnifiedChatService) {
        guard case .idle = state else { return }
        Log.ai.info("📚 Test prep intent detected: \(rawPhrase.prefix(50))")
        state = .detectingIntent(rawPhrase: rawPhrase)
        let emptyInfo = TestPrepIntentInfo()
        state = .gatheringInfo(phase: .subject, gathered: emptyInfo)
        chatService.appendAssistantMessage(funnelQuestion(for: .subject))
    }

    func handleFunnelResponse(_ text: String, attachmentIds: [String] = [], in chatService: UnifiedChatService) {
        guard case .gatheringInfo(let phase, var gathered) = state else { return }

        parseAnswer(text, attachmentIds: attachmentIds, for: phase, into: &gathered)

        if let nextPhase = FunnelPhase(rawValue: phase.rawValue + 1) {
            state = .gatheringInfo(phase: nextPhase, gathered: gathered)
            chatService.appendAssistantMessage(funnelQuestion(for: nextPhase))
        } else {
            // All questions answered — generate plan
            startPlanGeneration(from: gathered, in: chatService)
        }
    }

    func confirmAndExecute(content: TestPrepContent, in chatService: UnifiedChatService) async {
        pendingContent = content
        state = .deliveryPhase(.studyPlan)

        // Schedule calendar event + notifications (user has already approved via CTA)
        if let testDate = content.testDate {
            _ = await testPrepService.scheduleExamInCalendar(
                title: content.subject,
                date: testDate,
                description: "Exam type: \(content.testType)"
            )
            await testPrepService.scheduleMotivationalMessage(
                examDate: testDate,
                topic: content.subject
            )
        }

        // Schedule study reminders from the plan
        if let plan = content.studyPlan {
            let sessions = studySessions(from: plan)
            await testPrepService.scheduleStudyReminders(sessions: sessions)
        }

        // Sequentially deliver rich bubbles
        await deliverStudyPlan(content: content, in: chatService)

        state = .deliveryPhase(.flashcards)
        try? await Task.sleep(nanoseconds: 800_000_000)
        deliverFlashcards(content: content, in: chatService)

        state = .deliveryPhase(.practiceQuiz)
        try? await Task.sleep(nanoseconds: 800_000_000)
        deliverQuizItems(content: content, in: chatService)

        state = .deliveryPhase(.progressCard)
        try? await Task.sleep(nanoseconds: 800_000_000)
        chatService.appendTestPrepProgressBubble(content)

        state = .active(content)
        Log.ai.info("✅ Test prep active for: \(content.subject)")
    }

    func reset() {
        generationTask?.cancel()
        generationTask = nil
        state = .idle
        pendingContent = nil
    }

    // MARK: - Funnel Questions

    func funnelQuestion(for phase: FunnelPhase) -> String {
        switch phase {
        case .subject:
            return "📚 I'd love to help you ace your test! What subject or course is it for? (e.g., AP Chemistry, Calculus, Spanish, History)"
        case .testType:
            return "Got it! What kind of test is it? (quiz, midterm, final exam, SAT, MCAT, bar exam, or something else?)"
        case .testDate:
            return "When exactly is the exam? You can say something like 'December 15th at 9am', 'next Friday', or 'in two weeks'."
        case .confidence:
            return "On a scale of 1–5, how confident do you feel about this subject right now? (1 = completely lost, 5 = very solid)"
        case .studyHours:
            return "How many hours per day can you realistically dedicate to studying? Even 30 minutes a day counts!"
        case .materials:
            return "Do you have any notes, slides, or study guides? You can tap the 📎 button to attach them, or just say 'skip' to continue."
        }
    }

    // MARK: - Answer Parsing

    private func parseAnswer(_ text: String, attachmentIds: [String], for phase: FunnelPhase, into info: inout TestPrepIntentInfo) {
        let lower = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        switch phase {
        case .subject:
            info.subject = text.trimmingCharacters(in: .whitespacesAndNewlines)

        case .testType:
            let types = ["quiz", "midterm", "final", "sat", "mcat", "bar", "ap", "gre", "lsat", "gmat"]
            info.testType = types.first { lower.contains($0) } ?? lower

        case .testDate:
            info.testDate = extractDate(from: text)

        case .confidence:
            if let digit = lower.first(where: { $0.isNumber }), let value = Int(String(digit)) {
                info.confidenceLevel = value <= 2 ? "low" : value == 3 ? "medium" : "high"
            } else if lower.contains("low") || lower.contains("lost") || lower.contains("hard") {
                info.confidenceLevel = "low"
            } else if lower.contains("high") || lower.contains("great") || lower.contains("solid") {
                info.confidenceLevel = "high"
            } else {
                info.confidenceLevel = "medium"
            }

        case .studyHours:
            info.dailyStudyHours = extractHours(from: lower)

        case .materials:
            if !attachmentIds.isEmpty {
                info.uploadedMaterialIds = attachmentIds
            }
            // "skip" or "no" → leave uploadedMaterialIds empty (already initialized to [])
        }
    }

    private func extractDate(from text: String) -> Date? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else {
            return nil
        }
        let range = NSRange(text.startIndex..., in: text)
        let matches = detector.matches(in: text, options: [], range: range)
        return matches.first?.date
    }

    private func extractHours(from lower: String) -> Double {
        // Handle "30 min" → 0.5, "1.5 hours" → 1.5, "2" → 2.0
        if lower.contains("min") {
            if let num = extractFirstNumber(from: lower) { return num / 60.0 }
        }
        return extractFirstNumber(from: lower) ?? 2.0
    }

    private func extractFirstNumber(from text: String) -> Double? {
        let pattern = #"(\d+(?:\.\d+)?)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else { return nil }
        return Double(text[range])
    }

    // MARK: - Plan Generation

    private func startPlanGeneration(from info: TestPrepIntentInfo, in chatService: UnifiedChatService) {
        state = .generatingPlan
        chatService.appendAssistantMessage("✨ Building your personalized study plan now — this'll just take a moment!")

        generationTask = Task {
            do {
                let content = try await generatePlan(from: info, chatService: chatService)
                if !Task.isCancelled {
                    pendingContent = content
                    chatService.appendTestPrepBubble(content)
                }
            } catch {
                Log.ai.error("❌ Test prep plan generation failed: \(error.localizedDescription)")
                chatService.appendAssistantMessage("I ran into a problem building your plan. Let's try again — what subject is your test on?")
                state = .gatheringInfo(phase: .subject, gathered: TestPrepIntentInfo())
            }
        }
    }

    private func generatePlan(from info: TestPrepIntentInfo, chatService: UnifiedChatService) async throws -> TestPrepContent {
        let subject = info.subject ?? "General"
        let testType = info.testType ?? "exam"
        let confidence = info.confidenceLevel ?? "medium"
        let hours = info.dailyStudyHours ?? 2.0
        let daysUntil = info.testDate.map { date in
            max(1, Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 7)
        } ?? 7

        // Build context prompt for the AI
        let contextPrompt = """
        Generate a structured test prep plan as JSON matching the TEST_PREP command schema.
        Subject: \(subject)
        Test type: \(testType)
        Days until exam: \(daysUntil)
        Confidence level: \(confidence)
        Daily study hours: \(hours)
        Uploaded material IDs: \(info.uploadedMaterialIds.joined(separator: ", "))

        Return a TEST_PREP JSON command with a studyPlan (StudyDay array), quizItems (5 questions), and flashcardSets (1 set of 8 cards).
        """

        let aiResult = try await BackendAIService.shared.studySession(
            message: contextPrompt,
            mode: "test_prep"
        )

        // Try to parse a TEST_PREP command from the response
        let parsed = AICommandParser.parse(aiResult.response)
        if case .command(let cmd) = parsed, cmd.type == .testPrep, let tp = cmd.payload?.testPrep {
            let handlerResult = AICommandHandler.shared.handleTestPrep(AICommandPayload(
                stackItem: nil,
                course: nil,
                testPrep: tp
            ))
            if handlerResult.wasCommand, let content = AICommandHandler.shared.pendingTestPrep {
                return content
            }
        }

        // Fallback: build a minimal local plan if AI didn't return structured data
        return buildFallbackContent(from: info, daysUntil: daysUntil)
    }

    private func buildFallbackContent(from info: TestPrepIntentInfo, daysUntil: Int) -> TestPrepContent {
        let subject = info.subject ?? "Your Subject"
        let studyDays = (1...min(daysUntil, 14)).map { day -> StudyDay in
            StudyDay(
                dayNumber: day,
                topic: "Day \(day): \(subject) Review",
                tasks: [
                    StudyTask(title: "Review key concepts", durationMinutes: 30, type: "read"),
                    StudyTask(title: "Practice problems", durationMinutes: 30, type: "practice"),
                    StudyTask(title: "Self-quiz", durationMinutes: 15, type: "practice")
                ]
            )
        }
        let plan = StudyPlan(
            title: "\(subject) Prep Plan",
            description: "\(daysUntil)-day study plan",
            schedule: studyDays
        )
        return TestPrepContent(
            subject: subject,
            testType: info.testType ?? "exam",
            testDate: info.testDate,
            daysUntilTest: daysUntil,
            dailyStudyHours: info.dailyStudyHours ?? 2.0,
            confidenceLevel: info.confidenceLevel ?? "medium",
            studyPlan: plan,
            uploadedMaterialIds: info.uploadedMaterialIds
        )
    }

    // MARK: - Bubble Delivery

    private func deliverStudyPlan(content: TestPrepContent, in chatService: UnifiedChatService) async {
        if let plan = content.studyPlan {
            chatService.appendStudyPlanBubble(plan, testTitle: content.subject, testDate: content.testDate)
        } else {
            chatService.appendAssistantMessage("📅 Your personalized study schedule has been created and your exam has been added to your calendar!")
        }
    }

    private func deliverFlashcards(content: TestPrepContent, in chatService: UnifiedChatService) {
        for set in content.flashcardSets.prefix(2) {
            chatService.appendFlashcardBubble(title: set.title, cards: set.cards)
        }
        if content.flashcardSets.isEmpty {
            chatService.appendAssistantMessage("🃏 I'll generate personalized flashcards for \(content.subject) as you progress through your plan!")
        }
    }

    private func deliverQuizItems(content: TestPrepContent, in chatService: UnifiedChatService) {
        for item in content.quizBank.prefix(3) {
            chatService.appendQuizBubble(item: item)
        }
        if content.quizBank.isEmpty {
            chatService.appendAssistantMessage("🧠 Practice quizzes will appear here as you complete each study session!")
        }
    }

    // MARK: - Helpers

    private func studySessions(from plan: StudyPlan) -> [StudySession] {
        var sessions: [StudySession] = []
        var currentDate = Date()

        for day in plan.schedule {
            for task in day.tasks {
                let session = StudySession(
                    title: task.title,
                    description: day.topic,
                    durationMinutes: task.durationMinutes,
                    date: currentDate
                )
                sessions.append(session)
            }
            currentDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        return sessions
    }
}
