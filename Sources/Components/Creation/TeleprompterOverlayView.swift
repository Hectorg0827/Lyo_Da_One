//
//  TeleprompterOverlayView.swift
//  Lyo
//
//  Translucent auto-scrolling teleprompter that sits near the camera lens
//  so the creator maintains "eye contact" while reading their script.
//

import SwiftUI

// MARK: - Teleprompter Overlay

struct TeleprompterOverlayView: View {
    @Binding var scriptText: String
    @Binding var scrollSpeed: Double
    @Binding var isPaused: Bool
    @Binding var opacity: Double
    let onDismiss: () -> Void
    
    @State private var scrollOffset: CGFloat = 0
    @State private var scrollTimer: Timer?
    @State private var isEditing: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header
            HStack {
                // Title
                HStack(spacing: 6) {
                    Image(systemName: "text.justify.left")
                        .font(.system(size: 14, weight: .medium))
                    Text("Teleprompter")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
                .foregroundColor(.white)
                
                Spacer()
                
                // Edit / Done Toggle
                Button {
                    isEditing.toggle()
                } label: {
                    Text(isEditing ? "Done" : "Edit")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.cyan)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(.ultraThinMaterial))
                }
                
                // Dismiss
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
            
            Divider()
                .background(Color.white.opacity(0.2))
            
            // MARK: - Script Area
            if isEditing {
                TextEditor(text: $scriptText)
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .frame(height: 160)
                    .onChange(of: scriptText) { _, _ in
                        scrollOffset = 0
                    }
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    Text(scriptText.isEmpty ? "Tap Edit to write your script..." : scriptText)
                        .font(.system(size: 22, weight: .medium, design: .rounded))
                        .foregroundColor(scriptText.isEmpty ? .white.opacity(0.4) : .white)
                        .lineSpacing(8)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .offset(y: -scrollOffset)
                }
                .frame(height: 160)
                .clipped()
            }
            
            Divider()
                .background(Color.white.opacity(0.2))
            
            // MARK: - Speed Control
            HStack(spacing: 12) {
                Image(systemName: "tortoise.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
                
                Slider(value: $scrollSpeed, in: 0.3...3.0, step: 0.1)
                    .tint(.cyan)
                    .frame(maxWidth: .infinity)
                
                Image(systemName: "hare.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
                
                Text(String(format: "%.1f×", scrollSpeed))
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.cyan)
                    .frame(width: 36)
                
                // Pause / Play
                Button {
                    isPaused.toggle()
                } label: {
                    Image(systemName: isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(.ultraThinMaterial))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .opacity(opacity)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.4), radius: 20, y: 5)
        .padding(.horizontal, 20)
        .onAppear { startScrolling() }
        .onDisappear { stopScrolling() }
        .onChange(of: isPaused) { _, paused in
            if paused {
                stopScrolling()
            } else {
                startScrolling()
            }
        }
        .onChange(of: scrollSpeed) { _, _ in
            restartScrolling()
        }
        .onTapGesture {
            if !isEditing {
                isPaused.toggle()
            }
        }
    }
    
    // MARK: - Auto-Scroll
    
    private func startScrolling() {
        guard !scriptText.isEmpty else { return }
        scrollTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            Task { @MainActor in
                scrollOffset += CGFloat(scrollSpeed) * 0.4
            }
        }
    }
    
    private func stopScrolling() {
        scrollTimer?.invalidate()
        scrollTimer = nil
    }
    
    private func restartScrolling() {
        stopScrolling()
        if !isPaused { startScrolling() }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        VStack {
            TeleprompterOverlayView(
                scriptText: .constant("Welcome to this quick explainer on photosynthesis.\n\nToday we'll cover the basics of how plants convert sunlight into energy.\n\nFirst, let's talk about chlorophyll — the green pigment in leaves.\n\nChlorophyll absorbs light energy, primarily from blue and red wavelengths.\n\nThis energy drives the light-dependent reactions in the thylakoid membrane."),
                scrollSpeed: .constant(1.0),
                isPaused: .constant(false),
                opacity: .constant(0.75),
                onDismiss: {}
            )
            
            Spacer()
        }
        .padding(.top, 80)
    }
}
