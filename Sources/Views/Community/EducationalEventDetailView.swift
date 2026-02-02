import SwiftUI
import MapKit

struct EducationalEventDetailView: View {
    let event: APIEducationalEvent
    @ObservedObject var viewModel: CommunityViewModel
    
    @Environment(\.dismiss) private var dismiss
    @State private var showingChat = false
    @State private var isRegistering = false
    @State private var hasRegistered = false
    @State private var region: MKCoordinateRegion
    
    init(event: APIEducationalEvent, viewModel: CommunityViewModel) {
        self.event = event
        self.viewModel = viewModel
        let coordinate = CLLocationCoordinate2D(
            latitude: event.lat ?? 40.7128,
            longitude: event.lng ?? -74.0060
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
                    
                    // Organizer Section
                    organizerSection
                    
                    Divider()
                    
                    // Description
                    descriptionSection
                    
                    Divider()
                    
                    // Location
                    locationSection
                    
                    // Action Buttons
                    actionButtons
                }
                .padding(20)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingChat) {
            NavigationStack {
                ChatView(recipient: event.organizerProfile ?? APIUserPreview(id: event.organizerId, name: "Organizer", avatar: nil))
                    .navigationTitle("Contact Organizer")
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
    }
    
    private var heroSection: some View {
        ZStack(alignment: .bottomLeading) {
            if let imageURL = event.imageURL, let url = URL(string: imageURL) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        Color.orange
                    }
                }
                .frame(height: 200)
                .clipped()
            } else {
                LinearGradient(
                    colors: [.orange, .red],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: 200)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("EVENT")
                    .font(.caption.bold())
                    .foregroundColor(.white.opacity(0.8))
                
                Text(event.title)
                    .font(.title.bold())
                    .foregroundColor(.white)
            }
            .padding(20)
            .background(
                LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .top, endPoint: .bottom)
            )
        }
    }
    
    private var quickInfoSection: some View {
        HStack(spacing: 20) {
            infoColumn(icon: "calendar", title: event.date.formatted(date: .abbreviated, time: .omitted), subtitle: event.date.formatted(date: .omitted, time: .shortened), color: .orange)
            Divider().frame(height: 40)
            infoColumn(icon: "person.2.fill", title: "\(event.attendeeCount)", subtitle: "attending", color: .blue)
            Divider().frame(height: 40)
            infoColumn(icon: "tag.fill", title: event.cost ?? 0 > 0 ? "$\(Int(event.cost!))" : "Free", subtitle: "cost", color: .green)
        }
        .padding(.vertical, 8)
    }
    
    private func infoColumn(icon: String, title: String, subtitle: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            Text(title)
                .font(.headline)
                .lineLimit(1)
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    private var organizerSection: some View {
        HStack(spacing: 16) {
            // Avatar Placeholder
            Circle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 50, height: 50)
                .overlay(Image(systemName: "person.fill").foregroundColor(.gray))
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Organized by")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(event.organizerProfile?.name ?? "Organizer")
                    .font(.headline)
            }
            
            Spacer()
            
            Button("Contact") {
                showingChat = true
            }
            .font(.subheadline.bold())
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.orange.opacity(0.1))
            .foregroundColor(.orange)
            .clipShape(Capsule())
        }
    }
    
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Details")
                .font(.headline)
            Text(event.description)
                .font(.body)
                .foregroundColor(.secondary)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Location")
                .font(.headline)
            
            HStack {
                Image(systemName: "mappin.circle.fill")
                    .foregroundColor(.red)
                Text(event.locationName)
                    .font(.subheadline)
            }
            
            Map(coordinateRegion: .constant(region), annotationItems: [MapLocation(coordinate: region.center)]) { location in
                MapMarker(coordinate: location.coordinate, tint: .orange)
            }
            .frame(height: 150)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .disabled(true)
        }
    }
    
    private var actionButtons: some View {
        Button {
            registerForEvent()
        } label: {
            HStack {
                if isRegistering {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: hasRegistered ? "checkmark.circle.fill" : "ticket.fill")
                    Text(hasRegistered ? "Registered" : "Register for Event")
                }
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(hasRegistered ? Color.green : Color.orange)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(isRegistering || hasRegistered)
        .padding(.top, 12)
    }
    
    private func registerForEvent() {
        isRegistering = true
        Task {
            do {
                try await viewModel.registerForEvent(id: String(event.id))
                await MainActor.run {
                    isRegistering = false
                    hasRegistered = true
                    HapticManager.shared.playSuccess()
                }
            } catch {
                await MainActor.run {
                    isRegistering = false
                }
            }
        }
    }
}

private struct MapLocation: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}
