//
//  MyCoursesView.swift
//  Lyo
//
//  Unified course library view
//

import SwiftUI

struct MyCoursesView: View {
    
    @StateObject private var libraryService = CourseLibraryService.shared
    @StateObject private var socialService = CourseSocialService.shared
    
    @State private var selectedTab = 0
    @State private var showFilters = false
    @State private var searchText = ""
    
    private let columns = [
        GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 16)
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                searchBar
                
                // Tab Selector
                tabSelector
                
                // Content
                if libraryService.isLoading {
                    loadingView
                } else if let error = libraryService.error {
                    errorView(error)
                } else {
                    courseGrid
                }
            }
            .navigationTitle("My Courses")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showFilters.toggle() }) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .foregroundColor(.primary)
                    }
                }
            }
            .sheet(isPresented: $showFilters) {
                FiltersView(
                    selectedLevel: $libraryService.selectedLevel,
                    selectedTags: $libraryService.selectedTags
                )
            }
            .task {
                await libraryService.fetchMyCourses()
                await libraryService.fetchTrendingCourses()
            }
        }
    }
    
    // MARK: - Search Bar
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("Search courses...", text: $searchText)
                .textFieldStyle(.plain)
                .autocapitalization(.none)
                .onChange(of: searchText) { _, newValue in
                    Task {
                        await libraryService.search(query: newValue)
                    }
                }
            
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    // MARK: - Tab Selector
    
    private var tabSelector: some View {
        Picker("", selection: $selectedTab) {
            Text("In Progress (\(libraryService.inProgressCourses.count))").tag(0)
            Text("Saved (\(libraryService.savedCourses.count))").tag(1)
            Text("Completed (\(libraryService.completedCourses.count))").tag(2)
            Text("Trending").tag(3)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    // MARK: - Course Grid
    
    private var courseGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(currentCourses) { course in
                    MyCourseCardView(course: course)
                        .environmentObject(socialService)
                }
            }
            .padding()
        }
    }
    
    private var currentCourses: [CourseCard] {
        switch selectedTab {
        case 0: return libraryService.inProgressCourses
        case 1: return libraryService.savedCourses
        case 2: return libraryService.completedCourses
        case 3: return libraryService.trendingCourses
        default: return []
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading courses...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Error View
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            Text("Failed to load courses")
                .font(.headline)
            
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Try Again") {
                Task {
                    await libraryService.fetchMyCourses()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Course Card View

struct MyCourseCardView: View {
    
    let course: CourseCard
    
    @EnvironmentObject var socialService: CourseSocialService
    @State private var showDetails = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Thumbnail
            ZStack {
                if let thumbnailURL = course.coverURL, let url = URL(string: thumbnailURL) {
                    AsyncImage(url: url) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        placeholderImage
                    }
                } else {
                    placeholderImage
                }
                
                // Level Badge
                VStack {
                    HStack {
                        Spacer()
                        Text(course.status.rawValue.capitalized)
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.ultraThinMaterial)
                            .cornerRadius(8)
                            .padding(8)
                    }
                    Spacer()
                }
            }
            .frame(height: 120)
            .clipped()
            .cornerRadius(12)
            
            // Title
            Text(course.title)
                .font(.headline)
                .lineLimit(2)
            
            // Duration
            HStack {
                Image(systemName: "clock")
                    .font(.caption)
                Text(course.timeLeft ?? "10 min")
                    .font(.caption)
                
                Spacer()
                
                // Social Stats
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .font(.caption)
                        Text("\(socialService.getLikeCount(courseId: course.id))")
                            .font(.caption)
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundColor(.yellow)
                        Text(String(format: "%.1f", socialService.getAverageRating(courseId: course.id)))
                            .font(.caption)
                    }
                }
            }
            .foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        .onTapGesture {
            showDetails = true
        }
        .sheet(isPresented: $showDetails) {
            CourseDetailView(course: course)
        }
    }
    
    private var placeholderImage: some View {
        // Each course gets a stable, distinct cover derived from its title —
        // so the grid reads as a row of distinct shelves, not five identical
        // purple rectangles. Same art appears in the chat proposal and the
        // classroom hero once the course is opened.
        TopicArtSwatch(topic: course.title, iconSize: 38, cornerRadius: 0)
    }
}

// MARK: - Course Detail View

struct CourseDetailView: View {

    let course: CourseCard
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var socialService: CourseSocialService
    @State private var showFullDescription = false
    @State private var showCourseRuntime = false
    @State private var courseRuntime: LyoCourseRuntime?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Hero Image
                    heroImage
                    
                    VStack(alignment: .leading, spacing: 16) {
                        // Title & Stats
                        VStack(alignment: .leading, spacing: 8) {
                            Text(course.title)
                                .font(.title)
                                .fontWeight(.bold)
                            
                            HStack {
                                Label(course.timeLeft ?? "10 min", systemImage: "clock")
                                Spacer()
                                Label(course.status.rawValue.capitalized, systemImage: "chart.bar")
                            }
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        }
                        
                        // Description
                        VStack(alignment: .leading, spacing: 8) {
                            Text("About")
                                .font(.headline)
                            
                            Text(course.description ?? "")
                                .font(.body)
                                .lineLimit(showFullDescription ? nil : 3)
                            
                            if (course.description ?? "").count > 100 {
                                Button(showFullDescription ? "Show Less" : "Show More") {
                                    withAnimation {
                                        showFullDescription.toggle()
                                    }
                                }
                                .font(.caption)
                                .foregroundColor(.blue)
                            }
                        }
                        
                        // Tags
                        if !(course.tags ?? []).isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Tags")
                                    .font(.headline)
                                
                                MyCoursesFlowLayout(spacing: 8) {
                                    ForEach(course.tags ?? [], id: \.self) { tag in
                                        Text(tag)
                                            .font(.caption)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Color(.systemGray6))
                                            .cornerRadius(12)
                                    }
                                }
                            }
                        }
                        
                        // Social Actions
                        socialActions
                        
                        // Start Button
                        Button(action: {
                            let skeleton = LyoCourse(
                                id: course.id,
                                title: course.title,
                                targetAudience: "General",
                                learningObjectives: [],
                                modules: [],
                                generationSource: "library",
                                version: "1.0",
                                metadata: nil
                            )
                            courseRuntime = LyoCourseRuntime(course: skeleton)
                            showCourseRuntime = true
                        }) {
                            Text("Start Course")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        .fullScreenCover(isPresented: $showCourseRuntime) {
                            if let runtime = courseRuntime {
                                CourseRuntimeView(runtime: runtime)
                            }
                        }
                    }
                    .padding()
                }
            }
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
    
    private var heroImage: some View {
        ZStack {
            if let thumbnailURL = course.coverURL, let url = URL(string: thumbnailURL) {
                AsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    placeholderHero
                }
            } else {
                placeholderHero
            }
        }
        .frame(height: 240)
        .clipped()
    }
    
    private var placeholderHero: some View {
        Rectangle()
            .fill(LinearGradient(
                colors: [Color(hex: "6366F1"), Color(hex: "8B5CF6")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
            .overlay {
                Image(systemName: "book.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.white.opacity(0.5))
            }
    }
    
    private var socialActions: some View {
        HStack(spacing: 20) {
            // Like Button
            Button(action: {
                Task {
                    if socialService.hasLiked(courseId: course.id) {
                        try? await socialService.unlikeCourse(courseId: course.id)
                    } else {
                        try? await socialService.likeCourse(courseId: course.id)
                    }
                }
            }) {
                VStack {
                    Image(systemName: socialService.hasLiked(courseId: course.id) ? "heart.fill" : "heart")
                        .font(.title2)
                        .foregroundColor(socialService.hasLiked(courseId: course.id) ? .red : .gray)
                    Text("\(socialService.getLikeCount(courseId: course.id))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Rating
            VStack {
                HStack(spacing: 4) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: star <= (socialService.getUserRating(courseId: course.id) ?? 0) ? "star.fill" : "star")
                            .font(.title3)
                            .foregroundColor(.yellow)
                            .onTapGesture {
                                Task {
                                    try? await socialService.rateCourse(courseId: course.id, rating: star)
                                }
                            }
                    }
                }
                Text(String(format: "%.1f (\(socialService.getLikeCount(courseId: course.id)))", socialService.getAverageRating(courseId: course.id)))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Share Button
            ShareLink(item: "lyoapp://course/\(course.id)", subject: Text(course.title), message: Text("Check out this course on Lyo!")) {
                VStack {
                    Image(systemName: "square.and.arrow.up")
                        .font(.title2)
                        .foregroundColor(.blue)
                    Text("Share")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Filters View

struct FiltersView: View {
    
    @Binding var selectedLevel: CourseLevel?
    @Binding var selectedTags: Set<String>
    @Environment(\.dismiss) var dismiss
    
    private let allTags = ["AI", "Programming", "Business", "Design", "Math", "Science", "Languages"]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Level") {
                    Picker("Level", selection: $selectedLevel) {
                        Text("All Levels").tag(nil as CourseLevel?)
                        ForEach(CourseLevel.allCases, id: \.self) { level in
                            Text(level.rawValue).tag(level as CourseLevel?)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("Tags") {
                    ForEach(allTags, id: \.self) { tag in
                        Toggle(tag, isOn: Binding(
                            get: { selectedTags.contains(tag) },
                            set: { isOn in
                                if isOn {
                                    selectedTags.insert(tag)
                                } else {
                                    selectedTags.remove(tag)
                                }
                            }
                        ))
                    }
                }
                
                Section {
                    Button("Clear All") {
                        selectedLevel = nil
                        selectedTags.removeAll()
                    }
                    .foregroundColor(.red)
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

// MARK: - Flow Layout (for tags)

struct MyCoursesFlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.frames[index].minX, y: bounds.minY + result.frames[index].minY), proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size = CGSize.zero
        var frames = [CGRect]()
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }
                
                frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
                
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
            }
            
            self.size = CGSize(width: maxWidth, height: y + lineHeight)
        }
    }
}

// MARK: - Preview

struct MyCoursesView_Previews: PreviewProvider {
    static var previews: some View {
        MyCoursesView()
    }
}
