import SwiftUI

/// Report a Discover video, or block the person who posted it.
///
/// The same choices and rules as the web sheet (ReportClipSheet.tsx): a
/// reason, an optional note, and Block with a confirmation when
/// DiscoverSafety.canBlock allows it. What the server answers decides the
/// outcome; a failure keeps the sheet open with the choices intact.
struct ReportClipSheet: View {
    let item: DiscoverItem
    let canBlock: Bool
    let onReported: (DiscoverSafety.Outcome) -> Void
    let onBlocked: (DiscoverSafety.Outcome) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var reason: DiscoverReportReason?
    @State private var note = ""
    @State private var sending = false
    @State private var blocking = false
    @State private var confirmingBlock = false
    @State private var errorMessage: String?

    private var ownerName: String { item.authorName ?? "this person" }
    private var busy: Bool { sending || blocking }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(DiscoverReportReason.allCases) { option in
                        Button {
                            reason = option
                        } label: {
                            HStack {
                                Text(option.label)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if reason == option {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.red)
                                }
                            }
                        }
                        .accessibilityAddTraits(reason == option ? .isSelected : [])
                    }
                } header: {
                    Text("What's wrong with this video?")
                }

                Section("Anything else we should know? (optional)") {
                    TextField("Add a note", text: $note, axis: .vertical)
                        .lineLimit(2...5)
                        .onChange(of: note) { _, value in
                            if value.count > DiscoverSafety.noteLimit {
                                note = String(value.prefix(DiscoverSafety.noteLimit))
                            }
                        }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button {
                        Task { await send() }
                    } label: {
                        HStack {
                            Spacer()
                            if sending {
                                ProgressView()
                            } else {
                                Text("Send report").bold()
                            }
                            Spacer()
                        }
                    }
                    .disabled(reason == nil || busy)
                }

                if canBlock {
                    Section {
                        Button(role: .destructive) {
                            confirmingBlock = true
                        } label: {
                            HStack {
                                Spacer()
                                if blocking {
                                    ProgressView()
                                } else {
                                    Label("Block \(ownerName)", systemImage: "person.fill.xmark")
                                }
                                Spacer()
                            }
                        }
                        .disabled(busy)
                    } footer: {
                        Text("You won't see each other's videos or comments in Discover.")
                    }
                }
            }
            .navigationTitle("Report video")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(busy)
                }
            }
            .confirmationDialog("Block \(ownerName)?", isPresented: $confirmingBlock, titleVisibility: .visible) {
                Button("Block", role: .destructive) {
                    Task { await block() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You won't see each other's videos or comments in Discover. You can unblock them in Settings.")
            }
            .interactiveDismissDisabled(busy)
        }
    }

    private func send() async {
        guard let reason, !busy else { return }
        sending = true
        errorMessage = nil
        let status = await LyoAPIClient.shared.reportClip(
            clipId: item.id,
            reason: reason.rawValue,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        let outcome = DiscoverSafety.reportOutcome(status: status)
        sending = false
        if outcome.succeeded {
            onReported(outcome)
        } else {
            errorMessage = outcome.message
        }
    }

    private func block() async {
        guard let ownerId = item.authorId, !busy else { return }
        blocking = true
        errorMessage = nil
        let status = await LyoAPIClient.shared.blockUser(userId: ownerId)
        let outcome = DiscoverSafety.blockOutcome(status: status, name: ownerName)
        blocking = false
        if outcome.succeeded {
            onBlocked(outcome)
        } else {
            errorMessage = outcome.message
        }
    }
}
