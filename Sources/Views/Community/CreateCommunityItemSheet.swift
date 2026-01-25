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
    
    // New Fields
    @State private var subject: String = ""
    @State private var cost: Double = 0
    @State private var durationMinutes: Int = 60
    @State private var category: String = "General"
    @State private var openingHours: String = "9AM - 5PM"
    
    // Loading State
    @State private var isSubmitting: Bool = false
    
    var body: some View {
        NavigationView {
            Form {
                // TYPE SELECTION
                Section {
                    Picker("Type", selection: $selectedType) {
                        Text("Event").tag(CommunityItemType.event)
                        Text("Group").tag(CommunityItemType.group)
                        Text("Class").tag(CommunityItemType.privateLesson) // NEW
                        Text("Center").tag(CommunityItemType.educationalCenter) // NEW
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
                    
                    if selectedType == .privateLesson {
                        TextField("Subject", text: $subject)
                        TextField("Cost ($)", value: $cost, format: .currency(code: "USD"))
                            .keyboardType(.decimalPad)
                        Stepper("Duration: \(durationMinutes) min", value: $durationMinutes, step: 15)
                    }
                    
                    if selectedType == .educationalCenter {
                         Picker("Category", selection: $category) {
                             Text("Library").tag("Library")
                             Text("Dance School").tag("Dance School")
                             Text("Book Store").tag("Book Store")
                             Text("Health Club").tag("Health Club")
                             Text("Other").tag("Other")
                         }
                         TextField("Opening Hours", text: $openingHours)
                    }
                    
                    TextField(selectedType == .question ? "Your Question" : "Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                    
                    if selectedType == .event || selectedType == .group || selectedType == .educationalCenter {
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
                    
                case .privateLesson:
                    let newLesson = APIPrivateLesson(
                        id: Int.random(in: 1000...9999),
                        title: title,
                        subject: subject,
                        instructor: APIUserPreview(id: 0, name: "Me", avatar: nil),
                        cost: cost,
                        durationMinutes: durationMinutes,
                        description: description,
                        lat: viewModel.region.center.latitude,
                        lng: viewModel.region.center.longitude,
                        imageURL: nil
                    )
                    try await viewModel.createPrivateLesson(newLesson)
                    
                case .educationalCenter:
                    let newCenter = APIEducationalCenter(
                        id: Int.random(in: 1000...9999),
                        name: title,
                        category: category,
                        description: description,
                        lat: viewModel.region.center.latitude,
                        lng: viewModel.region.center.longitude,
                        imageURL: nil,
                        address: locationName,
                        openingHours: openingHours
                    )
                    try await viewModel.createEducationalCenter(newCenter)
                    
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
