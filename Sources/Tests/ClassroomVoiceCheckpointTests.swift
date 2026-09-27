import XCTest
@testable import Lyo

/// Checks the classroom adapter that XcodeGen actually includes in LyoTests.
@MainActor
final class ClassroomVoiceCheckpointTests: XCTestCase {
    func testGeneratedReviewRetainsFocusedIdentityAcrossSavedCards() throws {
        let suiteName = "ClassroomVoiceCheckpointTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = UIStackStore(defaults: defaults)
        store.upsertCourse(courseId: "GENERATE:fractions", title: "Review: Fractions",
                           focusedConcept: true)
        // Updating a due-review card's progress/title must keep its focused identity.
        store.upsertCourse(courseId: "GENERATE:fractions", title: "Review: Fractions again")
        // Older saved cards have no scope flag and still open as free-topic classes.
        store.upsert(UIStackItem(type: .course, title: "Older class",
                                 courseId: "GENERATE:legacy"))

        let restored = UIStackStore(defaults: defaults)
        XCTAssertEqual(restored.items.first(where: { $0.courseId == "GENERATE:fractions" })?.focusedConcept, true)
        XCTAssertNil(restored.items.first(where: { $0.courseId == "GENERATE:legacy" })?.focusedConcept)
    }

    func testOpeningApplicationOffersDictationOnItsAnswerField() {
        let framing = SDUIComponent(id: "opening", type: .teacherMessage,
                                    content: "Consider this example. What would you do?")
        let question = SDUIComponent(id: "probe", type: .inputField,
                                     content: "Explain your choice and why.",
                                     question: "What would you do, and why?",
                                     actionIntent: "submit_transfer", languageCode: "es-MX")
        let steps = ActiveLessonAdapter.steps(from: [framing, question])
        XCTAssertTrue(steps.contains { step in
            guard step.isAnswerableByVoice,
                  case .some(.classroomInput(let component)) = step.supporting else { return false }
            return component.id == question.id && step.languageCode == "es-MX"
        })
        XCTAssertFalse(ActiveLessonAdapter.steps(from: [framing]).contains { $0.isAnswerableByVoice })
    }

    func testSpokenPromptKeepsItsLanguageThroughTheFinalContinueStep() {
        let prompt = SDUIComponent(
            id: "ask", type: .teacherMessage,
            content: "[{\"type\":\"user_prompt\",\"speaker\":\"Teacher\",\"text\":\"¿Por qué?\"}]",
            languageCode: "es-MX"
        )
        let next = SDUIComponent(id: "continue", type: .ctaButton, content: "Continue")
        let steps = ActiveLessonAdapter.steps(from: [prompt, next])
        XCTAssertEqual(steps.last?.requiresOpenResponse, true)
        XCTAssertEqual(steps.last?.languageCode, "es-MX")
    }
}
