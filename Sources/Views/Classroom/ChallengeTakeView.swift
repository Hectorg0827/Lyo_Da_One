import SwiftUI

/// Take a friend's challenge: fetch by code, answer the questions, submit,
/// and see the scoreboard. Opened from lyoapp://challenge/<code> deep links
/// or by entering a code.
struct ChallengeTakeView: View {
    let code: String
    @Environment(\.dismiss) private var dismiss

    private enum Phase {
        case loading
        case playing(FriendChallenge)
        case scoreboard(ChallengeScoreboard, myScore: Int, total: Int)
        case failed(String)
    }

    @State private var phase: Phase = .loading
    @State private var currentIndex = 0
    @State private var score = 0
    @State private var selectedOption: Int?
    @State private var startedAt = Date()

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hexString: "0B1230").ignoresSafeArea()

                switch phase {
                case .loading:
                    ProgressView("Loading challenge…")
                        .tint(.white)
                        .foregroundColor(.white.opacity(0.8))

                case .failed(let message):
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.title)
                            .foregroundColor(.orange)
                        Text(message)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                        Button("Close") { dismiss() }
                            .buttonStyle(.borderedProminent)
                    }
                    .padding(32)

                case .playing(let challenge):
                    quizBody(challenge)

                case .scoreboard(let board, let myScore, let total):
                    scoreboardBody(board, myScore: myScore, total: total)
                }
            }
            .navigationTitle("Challenge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .preferredColorScheme(.dark)
        }
        .task { await load() }
    }

    // MARK: Quiz

    @ViewBuilder
    private func quizBody(_ challenge: FriendChallenge) -> some View {
        let questions = challenge.questions
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                if let name = challenge.creatorName {
                    Text("\(name) challenged you!")
                        .font(.caption.bold())
                        .foregroundColor(Color(hexString: "A78BFA"))
                }
                Text(challenge.topic)
                    .font(.title2.bold())
                    .foregroundColor(.white)
                Text("Question \(currentIndex + 1) of \(questions.count) · Score \(score)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }

            if currentIndex < questions.count {
                let q = questions[currentIndex]
                Text(q.question)
                    .font(.headline)
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 10) {
                    ForEach(Array(q.options.enumerated()), id: \.offset) { idx, option in
                        Button {
                            guard selectedOption == nil else { return }
                            selectedOption = idx
                            if idx == q.answerIndex {
                                score += 1
                                HapticManager.shared.playSuccess()
                            } else {
                                HapticManager.shared.playLightImpact()
                            }
                            // Brief reveal, then advance.
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                                selectedOption = nil
                                if currentIndex + 1 < questions.count {
                                    currentIndex += 1
                                } else {
                                    Task { await finish(total: questions.count) }
                                }
                            }
                        } label: {
                            HStack {
                                Text(option)
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.leading)
                                Spacer()
                                if let sel = selectedOption, sel == idx {
                                    Image(systemName: idx == q.answerIndex ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundColor(idx == q.answerIndex ? .green : .red)
                                }
                            }
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(selectedOption == idx ? 0.15 : 0.06))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                    )
                            )
                        }
                        .disabled(selectedOption != nil)
                    }
                }
            }
            Spacer()
        }
        .padding(20)
    }

    // MARK: Scoreboard

    @ViewBuilder
    private func scoreboardBody(_ board: ChallengeScoreboard, myScore: Int, total: Int) -> some View {
        VStack(spacing: 18) {
            VStack(spacing: 6) {
                Text("You scored \(myScore)/\(total)")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                Text(board.topic)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.top, 12)

            VStack(spacing: 8) {
                ForEach(Array(board.attempts.enumerated()), id: \.element.id) { rank, attempt in
                    HStack(spacing: 12) {
                        Text(rank == 0 ? "🥇" : rank == 1 ? "🥈" : rank == 2 ? "🥉" : "\(rank + 1).")
                            .frame(width: 32)
                        Text(attempt.userName ?? "Learner \(attempt.userId)")
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                        Spacer()
                        Text("\(attempt.score)/\(attempt.total)")
                            .font(.subheadline.monospacedDigit())
                            .foregroundColor(Color(hexString: "A78BFA"))
                        if let secs = attempt.secondsTaken {
                            Text("· \(Int(secs))s")
                                .font(.caption.monospacedDigit())
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(rank == 0 ? 0.12 : 0.05))
                    )
                }
            }

            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        Capsule().fill(
                            LinearGradient(
                                colors: [Color(hexString: "8B5CF6"), Color(hexString: "6366F1")],
                                startPoint: .leading, endPoint: .trailing
                            ))
                    )
                    .foregroundColor(.white)
            }
            Spacer()
        }
        .padding(20)
    }

    // MARK: Data

    private func load() async {
        do {
            let challenge = try await ChallengeService.shared.fetch(code: code)
            guard !challenge.questions.isEmpty else {
                phase = .failed("This challenge has no questions.")
                return
            }
            startedAt = Date()
            phase = .playing(challenge)
        } catch {
            phase = .failed("Couldn't load challenge \(code.uppercased()). Check the code and your connection.")
        }
    }

    private func finish(total: Int) async {
        let seconds = Date().timeIntervalSince(startedAt)
        do {
            let board = try await ChallengeService.shared.submit(
                code: code, score: score, total: total, secondsTaken: seconds)
            phase = .scoreboard(board, myScore: score, total: total)
        } catch {
            phase = .failed("Your score couldn't be submitted. Try again in a moment.")
        }
    }
}
