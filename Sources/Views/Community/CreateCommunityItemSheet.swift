import SwiftUI

/// The shared event/group creator. Its fields intentionally mirror the web and
/// Android forms and the canonical Community backend schemas.
struct CreateCommunityItemSheet: View {
    @ObservedObject var viewModel: CommunityViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedType: CommunityItemType = .event
    @State private var title = ""
    @State private var description = ""
    @State private var startTime = Date().addingTimeInterval(3_600)
    @State private var endTime = Date().addingTimeInterval(7_200)
    @State private var location = ""
    @State private var maxPeople = 20
    @State private var isPrivate = false
    @State private var addToMap = false
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type", selection: $selectedType) {
                        Text("Event").tag(CommunityItemType.event)
                        Text("Study group").tag(CommunityItemType.group)
                    }
                    .pickerStyle(.segmented)
                }

                Section("Details") {
                    TextField(selectedType == .event ? "Event title" : "Group name", text: $title)
                        .textInputAutocapitalization(.sentences)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }

                if selectedType == .event {
                    Section("When and where") {
                        DatePicker("Starts", selection: $startTime)
                        DatePicker("Ends", selection: $endTime, in: startTime...)
                        TextField("Location or Online", text: $location)
                        Toggle("Add current map location", isOn: $addToMap)
                    }
                    .onChange(of: startTime) { _, newStart in
                        if endTime <= newStart {
                            endTime = newStart.addingTimeInterval(3_600)
                        }
                    }
                } else {
                    Section("Privacy") {
                        Toggle("Private group (approval required)", isOn: $isPrivate)
                    }
                }

                Section("Capacity") {
                    Stepper(
                        selectedType == .event ? "Maximum attendees: \(maxPeople)" : "Maximum members: \(maxPeople)",
                        value: $maxPeople,
                        in: selectedType == .event ? 1...10_000 : 2...1_000
                    )
                }
            }
            .scrollContentBackground(.hidden)
            .background(DesignTokens.Colors.background)
            .navigationTitle("Create in Community")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSubmitting)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSubmitting ? "Creating…" : "Create") { submit() }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
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

    private func submit() {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { return }
        guard selectedType != .event || endTime > startTime else {
            errorMessage = "The event must end after it starts."
            return
        }

        isSubmitting = true
        Task {
            do {
                if selectedType == .event {
                    try await viewModel.createEvent(request: APICreateEducationalEventRequest(
                        title: cleanTitle,
                        description: cleanDescription,
                        eventType: "study_session",
                        location: cleanLocation,
                        maxAttendees: maxPeople,
                        startTime: startTime,
                        endTime: endTime,
                        timezone: TimeZone.current.identifier,
                        latitude: addToMap ? viewModel.region.center.latitude : nil,
                        longitude: addToMap ? viewModel.region.center.longitude : nil
                    ))
                } else {
                    try await viewModel.createStudyGroup(request: APICreateStudyGroupRequest(
                        name: cleanTitle,
                        description: cleanDescription,
                        privacy: isPrivate ? "private" : "public",
                        maxMembers: maxPeople,
                        requiresApproval: isPrivate
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

    private var cleanDescription: String? {
        let value = description.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private var cleanLocation: String? {
        let value = location.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "Online" : value
    }
}
