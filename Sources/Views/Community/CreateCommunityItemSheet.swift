import SwiftUI
import MapKit

struct CreateCommunityItemSheet: View {
    @ObservedObject var viewModel: CommunityViewModel
    @Environment(\.presentationMode) var presentationMode
    
    @State private var selectedType: CommunityItemType = .event
    
    // Form Factors
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var date: Date = Date()
    @State private var locationName: String = ""
    @State private var tags: String = "" // Comma separated
    @State private var isAnonymous: Bool = false
    
    // Loading State
    @State private var isSubmitting: Bool = false
    
    var body: some View {
        NavigationView {
            Form {
                // TYPE SELECTION
                Section {
                    Picker("Type", selection: $selectedType) {
                        Text("Event").tag(CommunityItemType.event)
                        Text("Study Group").tag(CommunityItemType.group)
                        Text("Question").tag(CommunityItemType.question)
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .padding(.vertical, 8)
                }
                
                // COMMON FIELDS
                Section(header: Text("Details")) {
                    if selectedType != .question {
                        TextField("Title", text: $title)
                    }
                    
                    TextField(selectedType == .question ? "Your Question" : "Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                    
                    if selectedType == .event || selectedType == .group {
                        TextField("Location Name", text: $locationName)
                    }
                    
                    if selectedType == .event {
                        DatePicker("Date & Time", selection: $date)
                    }
                }
                
                // EXTRA OPTIONS
                Section(header: Text("Options")) {
                    TextField("Tags (comma separated)", text: $tags)
                    
                    if selectedType == .question {
                        Toggle("Ask Anonymously", isOn: $isAnonymous)
                    }
                }
                
                // SUBMIT BUTTON
                Section {
                    Button(action: submit) {
                        HStack {
                            Spacer()
                            if isSubmitting {
                                ProgressView()
                            } else {
                                Text("Create \(selectedType.rawValue.dropLast())") // Remove 's' roughly
                                    .fontWeight(.bold)
                            }
                            Spacer()
                        }
                    }
                    .disabled(isFormInvalid || isSubmitting)
                    .foregroundColor(isFormInvalid ? .gray : .white)
                    .listRowBackground(isFormInvalid ? Color(.systemGray6) : Color.blue)
                }
            }
            .navigationTitle("Create New")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Logic
    
    var isFormInvalid: Bool {
        if description.isEmpty { return true }
        if selectedType != .question && title.isEmpty { return true }
        return false
    }
    
    func submit() {
        guard !isFormInvalid else { return }
        isSubmitting = true
        
        Task {
            do {
                switch selectedType {
                case .event:
                    // Create domain model EducationalEvent
                    let placeholderUser = User(id: 0, email: "", name: "Me", avatarURL: nil, createdAt: Date(), level: 1, xp: 0, streak: 0, totalLessonsCompleted: 0, achievements: [])
                    let location = Location(
                        type: locationName.isEmpty ? .virtual : .coordinates,
                        name: locationName.isEmpty ? "Virtual" : locationName,
                        coordinate: CLLocationCoordinate2D(
                            latitude: viewModel.region.center.latitude,
                            longitude: viewModel.region.center.longitude
                        )
                    )
                    let tagList = tags.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                    let newEvent = EducationalEvent(
                        id: UUID().uuidString,
                        title: title,
                        description: description,
                        organizer: placeholderUser,
                        location: location,
                        dateTime: date,
                        duration: 3600, // 1 hour default
                        capacity: 50,
                        registeredUsers: [],
                        cost: 0,
                        skillLevel: .beginner,
                        category: .workshop,
                        tags: tagList,
                        coverImageURL: nil,
                        isVerified: false
                    )
                    try await viewModel.createEvent(newEvent)
                    
                case .group:
                    // Create domain model StudyGroup
                    let placeholderUser = User(id: 0, email: "", name: "Me", avatarURL: nil, createdAt: Date(), level: 1, xp: 0, streak: 0, totalLessonsCompleted: 0, achievements: [])
                    let location = Location(
                        type: locationName.isEmpty ? .virtual : .coordinates,
                        name: locationName.isEmpty ? "Virtual" : locationName,
                        coordinate: CLLocationCoordinate2D(
                            latitude: viewModel.region.center.latitude,
                            longitude: viewModel.region.center.longitude
                        )
                    )
                    let tagList = tags.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                    let newGroup = StudyGroup(
                        id: UUID().uuidString,
                        title: title,
                        description: description,
                        organizer: placeholderUser,
                        location: location,
                        schedule: .oneTime(date: Date().addingTimeInterval(86400), duration: 3600),
                        maxAttendees: 10,
                        currentAttendees: [],
                        skillLevel: .beginner,
                        relatedCourse: nil,
                        cost: 0,
                        tags: tagList,
                        createdAt: Date(),
                        isVerified: false
                    )
                    try await viewModel.createStudyGroup(newGroup)
                    
                case .question:
                    let tagList = tags.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                    try await viewModel.createQuestion(content: description, tags: tagList, isAnonymous: isAnonymous)
                    
                default:
                    break
                }
                
                // Success
                await MainActor.run {
                    isSubmitting = false
                    presentationMode.wrappedValue.dismiss()
                }
                
            } catch {
                print("❌ Creation failed: \(error)")
                await MainActor.run {
                    isSubmitting = false
                    // Real app should show alert here
                }
            }
        }
    }
}
