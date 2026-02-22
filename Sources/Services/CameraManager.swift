import SwiftUI
import AVFoundation
import UIKit
import os

// MARK: - Enhanced Camera Manager

/// Enhanced camera manager with front/back switching, flash, timer, and thumbnail generation
class CameraManager: NSObject, ObservableObject, AVCaptureFileOutputRecordingDelegate {
    // MARK: - Published State
    
    @Published var permissionGranted = false
    @Published var audioPermissionGranted = false
    @Published var isRecording = false
    @Published var recordedVideoURL: URL?
    @Published var recordingDuration: TimeInterval = 0
    @Published var currentPosition: AVCaptureDevice.Position = .back
    @Published var isFlashOn = false
    @Published var generatedThumbnail: UIImage?
    @Published var errorMessage: String?
    
    // MARK: - Configuration
    
    /// Maximum recording duration in seconds (3 minutes)
    let maxDurationSeconds: TimeInterval = 180
    
    // MARK: - Session Components
    
    let session = AVCaptureSession()
    private let movieOutput = AVCaptureMovieFileOutput()
    private let photoOutput = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "cameraSessionQueue")
    private var currentVideoInput: AVCaptureDeviceInput?
    private var currentAudioInput: AVCaptureDeviceInput?
    
    // MARK: - Recording Timer
    
    private var recordingTimer: Timer?
    private var recordingStartTime: Date?
    
    // MARK: - Init
    
    override init() {
        super.init()
        checkPermissions()
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
    
    // MARK: - Session Configuration
    
    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .high
        
        // Add video input
        configureVideoInput(position: .back)
        
        // Add audio input
        configureAudioInput()
        
        // Add movie output with max duration
        if session.canAddOutput(movieOutput) {
            session.addOutput(movieOutput)
            movieOutput.maxRecordedDuration = CMTime(seconds: maxDurationSeconds, preferredTimescale: 600)
            
            // Set video quality
            if let connection = movieOutput.connection(with: .video) {
                if connection.isVideoStabilizationSupported {
                    connection.preferredVideoStabilizationMode = .auto
                }
            }
        }
        
        // Add photo output
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }
        
        session.commitConfiguration()
    }
    
    private func configureVideoInput(position: AVCaptureDevice.Position) {
        // Remove existing video input
        if let existing = currentVideoInput {
            session.removeInput(existing)
        }
        
        // Add new video input
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
              let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice),
              session.canAddInput(videoDeviceInput) else {
            Log.media.warning("Failed to configure video input for position: \(String(describing: position))")
            return
        }
        
        session.addInput(videoDeviceInput)
        currentVideoInput = videoDeviceInput
        
        DispatchQueue.main.async {
            self.currentPosition = position
        }
    }
    
    private func configureAudioInput() {
        guard let audioDevice = AVCaptureDevice.default(for: .audio),
              let audioDeviceInput = try? AVCaptureDeviceInput(device: audioDevice),
              session.canAddInput(audioDeviceInput) else {
            Log.media.warning("Failed to configure audio input")
            return
        }
        
        session.addInput(audioDeviceInput)
        currentAudioInput = audioDeviceInput
    }
    
    // MARK: - Camera Controls
    
    /// Switch between front and back camera
    func switchCamera() {
        guard !isRecording else { return } // Don't switch while recording
        
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.session.beginConfiguration()
            
            let newPosition: AVCaptureDevice.Position = self.currentPosition == .back ? .front : .back
            self.configureVideoInput(position: newPosition)
            
            self.session.commitConfiguration()
        }
    }
    
    /// Toggle flash/torch
    func toggleFlash() {
        guard let device = currentVideoInput?.device,
              device.hasTorch else { return }
        
        do {
            try device.lockForConfiguration()
            
            if device.torchMode == .off {
                try device.setTorchModeOn(level: 0.7)
                DispatchQueue.main.async {
                    self.isFlashOn = true
                }
            } else {
                device.torchMode = .off
                DispatchQueue.main.async {
                    self.isFlashOn = false
                }
            }
            
            device.unlockForConfiguration()
        } catch {
            Log.media.warning("Failed to toggle flash: \(error)")
        }
    }
    
    /// Set flash on or off explicitly
    func setFlash(on: Bool) {
        guard let device = currentVideoInput?.device,
              device.hasTorch else { return }
        
        do {
            try device.lockForConfiguration()
            
            if on {
                try device.setTorchModeOn(level: 0.7)
            } else {
                device.torchMode = .off
            }
            
            device.unlockForConfiguration()
            
            DispatchQueue.main.async {
                self.isFlashOn = on
            }
        } catch {
            Log.media.warning("Failed to set flash: \(error)")
        }
    }
    
    // MARK: - Recording
    
    func startRecording() {
        guard !isRecording else { return }
        guard permissionGranted else {
            errorMessage = "Camera permission not granted"
            return
        }
        
        // Clear previous recording
        recordedVideoURL = nil
        generatedThumbnail = nil
        recordingDuration = 0
        
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("clip_\(UUID().uuidString).mp4")
        
        movieOutput.startRecording(to: tempURL, recordingDelegate: self)
        
        DispatchQueue.main.async {
            self.isRecording = true
            self.recordingStartTime = Date()
            self.startRecordingTimer()
        }
    }
    
    func stopRecording() {
        guard isRecording else { return }
        
        movieOutput.stopRecording()
        stopRecordingTimer()
        
        DispatchQueue.main.async {
            self.isRecording = false
        }
    }
    
    // MARK: - Recording Timer
    
    private func startRecordingTimer() {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let startTime = self.recordingStartTime else { return }
            
            let elapsed = Date().timeIntervalSince(startTime)
            
            DispatchQueue.main.async {
                self.recordingDuration = elapsed
            }
            
            // Auto-stop at max duration
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
    
    // MARK: - AVCaptureFileOutputRecordingDelegate
    
    func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        Log.media.info("📹 Recording started: \(fileURL)")
    }
    
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if let error = error {
            Log.media.error("Recording error: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.errorMessage = error.localizedDescription
            }
            return
        }
        
        Log.media.info("Recording finished: \(outputFileURL)")
        
        // Generate thumbnail
        Task {
            let thumbnail = await self.generateThumbnail(from: outputFileURL)
            
            await MainActor.run {
                self.recordedVideoURL = outputFileURL
                self.generatedThumbnail = thumbnail
            }
        }
    }
    
    // MARK: - Thumbnail Generation
    
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
            Log.media.warning("Failed to generate thumbnail: \(error)")
            return nil
        }
    }
    
    // MARK: - Cleanup
    
    func cleanup() {
        stopRecordingTimer()
        
        sessionQueue.async { [weak self] in
            self?.session.stopRunning()
        }
        
        // Turn off flash
        setFlash(on: false)
    }
    
    deinit {
        cleanup()
    }
}

// MARK: - Duration Formatter Extension

extension CameraManager {
    /// Format recording duration as mm:ss
    var formattedDuration: String {
        let mins = Int(recordingDuration) / 60
        let secs = Int(recordingDuration) % 60
        return String(format: "%d:%02d", mins, secs)
    }
    
    /// Format max duration as mm:ss
    var formattedMaxDuration: String {
        let mins = Int(maxDurationSeconds) / 60
        let secs = Int(maxDurationSeconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
    
    /// Recording progress (0-1)
    var recordingProgress: Double {
        recordingDuration / maxDurationSeconds
    }
}
