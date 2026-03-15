//
//  ChapterProgressBar.swift
//  Lyo
//
//  Segmented chapter progress bar for Clips recording.
//  Shows Intro → Key Point → Action → Summary with per-segment status.
//

import SwiftUI

// MARK: - Chapter Progress Bar

struct ChapterProgressBar: View {
    let chapters: [ChapterSegment]
    let activeIndex: Int
    let isRecording: Bool
    let onSelectChapter: (Int) -> Void
    let onReRecord: (Int) -> Void
    
    @State private var pulseAnimation: Bool = false
    
    var body: some View {
        VStack(spacing: 8) {
            // MARK: - Segment Bar
            HStack(spacing: 3) {
                ForEach(Array(chapters.enumerated()), id: \.element.id) { index, chapter in
                    chapterSegment(chapter: chapter, index: index)
                }
            }
            .frame(height: 6)
            .clipShape(Capsule())
            
            // MARK: - Labels
            HStack(spacing: 0) {
                ForEach(Array(chapters.enumerated()), id: \.element.id) { index, chapter in
                    Button {
                        if chapter.isRecorded {
                            onReRecord(index)
                        } else {
                            onSelectChapter(index)
                        }
                    } label: {
                        VStack(spacing: 4) {
                            // Status icon
                            ZStack {
                                if chapter.isRecorded {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(chapter.color)
                                } else if index == activeIndex {
                                    Circle()
                                        .fill(chapter.color)
                                        .frame(width: 10, height: 10)
                                        .scaleEffect(pulseAnimation ? 1.3 : 1.0)
                                        .opacity(pulseAnimation ? 0.6 : 1.0)
                                } else {
                                    Circle()
                                        .stroke(chapter.color.opacity(0.5), lineWidth: 1.5)
                                        .frame(width: 10, height: 10)
                                }
                            }
                            .frame(height: 16)
                            
                            // Title
                            Text(chapter.title)
                                .font(.system(size: 10, weight: index == activeIndex ? .bold : .medium, design: .rounded))
                                .foregroundColor(index == activeIndex ? .white : .white.opacity(0.6))
                            
                            // Duration or re-record hint
                            if chapter.isRecorded {
                                Text(formatDuration(chapter.duration))
                                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                                    .foregroundColor(chapter.color.opacity(0.8))
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
        .padding(.horizontal, 20)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                pulseAnimation = true
            }
        }
    }
    
    // MARK: - Segment Capsule
    
    private func chapterSegment(chapter: ChapterSegment, index: Int) -> some View {
        GeometryReader { geo in
            RoundedRectangle(cornerRadius: 3)
                .fill(segmentColor(for: chapter, at: index))
                .overlay(
                    // Recording fill animation
                    Group {
                        if index == activeIndex && isRecording {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(chapter.color)
                                .scaleEffect(x: 1, y: 1, anchor: .leading)
                                .animation(.linear(duration: 0.3), value: isRecording)
                        }
                    }
                )
        }
    }
    
    private func segmentColor(for chapter: ChapterSegment, at index: Int) -> some ShapeStyle {
        if chapter.isRecorded {
            return AnyShapeStyle(chapter.color)
        } else if index == activeIndex {
            return AnyShapeStyle(chapter.color.opacity(0.5))
        } else {
            return AnyShapeStyle(Color.white.opacity(0.15))
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let seconds = Int(duration)
        return "\(seconds)s"
    }
}

// MARK: - Preview

struct ChapterProgressBar_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack {
                ChapterProgressBar(
                    chapters: [
                        ChapterSegment(title: "Intro",     color: Color(hex: "42A5F5"), isRecorded: true, duration: 12),
                        ChapterSegment(title: "Key Point", color: Color(hex: "AB47BC"), isRecorded: true, duration: 18),
                        ChapterSegment(title: "Action",    color: Color(hex: "66BB6A")),
                        ChapterSegment(title: "Summary",   color: Color(hex: "FFA726"))
                    ],
                    activeIndex: 2,
                    isRecording: false,
                    onSelectChapter: { _ in },
                    onReRecord: { _ in }
                )
                
                Spacer()
            }
            .padding(.top, 60)
        }
    }
}
