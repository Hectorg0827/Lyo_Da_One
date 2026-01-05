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
                .onChange(of: searchText) { newValue in
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
                    CourseCardView(course: course)
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

// MARK: - Preview


struct MyCoursesView_Previews: PreviewProvider {
    static var previews: some View {
        MyCoursesView()
    }
}
