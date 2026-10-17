import XCTest
import AVFoundation
@testable import Lyo

@MainActor
final class DiscoverPlaybackTests: XCTestCase {
    private let url = URL(string: "https://example.invalid/clip.mp4")!

    func testPrewarmedNeighbourAdvancesAfterSelectionAndIgnoresOffscreenEnd() {
        let player = AVPlayer()
        let controller = DiscoverPlayerController(makePlayer: { _ in player })
        controller.configure(selected: false, foreground: true, quizPaused: false)
        controller.load(url: url)
        controller.didFinish(player)
        XCTAssertEqual(controller.completionCount, 0)
        controller.configure(selected: true, foreground: true, quizPaused: false)
        controller.didFinish(player)
        XCTAssertEqual(controller.completionCount, 1)
        controller.didFinish(player)
        XCTAssertEqual(controller.completionCount, 1)
        controller.teardown()
    }

    func testBackgroundAndQuizRecoveryPreserveManualPause() {
        let controller = DiscoverPlayerController()
        controller.configure(selected: true, foreground: true, quizPaused: false)
        controller.togglePause()
        controller.configure(selected: true, foreground: false, quizPaused: false)
        controller.configure(selected: true, foreground: true, quizPaused: false)
        XCTAssertFalse(controller.state.shouldPlay)
        controller.togglePause()
        controller.configure(selected: true, foreground: true, quizPaused: true)
        XCTAssertFalse(controller.state.shouldPlay)
        controller.configure(selected: true, foreground: true, quizPaused: false)
        XCTAssertTrue(controller.state.shouldPlay)
    }

    func testStalePlayerCannotAdvanceAfterRetryOrTeardown() {
        let controller = DiscoverPlayerController(makePlayer: { _ in AVPlayer() })
        controller.configure(selected: true, foreground: true, quizPaused: false)
        controller.load(url: url)
        let oldPlayer = controller.player!
        controller.retry(url: url)
        controller.didFinish(oldPlayer)
        XCTAssertEqual(controller.completionCount, 0)
        let current = controller.player!
        controller.teardown()
        controller.didFinish(current)
        XCTAssertEqual(controller.completionCount, 0)
        XCTAssertNil(controller.player)
    }

    func testRapidSwipeDuringScrubCannotResumeOffscreenPlayer() {
        let controller = DiscoverPlayerController()
        controller.configure(selected: true, foreground: true, quizPaused: false)
        controller.beginScrubbing()
        XCTAssertFalse(controller.state.shouldPlay)
        controller.configure(selected: false, foreground: true, quizPaused: false)
        controller.endScrubbing()
        XCTAssertFalse(controller.state.shouldPlay)
        controller.configure(selected: true, foreground: true, quizPaused: false)
        XCTAssertTrue(controller.state.shouldPlay)
    }
}
