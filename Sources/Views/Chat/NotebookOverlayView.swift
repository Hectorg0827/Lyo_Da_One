import SwiftUI

// MARK: - Chat Notes Sheet
/// Full-height sheet opened from the notebook icon in the chat header.
/// Lists all notes saved from the current conversation with per-note actions:
///   - "Explain Further" → asks the AI to elaborate on the note text
///   - "Branch to New Chat" → opens a fresh chat pre-seeded with this topic

struct ChatNotesSheetView: View {
    @ObservedObject var store: NotebookStore
    @Binding var isPresented: Bool
    var onExplainFurther: ((NotebookEntry) -> Void)?
    var onBranchToNewChat: ((NotebookEntry) -> Void)?

    var body: some View {
        NavigationStack {
            Group {
                if store.notes.isEmpty {
                    emptyState
                } else {
                    notesList
                }
            }
            .navigationTitle("My Notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { isPresented = false }
                        .foregroundColor(.white)
                }
            }
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .preferredColorScheme(.dark)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "note.text")
                .font(.system(size: 48))
                .foregroundColor(.white.opacity(0.15))
            Text("No notes yet")
                .font(.headline)
                .foregroundColor(.white.opacity(0.5))
            Text("Select text in a message and tap\n\"Note\" to save it here.")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.35))
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Color(white: 0.08))
    }

    // MARK: - Notes List

    private var notesList: some View {
        List {
            ForEach(store.notes) { note in
                NoteCardRow(
                    note: note,
                    onExplain: { onExplainFurther?(note) },
                    onBranch: { onBranchToNewChat?(note) }
                )
                .listRowBackground(Color.white.opacity(0.04))
                .listRowSeparatorTint(.white.opacity(0.08))
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        withAnimation {
                            store.deleteNote(noteId: note.id)
                        }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(white: 0.08))
    }
}

// MARK: - Note Card Row

private struct NoteCardRow: View {
    let note: NotebookEntry
    var onExplain: (() -> Void)?
    var onBranch: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Source context badge + timestamp
            HStack {
                if let ctx = note.sourceContext {
                    Text(ctx)
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(hex: note.color).opacity(0.2))
                        .foregroundColor(Color(hex: note.color))
                        .clipShape(Capsule())
                }
                Spacer()
                Text(note.createdAt.formatted(.dateTime.month(.abbreviated).day().hour().minute()))
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.35))
            }

            // Note text
            Text(note.text)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.9))
                .lineLimit(6)
                .textSelection(.enabled)

            // Action buttons
            HStack(spacing: 12) {
                Button(action: { onExplain?() }) {
                    Label("Explain Further", systemImage: "sparkles")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.purple)
                }

                Button(action: { onBranch?() }) {
                    Label("Branch to New Chat", systemImage: "arrow.turn.up.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.blue)
                }

                Spacer()

                // Copy
                Button {
                    UIPasteboard.general.string = note.text
                    HapticManager.shared.playLightImpact()
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Notebook Icon Button (shown in chat header when notes exist)

struct NotebookIconButton: View {
    @ObservedObject var store: NotebookStore
    @Binding var showSheet: Bool

    var body: some View {
        if store.hasNotesInActiveConversation {
            Button {
                showSheet = true
                HapticManager.shared.playLightImpact()
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "note.text")
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.8))
                        .frame(width: 40, height: 40)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())

                    // Badge count
                    Text("\(store.notes.count)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .frame(minWidth: 16, minHeight: 16)
                        .background(Color.purple)
                        .clipShape(Circle())
                        .offset(x: 4, y: -4)
                }
            }
        }
    }
}

// RoundedCorner & cornerRadius helper already in ShapeExtensions.swift

#Preview {
    ChatNotesSheetView(
        store: NotebookStore(),
        isPresented: .constant(true)
    )
}
