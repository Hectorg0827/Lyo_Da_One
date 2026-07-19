import SwiftUI
import MapKit

// MARK: - Community Map View
@available(iOS 17.0, *)
struct CommunityMapView: View {
    
    @StateObject private var viewModel = CommunityViewModel()
    @State private var searchQuery = ""
    @State private var isDockExpanded = false
    @State private var showDetailSheet = false

    var body: some View {
        mapContent
            .task {
                viewModel.startUpdatingLocation()
                await viewModel.loadAllData()
            }
    }

    private var mapContent: some View {
        ZStack(alignment: .top) {
            mapLayer
            topControls

            CommunityDockView(viewModel: viewModel, isExpanded: $isDockExpanded)
                .zIndex(10)
        }
    }

    private var mapLayer: some View {
        Map(position: .constant(.region(viewModel.mapRegion)))
        .ignoresSafeArea()
        .onTapGesture {
            withAnimation {
                viewModel.selectedPin = nil
                isDockExpanded = false
            }
        }
    }

    private var topControls: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                searchField
                profileButton
            }
            .padding(.horizontal)
            .padding(.top, 60)

            HStack {
                Spacer()
                locationButton
                    .padding(.trailing, 16)
                    .padding(.top, 8)
            }

            Spacer()
        }
        .allowsHitTesting(true)
    }

    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)

            TextField("Search Community...", text: $searchQuery)
                .submitLabel(.search)
                .onSubmit {
                    Task { await viewModel.searchInstitutions(query: searchQuery) }
                }

            if !searchQuery.isEmpty {
                Button(action: { searchQuery = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4)
    }

    private var profileButton: some View {
        Button(action: {}) {
            Circle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 44, height: 44)
                .overlay(Image(systemName: "person.fill").foregroundColor(.gray))
        }
    }

    private var locationButton: some View {
        Button(action: centerMapOnUser) {
            Image(systemName: "location.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.blue)
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
    }

    private func select(_ pin: MapPin) {
        HapticManager.shared.selection()
        viewModel.centerMapOnPin(pin)
        withAnimation {
            isDockExpanded = true
        }
    }

    private func centerMapOnUser() {
        HapticManager.shared.selection()
        viewModel.centerMapOnUser()
    }
}

// MARK: - Map Pin View
struct MapPinView: View {
    let pin: MapPin
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                Image(systemName: pin.type.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(pinColor)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 3)
                    )
                    .shadow(color: .black.opacity(0.3), radius: 4, y: 2)

                // Pin tail
                Triangle()
                    .fill(pinColor)
                    .frame(width: 12, height: 8)
                    .offset(y: -4)
            }
        }
    }

    private var pinColor: Color {
        switch pin.type.color {
        case "purple": return .purple
        case "blue": return .blue
        case "green": return .green
        case "gray": return .gray
        default: return .blue
        }
    }
}

// MARK: - Triangle Shape for Pin Tail
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

// MARK: - Filter Chip
struct CommunityMapFilterChip: View {
    let filter: CommunityFilter
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: filter.icon)
                    .font(.system(size: 14))

                Text(filter.title)
                    .font(.system(size: 14, weight: .medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue : Color(.systemGray6))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(20)
        }
    }
}

// MARK: - Filter Sheet View
struct FilterSheetView: View {
    @ObservedObject var viewModel: CommunityViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            List {
                Section("Filter by Type") {
                    ForEach(viewModel.availableFilters) { filter in
                        Button {
                            viewModel.applyFilter(filter)
                        } label: {
                            HStack {
                                Image(systemName: filter.icon)
                                    .foregroundColor(.blue)
                                    .frame(width: 24)

                                Text(filter.title)
                                    .foregroundColor(.primary)

                                Spacer()

                                if viewModel.activeFilters.contains(filter) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }

                Section("Statistics") {
                    HStack {
                        Text("Study Groups")
                        Spacer()
                        Text("\(viewModel.studyGroups.count)")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Events")
                        Spacer()
                        Text("\(viewModel.events.count)")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Marketplace Listings")
                        Spacer()
                        Text("\(viewModel.listings.count)")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Institutions")
                        Spacer()
                        Text("\(viewModel.institutions.count)")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Pin Detail View
struct PinDetailView: View {
    let pin: MapPin
    @ObservedObject var viewModel: CommunityViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch pin.type {
                    case .studyGroup(let group):
                        CommunityMapStudyGroupDetailView(group: group, viewModel: viewModel)

                    case .event(let event):
                        EventDetailView(event: event, viewModel: viewModel)

                    case .marketplace(let listing):
                        MarketplaceDetailView(listing: listing, viewModel: viewModel)

                    case .institution(let institution):
                        InstitutionDetailView(institution: institution, viewModel: viewModel)
                    }

                    // Distance & Directions
                    if let distance = pin.distance {
                        Divider()

                        HStack {
                            Image(systemName: "location.fill")
                                .foregroundColor(.blue)

                            Text(String(format: "%.1f mi away", distance))
                                .font(.subheadline)

                            Spacer()

                            Button {
                                viewModel.getDirections(to: pin.coordinate)
                                dismiss()
                            } label: {
                                HStack {
                                    Image(systemName: "arrow.triangle.turn.up.right.diamond")
                                    Text("Directions")
                                }
                                .font(.subheadline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.blue)
                                .cornerRadius(8)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .navigationTitle(pin.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
        }
    }
}

// MARK: - Study Group Detail View
struct CommunityMapStudyGroupDetailView: View {
    let group: StudyGroup
    @ObservedObject var viewModel: CommunityViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(group.title)
                .font(.title2)
                .fontWeight(.bold)

            Text(group.description)
                .font(.body)
                .foregroundColor(.secondary)

            HStack {
                Label("\(group.attendeeCount)/\(group.maxAttendees)", systemImage: "person.3")
                Spacer()
                Label(group.skillLevel.rawValue.capitalized, systemImage: "chart.bar")
                Spacer()
                Label(group.cost == 0 ? "Free" : "$\(Int(group.cost))", systemImage: "dollarsign.circle")
            }
            .font(.subheadline)
            .foregroundColor(.secondary)

            Divider()

            Text("Organizer: \(group.organizer.name)")
                .font(.subheadline)

            Text("Schedule: \(group.schedule.displayString)")
                .font(.subheadline)

            if let course = group.relatedCourse {
                Text("Related Course: \(course)")
                    .font(.subheadline)
            }

            if group.isVerified {
                HStack {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.blue)
                    Text("Verified Study Group")
                        .font(.caption)
                }
            }

            if !group.isFull {
                Button {
                    Task {
                        await viewModel.joinStudyGroup(group)
                    }
                } label: {
                    Text("Join Study Group")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
            } else {
                Text("Study Group Full")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.gray)
                    .cornerRadius(12)
            }
        }
        .padding()
    }
}

// MARK: - Event Detail View
struct EventDetailView: View {
    let event: EducationalEvent
    @ObservedObject var viewModel: CommunityViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let imageURL = event.coverImageURL {
                AsyncImage(url: URL(string: imageURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                }
                .frame(height: 200)
                .clipped()
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(event.title)
                    .font(.title2)
                    .fontWeight(.bold)

                Text(event.description)
                    .font(.body)
                    .foregroundColor(.secondary)

                HStack {
                    Label(formatDate(event.dateTime), systemImage: "calendar")
                    Spacer()
                    Label(event.category.rawValue.capitalized, systemImage: "tag")
                }
                .font(.subheadline)
                .foregroundColor(.secondary)

                HStack {
                    Label("\(event.registrationCount)/\(event.capacity)", systemImage: "person.3")
                    Spacer()
                    Label(event.skillLevel.rawValue.capitalized, systemImage: "chart.bar")
                    Spacer()
                    Label(event.cost == 0 ? "Free" : "$\(Int(event.cost))", systemImage: "dollarsign.circle")
                }
                .font(.subheadline)
                .foregroundColor(.secondary)

                Divider()

                Text("Organizer: \(event.organizer.name)")
                    .font(.subheadline)

                if event.isVerified {
                    HStack {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.blue)
                        Text("Verified Event")
                            .font(.caption)
                    }
                }

                if !event.isFull {
                    Button {
                        Task {
                            await viewModel.registerForEvent(event)
                        }
                    } label: {
                        Text("Register for Event")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                } else {
                    Text("Event Full")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray)
                        .cornerRadius(12)
                }
            }
            .padding()
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Marketplace Detail View
struct MarketplaceDetailView: View {
    let listing: MarketplaceListing
    @ObservedObject var viewModel: CommunityViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !listing.photos.isEmpty {
                TabView {
                    ForEach(listing.photos, id: \.self) { photo in
                        AsyncImage(url: URL(string: photo)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                        }
                    }
                }
                .frame(height: 250)
                .tabViewStyle(.page)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(listing.title)
                        .font(.title2)
                        .fontWeight(.bold)

                    Spacer()

                    Text(listing.priceString)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }

                Text(listing.description)
                    .font(.body)
                    .foregroundColor(.secondary)

                HStack {
                    Label(listing.condition.rawValue.replacingOccurrences(of: "_", with: " ").capitalized, systemImage: "star")
                    Spacer()
                    Label(listing.category.rawValue.replacingOccurrences(of: "_", with: " ").capitalized, systemImage: "tag")
                }
                .font(.subheadline)
                .foregroundColor(.secondary)

                Divider()

                HStack {
                    if let avatarURL = listing.seller.avatarURL {
                        AsyncImage(url: URL(string: avatarURL)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                        }
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                    }

                    VStack(alignment: .leading) {
                        Text(listing.seller.name)
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Text("Level \(listing.seller.level)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }

                if listing.status == .active {
                    Button {
                        viewModel.contactSeller(listing: listing)
                    } label: {
                        Text("Contact Seller")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .cornerRadius(12)
                    }
                } else {
                    Text(listing.status.rawValue.capitalized)
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray)
                        .cornerRadius(12)
                }
            }
            .padding()
        }
    }
}

// MARK: - Institution Detail View
struct InstitutionDetailView: View {
    let institution: Institution
    @ObservedObject var viewModel: CommunityViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !institution.photos.isEmpty {
                TabView {
                    ForEach(institution.photos, id: \.self) { photo in
                        AsyncImage(url: URL(string: photo)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                        }
                    }
                }
                .frame(height: 200)
                .tabViewStyle(.page)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(institution.name)
                        .font(.title2)
                        .fontWeight(.bold)

                    if institution.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.blue)
                    }

                    if institution.isLyoPartner {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                    }
                }

                if let rating = institution.rating {
                    HStack {
                        ForEach(0..<Int(rating), id: \.self) { _ in
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                        }
                        if rating.truncatingRemainder(dividingBy: 1) > 0 {
                            Image(systemName: "star.leadinghalf.filled")
                                .foregroundColor(.yellow)
                        }
                        Text(String(format: "%.1f", rating))
                            .foregroundColor(.secondary)
                    }
                    .font(.subheadline)
                }

                Text(institution.type.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Divider()

                Label(institution.address, systemImage: "mappin.circle")
                    .font(.subheadline)

                if let phone = institution.phone {
                    Button {
                        if let url = URL(string: "tel://\(phone)") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label(phone, systemImage: "phone.circle")
                            .font(.subheadline)
                    }
                }

                if let website = institution.website {
                    Button {
                        if let url = URL(string: website) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label("Visit Website", systemImage: "safari")
                            .font(.subheadline)
                    }
                }

                if !institution.amenities.isEmpty {
                    Divider()

                    Text("Amenities")
                        .font(.headline)

                    FlowLayout(spacing: 8) {
                        ForEach(institution.amenities, id: \.self) { amenity in
                            Text(amenity.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(8)
                        }
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Flow Layout (for amenity tags)
// FlowLayout moved to Sources/Components/Common/FlowLayout.swift

// MARK: - Fallback for iOS 16
struct CommunityMapFallbackView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "map.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue.opacity(0.6))
            
            Text("Community Map")
                .font(.title2.bold())
            
            Text("The interactive community map requires iOS 17 or later.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

// Wrapper that selects appropriate view based on iOS version
struct CommunityMapFallbackWrapper: View {
    var body: some View {
        if #available(iOS 17.0, *) {
            CommunityMapView()
        } else {
            CommunityMapFallbackView()
        }
    }
}

@available(iOS 17.0, *)
struct CommunityMapView_Previews: PreviewProvider {
    static var previews: some View {
        CommunityMapView()
    }
}
