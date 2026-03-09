import SwiftUI

struct NotebookOverlayView: View {
    @ObservedObject var store: NotebookStore
    @Binding var isOpen: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "pencil.and.outline")
                        .foregroundColor(.yellow)
                    Text("Persistent Notebook")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                HStack(spacing: 16) {
                    if !store.notes.isEmpty {
                        Text("\(store.notes.count) items")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    
                    Button {
                        withAnimation(.spring()) {
                            isOpen.toggle()
                        }
                    } label: {
                        Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.black.opacity(0.4))
            .background(.ultraThinMaterial)
            
            if isOpen {
                Divider().background(Color.white.opacity(0.1))
                
                if store.notes.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "text.badge.plus")
                            .font(.system(size: 32))
                            .foregroundColor(.white.opacity(0.2))
                        Text("No highlights yet")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.4))
                        Text("Hold down on any message to save it.")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.3))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .background(Color.black.opacity(0.3))
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(store.notes) { note in
                                NoteMiniCard(note: note)
                            }
                        }
                        .padding(16)
                    }
                    .background(Color.black.opacity(0.3))
                }
            }
        }
        .cornerRadius(16, corners: [.bottomLeft, .bottomRight])
        .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
    }
}

struct NoteMiniCard: View {
    let note: NotebookEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(note.tags.first ?? "General")
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(hex: note.color).opacity(0.2))
                    .foregroundColor(Color(hex: note.color))
                    .cornerRadius(4)
                
                Spacer()
                
                Text(note.createdAt.formatted(.dateTime.hour().minute()))
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.4))
            }
            
            Text(note.text)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.9))
                .lineLimit(3)
                .multilineTextAlignment(.leading)
            
            if let context = note.sourceContext {
                Text(context)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.3))
                    .lineLimit(1)
            }
        }
        .frame(width: 180, height: 120, alignment: .topLeading)
        .padding(12)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

// RoundedCorner & cornerRadius helper already in ShapeExtensions.swift

#Preview {
    ZStack(alignment: .top) {
        Color.blue.ignoresSafeArea()
        NotebookOverlayView(store: NotebookStore(), isOpen: .constant(true))
            .padding(.top, 50)
    }
}
