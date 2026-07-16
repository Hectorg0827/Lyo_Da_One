//
//  MyActivitiesView.swift
//  Lyo
//
//  Dashboard view for user's community activities
//

import SwiftUI

struct MyActivitiesView: View {
    @StateObject private var viewModel = MyActivitiesViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter Bar
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(MyActivitiesViewModel.ActivityFilter.allCases) { filter in
                            FilterChip(
                                title: filter.rawValue,
                                isSelected: viewModel.selectedFilter == filter,
                                action: {
                                    withAnimation {
                                        viewModel.selectedFilter = filter
                                    }
                                }
                            )
                        }
                    }
                    .padding()
                }
                .background(Color(.systemBackground))
                
                Divider()
                
                // Content
                if viewModel.isLoading {
                    Spacer()
                    ProgressView("Loading activities...")
                    Spacer()
                } else if viewModel.filteredItems.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("No activities found")
                            .font(.headline)
                        Text("Join groups, book lessons, or register for events to see them here.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    Spacer()
                } else {
                    List {
                        ForEach(viewModel.filteredItems) { item in
                            ActivityRow(item: item)
                        }
                    }
                    .listStyle(.plain)
                    .refreshable {
                        await viewModel.fetchData()
                    }
                }
            }
            .navigationTitle("My Activities")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                await viewModel.fetchData()
            }
        }
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.bold())
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color(.systemGray6))
                .clipShape(Capsule())
        }
    }
}

struct ActivityRow: View {
    let item: AnyActivityItem
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(itemColor.opacity(0.1))
                    .frame(width: 48, height: 48)
                Image(systemName: itemIcon)
                    .foregroundColor(itemColor)
                    .font(.title3)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(itemTitle)
                    .font(.headline)
                
                Text(itemSubtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let date = itemDate {
                    Text(date, style: .date)
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(.vertical, 8)
    }
    
    var itemTitle: String {
        switch item {
        case .booking(let b): return b.lesson.title
        case .event(let e): return e.title
        case .group(let g): return g.title
        }
    }
    
    var itemSubtitle: String {
        switch item {
        case .booking(let b): return "Instructor: \(b.lesson.instructor.name)"
        case .event(let e): return e.location.name
        case .group(let g): return "\(g.attendeeCount) members"
        }
    }
    
    var itemDate: Date? {
        switch item {
        case .booking(let b): return b.startTime
        case .event(let e): return e.dateTime
        case .group: return nil
        }
    }
    
    var itemIcon: String {
        switch item {
        case .booking: return "graduationcap.fill"
        case .event: return "calendar"
        case .group: return "person.3.fill"
        }
    }
    
    var itemColor: Color {
        switch item {
        case .booking: return .purple
        case .event: return .orange
        case .group: return .blue
        }
    }
}

#Preview {
    MyActivitiesView()
}
