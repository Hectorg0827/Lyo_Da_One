//
//  MyActivitiesViewModel.swift
//  Lyo
//
//  ViewModel for MyActivitiesView
//

import SwiftUI
import Foundation
import os

// Wrapper for different activity types
enum AnyActivityItem: Identifiable {
    case booking(APIUserBooking)
    case event(EducationalEvent)
    case group(StudyGroup)
    
    var id: String {
        switch self {
        case .booking(let b): return "booking_\(b.id)"
        case .event(let e): return "event_\(e.id)"
        case .group(let g): return "group_\(g.id)"
        }
    }
}

@MainActor
class MyActivitiesViewModel: ObservableObject {
    @Published var filteredItems: [AnyActivityItem] = []
    @Published var selectedFilter: ActivityFilter = .all {
        didSet {
            filterItems()
        }
    }
    @Published var isLoading = false
    
    private var allItems: [AnyActivityItem] = []
    private let repository = LyoRepository.shared
    
    enum ActivityFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case bookings = "Bookings"
        case events = "Events"
        case groups = "Groups"
        
        var id: String { rawValue }
    }
    
    init() {
        Task {
            await fetchData()
        }
    }
    
    func fetchData() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            async let groups = repository.getMyStudyGroups()
            async let events = repository.getMyEvents()
            async let bookings = repository.getUserBookings() // Assuming this exists in LyoRepository
            
            let (fetchedGroups, fetchedEvents, fetchedBookings) = try await (groups, events, bookings)
            
            var items: [AnyActivityItem] = []
            items.append(contentsOf: fetchedBookings.map { .booking($0) })
            items.append(contentsOf: fetchedEvents.map { .event($0) })
            items.append(contentsOf: fetchedGroups.map { .group($0) })
            
            // Sort by date (if available)
            self.allItems = items.sorted { item1, item2 in
                let date1 = getDate(for: item1)
                let date2 = getDate(for: item2)
                return date1 > date2 // Newest first
            }
            
            filterItems()
            
        } catch {
            Log.ui.error("Failed to fetch my activities: \(error)")
        }
    }
    
    // Watch for filter changes
    var filterPublisher: Any? // Could use Combine but simpler to just call filter in didSet
    
    func filterItems() {
        switch selectedFilter {
        case .all:
            filteredItems = allItems
        case .bookings:
            filteredItems = allItems.filter { if case .booking = $0 { return true }; return false }
        case .events:
            filteredItems = allItems.filter { if case .event = $0 { return true }; return false }
        case .groups:
            filteredItems = allItems.filter { if case .group = $0 { return true }; return false }
        }
    }
    
    private func getDate(for item: AnyActivityItem) -> Date {
        switch item {
        case .booking(let b): return b.startTime
        case .event(let e): return e.dateTime
        case .group: return Date.distantPast // Groups don't have a specific time in this context, put at bottom
        }
    }
}

// Observe filter changes manually
extension MyActivitiesViewModel {
    // Hack to trigger filtering when selectedFilter changes
    // In strict MVVM, use didSet or Combine
}
