//
//  WaitingRoomView.swift
//  Lyo
//
//  A dedicated loading screen for AI Course Generation, showing local
//  targeted ads and a progress bar while the backend prepares the syllabus.
//

import SwiftUI

struct WaitingRoomView: View {
    let courseTitle: String
    var mascotNamespace: Namespace.ID
    let onComplete: () -> Void
    
    @State private var progress: CGFloat = 0.0
    @State private var adIndex: Int = 0
    @State private var hasCompleted: Bool = false
    
    @StateObject private var adService = AdService.shared
    
    var body: some View {
        ZStack {
            // Dark Background
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // Targeted Ad Carousel
                VStack(spacing: 16) {
                    HStack {
                        Text("Sponsored")
                            .font(.caption.bold())
                            .foregroundColor(.white.opacity(0.6))
                        Spacer()
                    }
                    .padding(.horizontal, 32)
                    
                    ZStack {
                        if adService.availableAds.isEmpty {
                            ProgressView()
                                .tint(.white)
                        } else {
                            ForEach(0..<adService.availableAds.count, id: \.self) { index in
                                if index == adIndex {
                                    adCard(adService.availableAds[index])
                                        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                                }
                            }
                        }
                    }
                    .frame(height: 180)
                    .padding(.horizontal, 24)
                }
                
                Spacer()
                
                // Mascot & Progress
                VStack(spacing: 24) {
                    // Thinking Mascots - using Matched Geometry to jump from chat
                    AnimatedReadingMascotView(size: 80)
                        .matchedGeometryEffect(id: "mascot_shared", in: mascotNamespace)
                    
                    VStack(spacing: 12) {
                        Text("Designing your course...")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text(courseTitle)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .padding(.horizontal, 40)
                        
                        // Progress Bar
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.white.opacity(0.1))
                                    .frame(height: 8)
                                
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [.purple, .indigo],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: max(0, proxy.size.width * progress), height: 8)
                            }
                        }
                        .frame(height: 8)
                        .frame(width: 240)
                        .padding(.top, 10)
                        
                        Text("\(Int(progress * 100))%")
                            .font(.caption.bold())
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                .padding(.bottom, 60)
            }
        }
        .onAppear {
            startGenerationSequence()
            startAdRotation()
            Task {
                await adService.fetchAds()
            }
        }
    }
    
    private func adCard(_ ad: LyoAd) -> some View {
        Button(action: {
            if let urlString = ad.destinationURL, let url = URL(string: urlString) {
                UIApplication.shared.open(url)
            }
        }) {
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                
                HStack(spacing: 20) {
                    // Icon/Image
                    if let imageURLString = ad.imageURL, let url = URL(string: imageURLString) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .empty:
                                Circle()
                                    .fill(Color.white.opacity(0.1))
                                    .frame(width: 60, height: 60)
                                    .overlay(ProgressView())
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 60, height: 60)
                                    .clipShape(Circle())
                            case .failure:
                                Circle()
                                    .fill(Color.blue.opacity(0.2))
                                    .frame(width: 60, height: 60)
                                    .overlay(
                                        Image(systemName: "star.fill")
                                            .foregroundColor(.blue)
                                    )
                            @unknown default:
                                EmptyView()
                            }
                        }
                    } else {
                        Circle()
                            .fill(Color.blue.opacity(0.2))
                            .frame(width: 60, height: 60)
                            .overlay(
                                Image(systemName: "star.fill")
                                    .foregroundColor(.blue)
                            )
                    }
                    
                    // Content
                    VStack(alignment: .leading, spacing: 6) {
                        Text(ad.title)
                            .font(.headline)
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        
                        Text(ad.subtitle)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.5))
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                        
                        Text(ad.callToAction)
                            .font(.caption.bold())
                            .foregroundColor(.blue)
                            .padding(.top, 4)
                    }
                    Spacer()
                }
                .padding(24)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func startGenerationSequence() {
        let totalDuration: TimeInterval = 7.0
        let steps = 100
        let stepDuration = totalDuration / Double(steps)
        
        Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { timer in
            withAnimation(.linear(duration: stepDuration)) {
                progress += 0.01
            }
            
            if progress >= 1.0 {
                timer.invalidate()
                if !hasCompleted {
                    hasCompleted = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        onComplete()
                    }
                }
            }
        }
    }
    
    private func startAdRotation() {
        Timer.scheduledTimer(withTimeInterval: 3.5, repeats: true) { timer in
            Task { @MainActor in
                if hasCompleted {
                    timer.invalidate()
                    return
                }
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    adIndex = (adIndex + 1) % max(1, adService.availableAds.count)
                }
            }
        }
    }
}
