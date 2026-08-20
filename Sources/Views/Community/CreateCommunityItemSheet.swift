import SwiftUI

/// Creates the same account-owned learning nodes exposed on Android and web.
struct CreateCommunityItemSheet: View {
    @ObservedObject var viewModel: CommunityViewModel
    @Environment(\.dismiss) private var dismiss

    private enum CreationType: String, CaseIterable {
        case event = "Event"
        case group = "Study group"
        case tutor = "Tutoring"
    }

    @State private var selectedType: CreationType = .event
    @State private var eventType = "study_session"
    @State private var title = ""
    @State private var description = ""
    @State private var subject = ""
    @State private var hourlyPrice = 0.0
    @State private var startTime = Date().addingTimeInterval(3_600)
    @State private var endTime = Date().addingTimeInterval(7_200)
    @State private var location = ""
    @State private var meetingURL = ""
    @State private var isOnline = false
    @State private var maxPeople = 20
    @State private var isPrivate = false
    @State private var addToMap = true
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type", selection: $selectedType) {
                        ForEach(CreationType.allCases, id: \.self) { type in Text(type.rawValue).tag(type) }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Details") {
                    TextField(titlePrompt, text: $title)
                        .textInputAutocapitalization(.sentences)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
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
                    Section("Event format") {
                        Picker("Kind", selection: $eventType) {
                            Text("Study session").tag("study_session")
                            Text("Workshop").tag("workshop")
                            Text("Class").tag("class")
                            Text("Seminar").tag("seminar")
                            Text("Office hours").tag("office_hours")
                        }
                        DatePicker("Starts", selection: $startTime)
                        DatePicker("Ends", selection: $endTime, in: startTime...)
                    }
                    .onChange(of: startTime) { _, newStart in
                        if endTime <= newStart { endTime = newStart.addingTimeInterval(3_600) }
                    }
                }

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

                if selectedType == .group {
                    Section("Privacy") {
                        Toggle("Private group (approval required)", isOn: $isPrivate)
                    }
                }

                if selectedType != .tutor {
                    Section("Capacity") {
                        Stepper(
                            selectedType == .event ? "Maximum attendees: \(maxPeople)" : "Maximum members: \(maxPeople)",
                            value: $maxPeople,
                            in: selectedType == .event ? 1...10_000 : 2...1_000
                        )
                    }
                }

                Section {
                    Text("After publishing, this node and your participation are saved to your Lyo account and appear on iOS, Android, and web.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(DesignTokens.Colors.background)
            .navigationTitle("Create in Community")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.disabled(isSubmitting)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSubmitting ? "Creating…" : "Create") { submit() }
                        .disabled(!canSubmit || isSubmitting)
                }
            }
            .alert("Creation failed", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "Please try again.")
            }
        }
        .tint(DesignTokens.Colors.accent)
        .preferredColorScheme(.dark)
    }

    private var titlePrompt: String {
        switch selectedType {
        case .event: return "Event title"
        case .group: return "Group name"
        case .tutor: return "Lesson title"
        }
    }

    private var canSubmit: Bool {
        !cleanTitle.isEmpty && (selectedType != .tutor || !subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    private func submit() {
        guard canSubmit else { return }
        guard selectedType != .event || endTime > startTime else {
            errorMessage = "The event must end after it starts."
            return
        }

        isSubmitting = true
        Task {
            do {
                switch selectedType {
                case .event:
                    try await viewModel.createEvent(request: APICreateEducationalEventRequest(
                        title: cleanTitle,
                        description: cleanDescription,
                        eventType: eventType,
                        location: cleanLocation,
                        isOnline: isOnline,
                        meetingUrl: cleanMeetingURL,
                        maxAttendees: maxPeople,
                        startTime: startTime,
                        endTime: endTime,
                        timezone: TimeZone.current.identifier,
                        latitude: mapLatitude,
                        longitude: mapLongitude
                    ))
                case .group:
                    try await viewModel.createStudyGroup(request: APICreateStudyGroupRequest(
                        name: cleanTitle,
                        description: cleanDescription,
                        privacy: isPrivate ? "private" : "public",
                        maxMembers: maxPeople,
                        requiresApproval: isPrivate,
                        location: cleanLocation,
                        isOnline: isOnline,
                        meetingUrl: cleanMeetingURL,
                        latitude: mapLatitude,
                        longitude: mapLongitude
                    ))
                case .tutor:
                    try await viewModel.createPrivateLesson(request: APICreatePrivateLessonRequest(
                        title: cleanTitle,
                        description: cleanDescription,
                        subject: subject.trimmingCharacters(in: .whitespacesAndNewlines),
                        pricePerHour: max(0, hourlyPrice),
                        currency: "USD",
                        durationMinutes: 60,
                        location: cleanLocation,
                        latitude: mapLatitude,
                        longitude: mapLongitude,
                        isOnline: isOnline,
                        meetingUrl: cleanMeetingURL
                    ))
                }
                isSubmitting = false
                dismiss()
            } catch {
                isSubmitting = false
                errorMessage = error.localizedDescription
            }
        }
    }

    private var cleanTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var cleanDescription: String? {
        let value = description.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private var cleanLocation: String? {
        guard !isOnline else { return "Online" }
        let value = location.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private var cleanMeetingURL: String? {
        guard isOnline else { return nil }
        let value = meetingURL.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private var mapLatitude: Double? { !isOnline && addToMap ? viewModel.region.center.latitude : nil }
    private var mapLongitude: Double? { !isOnline && addToMap ? viewModel.region.center.longitude : nil }
}
