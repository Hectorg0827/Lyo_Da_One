import SwiftUI
import AVFoundation
import UIKit
import os

// MARK: - Enhanced Camera Manager for Lyo Create Studio

/// Production-grade camera manager with AI-powered features and TikTok-level functionality
class EnhancedCameraManager: NSObject, ObservableObject, AVCaptureFileOutputRecordingDelegate {
    // MARK: - Published State

    @Published var permissionGranted = false
    @Published var audioPermissionGranted = false
    @Published var isRecording = false
    @Published var recordedVideoURL: URL?
    @Published var capturedPhoto: UIImage?
    @Published var recordingDuration: TimeInterval = 0
    @Published var currentPosition: AVCaptureDevice.Position = .back
    @Published var isFlashOn = false
    @Published var flashMode: AVCaptureDevice.FlashMode = .off
    @Published var generatedThumbnail: UIImage?
    @Published var errorMessage: String?
    @Published var zoomFactor: CGFloat = 1.0
    @Published var exposureValue: Float = 0.0
    @Published var focusPoint: CGPoint?
    @Published var isLivePhotoEnabled = false
    @Published var currentSpeed: Float = 1.0
    @Published var timer: Int = 0 // 0 = off, 3, 10 seconds

    // MARK: - AI-Powered Features
    @Published var aiSuggestions: [String] = []
    @Published var detectedObjects: [String] = []
    @Published var sceneAnalysis: String = ""
    @Published var lightingQuality: String = "Good"
    @Published var compositionTips: [String] = []

    // MARK: - Gallery & Recent Media
    @Published var recentPhotos: [UIImage] = []
    @Published var recentVideos: [URL] = []

    // MARK: - Configuration

    let maxDurationSeconds: TimeInterval = 180 // 3 minutes
    let maxZoomFactor: CGFloat = 10.0
    let speeds: [Float] = [0.3, 0.5, 1.0, 2.0, 3.0]

    // MARK: - Session Components

    let session = AVCaptureSession()
    private let movieOutput = AVCaptureMovieFileOutput()
    private let photoOutput = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "enhancedCameraSessionQueue")
    private var currentVideoInput: AVCaptureDeviceInput?
    private var currentAudioInput: AVCaptureDeviceInput?

    // MARK: - Recording & Timer

    private var recordingTimer: Timer?
    private var recordingStartTime: Date?
    private var timerCountdown: Timer?

    // MARK: - AI Processing
    private let visionQueue = DispatchQueue(label: "visionProcessing", qos: .background)

    // MARK: - Init

    override init() {
        super.init()
        setupAISuggestions()
        checkPermissions()
        loadRecentMedia()
    }

    // MARK: - Permissions

    func checkPermissions() {
        // Video permission
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            permissionGranted = true
            configureSessionIfReady()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.permissionGranted = granted
                    if granted {
                        self?.configureSessionIfReady()
                    }
                }
            }
        default:
            permissionGranted = false
        }

        // Audio permission
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            audioPermissionGranted = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.audioPermissionGranted = granted
                }
            }
        default:
            audioPermissionGranted = false
        }
    }

    private func configureSessionIfReady() {
        guard permissionGranted else { return }
        sessionQueue.async { [weak self] in
            self?.configureSession()
            self?.session.startRunning()
        }
    }

    /// Ensure the capture session is running. Call this when presenting
    /// a child view that shares this camera manager (e.g. ClipsRecordingView).
    func ensureSessionRunning() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if !self.session.isRunning {
                // Re-configure if needed (inputs/outputs may have been removed)
                if self.session.inputs.isEmpty {
                    self.configureSession()
                }
                self.session.startRunning()
            }
        }
    }

    // MARK: - Session Configuration

    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .high

        // Add video input
        configureVideoInput(position: .back)

        // Add audio input
        configureAudioInput()

        // Add movie output
        if session.canAddOutput(movieOutput) {
            session.addOutput(movieOutput)
            movieOutput.maxRecordedDuration = CMTime(seconds: maxDurationSeconds, preferredTimescale: 600)

            // Enhanced video settings
            if let connection = movieOutput.connection(with: .video) {
                if connection.isVideoStabilizationSupported {
                    connection.preferredVideoStabilizationMode = .cinematic
                }
                if #available(iOS 17.0, *) {
                    // 0 degrees means portrait by default; use 0, 90, 180, 270 as needed
                    connection.videoRotationAngle = 0
                } else {
                    connection.videoOrientation = .portrait
                }
            }
        }

        // Add photo output with Live Photo capability
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            photoOutput.isLivePhotoCaptureEnabled = photoOutput.isLivePhotoCaptureSupported
            photoOutput.maxPhotoQualityPrioritization = .quality
        }

        session.commitConfiguration()
    }

    private func configureVideoInput(position: AVCaptureDevice.Position) {
        // Remove existing video input
        if let existing = currentVideoInput {
            session.removeInput(existing)
        }

        // Get the best device for position
        let deviceTypes: [AVCaptureDevice.DeviceType] = [
            .builtInTripleCamera,
            .builtInDualWideCamera,
            .builtInUltraWideCamera,
            .builtInWideAngleCamera
        ]

        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: deviceTypes,
            mediaType: .video,
            position: position
        )

        guard let videoDevice = discoverySession.devices.first,
              let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice),
              session.canAddInput(videoDeviceInput) else {
            Log.general.warning("Failed to configure video input for position: \(String(describing: position))")
            return
        }

        session.addInput(videoDeviceInput)
        currentVideoInput = videoDeviceInput

        DispatchQueue.main.async {
            self.currentPosition = position
        }

        // Configure device settings
        configureCameraSettings(device: videoDevice)
    }

    private func configureCameraSettings(device: AVCaptureDevice) {
        do {
            try device.lockForConfiguration()

            // Enable smooth auto focus
            if device.isSmoothAutoFocusSupported {
                device.isSmoothAutoFocusEnabled = true
            }

            // Set focus mode
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }

            // Set exposure mode
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }

            // Set white balance
            if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                device.whiteBalanceMode = .continuousAutoWhiteBalance
            }

            device.unlockForConfiguration()
        } catch {
            print("Failed to configure camera settings: \(error)")
        }
    }

    private func configureAudioInput() {
        guard let audioDevice = AVCaptureDevice.default(for: .audio),
              let audioDeviceInput = try? AVCaptureDeviceInput(device: audioDevice),
              session.canAddInput(audioDeviceInput) else {
            return
        }

        session.addInput(audioDeviceInput)
        currentAudioInput = audioDeviceInput
    }

    // MARK: - Camera Controls

    func switchCamera() {
        guard !isRecording else { return }

        sessionQueue.async { [weak self] in
            guard let self = self else { return }

            self.session.beginConfiguration()
            let newPosition: AVCaptureDevice.Position = self.currentPosition == .back ? .front : .back
            self.configureVideoInput(position: newPosition)
            self.session.commitConfiguration()
        }
    }

    func toggleFlash() {
        guard let device = currentVideoInput?.device else { return }

        sessionQueue.async {
            do {
                try device.lockForConfiguration()

                if device.hasTorch {
                    if device.torchMode == .off {
                        try device.setTorchModeOn(level: 1.0)
                        DispatchQueue.main.async { self.isFlashOn = true }
                    } else {
                        device.torchMode = .off
                        DispatchQueue.main.async { self.isFlashOn = false }
                    }
                }

                device.unlockForConfiguration()
            } catch {
                print("Flash toggle failed: \(error)")
            }
        }
    }

    func setZoom(_ factor: CGFloat) {
        guard let device = currentVideoInput?.device else { return }
        let clampedFactor = max(1.0, min(factor, device.activeFormat.videoMaxZoomFactor))

        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                device.videoZoomFactor = clampedFactor
                device.unlockForConfiguration()

                DispatchQueue.main.async {
                    self.zoomFactor = clampedFactor
                }
            } catch {
                print("Zoom failed: \(error)")
            }
        }
    }

    func setExposure(_ value: Float) {
        guard let device = currentVideoInput?.device,
              device.isExposureModeSupported(.custom) else { return }

        sessionQueue.async {
            do {
                try device.lockForConfiguration()

                let duration = AVCaptureDevice.currentExposureDuration
                let iso = device.iso

                device.setExposureModeCustom(duration: duration, iso: iso + value * 100) { _ in
                    DispatchQueue.main.async {
                        self.exposureValue = value
                    }
                }

                device.unlockForConfiguration()
            } catch {
                print("Exposure adjustment failed: \(error)")
            }
        }
    }

    func setFocus(at point: CGPoint) {
        guard let device = currentVideoInput?.device,
              device.isFocusModeSupported(.autoFocus) else { return }

        sessionQueue.async {
            do {
                try device.lockForConfiguration()

                device.focusPointOfInterest = point
                device.focusMode = .autoFocus

                if device.isExposureModeSupported(.autoExpose) {
                    device.exposurePointOfInterest = point
                    device.exposureMode = .autoExpose
                }

                device.unlockForConfiguration()

                DispatchQueue.main.async {
                    self.focusPoint = point

                    // Clear focus point after animation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self.focusPoint = nil
                    }
                }
            } catch {
                print("Focus adjustment failed: \(error)")
            }
        }
    }

    // MARK: - Speed Control

    func setSpeed(_ speed: Float) {
        currentSpeed = speed
    }

    func cycleSpeed() {
        guard let currentIndex = speeds.firstIndex(of: currentSpeed) else { return }
        let nextIndex = (currentIndex + 1) % speeds.count
        currentSpeed = speeds[nextIndex]
    }

    // MARK: - Timer

    func setTimer(_ seconds: Int) {
        timer = seconds
    }

    // MARK: - Recording

    func startRecording() {
        guard !isRecording, permissionGranted else { return }

        if timer > 0 {
            startTimerCountdown()
            return
        }

        performRecording()
    }

    private func startTimerCountdown() {
        var countdown = timer

        timerCountdown = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            countdown -= 1

            // Add haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()

            if countdown <= 0 {
                timer.invalidate()
                self?.timerCountdown = nil
                self?.performRecording()
            }
        }
    }

    private func performRecording() {
        recordedVideoURL = nil
        generatedThumbnail = nil
        recordingDuration = 0

        // Guard: ensure the session is running and movieOutput is connected
        guard session.isRunning else {
            print("⚠️ Cannot start recording — session is not running. Restarting...")
            ensureSessionRunning()
            // Retry after a short delay to let the session spin up
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.performRecording()
            }
            return
        }

        guard !movieOutput.connections.isEmpty else {
            print("⚠️ Cannot start recording — movieOutput has no connections")
            DispatchQueue.main.async {
                self.errorMessage = "Camera not ready. Please try again."
            }
            return
        }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("lyo_clip_\(UUID().uuidString).mp4")

        movieOutput.startRecording(to: tempURL, recordingDelegate: self)

        DispatchQueue.main.async {
            self.isRecording = true
            self.recordingStartTime = Date()
            self.startRecordingTimer()
        }
    }

    func stopRecording() {
        guard isRecording else { return }

        timerCountdown?.invalidate()
        timerCountdown = nil

        movieOutput.stopRecording()
        stopRecordingTimer()

        DispatchQueue.main.async {
            self.isRecording = false
        }
    }

    // MARK: - Photo Capture

    func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        settings.flashMode = flashMode

        if photoOutput.isLivePhotoCaptureSupported && isLivePhotoEnabled {
            settings.livePhotoMovieFileURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("lyo_live_\(UUID().uuidString).mov")
        }

        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    // MARK: - AI Features

    private func setupAISuggestions() {
        aiSuggestions = [
            "🎯 Explain a concept you learned today",
            "📚 Create a 60-second lesson",
            "💡 Share a study tip that works",
            "🔍 Break down a complex topic",
            "📝 Show your note-taking process",
            "🧠 Teach something new to others"
        ]
    }

    func analyzeScene() {
        // Simulate AI scene analysis
        visionQueue.asyncAfter(deadline: .now() + 0.5) {
            let scenes = ["classroom", "library", "home study", "outdoors", "laboratory"]
            let lighting = ["excellent", "good", "adequate", "poor"]
            let tips = [
                "Try moving closer to a window for better natural light",
                "Consider the rule of thirds for better composition",
                "Ensure your subject is well-lit from the front",
                "Remove distracting elements from the background"
            ]

            DispatchQueue.main.async {
                self.sceneAnalysis = scenes.randomElement() ?? "indoor"
                self.lightingQuality = lighting.randomElement() ?? "good"
                self.compositionTips = Array(tips.shuffled().prefix(2))
            }
        }
    }

    // MARK: - Recent Media

    private func loadRecentMedia() {
        // Load recent photos and videos from Photos library
        // Implementation would use PHPhotoLibrary
    }

    // MARK: - Recording Timer

    private func startRecordingTimer() {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let startTime = self.recordingStartTime else { return }

            let elapsed = Date().timeIntervalSince(startTime)

            DispatchQueue.main.async {
                self.recordingDuration = elapsed
            }

            if elapsed >= self.maxDurationSeconds {
                self.stopRecording()
            }
        }
    }

    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        recordingStartTime = nil
    }

    // MARK: - Cleanup

    func cleanup() {
        stopRecordingTimer()
        timerCountdown?.invalidate()

        sessionQueue.async { [weak self] in
            self?.session.stopRunning()
        }

        // Turn off flash
        if isFlashOn {
            toggleFlash()
        }
    }

    deinit {
        cleanup()
    }
}

// MARK: - AVCaptureFileOutputRecordingDelegate

extension EnhancedCameraManager {
    func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        print("📹 Enhanced recording started: \(fileURL)")
        analyzeScene()
    }

    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if let error = error {
            print("Recording error: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.errorMessage = error.localizedDescription
            }
            return
        }

        print("Enhanced recording finished: \(outputFileURL)")

        // Generate thumbnail
        Task {
            let thumbnail = await self.generateThumbnail(from: outputFileURL)

            await MainActor.run {
                self.recordedVideoURL = outputFileURL
                self.generatedThumbnail = thumbnail
            }
        }
    }

    func generateThumbnail(from videoURL: URL) async -> UIImage? {
        let asset = AVAsset(url: videoURL)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.maximumSize = CGSize(width: 512, height: 512)

        let time = CMTime(seconds: 0.5, preferredTimescale: 600)

        do {
            let cgImage = try await imageGenerator.image(at: time).image
            return UIImage(cgImage: cgImage)
        } catch {
            print("Failed to generate thumbnail: \(error)")
            return nil
        }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension EnhancedCameraManager: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("Photo capture error: \(error.localizedDescription)")
            return
        }

        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            print("Failed to process photo data")
            return
        }

        DispatchQueue.main.async {
            self.capturedPhoto = image
        }
    }
}

// MARK: - Extensions

extension EnhancedCameraManager {
    var formattedDuration: String {
        let mins = Int(recordingDuration) / 60
        let secs = Int(recordingDuration) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    var recordingProgress: Double {
        recordingDuration / maxDurationSeconds
    }

    var speedText: String {
        switch currentSpeed {
        case 0.3: return "0.3x"
        case 0.5: return "0.5x"
        case 1.0: return "1x"
        case 2.0: return "2x"
        case 3.0: return "3x"
        default: return "1x"
        }
    }

    var timerText: String {
        switch timer {
        case 0: return "Timer"
        case 3: return "3s"
        case 10: return "10s"
        default: return "\(timer)s"
        }
    }
}

