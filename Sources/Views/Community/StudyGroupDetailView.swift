import SwiftUI
import MapKit

struct StudyGroupDetailView: View {
    let group: APIStudyGroup
    @ObservedObject var viewModel: CommunityViewModel
    
    @Environment(\.dismiss) private var dismiss
    @State private var showingChat = false
    @State private var isJoining = false
    @State private var hasJoined = false
    @State private var region: MKCoordinateRegion
    
    init(group: APIStudyGroup, viewModel: CommunityViewModel) {
        self.group = group
        self.viewModel = viewModel
        let coordinate = CLLocationCoordinate2D(
            latitude: group.lat ?? 40.7128,
            longitude: group.lng ?? -74.0060
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
                    
                    // Host Section
                    hostSection
                    
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
                ChatView(recipient: group.host)
                    .navigationTitle("Contact \(group.host.name)")
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
            LinearGradient(
                colors: [.blue, .blue.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 180)
            .overlay(
                Image(systemName: "person.3.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.white.opacity(0.3))
            )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(group.subject.uppercased())
                    .font(.caption.bold())
                    .foregroundColor(.white.opacity(0.8))
                
                Text(group.name)
                    .font(.title.bold())
                    .foregroundColor(.white)
            }
            .padding(20)
        }
    }
    
    private var quickInfoSection: some View {
        HStack(spacing: 20) {
            infoColumn(icon: "person.2.fill", title: "\(group.memberCount)/\(group.maxMembers)", subtitle: "members", color: .blue)
            Divider().frame(height: 40)
            infoColumn(icon: "calendar", title: group.nextSession?.formatted(date: .abbreviated, time: .omitted) ?? "TBD", subtitle: "next session", color: .orange)
            Divider().frame(height: 40)
            infoColumn(icon: "mappin.circle.fill", title: group.isRemote ? "Remote" : (group.locationName ?? "Local"), subtitle: "location", color: .green)
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
    
    private var hostSection: some View {
        HStack(spacing: 16) {
            // Avatar Placeholder
            Circle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 50, height: 50)
                .overlay(Image(systemName: "person.fill").foregroundColor(.gray))
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Hosted by")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(group.host.name)
                    .font(.headline)
            }
            
            Spacer()
            
            Button("Message") {
                showingChat = true
            }
            .font(.subheadline.bold())
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.blue.opacity(0.1))
            .foregroundColor(.blue)
            .clipShape(Capsule())
        }
    }
    
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("About the Group")
                .font(.headline)
            Text(group.description)
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
            
            Map(coordinateRegion: .constant(region), annotationItems: [MapLocation(coordinate: region.center)]) { location in
                MapMarker(coordinate: location.coordinate, tint: .blue)
            }
            .frame(height: 150)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .disabled(true)
        }
    }
    
    private var actionButtons: some View {
        Button {
            joinGroup()
        } label: {
            HStack {
                if isJoining {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: hasJoined ? "checkmark.circle.fill" : "person.badge.plus.fill")
                    Text(hasJoined ? "Joined" : "Join Study Group")
                }
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(hasJoined ? Color.green : Color.blue)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(isJoining || hasJoined)
        .padding(.top, 12)
    }
    
    private func joinGroup() {
        isJoining = true
        Task {
            do {
                try await viewModel.joinStudyGroup(id: String(group.id))
                await MainActor.run {
                    isJoining = false
                    hasJoined = true
                    HapticManager.shared.playSuccess()
                }
            } catch {
                await MainActor.run {
                    isJoining = false
                }
            }
        }
    }
}

private struct MapLocation: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}
