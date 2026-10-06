import XCTest
@testable import Lyo

@MainActor
final class ChatVoiceSubmissionTests: XCTestCase {
    private final class SubmissionSpy: LyoAIViewModel {
        var capturedResumeVoiceLoop: Bool?
        var submissionCount = 0
        var onSubmission: (() -> Void)?

        override func sendMessage(mode: String? = nil, resumeVoiceLoop: Bool? = nil) async {
            capturedResumeVoiceLoop = resumeVoiceLoop
            submissionCount += 1
            onSubmission?()
        }
    }

    func testStoppingMicrophonePreservesVoiceDeliveryForTheAsynchronousSend() async {
        let model = SubmissionSpy()
        let submitted = expectation(description: "Spoken turn submitted through Chat")
        model.onSubmission = { submitted.fulfill() }
        model.isVoiceActive = true
        model.isLiveMode = true
        model.inputText = "Explain fractions"

        model.stopListening()

        XCTAssertFalse(model.isVoiceActive)
        XCTAssertTrue(model.isLiveMode)
        await fulfillment(of: [submitted], timeout: 1)
        XCTAssertEqual(model.capturedResumeVoiceLoop, true)
        XCTAssertEqual(model.submissionCount, 1)
    }

    func testMicrophoneStateAloneIsEnoughToCaptureAVoiceSubmission() async {
        let model = SubmissionSpy()
        let submitted = expectation(description: "Microphone turn submitted")
        model.onSubmission = { submitted.fulfill() }
        model.isVoiceActive = true
        model.isLiveMode = false
        model.inputText = "Explain fractions"

        model.stopListening()

        await fulfillment(of: [submitted], timeout: 1)
        XCTAssertEqual(model.capturedResumeVoiceLoop, true)
    }

    func testEndingLiveModeDoesNotSubmitAPendingTranscript() async {
        let model = SubmissionSpy()
        model.isVoiceActive = true
        model.isLiveMode = true
        model.inputText = "Unfinished question"

        model.stopLiveMode()
        await Task.yield()

        XCTAssertFalse(model.isVoiceActive)
        XCTAssertFalse(model.isLiveMode)
        XCTAssertEqual(model.inputText, "Unfinished question")
        XCTAssertEqual(model.submissionCount, 0)
    }

    func testWhitespaceOnlyTranscriptEndsVoiceModeWithoutSending() async {
        let model = SubmissionSpy()
        model.isVoiceActive = true
        model.isLiveMode = true
        model.inputText = " \n "

        model.stopListening()
        await Task.yield()

        XCTAssertFalse(model.isLiveMode)
        XCTAssertEqual(model.submissionCount, 0)
    }
}
