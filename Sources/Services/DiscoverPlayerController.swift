import AVFoundation
import Combine
import SwiftUI
import UIKit

/// Selection and user intent survive background transitions and seek completion.
struct DiscoverPlaybackState {
    var isSelected = false
    var isForeground = true
    var userPaused = false
    var scrubbing = false
    var quizPaused = false

    var shouldPlay: Bool { isSelected && isForeground && !userPaused && !scrubbing && !quizPaused }
}

@MainActor
final class DiscoverPlayerController: ObservableObject {
    @Published private(set) var player: AVPlayer?
    @Published private(set) var state = DiscoverPlaybackState()
    @Published var position: Double = 0
    @Published private(set) var duration: Double = 0
    @Published private(set) var isPlayingFirstFrame = false
    @Published private(set) var loadFailed = false
    @Published private(set) var ended = false
    @Published private(set) var completionCount = 0
    @Published private(set) var isMuted = false

    private let makePlayer: (URL) -> AVPlayer
    private var currentURL: URL?
    private var endObserver: NSObjectProtocol?
    private var interruptionObserver: NSObjectProtocol?
    private var timeObserver: Any?
    private var statusObserver: NSKeyValueObservation?
    private var audioInterrupted = false
    private var seekGeneration = 0

    init(makePlayer: @escaping (URL) -> AVPlayer = { AVPlayer(url: $0) }) {
        self.makePlayer = makePlayer
    }

    func configure(selected: Bool, foreground: Bool, quizPaused: Bool) {
        if state.isSelected && !selected {
            state.userPaused = false
            state.scrubbing = false
            if ended { player?.seek(to: .zero); ended = false }
        }
        state.isSelected = selected
        state.isForeground = foreground
        state.quizPaused = quizPaused
        applyIntent()
    }

    func load(url: URL) {
        if currentURL == url, player != nil { applyIntent(); return }
        teardown()
        currentURL = url
        let newPlayer = makePlayer(url)
        newPlayer.isMuted = isMuted
        newPlayer.currentItem?.preferredForwardBufferDuration = 3
        player = newPlayer
        endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: newPlayer.currentItem, queue: .main) { [weak self, weak newPlayer] _ in
            Task { @MainActor in
                guard let newPlayer else { return }
                self?.didFinish(newPlayer)
            }
        }
        timeObserver = newPlayer.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.25, preferredTimescale: 600), queue: .main) { [weak self, weak newPlayer] time in
            Task { @MainActor in
                guard let self, let newPlayer, self.player === newPlayer else { return }
                if !self.state.scrubbing, time.seconds.isFinite { self.position = max(0, time.seconds) }
                let seconds = newPlayer.currentItem?.duration.seconds ?? 0
                if seconds.isFinite { self.duration = max(0, seconds) }
            }
        }
        statusObserver = newPlayer.currentItem?.observe(\.status, options: [.initial, .new]) { [weak self, weak newPlayer] item, _ in
            Task { @MainActor in
                guard let self, let newPlayer, self.player === newPlayer else { return }
                if item.status == .failed { self.loadFailed = true; self.applyIntent() }
                if item.status == .readyToPlay {
                    self.loadFailed = false
                    self.applyIntent()
                    if !self.state.isSelected { newPlayer.preroll(atRate: 1.0) { _ in } }
                }
            }
        }
        interruptionObserver = NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] notification in
            let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            let options = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            Task { @MainActor in
                guard let self, let raw, let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
                self.audioInterrupted = type == .began
                if type == .ended && self.state.isSelected && !AVAudioSession.InterruptionOptions(rawValue: options).contains(.shouldResume) { self.state.userPaused = true }
                self.applyIntent()
            }
        }
        applyIntent()
    }

    /// Both identity and the current selection are checked when the notification arrives.
    func didFinish(_ observedPlayer: AVPlayer) {
        guard player === observedPlayer, state.shouldPlay, !audioInterrupted, !loadFailed, !ended else { return }
        ended = true
        player?.pause()
        completionCount += 1
    }

    func markFirstFrame(_ observedPlayer: AVPlayer) {
        guard player === observedPlayer else { return }
        isPlayingFirstFrame = true
    }

    func togglePause() {
        guard state.isSelected, state.isForeground, !state.quizPaused else { return }
        if ended { ended = false; player?.seek(to: .zero); state.userPaused = false }
        else { state.userPaused.toggle() }
        applyIntent()
    }

    func toggleMute() { isMuted.toggle(); player?.isMuted = isMuted }

    func beginScrubbing() { state.scrubbing = true; applyIntent() }

    func endScrubbing() {
        guard let player else { state.scrubbing = false; return }
        seekGeneration += 1
        let generation = seekGeneration
        let target = max(0, min(position, duration))
        player.seek(to: CMTime(seconds: target, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero) { [weak self, weak player] _ in
            Task { @MainActor in
                guard let self, self.player === player, self.seekGeneration == generation else { return }
                self.state.scrubbing = false
                self.ended = false
                self.applyIntent()
            }
        }
    }

    func retry(url: URL) { currentURL = nil; state.userPaused = false; load(url: url) }

    func teardown() {
        seekGeneration += 1
        if let token = endObserver { NotificationCenter.default.removeObserver(token) }
        if let token = interruptionObserver { NotificationCenter.default.removeObserver(token) }
        if let token = timeObserver, let player { player.removeTimeObserver(token) }
        endObserver = nil
        interruptionObserver = nil
        timeObserver = nil
        statusObserver?.invalidate()
        statusObserver = nil
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil
        currentURL = nil
        state.scrubbing = false
        audioInterrupted = false
        position = 0
        duration = 0
        ended = false
        loadFailed = false
        isPlayingFirstFrame = false
    }

    private func applyIntent() {
        guard state.shouldPlay, !audioInterrupted, !loadFailed, !ended else { player?.pause(); return }
        if let player {
            let session = AVAudioSession.sharedInstance()
            try? session.setCategory(.playback, mode: .moviePlayback)
            try? session.setActive(true)
            player.play()
        }
    }
}

/// AVPlayerLayer supplies actual first-frame readiness; controls live in SwiftUI.
struct DiscoverVideoSurface: UIViewRepresentable {
    @ObservedObject var controller: DiscoverPlayerController

    final class Surface: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }
    final class Coordinator {
        var readyObserver: NSKeyValueObservation?
    }
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIView(context: Context) -> Surface { Surface() }
    func updateUIView(_ view: Surface, context: Context) {
        guard view.playerLayer.player !== controller.player else { return }
        context.coordinator.readyObserver?.invalidate()
        view.playerLayer.videoGravity = .resizeAspectFill
        view.playerLayer.player = controller.player
        let player = controller.player
        context.coordinator.readyObserver = view.playerLayer.observe(\.isReadyForDisplay, options: [.initial, .new]) { [weak controller, weak player] layer, _ in
            guard layer.isReadyForDisplay, let player else { return }
            Task { @MainActor in controller?.markFirstFrame(player) }
        }
    }
    static func dismantleUIView(_ view: Surface, coordinator: Coordinator) {
        coordinator.readyObserver?.invalidate()
        view.playerLayer.player = nil
    }
}
