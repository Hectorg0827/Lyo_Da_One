import SwiftUI

// MARK: - TTS View
struct TTSView: View {

    @StateObject private var viewModel = TTSViewModel()
    @State private var inputText = ""
    @State private var showVoiceSelector = false
    @State private var showSpeedSelector = false

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Text Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Enter text to convert to speech")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    TextEditor(text: $inputText)
                        .frame(minHeight: 150)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(.systemGray4), lineWidth: 1)
                        )
                }
                .padding(.horizontal)

                // Generate Button
                Button {
                    Task {
                        await viewModel.generateSpeech(for: inputText)
                    }
                } label: {
                    HStack {
                        if viewModel.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "waveform")
                            Text("Generate Speech")
                        }
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(inputText.isEmpty ? Color.gray : Color.blue)
                    .cornerRadius(12)
                }
                .disabled(inputText.isEmpty || viewModel.isLoading)
                .padding(.horizontal)

                Divider()

                // Highlighted Text Display
                if viewModel.totalDuration > 0 {
                    ScrollView {
                        HighlightedTextView(
                            text: inputText,
                            currentWordIndex: viewModel.currentWordIndex
                        )
                        .padding()
                    }
                    .frame(maxHeight: 200)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }

                Spacer()

                // Player Controls
                if viewModel.totalDuration > 0 {
                    VStack(spacing: 16) {
                        // Progress Bar
                        VStack(spacing: 8) {
                            ProgressView(value: viewModel.progress)
                                .progressViewStyle(LinearProgressViewStyle(tint: .blue))

                            HStack {
                                Text(viewModel.formattedCurrentTime)
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                Spacer()

                                Text(viewModel.formattedTotalDuration)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        // Playback Controls
                        HStack(spacing: 32) {
                            // Speed Control
                            Button {
                                showSpeedSelector = true
                            } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: "speedometer")
                                        .font(.system(size: 24))
                                    Text(viewModel.currentSpeedLabel)
                                        .font(.caption)
                                }
                                .foregroundColor(.blue)
                            }

                            // Previous (Rewind 10s)
                            Button {
                                let newTime = max(0, viewModel.currentTime - 10)
                                viewModel.seek(to: newTime)
                            } label: {
                                Image(systemName: "gobackward.10")
                                    .font(.system(size: 32))
                                    .foregroundColor(.blue)
                            }

                            // Play/Pause
                            Button {
                                if viewModel.isPlaying {
                                    viewModel.pause()
                                } else {
                                    viewModel.play()
                                }
                            } label: {
                                Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                    .font(.system(size: 64))
                                    .foregroundColor(.blue)
                            }

                            // Next (Forward 10s)
                            Button {
                                let newTime = min(viewModel.totalDuration, viewModel.currentTime + 10)
                                viewModel.seek(to: newTime)
                            } label: {
                                Image(systemName: "goforward.10")
                                    .font(.system(size: 32))
                                    .foregroundColor(.blue)
                            }

                            // Voice Selection
                            Button {
                                showVoiceSelector = true
                            } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: "person.wave.2")
                                        .font(.system(size: 24))
                                    Text(viewModel.selectedVoice.rawValue.capitalized)
                                        .font(.caption)
                                }
                                .foregroundColor(.blue)
                            }
                        }

                        // Stop Button
                        Button {
                            viewModel.stop()
                        } label: {
                            HStack {
                                Image(systemName: "stop.fill")
                                Text("Stop")
                            }
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .cornerRadius(12)
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.1), radius: 10, y: -5)
                }
            }
            .navigationTitle("Text to Speech")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showVoiceSelector) {
                VoiceSelectorView(viewModel: viewModel)
            }
            .sheet(isPresented: $showSpeedSelector) {
                SpeedSelectorView(viewModel: viewModel)
            }
            .alert("Error", isPresented: .constant(viewModel.error != nil)) {
                Button("OK") {
                    viewModel.error = nil
                }
            } message: {
                if let error = viewModel.error {
                    Text(error.errorDescription ?? "An error occurred")
                }
            }
            .task {
                await viewModel.loadVoices()
            }
        }
    }
}

// MARK: - Highlighted Text View
struct HighlightedTextView: View {
    let text: String
    let currentWordIndex: Int?

    var body: some View {
        let words = text.split(separator: " ").map(String.init)

        FlowLayout(spacing: 8) {
            ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                Text(word)
                    .font(.title3)
                    .fontWeight(currentWordIndex == index ? .bold : .regular)
                    .foregroundColor(currentWordIndex == index ? .white : .primary)
                    .padding(.horizontal, currentWordIndex == index ? 12 : 0)
                    .padding(.vertical, currentWordIndex == index ? 6 : 0)
                    .background(
                        currentWordIndex == index ?
                            AnyView(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.blue)
                                    .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                            ) :
                            AnyView(EmptyView())
                    )
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentWordIndex)
            }
        }
    }
}

// MARK: - Voice Selector View
struct VoiceSelectorView: View {
    @ObservedObject var viewModel: TTSViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            List {
                Section("Available Voices") {
                    ForEach(TTSVoice.allCases, id: \.self) { voice in
                        Button {
                            viewModel.changeVoice(voice)
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(voice.rawValue.capitalized)
                                        .font(.headline)
                                        .foregroundColor(.primary)

                                    Text(voiceDescription(for: voice))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                if viewModel.selectedVoice == voice {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }

                if !viewModel.availableVoices.isEmpty {
                    Section("Premium Voices") {
                        ForEach(viewModel.availableVoices) { voice in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(voice.name)
                                        .font(.headline)

                                    HStack {
                                        Text(voice.language)
                                            .font(.caption)
                                        if let gender = voice.gender {
                                            Text("•")
                                                .font(.caption)
                                            Text(gender)
                                                .font(.caption)
                                        }
                                    }
                                    .foregroundColor(.secondary)
                                }

                                Spacer()

                                if voice.previewURL != nil {
                                    Button {
                                        // TODO: Play preview
                                    } label: {
                                        Image(systemName: "play.circle")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Voice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func voiceDescription(for voice: TTSVoice) -> String {
        switch voice {
        case .alloy: return "Neutral and balanced"
        case .echo: return "Male, warm and expressive"
        case .fable: return "British accent, articulate"
        case .onyx: return "Deep and authoritative"
        case .nova: return "Female, bright and energetic"
        case .shimmer: return "Female, soft and soothing"
        }
    }
}

// MARK: - Speed Selector View
struct SpeedSelectorView: View {
    @ObservedObject var viewModel: TTSViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            List {
                Section("Playback Speed") {
                    ForEach(viewModel.speedOptions, id: \.self) { speed in
                        Button {
                            viewModel.changeSpeed(speed)
                            dismiss()
                        } label: {
                            HStack {
                                Text(speedLabel(for: speed))
                                    .foregroundColor(.primary)

                                Spacer()

                                if viewModel.playbackSpeed == speed {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Playback Speed")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func speedLabel(for speed: Float) -> String {
        if speed == 1.0 {
            return "Normal (1.0x)"
        } else if speed < 1.0 {
            return "Slow (\(speed)x)"
        } else {
            return "Fast (\(speed)x)"
        }
    }
}

// MARK: - TTSVoice Extension
extension TTSVoice: CaseIterable {
    static var allCases: [TTSVoice] {
        [.alloy, .echo, .fable, .onyx, .nova, .shimmer]
    }
}

struct TTSView_Previews: PreviewProvider {
    static var previews: some View {
        TTSView()
    }
}
