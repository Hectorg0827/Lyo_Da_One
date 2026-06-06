import SwiftUI

struct ControlsOverlay: View {
    @ObservedObject var viewModel: ClassroomViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    viewModel.hideControls()
                }
            
            VStack {
                // Top bar
                topBar
                
                Spacer()
                
                // Center controls
                centerControls
                
                Spacer()
                
                // Bottom bar
                bottomBar
            }
        }
        .animation(.easeOut(duration: 0.2), value: viewModel.controlsVisible)
    }
    
    // MARK: - Top Bar
    
    private var topBar: some View {
        HStack {
            // Back button
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                    .padding()
                    .background(Circle().fill(Color.black.opacity(0.5)))
            }
            
            Spacer()
            
            // Module title
            if let session = viewModel.session {
                Text(session.modules[viewModel.currentModuleIndex].title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            Spacer()
            
            // Overflow menu
            Menu {
                Button {
                    // Save module
                } label: {
                    Label("Save Module", systemImage: "bookmark")
                }
                
                Button {
                    // Report issue
                } label: {
                    Label("Report Issue", systemImage: "exclamationmark.triangle")
                }
                
                Button(role: .destructive) {
                    dismiss()
                } label: {
                    Label("Exit Classroom", systemImage: "xmark")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .padding()
                    .background(Circle().fill(Color.black.opacity(0.5)))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }
    
    // MARK: - Center Controls
    
    private var centerControls: some View {
        HStack(spacing: 40) {
            // Skip backward
            Button {
                viewModel.skipBackward()
            } label: {
                Image(systemName: "gobackward.10")
                    .font(.system(size: 32))
                    .foregroundColor(.white)
            }
            
            // Rephrase
            Button {
                // Rephrase current slide
            } label: {
                VStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 28))
                    Text("Rephrase")
                        .font(.system(size: 13))
                }
                .foregroundColor(.white)
            }
            
            // Play/Pause (big center button)
            Button {
                viewModel.togglePlayPause()
            } label: {
                Image(systemName: viewModel.isNarrating ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 72))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 8)
            }
            
            // Explain differently
            Button {
                // Show alternative explanation
            } label: {
                VStack(spacing: 8) {
                    Image(systemName: "brain")
                        .font(.system(size: 28))
                    Text("Explain")
                        .font(.system(size: 13))
                }
                .foregroundColor(.white)
            }
            
            // Skip forward
            Button {
                viewModel.skipForward()
            } label: {
                Image(systemName: "goforward.10")
                    .font(.system(size: 32))
                    .foregroundColor(.white)
            }
        }
    }
    
    // MARK: - Bottom Bar
    
    private var bottomBar: some View {
        VStack(spacing: 12) {
            // Scrubber
            if let session = viewModel.session {
                ScrubberView(
                    currentSlideIndex: viewModel.currentSlideIndex,
                    totalSlides: session.modules[viewModel.currentModuleIndex].slides.count,
                    narrationProgress: viewModel.narrationProgress,
                    onSeek: { slideIndex in
                        viewModel.currentSlideIndex = slideIndex
                        if viewModel.settings.autoplayNarration {
                            viewModel.startNarration()
                        }
                    }
                )
                .padding(.horizontal, 20)
            }
            
            // Controls
            HStack(spacing: 24) {
                // Speed control
                Menu {
                    ForEach([0.75, 1.0, 1.25, 1.5], id: \.self) { speed in
                        Button {
                            viewModel.changeSpeed(Float(speed))
                        } label: {
                            HStack {
                                Text("\(speed, specifier: "%.2f")×")
                                if viewModel.settings.playbackSpeed == Float(speed) {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "gauge")
                        Text("\(viewModel.settings.playbackSpeed, specifier: "%.2f")×")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.black.opacity(0.5)))
                }
                
                // Captions toggle
                Button {
                    viewModel.settings.captionsEnabled.toggle()
                } label: {
                    Image(systemName: viewModel.settings.captionsEnabled ? "captions.bubble.fill" : "captions.bubble")
                        .font(.system(size: 18))
                        .foregroundColor(viewModel.settings.captionsEnabled ? Color("LyoAccent") : .white)
                }
                
                // TTS toggle
                Button {
                    if viewModel.isNarrating {
                        viewModel.stopNarration()
                    }
                    viewModel.settings.autoplayNarration.toggle()
                } label: {
                    Image(systemName: viewModel.settings.autoplayNarration ? "speaker.wave.3.fill" : "speaker.slash.fill")
                        .font(.system(size: 18))
                        .foregroundColor(viewModel.settings.autoplayNarration ? Color("LyoAccent") : .white)
                }
                
                Spacer()
                
                // Notes button
                Button {
                    // Open notes
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "note.text")
                        Text("Notes")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.black.opacity(0.5)))
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
    }
}

// MARK: - Scrubber

struct ScrubberView: View {
    let currentSlideIndex: Int
    let totalSlides: Int
    let narrationProgress: Double
    let onSeek: (Int) -> Void
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                Rectangle()
                    .fill(Color.white.opacity(0.3))
                    .frame(height: 4)
                
                // Progress
                Rectangle()
                    .fill(Color("LyoAccent"))
                    .frame(
                        width: geometry.size.width * overallProgress,
                        height: 4
                    )
                
                // Chapter ticks
                HStack(spacing: 0) {
                    ForEach(0..<totalSlides, id: \.self) { index in
                        Rectangle()
                            .fill(Color.white.opacity(0.8))
                            .frame(width: 2, height: 8)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .clipShape(Capsule())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { value in
                        let progress = value.location.x / geometry.size.width
                        let slideIndex = Int(progress * Double(totalSlides))
                        onSeek(min(max(slideIndex, 0), totalSlides - 1))
                    }
            )
        }
        .frame(height: 8)
    }
    
    private var overallProgress: Double {
        (Double(currentSlideIndex) + narrationProgress) / Double(totalSlides)
    }
}
