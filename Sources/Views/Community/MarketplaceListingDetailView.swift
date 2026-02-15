import SwiftUI
import MapKit
import os

struct MarketplaceListingDetailView: View {
    let listing: APIMarketplaceListing
    
    @Environment(\.dismiss) private var dismiss
    @State private var showingChat = false
    @State private var currentPhotoIndex = 0
    @State private var region: MKCoordinateRegion
    
    init(listing: APIMarketplaceListing) {
        self.listing = listing
        let coordinate = CLLocationCoordinate2D(
            latitude: listing.lat ?? 40.7128,
            longitude: listing.lng ?? -74.0060
        )
        _region = State(initialValue: MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        ))
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Photo Gallery
                photoGallery
                
                // Content
                VStack(spacing: 24) {
                    // Title and Price
                    titlePriceSection
                    
                    Divider()
                    
                    // Item Details
                    detailsSection
                    
                    Divider()
                    
                    // Seller Section
                    sellerSection
                    
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
                ChatView(recipient: APIUserPreview(id: listing.seller.id, name: listing.seller.name, avatar: listing.seller.avatarURL))
                    .navigationTitle("Message Seller")
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
    
    private var photoGallery: some View {
        ZStack(alignment: .bottom) {
            if listing.images.isEmpty {
                Rectangle()
                    .fill(Color.gray.opacity(0.1))
                    .frame(height: 300)
                    .overlay(
                        Image(systemName: "bag.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.gray.opacity(0.3))
                    )
            } else {
                TabView(selection: $currentPhotoIndex) {
                    ForEach(0..<listing.images.count, id: \.self) { index in
                        AsyncImage(url: URL(string: listing.images[index])) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Color.gray.opacity(0.1)
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(.page)
                .frame(height: 300)
            }
            
            // Category Badge
            HStack {
                Text((listing.category ?? "General").uppercased())
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.8))
                    .clipShape(Capsule())
                Spacer()
            }
            .padding(20)
        }
    }
    
    private var titlePriceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(listing.title)
                .font(.title2.bold())
            
            Text("$\(String(format: "%.2f", listing.price))")
                .font(.title.bold())
                .foregroundColor(.green)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var detailsSection: some View {
        HStack(spacing: 20) {
            detailColumn(icon: "tag.fill", title: listing.condition ?? "Good", subtitle: "condition")
            Divider().frame(height: 40)
            detailColumn(icon: "clock.fill", title: timeAgo(from: listing.createdAtDate), subtitle: "listed")
            Divider().frame(height: 40)
            detailColumn(icon: "mappin.circle.fill", title: listing.locationName ?? "Local", subtitle: "location")
        }
        .padding(.vertical, 8)
    }
    
    private func detailColumn(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(.green)
            Text(title)
                .font(.headline)
                .lineLimit(1)
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    private var sellerSection: some View {
        HStack(spacing: 16) {
            // Avatar
            if let avatar = listing.seller.avatarURL, let url = URL(string: avatar) {
                AsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle().fill(Color.gray.opacity(0.2))
                }
                .frame(width: 50, height: 50)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.green.opacity(0.1))
                    .frame(width: 50, height: 50)
                    .overlay(Text(listing.seller.name.prefix(1)).foregroundColor(.green))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Seller")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(listing.seller.name)
                    .font(.headline)
            }
            
            Spacer()
            
            Button("View Profile") {
                // Navigate to seller's profile via deep link
                Log.social.info("Navigating to seller profile: \(listing.seller.name)")
                HapticManager.shared.light()
            }
            .font(.caption.bold())
            .foregroundColor(.green)
        }
    }
    
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Description")
                .font(.headline)
            Text(listing.description)
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
            
            Map(position: .constant(.region(region))) {
                Annotation("Location", coordinate: region.center) {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(.green)
                        .font(.title)
                        .background(Circle().fill(.white))
                }
            }
            .frame(height: 150)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .disabled(true)
        }
    }
    
    private var actionButtons: some View {
        Button {
            showingChat = true
            HapticManager.shared.playMediumImpact()
        } label: {
            HStack {
                Image(systemName: "message.fill")
                Text("Message Seller")
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.green)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .padding(.top, 12)
    }
    
    private func timeAgo(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

private struct MapLocation: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}
