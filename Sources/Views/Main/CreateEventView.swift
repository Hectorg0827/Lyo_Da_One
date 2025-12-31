import SwiftUI
import MapKit
import CoreLocation

struct CreateEventView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var uiState: AppUIState
    
    // Form Data
    @State private var title = ""
    @State private var description = ""
    @State private var eventType: CampusItemType = .studyGroup
    @State private var date = Date()
    @State private var location = ""
    @State private var maxParticipants = ""
    
    // Map State
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    @State private var showFullMap = false
    
    // UI State
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showMapSelection = false
    
    // Animation State
    @State private var formAppeared = false
    @State private var typeSelectorScale: CGFloat = 0.9
    
    private let apiClient = LyoAPIClient.shared
    
    var body: some View {
        ZStack {
            // Immersive Background with gradient
            LinearGradient(
                colors: [Color(hex: "0f172a"), Color(hex: "1e1b4b")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Custom Header
                headerView
                
                ScrollView {
                    VStack(spacing: 24) {
                        
                        // Type Selector with animation
                        typeSelector
                            .scaleEffect(typeSelectorScale)
                        
                        // Main Inputs with staggered animation
                        VStack(spacing: 20) {
                            EventTextField(
                                title: "Event Title",
                                placeholder: "e.g., Calculus Study Group",
                                text: $title,
                                icon: "pencil.line"
                            )
                            .offset(y: formAppeared ? 0 : 30)
                            .opacity(formAppeared ? 1 : 0)
                            
                            EventTextEditor(
                                title: "Description",
                                placeholder: "Describe what you'll be doing...",
                                text: $description
                            )
                            .offset(y: formAppeared ? 0 : 30)
                            .opacity(formAppeared ? 1 : 0)
                            .animation(.easeOut(duration: 0.4).delay(0.1), value: formAppeared)
                        }
                        
                        // Date & Time Card
                        dateTimeCard
                            .offset(y: formAppeared ? 0 : 30)
                            .opacity(formAppeared ? 1 : 0)
                            .animation(.easeOut(duration: 0.4).delay(0.2), value: formAppeared)
                        
                        // Enhanced Location Picker with MapKit
                        enhancedLocationPicker
                            .offset(y: formAppeared ? 0 : 30)
                            .opacity(formAppeared ? 1 : 0)
                            .animation(.easeOut(duration: 0.4).delay(0.3), value: formAppeared)
                        
                        // Max Participants
                        EventTextField(
                            title: "Max Attendees",
                            placeholder: "Optional (e.g., 10)",
                            text: $maxParticipants,
                            icon: "person.2.fill",
                            keyboardType: .numberPad
                        )
                        .offset(y: formAppeared ? 0 : 30)
                        .opacity(formAppeared ? 1 : 0)
                        .animation(.easeOut(duration: 0.4).delay(0.4), value: formAppeared)
                    }
                    .padding(20)
                    .padding(.bottom, 100) // Space for button
                }
            }
            
            // Floating Create Button
            VStack {
                Spacer()
                createButton
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
            }
            
            if isLoading {
                LoadingOverlay()
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                formAppeared = true
                typeSelectorScale = 1.0
            }
        }
        .sheet(isPresented: $showFullMap) {
            FullMapPicker(
                region: $region,
                selectedCoordinate: $selectedCoordinate,
                locationName: $location
            )
        }
    }
    
    // MARK: - Subviews
    
    private var headerView: some View {
        HStack {
            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .padding(10)
                    .background(Circle().fill(.ultraThinMaterial))
            }
            
            Spacer()
            
            Text("Create Event")
                .font(.headline)
                .foregroundColor(.white)
            
            Spacer()
            
            // Hidden balance to center title
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal)
        .padding(.top, 16)
        .padding(.bottom, 10)
    }
    
    private var typeSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(CampusItemType.allCases, id: \.self) { type in
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            eventType = type
                        }
                        // Haptic feedback
                        let impactLight = UIImpactFeedbackGenerator(style: .light)
                        impactLight.impactOccurred()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: typeIcon(for: type))
                            Text(type.displayName)
                        }
                        .font(.subheadline.weight(.medium))
                        .padding(.vertical, 10)
                        .padding(.horizontal, 18)
                        .background(
                            Capsule()
                                .fill(eventType == type ? 
                                      LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing) :
                                      LinearGradient(colors: [Color.white.opacity(0.1)], startPoint: .leading, endPoint: .trailing))
                        )
                        .foregroundColor(.white)
                        .overlay(
                            Capsule()
                                .stroke(eventType == type ? Color.clear : Color.white.opacity(0.15), lineWidth: 1)
                        )
                        .shadow(color: eventType == type ? .blue.opacity(0.3) : .clear, radius: 8, x: 0, y: 4)
                        .scaleEffect(eventType == type ? 1.05 : 1.0)
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }
    
    private var dateTimeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Date & Time", systemImage: "clock.fill")
                .font(.caption)
                .foregroundColor(.gray)
                .textCase(.uppercase)
            
            HStack {
                DatePicker("", selection: $date, displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden()
                    .colorScheme(.dark)
                    .tint(.blue)
                
                Spacer()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                LinearGradient(colors: [.white.opacity(0.1), .white.opacity(0.05)],
                                               startPoint: .topLeading, endPoint: .bottomTrailing),
                                lineWidth: 1
                            )
                    )
            )
        }
    }
    
    private var enhancedLocationPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Location", systemImage: "map.fill")
                .font(.caption)
                .foregroundColor(.gray)
                .textCase(.uppercase)
            
            Button(action: {
                showFullMap = true
                let impactMed = UIImpactFeedbackGenerator(style: .medium)
                impactMed.impactOccurred()
            }) {
                ZStack(alignment: .bottom) {
                    // Real MapKit view
                    Map(position: .constant(.region(region))) {
                        ForEach(markerItems) { item in
                            Annotation("", coordinate: item.coordinate) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.title)
                                    .foregroundColor(.blue)
                                    .shadow(radius: 3)
                            }
                        }
                    }
                    .frame(height: 140)
                    .cornerRadius(16)
                    .allowsHitTesting(false)
                    
                    // Gradient overlay
                    LinearGradient(
                        colors: [.clear, Color(hex: "0f172a").opacity(0.8)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 60)
                    .cornerRadius(16)
                    
                    // Location Input Overlay
                    HStack {
                        Image(systemName: "mappin.and.ellipse")
                            .foregroundColor(.blue)
                            .font(.system(size: 16, weight: .semibold))
                        
                        Text(location.isEmpty ? "Tap to select location..." : location)
                            .foregroundColor(location.isEmpty ? .gray : .white)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                            .font(.caption)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                    .padding(8)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(colors: [.white.opacity(0.15), .white.opacity(0.05)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 1
                        )
                )
            }
            .buttonStyle(.plain)
        }
    }
    
    private var markerItems: [MapMarkerItem] {
        if let coord = selectedCoordinate {
            return [MapMarkerItem(coordinate: coord)]
        }
        return []
    }
    
    private var createButton: some View {
        Button(action: createEvent) {
            HStack(spacing: 12) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "plus.circle.fill")
                    Text("Create Event")
                }
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                Group {
                    if isFormValid {
                        LinearGradient(
                            colors: [Color(hex: "3b82f6"), Color(hex: "8b5cf6")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    } else {
                        Color.gray.opacity(0.3)
                    }
                }
            )
            .cornerRadius(20)
            .shadow(color: isFormValid ? .blue.opacity(0.4) : .clear, radius: 15, x: 0, y: 8)
        }
        .disabled(!isFormValid || isLoading)
        .scaleEffect(isFormValid ? 1.0 : 0.98)
        .animation(.spring(response: 0.3), value: isFormValid)
    }
    
    private var isFormValid: Bool {
        !title.isEmpty && !location.isEmpty
    }
    
    // MARK: - Actions
    
    private func dismiss() {
        let impactLight = UIImpactFeedbackGenerator(style: .light)
        impactLight.impactOccurred()
        isPresented = false
        uiState.isCreatingEvent = false
    }
    
    private func createEvent() {
        isLoading = true
        errorMessage = nil
        
        // Success haptic
        let notificationFeedback = UINotificationFeedbackGenerator()
        
        let reqTitle = title
        let reqDesc = description
        let reqType = eventType.rawValue
        let reqDate = date
        let reqLoc = location
        let reqMax = Int(maxParticipants)
        
        Task {
            do {
                print("🚀 Creating Event: \(reqTitle) at \(reqLoc)")
                
                let request = CreateEventRequest(
                    title: reqTitle,
                    description: reqDesc,
                    eventType: reqType,
                    startTime: reqDate,
                    endTime: Calendar.current.date(byAdding: .hour, value: 1, to: reqDate),
                    location: reqLoc,
                    maxAttendees: reqMax
                )
                
                let event = try await apiClient.createCommunityEvent(request)
                print("✅ Event Created Successfully: \(event.title) (ID: \(event.id))")
                
                await MainActor.run {
                    notificationFeedback.notificationOccurred(.success)
                    isLoading = false
                    dismiss()
                }
            } catch {
                print("❌ Failed to create event: \(error)")
                await MainActor.run {
                    notificationFeedback.notificationOccurred(.error)
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func typeIcon(for type: CampusItemType) -> String {
        switch type {
        case .studyGroup: return "book.fill"
        case .workshop: return "hammer.fill"
        case .event: return "calendar"
        case .meetup: return "person.3.fill"
        case .office: return "building.columns.fill"
        }
    }
}

// MARK: - Map Marker Item

struct MapMarkerItem: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

// MARK: - Full Map Picker Sheet

struct FullMapPicker: View {
    @Environment(\.dismiss) var dismiss
    @Binding var region: MKCoordinateRegion
    @Binding var selectedCoordinate: CLLocationCoordinate2D?
    @Binding var locationName: String
    
    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var isSearching = false
    @State private var position: MapCameraPosition = .automatic
    
    var body: some View {
        NavigationView {
            ZStack {
                // Full Map
                Map(position: $position) {
                    ForEach(markerItems) { item in
                        Annotation("", coordinate: item.coordinate) {
                            VStack(spacing: 0) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.largeTitle)
                                    .foregroundColor(.blue)
                                Image(systemName: "arrowtriangle.down.fill")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                    .offset(y: -5)
                            }
                            .shadow(radius: 3)
                        }
                    }
                }
                .onMapCameraChange { context in
                    region = context.region
                }
                .onAppear {
                    position = .region(region)
                }
                .ignoresSafeArea(edges: .bottom)
                
                // Search Overlay
                VStack {
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        TextField("Search location...", text: $searchText)
                            .onSubmit {
                                searchLocation()
                            }
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                    .padding()
                    
                    // Search Results
                    if !searchResults.isEmpty {
                        ScrollView {
                            VStack(spacing: 8) {
                                ForEach(searchResults, id: \.self) { item in
                                    Button(action: {
                                        selectLocation(item)
                                    }) {
                                        HStack {
                                            Image(systemName: "mappin.circle")
                                                .foregroundColor(.blue)
                                            VStack(alignment: .leading) {
                                                Text(item.name ?? "Unknown")
                                                    .foregroundColor(.primary)
                                                Text(item.placemark.title ?? "")
                                                    .font(.caption)
                                                    .foregroundColor(.gray)
                                            }
                                            Spacer()
                                        }
                                        .padding()
                                        .background(.ultraThinMaterial)
                                        .cornerRadius(10)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        .frame(maxHeight: 200)
                    }
                    
                    Spacer()
                    
                    // Confirm Button
                    if selectedCoordinate != nil {
                        Button(action: {
                            dismiss()
                        }) {
                            Text("Confirm Location")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    LinearGradient(colors: [.blue, .purple],
                                                   startPoint: .leading, endPoint: .trailing)
                                )
                                .cornerRadius(16)
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Select Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var markerItems: [MapMarkerItem] {
        if let coord = selectedCoordinate {
            return [MapMarkerItem(coordinate: coord)]
        }
        return []
    }
    
    private func searchLocation() {
        guard !searchText.isEmpty else { return }
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText
        request.region = region
        
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            if let response = response {
                searchResults = response.mapItems
            }
        }
    }
    
    private func selectLocation(_ item: MKMapItem) {
        selectedCoordinate = item.placemark.coordinate
        locationName = item.name ?? item.placemark.title ?? "Selected Location"
        region.center = item.placemark.coordinate
        position = .region(MKCoordinateRegion(center: item.placemark.coordinate, span: region.span))
        searchResults = []
        searchText = ""
        
        let impactMed = UIImpactFeedbackGenerator(style: .medium)
        impactMed.impactOccurred()
    }
}

// MARK: - Custom Helper Components

struct EventTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var icon: String?
    var keyboardType: UIKeyboardType = .default
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon ?? "pencil")
                .font(.caption)
                .foregroundColor(.gray)
                .textCase(.uppercase)
            
            TextField("", text: $text)
                .focused($isFocused)
                .eventPlaceholder(when: text.isEmpty) {
                    Text(placeholder).foregroundColor(.white.opacity(0.3))
                }
                .foregroundColor(.white)
                .padding()
                .background(Color.white.opacity(isFocused ? 0.08 : 0.05))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isFocused ? Color.blue.opacity(0.5) : Color.white.opacity(0.1), lineWidth: 1)
                )
                .keyboardType(keyboardType)
                .animation(.easeInOut(duration: 0.2), value: isFocused)
        }
    }
}

struct EventTextEditor: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: "text.alignleft")
                .font(.caption)
                .foregroundColor(.gray)
                .textCase(.uppercase)
            
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .foregroundColor(.white.opacity(0.3))
                        .padding(.top, 12)
                        .padding(.leading, 16)
                }
                
                TextEditor(text: $text)
                    .focused($isFocused)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .foregroundColor(.white)
                    .padding(8)
                    .frame(height: 100)
            }
            .background(Color.white.opacity(isFocused ? 0.08 : 0.05))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isFocused ? Color.blue.opacity(0.5) : Color.white.opacity(0.1), lineWidth: 1)
            )
            .animation(.easeInOut(duration: 0.2), value: isFocused)
        }
    }
}

struct LoadingOverlay: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
            VStack(spacing: 16) {
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(
                        LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing),
                        lineWidth: 3
                    )
                    .frame(width: 40, height: 40)
                    .rotationEffect(.degrees(isAnimating ? 360 : 0))
                    .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: isAnimating)
                
                Text("Creating Event...")
                    .font(.subheadline)
                    .foregroundColor(.white)
            }
            .padding(30)
            .background(.ultraThinMaterial)
            .cornerRadius(20)
        }
        .onAppear {
            isAnimating = true
        }
    }
}

extension View {
    func eventPlaceholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {
        
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

