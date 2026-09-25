import SwiftUI
import MapKit
import PhotosUI

enum CommunityCreationType: String, CaseIterable {
    case event = "Event"
    case group = "Study group"
    case tutor = "Tutoring"
}

/// Creates the same account-owned learning nodes exposed on Android and web,
/// and edits events the learner hosts.
struct CreateCommunityItemSheet: View {
    @ObservedObject var viewModel: CommunityViewModel
    let editing: APICommunityEventRecord?
    let onSaved: (APICommunityEventRecord) -> Void
    @Environment(\.dismiss) private var dismiss

    private struct EventTypeOption: Identifiable {
        let id: String
        let label: String
    }

    private static let eventTypes = [
        EventTypeOption(id: "workshop", label: "Workshop"),
        EventTypeOption(id: "class", label: "Class"),
        EventTypeOption(id: "lecture", label: "Lecture or talk"),
        EventTypeOption(id: "seminar", label: "Seminar"),
        EventTypeOption(id: "study_session", label: "Study session or meetup"),
        EventTypeOption(id: "discussion", label: "Discussion"),
        EventTypeOption(id: "office_hours", label: "Office hours"),
        EventTypeOption(id: "networking", label: "Career or networking"),
        EventTypeOption(id: "project_showcase", label: "Project showcase"),
        EventTypeOption(id: "other", label: "Other learning event"),
    ]

    struct ChosenPlace: Equatable {
        var label: String
        var name: String
        var latitude: Double
        var longitude: Double
    }

    @State private var selectedType: CommunityCreationType
    @State private var eventType: String
    @State private var title: String
    @State private var description: String
    @State private var subject = ""
    @State private var hourlyPrice = 0.0
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var attendanceMode: String
    @State private var place: ChosenPlace?
    @State private var addressQuery = ""
    @State private var suggestions: [APIPlaceSuggestion] = []
    @State private var isSearchingAddress = false
    @State private var addressSearchTask: Task<Void, Never>?
    @State private var pinCamera: MapCameraPosition = .automatic
    @State private var venueName: String
    @State private var location = ""
    @State private var meetingURL: String
    @State private var websiteURL: String
    @State private var organizerName: String
    @State private var imageURL: String
    @State private var photoItem: PhotosPickerItem?
    @State private var isUploading = false
    @State private var limitCapacity: Bool
    @State private var maxPeople: Int
    @State private var isPaid: Bool
    @State private var price: Double
    @State private var visibility: String
    @State private var isOnline = false
    @State private var isPrivate = false
    @State private var addToMap = true
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    /// One id per form: a double tap or a retry after a timeout returns the
    /// event the first submit created instead of a duplicate.
    @State private var requestId = "ios-\(UUID().uuidString)"

    init(
        viewModel: CommunityViewModel,
        context: CommunityCreateContext,
        onSaved: @escaping (APICommunityEventRecord) -> Void = { _ in }
    ) {
        self.viewModel = viewModel
        self.onSaved = onSaved
        var record: APICommunityEventRecord?
        var type = CommunityCreationType.event
        switch context.mode {
        case .create(let kind): type = kind
        case .edit(let event): record = event
        }
        editing = record

        let start = record.flatMap { CommunityDiscovery.parseDate($0.startTime) } ?? Self.defaultStart()
        let end = record.flatMap { CommunityDiscovery.parseDate($0.endTime) } ?? start.addingTimeInterval(7_200)
        _selectedType = State(initialValue: type)
        _eventType = State(initialValue: record?.eventType ?? "workshop")
        _title = State(initialValue: record?.title ?? "")
        _description = State(initialValue: record?.description ?? "")
        _startTime = State(initialValue: start)
        _endTime = State(initialValue: end)
        _attendanceMode = State(initialValue: record?.attendanceMode ?? ((record?.isOnline ?? false) ? "online" : "in_person"))
        if let record, let latitude = record.latitude, let longitude = record.longitude {
            let label = record.address ?? record.location ?? "Event location"
            _place = State(initialValue: ChosenPlace(
                label: label,
                name: record.venueName ?? record.location ?? "Event location",
                latitude: latitude,
                longitude: longitude
            ))
            _pinCamera = State(initialValue: .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                latitudinalMeters: 800,
                longitudinalMeters: 800
            )))
        }
        _venueName = State(initialValue: record?.venueName ?? "")
        _meetingURL = State(initialValue: record?.meetingUrl ?? "")
        _websiteURL = State(initialValue: record?.websiteUrl ?? "")
        _organizerName = State(initialValue: record?.organizerName ?? "")
        _imageURL = State(initialValue: record?.imageUrl ?? "")
        _limitCapacity = State(initialValue: record?.maxAttendees != nil)
        _maxPeople = State(initialValue: record?.maxAttendees ?? 20)
        _isPaid = State(initialValue: record?.priceType == "paid")
        _price = State(initialValue: record?.priceAmount ?? 0)
        _visibility = State(initialValue: record?.visibility ?? "public")
    }

    /// Tomorrow, on the hour, during the day.
    private static func defaultStart() -> Date {
        let calendar = Calendar.current
        let tomorrow = Date().addingTimeInterval(86_400)
        var components = calendar.dateComponents([.year, .month, .day, .hour], from: tomorrow)
        components.hour = max(9, min(components.hour ?? 9, 18))
        components.minute = 0
        return calendar.date(from: components) ?? tomorrow
    }

    var body: some View {
        NavigationStack {
            Form {
                if editing == nil {
                    Section {
                        Picker("Type", selection: $selectedType) {
                            ForEach(CommunityCreationType.allCases, id: \.self) { type in Text(type.rawValue).tag(type) }
                        }
                        .pickerStyle(.segmented)
                    }
                }

                Section("Details") {
                    TextField(titlePrompt, text: $title)
                        .textInputAutocapitalization(.sentences)
                    TextField("Description — what will people learn?", text: $description, axis: .vertical)
                        .lineLimit(3...8)
                    if selectedType == .event {
                        Picker("Kind", selection: $eventType) {
                            ForEach(Self.eventTypes) { option in
                                Text(option.label).tag(option.id)
                            }
                        }
                    }
                    if selectedType == .tutor {
                        TextField("Subject", text: $subject)
                        HStack {
                            Text("Hourly price")
                            Spacer()
                            TextField("0", value: $hourlyPrice, format: .currency(code: "USD"))
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.decimalPad)
                        }
                    }
                }

                if selectedType == .event {
                    eventSections
                } else {
                    legacyPlaceSection
                    if selectedType == .group {
                        Section("Privacy") {
                            Toggle("Private group (approval required)", isOn: $isPrivate)
                        }
                        Section("Capacity") {
                            Stepper("Maximum members: \(maxPeople)", value: $maxPeople, in: 2...1_000)
                        }
                    }
                }

                Section {
                    Text("Everything you publish, and everyone's RSVPs, is saved to Lyo accounts — not this iPhone — so it appears on iOS, Android, and the web.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(DesignTokens.Colors.background)
            .navigationTitle(editing == nil ? "Create in Community" : "Edit event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.disabled(isSubmitting)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(submitLabel) { submit() }
                        .disabled(isSubmitting || isUploading)
                }
            }
            .alert("Please check this", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "Please try again.")
            }
            .interactiveDismissDisabled(isSubmitting)
        }
        .tint(DesignTokens.Colors.accent)
        .preferredColorScheme(.dark)
    }

    // MARK: Event sections

    @ViewBuilder
    private var eventSections: some View {
        Section {
            DatePicker("Starts", selection: $startTime)
            DatePicker("Ends", selection: $endTime, in: startTime...)
        } header: {
            Text("When")
        } footer: {
            Text("Times are in \(TimeZone.current.localizedName(for: .generic, locale: .current) ?? TimeZone.current.identifier). Everyone sees them in their own time zone.")
        }
        .onChange(of: startTime) { _, newStart in
            if endTime <= newStart { endTime = newStart.addingTimeInterval(3_600) }
        }

        Section("Where") {
            Picker("Format", selection: $attendanceMode) {
                Text("In person").tag("in_person")
                Text("Online").tag("online")
                Text("Hybrid").tag("hybrid")
            }
            .pickerStyle(.segmented)

            if attendanceMode != "online" {
                addressPicker
                TextField("Venue name (optional)", text: $venueName)
            }
            if attendanceMode != "in_person" {
                TextField(attendanceMode == "online" ? "Meeting link" : "Meeting link (optional)", text: $meetingURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
            }
        }

        Section("Host") {
            TextField("Organizer (you or your organization)", text: $organizerName)
            TextField("Website (optional)", text: $websiteURL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
        }

        Section("Photo") {
            if let url = CommunityDiscovery.safeWebURL(imageURL) {
                AsyncImage(url: url) { phase in
                    if case .success(let image) = phase {
                        image.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        Color.secondary.opacity(0.15)
                    }
                }
                .frame(height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                Button("Remove photo", role: .destructive) { imageURL = "" }
            }
            PhotosPicker(selection: $photoItem, matching: .images) {
                HStack {
                    Label(imageURL.isEmpty ? "Add a photo (optional)" : "Replace photo", systemImage: "photo")
                    if isUploading {
                        Spacer()
                        ProgressView()
                    }
                }
            }
            .disabled(isUploading)
            .onChange(of: photoItem) { _, item in
                if let item { upload(item) }
            }
        }

        Section {
            Toggle("Limit spots", isOn: $limitCapacity)
            if limitCapacity {
                Stepper("Up to \(maxPeople) people", value: $maxPeople, in: 1...10_000)
            }
            Picker("Price", selection: $isPaid) {
                Text("Free").tag(false)
                Text("Paid").tag(true)
            }
            .pickerStyle(.segmented)
            if isPaid {
                HStack {
                    Text("Price")
                    Spacer()
                    TextField("0", value: $price, format: .currency(code: "USD"))
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.decimalPad)
                }
            }
        } header: {
            Text("Spots and price")
        }

        Section {
            Picker("Who can find it", selection: $visibility) {
                Text("Public").tag("public")
                Text("Unlisted").tag("unlisted")
                Text("Private").tag("private")
            }
        } header: {
            Text("Visibility")
        } footer: {
            Text(visibilityHint)
        }
    }

    private var visibilityHint: String {
        switch visibility {
        case "unlisted": return "Only people with the link can open it. It never appears on the map."
        case "private": return "Only you — a draft until you share it."
        default: return "On the map and in search for every Lyo learner."
        }
    }

    @ViewBuilder
    private var addressPicker: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField(place == nil ? "Search the address" : "Search a different address", text: $addressQuery)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .onChange(of: addressQuery) { _, query in searchAddress(query) }
            if isSearchingAddress { ProgressView().controlSize(.small) }
        }
        ForEach(suggestions) { suggestion in
            Button {
                choose(ChosenPlace(
                    label: suggestion.label,
                    name: suggestion.name,
                    latitude: suggestion.latitude,
                    longitude: suggestion.longitude
                ))
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(suggestion.name).font(.subheadline.weight(.semibold))
                    Text(suggestion.label).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
            }
            .buttonStyle(.plain)
        }
        if place == nil {
            Button {
                let center = viewModel.region.center
                choose(ChosenPlace(
                    label: "Pinned location",
                    name: "Pinned location",
                    latitude: center.latitude,
                    longitude: center.longitude
                ))
            } label: {
                Label("Place at the current map center", systemImage: "mappin.and.ellipse")
            }
        }
        if let place {
            VStack(alignment: .leading, spacing: 6) {
                Text(place.label).font(.subheadline)
                MapReader { proxy in
                    Map(position: $pinCamera) {
                        Marker(place.name, coordinate: CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude))
                    }
                    .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
                    .onTapGesture { point in
                        if let coordinate = proxy.convert(point, from: .local) {
                            self.place?.latitude = coordinate.latitude
                            self.place?.longitude = coordinate.longitude
                        }
                    }
                }
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .accessibilityLabel("Map pin for \(place.label)")
                Text("Tap the map to move the pin to the exact entrance.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        }
    }

    // MARK: Study group and tutoring

    private var legacyPlaceSection: some View {
        Section("Where") {
            Toggle("Online", isOn: $isOnline)
            if isOnline {
                TextField("Meeting link (optional)", text: $meetingURL)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
            } else {
                TextField("Location", text: $location)
                Toggle("Place at the current map center", isOn: $addToMap)
                if addToMap {
                    Text("\(viewModel.region.center.latitude, specifier: "%.4f"), \(viewModel.region.center.longitude, specifier: "%.4f")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: Behaviour

    private var titlePrompt: String {
        switch selectedType {
        case .event: return "Event title"
        case .group: return "Group name"
        case .tutor: return "Lesson title"
        }
    }

    private var submitLabel: String {
        if isSubmitting { return editing == nil ? "Publishing…" : "Saving…" }
        return editing == nil ? (selectedType == .event ? "Publish" : "Create") : "Save"
    }

    private func choose(_ chosen: ChosenPlace) {
        place = chosen
        suggestions = []
        addressSearchTask?.cancel()
        addressQuery = ""
        if venueName.isEmpty && chosen.name != chosen.label && chosen.name != "Pinned location" {
            venueName = chosen.name
        }
        pinCamera = .region(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: chosen.latitude, longitude: chosen.longitude),
            latitudinalMeters: 800,
            longitudinalMeters: 800
        ))
    }

    private func searchAddress(_ query: String) {
        addressSearchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 3 else {
            suggestions = []
            isSearchingAddress = false
            return
        }
        addressSearchTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            isSearchingAddress = true
            let found = (try? await viewModel.geocode(trimmed)) ?? []
            guard !Task.isCancelled else { return }
            suggestions = found
            isSearchingAddress = false
        }
    }

    private func upload(_ item: PhotosPickerItem) {
        isUploading = true
        Task { @MainActor in
            defer {
                isUploading = false
                photoItem = nil
            }
            do {
                guard let data = try await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else {
                    errorMessage = "Choose an image file."
                    return
                }
                guard data.count <= 20 * 1024 * 1024 else {
                    errorMessage = "That photo is too large. Choose one under 20 MB."
                    return
                }
                imageURL = try await CloudStorageService.shared.uploadImage(image, folder: "community")
            } catch {
                errorMessage = "We couldn't upload that photo. You can publish without one."
            }
        }
    }

    private func trimmed(_ value: String) -> String? {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? nil : clean
    }

    private var cleanTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var timesChanged: Bool {
        guard let editing else { return true }
        return CommunityDiscovery.parseDate(editing.startTime) != startTime
            || CommunityDiscovery.parseDate(editing.endTime) != endTime
    }

    /// The same checks as the web form, before anything is sent.
    private func validationProblem() -> String? {
        if cleanTitle.isEmpty { return selectedType == .event ? "Give your event a title." : "Add a title." }
        switch selectedType {
        case .tutor:
            if trimmed(subject) == nil { return "Add the subject you teach." }
        case .group:
            break
        case .event:
            if endTime <= startTime { return "The event must end after it starts." }
            if endTime <= Date() && timesChanged { return "Choose a time in the future." }
            if attendanceMode != "online" && place == nil { return "Search for the address, then adjust the pin if needed." }
            if attendanceMode == "online" && trimmed(meetingURL) == nil { return "Add the link people will use to join." }
            if let link = trimmed(meetingURL), CommunityDiscovery.safeWebURL(link) == nil {
                return "The meeting link must start with https://"
            }
            if let site = trimmed(websiteURL), CommunityDiscovery.safeWebURL(site) == nil,
               CommunityDiscovery.safeWebURL("https://\(site)") == nil {
                return "The website doesn't look like a web address."
            }
            if isPaid && price < 0 { return "The price cannot be negative." }
        }
        return nil
    }

    private var normalizedWebsite: String? {
        guard let site = trimmed(websiteURL) else { return nil }
        if CommunityDiscovery.safeWebURL(site) != nil { return site }
        return "https://\(site)"
    }

    private func submit() {
        guard !isSubmitting else { return }
        if let problem = validationProblem() {
            errorMessage = problem
            return
        }
        isSubmitting = true
        Task { @MainActor in
            do {
                switch selectedType {
                case .event:
                    let record = try await saveEvent()
                    isSubmitting = false
                    dismiss()
                    onSaved(record)
                    return
                case .group:
                    try await viewModel.createStudyGroup(request: APICreateStudyGroupRequest(
                        name: cleanTitle,
                        description: trimmed(description),
                        privacy: isPrivate ? "private" : "public",
                        maxMembers: maxPeople,
                        requiresApproval: isPrivate,
                        location: legacyLocation,
                        isOnline: isOnline,
                        meetingUrl: isOnline ? trimmed(meetingURL) : nil,
                        latitude: legacyLatitude,
                        longitude: legacyLongitude
                    ))
                case .tutor:
                    try await viewModel.createPrivateLesson(request: APICreatePrivateLessonRequest(
                        title: cleanTitle,
                        description: trimmed(description),
                        subject: subject.trimmingCharacters(in: .whitespacesAndNewlines),
                        pricePerHour: max(0, hourlyPrice),
                        currency: "USD",
                        durationMinutes: 60,
                        location: legacyLocation,
                        latitude: legacyLatitude,
                        longitude: legacyLongitude,
                        isOnline: isOnline,
                        meetingUrl: isOnline ? trimmed(meetingURL) : nil
                    ))
                }
                isSubmitting = false
                viewModel.showToast(selectedType == .group ? "Study group created" : "Tutoring listing created")
                dismiss()
            } catch {
                isSubmitting = false
                let friendly = CommunityDiscovery.friendlyError(
                    error,
                    action: editing == nil ? "publish this" : "save your changes"
                )
                errorMessage = friendly.message
            }
        }
    }

    @MainActor
    private func saveEvent() async throws -> APICommunityEventRecord {
        let inPerson = attendanceMode != "online"
        let needsLink = attendanceMode != "in_person"
        let venue = inPerson ? (trimmed(venueName) ?? place.map(\.name).flatMap { $0 == "Pinned location" ? nil : $0 }) : nil
        let locationText = inPerson ? (place?.label ?? venue) : "Online"
        let capacity = limitCapacity ? max(1, min(10_000, maxPeople)) : nil
        let amount = isPaid && price > 0 ? price : nil

        if let editing {
            var request = APIUpdateEventRequest(
                title: cleanTitle,
                description: trimmed(description),
                eventType: eventType,
                location: locationText,
                isOnline: attendanceMode != "in_person",
                meetingUrl: needsLink ? trimmed(meetingURL) : nil,
                maxAttendees: capacity,
                startTime: timesChanged ? startTime : nil,
                endTime: timesChanged ? endTime : nil,
                timezone: timesChanged ? TimeZone.current.identifier : nil,
                latitude: inPerson ? place?.latitude : nil,
                longitude: inPerson ? place?.longitude : nil,
                attendanceMode: attendanceMode,
                venueName: venue,
                address: inPerson ? place?.label : nil,
                websiteUrl: normalizedWebsite,
                imageUrl: trimmed(imageURL),
                organizerName: trimmed(organizerName),
                priceType: isPaid ? "paid" : "free",
                priceAmount: amount,
                currency: isPaid ? "USD" : nil,
                visibility: visibility
            )
            // The form shows every field, so an emptied one means "remove it".
            request.cleared = APIUpdateEventRequest.clearableKeys
            return try await viewModel.updateEvent(id: editing.id, request: request)
        }

        return try await viewModel.createEvent(request: APICreateEducationalEventRequest(
            title: cleanTitle,
            description: trimmed(description),
            eventType: eventType,
            location: locationText,
            isOnline: attendanceMode != "in_person",
            meetingUrl: needsLink ? trimmed(meetingURL) : nil,
            maxAttendees: capacity,
            startTime: startTime,
            endTime: endTime,
            timezone: TimeZone.current.identifier,
            latitude: inPerson ? place?.latitude : nil,
            longitude: inPerson ? place?.longitude : nil,
            attendanceMode: attendanceMode,
            venueName: venue,
            address: inPerson ? place?.label : nil,
            websiteUrl: normalizedWebsite,
            imageUrl: trimmed(imageURL),
            organizerName: trimmed(organizerName),
            priceType: isPaid ? "paid" : "free",
            priceAmount: amount,
            currency: isPaid ? "USD" : nil,
            visibility: visibility,
            clientRequestId: requestId
        ))
    }

    private var legacyLocation: String? {
        guard !isOnline else { return "Online" }
        return trimmed(location)
    }

    private var legacyLatitude: Double? { !isOnline && addToMap ? viewModel.region.center.latitude : nil }
    private var legacyLongitude: Double? { !isOnline && addToMap ? viewModel.region.center.longitude : nil }
}
