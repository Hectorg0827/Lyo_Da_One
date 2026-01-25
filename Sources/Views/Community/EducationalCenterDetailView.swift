//
//  EducationalCenterDetailView.swift
//  Lyo
//
//  Detail view for educational centers (libraries, dance schools, etc.)
//

import SwiftUI
import MapKit

struct EducationalCenterDetailView: View {
    let center: APIEducationalCenter
    
    @Environment(\.dismiss) private var dismiss
    @State private var showingChat = false
    @State private var showingReviewInput = false
    @State private var region: MKCoordinateRegion
    
    init(center: APIEducationalCenter) {
        self.center = center
        let coordinate = CLLocationCoordinate2D(
            latitude: center.lat,
            longitude: center.lng
        )
        _region = State(initialValue: MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        ))
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Hero Section
                heroSection
                
                // Content
                VStack(spacing: 24) {
                    // Quick Info
                    quickInfoSection
                    
                    Divider()
                    
                    // Description
                    descriptionSection
                    
                    Divider()
                    
                    // Location & Hours
                    locationSection
                    
                    Divider()
                    
                    // Reviews
                    reviewsSection
                    
                    // Action Buttons
                    actionButtons
                }
                .padding(20)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingChat) {
            NavigationStack {
                ChatView(recipient: APIUserPreview(
                    id: Int(center.id),
                    name: center.name,
                    avatar: center.imageURL
                ))
                    .navigationTitle("Contact \(center.name)")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Done") {
                                showingChat = false
                            }
                        }
                    }
            }
        }
        .sheet(isPresented: $showingReviewInput) {
            ReviewInputView(
                targetId: String(center.id),
                targetType: "center",
                targetName: center.name
            )
        }
    }
    
    // MARK: - Hero Section
    
    private var heroSection: some View {
        ZStack(alignment: .bottomLeading) {
            // Background Image
            Group {
                if let imageURL = center.imageURL, let url = URL(string: imageURL) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        default:
                            defaultHeroBackground
                        }
                    }
                } else {
                    defaultHeroBackground
                }
            }
            .frame(height: 220)
            .clipped()
            
            // Gradient Overlay
            LinearGradient(
                colors: [.clear, .black.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            )
            
            // Title and Category Badge
            VStack(alignment: .leading, spacing: 8) {
                // Category Badge
                Text(center.category.uppercased())
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(categoryColor.opacity(0.8))
                    .clipShape(Capsule())
                
                Text(center.name)
                    .font(.title.bold())
                    .foregroundColor(.white)
            }
            .padding(20)
        }
    }
    
    private var defaultHeroBackground: some View {
        LinearGradient(
            colors: [categoryColor, categoryColor.opacity(0.7)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            Image(systemName: categoryIcon)
                .font(.system(size: 60))
                .foregroundColor(.white.opacity(0.3))
        )
    }
    
    private var categoryColor: Color {
        switch center.category.lowercased() {
        case "library": return .blue
        case "dance school", "salsa school": return .pink
        case "fitness", "gym": return .orange
        case "music school": return .purple
        case "art school": return .indigo
        case "bookstore": return .brown
        default: return .teal
        }
    }
    
    private var categoryIcon: String {
        switch center.category.lowercased() {
        case "library": return "books.vertical.fill"
        case "dance school", "salsa school": return "figure.dance"
        case "fitness", "gym": return "figure.run"
        case "music school": return "music.note.house.fill"
        case "art school": return "paintpalette.fill"
        case "bookstore": return "book.fill"
        default: return "building.2.fill"
        }
    }
    
    // MARK: - Quick Info Section
    
    private var quickInfoSection: some View {
        HStack(spacing: 20) {
            // Category
            VStack(spacing: 4) {
                Image(systemName: categoryIcon)
                    .font(.title2)
                    .foregroundColor(categoryColor)
                Text(center.category)
                    .font(.headline)
                    .lineLimit(1)
                Text("category")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            
            Divider()
                .frame(height: 50)
            
            // Hours
            VStack(spacing: 4) {
                Image(systemName: "clock.fill")
                    .font(.title2)
                    .foregroundColor(.green)
                Text(center.openingHours ?? "Hours vary")
                    .font(.headline)
                    .lineLimit(1)
                Text("open")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            
            Divider()
                .frame(height: 50)
            
            // Rating placeholder
            VStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .font(.title2)
                    .foregroundColor(.yellow)
                Text("4.5")
                    .font(.headline)
                Text("rating")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Description Section
    
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("About")
                .font(.headline)
            
            Text(center.description)
                .font(.body)
                .foregroundColor(.secondary)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Location Section
    
    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Location")
                .font(.headline)
            
            // Address
            if let address = center.address {
                HStack {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(.red)
                    Text(address)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            // Map
            Map(coordinateRegion: .constant(region), annotationItems: [MapLocation(coordinate: region.center)]) { location in
                MapMarker(coordinate: location.coordinate, tint: categoryColor)
            }
            .frame(height: 150)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .disabled(true)
            
            // Directions Button
            Button {
                openInMaps()
            } label: {
                HStack {
                    Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                    Text("Get Directions")
                }
                .font(.subheadline.bold())
                .foregroundColor(categoryColor)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Reviews Section
    
    private var reviewsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Reviews")
                    .font(.headline)
                
                Spacer()
                
                Button {
                    showingReviewInput = true
                    HapticManager.shared.playLightImpact()
                } label: {
                    Text("Write a Review")
                        .font(.subheadline.bold())
                        .foregroundColor(categoryColor)
                }
            }
            
            ReviewListView(targetType: "center", targetId: String(center.id))
        }
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Contact Center Button
            Button {
                initiateChat()
            } label: {
                HStack {
                    Image(systemName: "message.fill")
                    Text("Contact Center")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [categoryColor, categoryColor.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            
            // Share Button
            Button {
                shareCenter()
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share")
                }
                .font(.headline)
                .foregroundColor(categoryColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(categoryColor.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(categoryColor.opacity(0.3), lineWidth: 1)
                )
            }
        }
        .padding(.top, 8)
    }
    
    // MARK: - Actions
    
    private func initiateChat() {
        HapticManager.shared.playLightImpact()
        showingChat = true
    }
    
    private func openInMaps() {
        let coordinate = CLLocationCoordinate2D(latitude: center.lat, longitude: center.lng)
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        mapItem.name = center.name
        mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }
    
    private func shareCenter() {
        HapticManager.shared.playLightImpact()
        // Share functionality will be enhanced later
    }
}

// MARK: - Map Helper

private struct MapLocation: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

// MARK: - Preview

#Preview {
    NavigationStack {
        EducationalCenterDetailView(
            center: APIEducationalCenter(
                id: 1,
                name: "Downtown Dance Studio",
                category: "Dance School",
                description: "Premier salsa and bachata dance studio offering classes for all skill levels. Join our vibrant community and learn from professional instructors with years of experience.",
                lat: 40.7128,
                lng: -74.0060,
                imageURL: nil,
                address: "123 Dance Ave, New York, NY 10001",
                openingHours: "9AM - 10PM"
            )
        )
    }
}
