import AVFoundation
import SwiftUI
import UIKit

/// Camera controller used by the production Create Hub.
///
/// This controller owns one capture session and exposes only operations that are
/// actually supported by the UI: photo capture, video recording, camera switch,
/// torch control, permission state, and recorded output.
final class CreateCameraController: NSObject, ObservableObject {
    @Published private(set) var cameraPermissionGranted = false
    @Published private(set) var microphonePermissionGranted = false
    @Published private(set) var isSessionConfigured = false
    @Published private(set) var isRecording = false
    @Published private(set) var recordingDuration: TimeInterval = 0
    @Published private(set) var currentPosition: AVCaptureDevice.Position = .back
    @Published private(set) var isTorchOn = false
    @Published private(set) var torchAvailable = false
    @Published private(set) var capturedImage: UIImage?
    @Published private(set) var recordedVideoURL: URL?
    @Published var errorMessage: String?

    let session = AVCaptureSession()
    let maximumRecordingDuration: TimeInterval = 180

    private let sessionQueue = DispatchQueue(label: "com.lyo.create.camera.session")
    private let movieOutput = AVCaptureMovieFileOutput()
    private let photoOutput = AVCapturePhotoOutput()
    private var videoInput: AVCaptureDeviceInput?
    private var audioInput: AVCaptureDeviceInput?
    private var recordingTimer: Timer?
    private var recordingStartedAt: Date?
    private var configurationStarted = false

    override init() {
        super.init()
        refreshPermissions()
    }

    var formattedDuration: String {
        let seconds = Int(recordingDuration)
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    func refreshPermissions() {
        requestCameraPermissionIfNeeded()
        requestMicrophonePermissionIfNeeded()
    }

    func startSession() {
        refreshPermissions()
        configureSessionIfPossible()
        sessionQueue.async { [weak self] in
            guard let self, self.isSessionConfigured, !self.session.isRunning else { return }
            self.session.startRunning()
        }
    }

    func stopSession() {
        if isRecording {
            stopRecording()
        }
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    func switchCamera() {
        guard !isRecording else { return }
        sessionQueue.async { [weak self] in
            guard let self, self.isSessionConfigured else { return }
            let nextPosition: AVCaptureDevice.Position = self.currentPosition == .back ? .front : .back

            self.session.beginConfiguration()
            defer { self.session.commitConfiguration() }

            if let existingInput = self.videoInput {
                self.session.removeInput(existingInput)
            }

            guard let newInput = self.makeVideoInput(position: nextPosition),
                  self.session.canAddInput(newInput) else {
                if let existingInput = self.videoInput, self.session.canAddInput(existingInput) {
                    self.session.addInput(existingInput)
                }
                DispatchQueue.main.async {
                    self.errorMessage = "The selected camera is unavailable."
                }
                return
            }

            self.session.addInput(newInput)
            self.videoInput = newInput
            self.updateDeviceState(for: newInput.device, position: nextPosition)
        }
    }

    func toggleTorch() {
        setTorch(enabled: !isTorchOn)
    }

    func setTorch(enabled: Bool) {
        guard let device = videoInput?.device, device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            if enabled {
                try device.setTorchModeOn(level: min(0.7, AVCaptureDevice.maxAvailableTorchLevel))
            } else {
                device.torchMode = .off
            }
            device.unlockForConfiguration()
            DispatchQueue.main.async {
                self.isTorchOn = enabled
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "The camera light could not be changed."
            }
        }
    }

    func capturePhoto() {
        guard cameraPermissionGranted, isSessionConfigured, !isRecording else {
            errorMessage = "Camera access is required to take a photo."
            return
        }

        let settings = AVCapturePhotoSettings()
        if let device = videoInput?.device, device.hasFlash {
            settings.flashMode = isTorchOn ? .on : .off
        }
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    func startRecording() {
        guard cameraPermissionGranted, isSessionConfigured, !isRecording else {
            if !cameraPermissionGranted {
                errorMessage = "Camera access is required to record a video."
            }
            return
        }

        capturedImage = nil
        recordedVideoURL = nil
        recordingDuration = 0

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("lyo-create-\(UUID().uuidString)")
            .appendingPathExtension("mp4")

        if let connection = movieOutput.connection(with: .video),
           connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90
        }

        movieOutput.startRecording(to: outputURL, recordingDelegate: self)
        isRecording = true
        recordingStartedAt = Date()
        startRecordingTimer()
    }

    func stopRecording() {
        guard isRecording else { return }
        movieOutput.stopRecording()
        stopRecordingTimer()
        isRecording = false
    }

    func resetCapturedMedia(removeTemporaryVideo: Bool = true) {
        if removeTemporaryVideo, let recordedVideoURL {
            try? FileManager.default.removeItem(at: recordedVideoURL)
        }
        capturedImage = nil
        recordedVideoURL = nil
        recordingDuration = 0
    }

    func cleanup() {
        stopRecordingTimer()
        if isRecording {
            movieOutput.stopRecording()
            isRecording = false
        }
        setTorch(enabled: false)
        stopSession()
    }

    private func requestCameraPermissionIfNeeded() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            cameraPermissionGranted = true
            configureSessionIfPossible()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.cameraPermissionGranted = granted
                    if granted {
                        self?.configureSessionIfPossible()
                    }
                }
            }
        default:
            cameraPermissionGranted = false
        }
    }

    private func requestMicrophonePermissionIfNeeded() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            microphonePermissionGranted = true
            addAudioInputIfPossible()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.microphonePermissionGranted = granted
                    if granted {
                        self?.addAudioInputIfPossible()
                    }
                }
            }
        default:
            microphonePermissionGranted = false
        }
    }

    private func configureSessionIfPossible() {
        guard cameraPermissionGranted, !configurationStarted else { return }
        configurationStarted = true

        sessionQueue.async { [weak self] in
            guard let self else { return }

            self.session.beginConfiguration()
            self.session.sessionPreset = .high

            guard let initialVideoInput = self.makeVideoInput(position: .back),
                  self.session.canAddInput(initialVideoInput) else {
                self.session.commitConfiguration()
                DispatchQueue.main.async {
                    self.configurationStarted = false
                    self.errorMessage = "No usable camera was found on this device."
                }
                return
            }

            self.session.addInput(initialVideoInput)
            self.videoInput = initialVideoInput

            if self.microphonePermissionGranted {
                self.addAudioInputDuringConfiguration()
            }

            if self.session.canAddOutput(self.movieOutput) {
                self.session.addOutput(self.movieOutput)
                self.movieOutput.maxRecordedDuration = CMTime(
                    seconds: self.maximumRecordingDuration,
                    preferredTimescale: 600
                )
            }

            if self.session.canAddOutput(self.photoOutput) {
                self.session.addOutput(self.photoOutput)
            }

            self.session.commitConfiguration()

            DispatchQueue.main.async {
                self.isSessionConfigured = true
                self.updateDeviceState(for: initialVideoInput.device, position: .back)
            }

            if !self.session.isRunning {
                self.session.startRunning()
            }
        }
    }

    private func makeVideoInput(position: AVCaptureDevice.Position) -> AVCaptureDeviceInput? {
        guard let device = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: position
        ) else {
            return nil
        }
        return try? AVCaptureDeviceInput(device: device)
    }

    private func addAudioInputIfPossible() {
        sessionQueue.async { [weak self] in
            guard let self, self.isSessionConfigured, self.audioInput == nil else { return }
            self.session.beginConfiguration()
            self.addAudioInputDuringConfiguration()
            self.session.commitConfiguration()
        }
    }

    private func addAudioInputDuringConfiguration() {
        guard audioInput == nil,
              let device = AVCaptureDevice.default(for: .audio),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return }
        session.addInput(input)
        audioInput = input
    }

    private func updateDeviceState(for device: AVCaptureDevice, position: AVCaptureDevice.Position) {
        DispatchQueue.main.async {
            self.currentPosition = position
            self.torchAvailable = device.hasTorch && position == .back
            if position == .front {
                self.isTorchOn = false
            }
        }
    }

    private func startRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self, let recordingStartedAt = self.recordingStartedAt else { return }
            let elapsed = Date().timeIntervalSince(recordingStartedAt)
            self.recordingDuration = elapsed
            if elapsed >= self.maximumRecordingDuration {
                self.stopRecording()
            }
        }
    }

    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        recordingStartedAt = nil
    }
}

extension CreateCameraController: AVCapturePhotoCaptureDelegate {
    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if let error {
            DispatchQueue.main.async {
                self.errorMessage = error.localizedDescription
            }
            return
        }

        guard let data = photo.fileDataRepresentation(), let image = UIImage(data: data) else {
            DispatchQueue.main.async {
                self.errorMessage = "The captured photo could not be processed."
            }
            return
        }

        DispatchQueue.main.async {
            self.capturedImage = image
        }
    }
}

extension CreateCameraController: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        DispatchQueue.main.async {
            self.stopRecordingTimer()
            self.isRecording = false
            if let error {
                self.errorMessage = error.localizedDescription
            } else {
                self.recordedVideoURL = outputFileURL
            }
        }
    }
}
