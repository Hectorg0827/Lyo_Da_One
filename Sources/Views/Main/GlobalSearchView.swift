import SwiftUI
import os

struct GlobalSearchView: View {
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""
    @State private var searchResults: [String] = []
    
    var body: some View {
        NavigationView {
            VStack {
                // Search Field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    
                    TextField("Search courses, tutors, chats...", text: $searchText)
                        .foregroundColor(.white)
                        .onChange(of: searchText) { _, newValue in
                            performSearch(query: newValue)
                        }
                    
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(12)
                .padding()
                
                // Results List
                List {
                    if searchText.isEmpty {
                        Section(header: Text("Recent").foregroundColor(.gray)) {
                            Text("Calculus Limits")
                                .listRowBackground(Color.clear)
                            Text("Physics Kinematics")
                                .listRowBackground(Color.clear)
                        }
                    } else {
                        ForEach(searchResults, id: \.self) { result in
                            Button(action: {
                                // Simulate navigation
                                Log.ui.info("Selected: \(result)")
                                dismiss()
                            }) {
                                HStack {
                                    Image(systemName: "doc.text")
                                        .foregroundColor(.blue)
                                    Text(result)
                                        .foregroundColor(.white)
                                }
                            }
                            .listRowBackground(Color.clear)
                        }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .background(Color(hex: "0f172a"))
            .preferredColorScheme(.dark)
        }
    }
    
    private func performSearch(query: String) {
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        
        let repository = DefaultAIRepository()
        
        Task {
            do {
                // Call actual AI search endpoint
                // Note: The signature in DefaultAIRepository is searchSimilar(query:limit:) returns [SearchResult]
                let results = try await repository.searchSimilar(query: query, limit: 5)
                
                await MainActor.run {
                    self.searchResults = results.map { $0.title }
                }
            } catch {
                Log.ui.error("Search error: \(error)")
                // Fallback to mock if failure
                await MainActor.run {
                    searchResults = ["Failed to connect: \(error.localizedDescription)"]
                }
            }
        }
    }
}
