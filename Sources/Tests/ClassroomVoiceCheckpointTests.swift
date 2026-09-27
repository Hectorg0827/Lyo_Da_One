import XCTest
@testable import Lyo

/// Checks the classroom adapter that XcodeGen actually includes in LyoTests.
@MainActor
final class ClassroomVoiceCheckpointTests: XCTestCase {
    func testGeneratedReviewRetainsFocusedIdentityAcrossSavedCards() throws {
        let review = UIStackItem(type: .course, title: "Review: Fractions",
                                 courseId: "GENERATE:fractions", focusedConcept: true)
        let restored = try JSONDecoder().decode(UIStackItem.self, from: JSONEncoder().encode(review))
        XCTAssertEqual(restored.focusedConcept, true)

        // Older saved cards had no scope flag and continue to open as free-topic classes.
        var legacy = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(review)) as? [String: Any])
        legacy.removeValue(forKey: "focusedConcept")
        let oldCard = try JSONDecoder().decode(UIStackItem.self,
                                               from: JSONSerialization.data(withJSONObject: legacy))
        XCTAssertNil(oldCard.focusedConcept)
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
