import SwiftUI

struct CourseCardView: View {
    let card: CourseCard
    let onContinue: () -> Void
    let onSave: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Cover image
            AsyncImage(url: URL(string: card.coverURL ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(16/9, contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color("LyoSurface"))
                    .overlay(
                        Image(systemName: "book.fill")
                            .font(.system(size: 32))
                            .foregroundColor(Color("LyoTextSecondary"))
                    )
            }
            .frame(height: 140)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            VStack(alignment: .leading, spacing: 8) {
                // Title
                Text(card.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                
                // Description
                if let description = card.description {
                    Text(description)
                        .font(.system(size: 13))
                        .foregroundColor(Color("LyoTextSecondary"))
                        .lineLimit(2)
                }
                
                // Tags
                if let tags = card.tags, !tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(Color("LyoAccent"))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule()
                                            .fill(Color("LyoSurface"))
                                    )
                            }
                        }
                    }
                }
                
                // Progress bar
                if let progress = card.progress, progress > 0 {
                    VStack(alignment: .leading, spacing: 4) {
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(Color("LyoSurface"))
                                    .frame(height: 2)
                                
                                Rectangle()
                                    .fill(Color("LyoAccent"))
                                    .frame(width: geometry.size.width * CGFloat(progress), height: 2)
                                    .animation(.easeOut(duration: 0.6), value: progress)
                            }
                        }
                        .frame(height: 2)
                        
                        Text("\(Int(progress * 100))% complete")
                            .font(.system(size: 11))
                            .foregroundColor(Color("LyoTextSecondary"))
                    }
                }
                
                // Meta info
                HStack(spacing: 12) {
                    if let lastOpened = card.lastOpened {
                        Text("Last opened · \(timeAgo(lastOpened))")
                            .font(.system(size: 11))
                            .foregroundColor(Color("LyoTextSecondary"))
                    }
                    
                    if let timeLeft = card.timeLeft {
                        Text("• \(timeLeft)")
                            .font(.system(size: 11))
                            .foregroundColor(Color("LyoTextSecondary"))
                    }
                }
                
                // Action buttons
                HStack(spacing: 12) {
                    Button {
                        onContinue()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: statusIcon)
                                .font(.system(size: 14))
                            Text(statusLabel)
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(Color("LyoAccent"))
                        )
                    }
                    
                    Button {
                        onSave()
                    } label: {
                        Image(systemName: "bookmark")
                            .font(.system(size: 16))
                            .foregroundColor(Color("LyoAccent"))
                            .frame(width: 40, height: 40)
                            .background(
                                Circle()
                                    .fill(Color("LyoSurface"))
                            )
                    }
                    
                    Menu {
                        Button("Share", action: {})
                        Button("Remove", role: .destructive, action: {})
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 16))
                            .foregroundColor(Color("LyoAccent"))
                            .frame(width: 40, height: 40)
                            .background(
                                Circle()
                                    .fill(Color("LyoSurface"))
                            )
                    }
                }
            }
            .padding(12)
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color("LyoBackground").opacity(0.6))
        )
    }
    
    private var statusIcon: String {
        switch card.status {
        case .continue: return "play.fill"
        case .started: return "play.fill"
        case .suggested: return "plus"
        case .completed: return "checkmark"
        }
    }
    
    private var statusLabel: String {
        switch card.status {
        case .continue: return "Continue"
        case .started: return "Resume"
        case .suggested: return "Start"
        case .completed: return "Review"
        }
    }
    
    private func timeAgo(_ date: Date) -> String {
        let minutes = Int(Date().timeIntervalSince(date) / 60)
        if minutes < 60 {
            return "\(minutes)m ago"
        }
        let hours = minutes / 60
        if hours < 24 {
            return "\(hours)h ago"
        }
        let days = hours / 24
        return "\(days)d ago"
    }
}
