import XCTest
@testable import Lyo

/// What the app says when a learner finishes something.
///
/// This copy is shown on three platforms and the length it promises is
/// enforced by the recorder, so the strings and the number are a contract,
/// not decoration. `web/src/lib/teach-it.test.mjs` and `ClipPromptTest.kt`
/// assert the same things.
final class ClipPromptTests: XCTestCase {

    func testAKnownTopicIsNamedInTheInvitation() {
        XCTAssertEqual(
            ClipPrompt.invitation(topic: "Organic Chemistry"),
            "You just finished Organic Chemistry. Teach it in 60 seconds?"
        )
    }

    /// A prompt that confidently names the wrong course is worse than one that
    /// names none, so nothing is invented when the topic is missing.
    func testAnUnknownTopicIsNotInvented() {
        let generic = "Teach what you just learned in 60 seconds?"
        XCTAssertEqual(ClipPrompt.invitation(topic: nil), generic)
        XCTAssertEqual(ClipPrompt.invitation(topic: ""), generic)
        XCTAssertEqual(ClipPrompt.invitation(topic: "   "), generic)
    }

    /// A title the learner did not write gets published under their name.
    func testTheDraftTitleIsLeftEmptyWhenTheTopicIsUnknown() {
        XCTAssertEqual(ClipPrompt.draftTitle(topic: "Spanish B1"), "What I learned about Spanish B1")
        XCTAssertNil(ClipPrompt.draftTitle(topic: nil))
        XCTAssertNil(ClipPrompt.draftTitle(topic: "  "))
    }

    func testTheDraftSubjectIsTheTrimmedTopicOrNothing() {
        XCTAssertEqual(ClipPrompt.draftSubject(topic: "  Statistics  "), "Statistics")
        XCTAssertNil(ClipPrompt.draftSubject(topic: ""))
    }

    /// The invitation must not offer a length the camera will refuse.
    func testThePromisedLengthIsTheOneTheRecorderEnforces() {
        XCTAssertEqual(ClipPrompt.quickTakeSeconds, 60)
        XCTAssertTrue(ClipPrompt.invitation(topic: "Algebra").contains("60 seconds"))
        XCTAssertEqual(ClipPrompt.callToAction, "Teach it")
    }
}
