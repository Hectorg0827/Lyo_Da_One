//
//  CommunityMapView.swift
//  Lyo
//
//  Map view component for displaying community items on a map
//

import SwiftUI
import MapKit

/// A map view displaying community beacons and items
/// Note: Main map functionality is in CommunityGoogleStyleMap in CommunityView.swift
/// This view provides an alternative/standalone map implementation
struct CommunityMapView: View {
    @ObservedObject var viewModel: CommunityViewModel
    @State private var selectedBeacon: CommunityBeacon?
    
    var body: some View {
        ZStack {
            // Map with annotations
            Map(position: $viewModel.mapCameraPosition) {
                ForEach(viewModel.beacons) { beacon in
                    Annotation(beacon.title, coordinate: beacon.coordinate) {
                        BeaconMarkerView(
                            beacon: beacon,
                            isSelected: selectedBeacon?.id == beacon.id,
                            onTap: {
                                withAnimation(.spring(response: 0.3)) {
                                    selectedBeacon = beacon
                                }
                            }
                        )
                    }
                }
            }
            .ignoresSafeArea()
            
            // Selected beacon detail card
            if let beacon = selectedBeacon {
                VStack {
                    Spacer()
                    BeaconDetailCard(beacon: beacon) {
                        withAnimation {
                            selectedBeacon = nil
                        }
                    }
                    .padding()
                    .padding(.bottom, 20)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
}

// MARK: - Beacon Marker View

struct BeaconMarkerView: View {
    let beacon: CommunityBeacon
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                ZStack {
                    // Shadow/glow effect
                    Circle()
                        .fill(beacon.type.color.opacity(0.3))
                        .frame(width: isSelected ? 50 : 40, height: isSelected ? 50 : 40)
                        .blur(radius: 4)
                    
                    // Main circle
                    Circle()
                        .fill(beacon.type.color)
                        .frame(width: isSelected ? 40 : 32, height: isSelected ? 40 : 32)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: isSelected ? 3 : 2)
                        )
                        .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 2)
                    
                    // Icon
                    Image(systemName: beacon.type.icon)
                        .font(.system(size: isSelected ? 16 : 12, weight: .bold))
                        .foregroundColor(.white)
                }
                
                // Pointer triangle
                Triangle()
                    .fill(beacon.type.color)
                    .frame(width: 12, height: 8)
                    .offset(y: -2)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isSelected ? 1.1 : 1.0)
        .animation(.spring(response: 0.3), value: isSelected)
    }
}

// MARK: - Triangle Shape

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Beacon Detail Card

struct BeaconDetailCard: View {
    let beacon: CommunityBeacon
    let onDismiss: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(beacon.type.color.opacity(0.15))
                    .frame(width: 50, height: 50)
                
                Image(systemName: beacon.type.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(beacon.type.color)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(beacon.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                if let subtitle = beacon.subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                // Type badge
                Text(beacon.type.rawValue)
                    .font(.caption.weight(.medium))
                    .foregroundColor(beacon.type.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(beacon.type.color.opacity(0.1))
                    .cornerRadius(4)
            }
            
            Spacer()
            
            // Actions
            VStack(spacing: 8) {
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.gray)
                }
                
                Button(action: {
                    // Navigate to detail
                }) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.title2)
                        .foregroundColor(beacon.type.color)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
        )
    }
}

// MARK: - Preview

#Preview {
    CommunityMapView(viewModel: CommunityViewModel())
}
