//
//  BookingCalendarView.swift
//  Lyo
//
//  Calendar view for booking private lessons
//

import SwiftUI
import Combine

// MARK: - ViewModel

@MainActor
class BookingViewModel: ObservableObject {
    @Published var selectedDate = Date()
    @Published var availableSlots: [APIBookingSlot] = []
    @Published var isLoadingSlots = false
    @Published var isBooking = false
    @Published var bookingError: String?
    @Published var showingConfirmation = false
    
    private let lessonId: Int
    private var cancellables = Set<AnyCancellable>()
    
    init(lessonId: Int) {
        self.lessonId = lessonId
        
        // Fetch slots when date changes
        $selectedDate
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] date in
                self?.fetchSlots(for: date)
            }
            .store(in: &cancellables)
    }
    
    func fetchSlots(for date: Date) {
        isLoadingSlots = true
        bookingError = nil
        availableSlots = []
        
        Task {
            do {
                let slots: [APIBookingSlot] = try await NetworkClient.shared.request(
                    Endpoints.Community.getAvailableSlots(lessonId: lessonId, date: date)
                )
                
                await MainActor.run {
                    self.availableSlots = slots
                    self.isLoadingSlots = false
                }
            } catch {
                await MainActor.run {
                    self.bookingError = "Failed to load slots. Please try again."
                    self.isLoadingSlots = false
                }
            }
        }
    }
    
    func bookLesson(slot: APIBookingSlot) {
        isBooking = true
        bookingError = nil
        
        Task {
            do {
                let request = APIBookingRequest(
                    lessonId: lessonId,
                    slotId: slot.id,
                    notes: nil
                )
                
                let _: APIBookingResponse = try await NetworkClient.shared.request(
                    Endpoints.Community.createBooking(request: request)
                )
                
                await MainActor.run {
                    HapticManager.shared.playSuccess()
                    self.showingConfirmation = true
                    self.isBooking = false
                }
            } catch {
                await MainActor.run {
                    self.bookingError = "Booking failed. Please try again."
                    self.isBooking = false
                }
            }
        }
    }
}

// MARK: - View

struct BookingCalendarView: View {
    let lesson: APIPrivateLesson
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: BookingViewModel
    @State private var selectedSlot: APIBookingSlot?
    
    init(lesson: APIPrivateLesson) {
        self.lesson = lesson
        _viewModel = StateObject(wrappedValue: BookingViewModel(lessonId: lesson.id))
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                headerSection
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Calendar Picker
                        calendarSection
                        
                        Divider()
                        
                        // Time Slots
                        timeSlotsSection
                        
                        // Booking Summary
                        if selectedSlot != nil {
                            summarySection
                        }
                        
                        // Error
                        if let error = viewModel.bookingError {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    }
                    .padding(20)
                }
                
                // Book Button
                if selectedSlot != nil {
                    bookButton
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Booking Confirmed!", isPresented: $viewModel.showingConfirmation) {
                Button("Done") {
                    dismiss()
                }
            } message: {
                if let slot = selectedSlot {
                    Text("Your lesson with \(lesson.instructor.name) has been booked for \(formatTime(slot.startTime)).")
                } else {
                    Text("Your lesson has been booked!")
                }
            }
            .onAppear {
                // Initial fetch
                viewModel.fetchSlots(for: Date())
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("Book a Lesson")
                .font(.title2.bold())
            
            Text(lesson.title)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
    }
    
    // MARK: - Calendar Section
    
    private var calendarSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select Date")
                .font(.headline)
            
            DatePicker(
                "Select a date",
                selection: $viewModel.selectedDate,
                in: Date()...,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .tint(.purple)
            .onChange(of: viewModel.selectedDate) {
                selectedSlot = nil // Deselect slot on date change
            }
        }
    }
    
    // MARK: - Time Slots Section
    
    private var timeSlotsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Available Times")
                    .font(.headline)
                if viewModel.isLoadingSlots {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            if viewModel.availableSlots.isEmpty && !viewModel.isLoadingSlots {
                Text("No slots available for this date")
                    .foregroundColor(.secondary)
                    .italic()
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    ForEach(viewModel.availableSlots) { slot in
                        TimeSlotButton(
                            slot: slot,
                            isSelected: selectedSlot?.id == slot.id,
                            action: {
                                if slot.isAvailable {
                                    withAnimation(.spring(response: 0.3)) {
                                        selectedSlot = slot
                                    }
                                    HapticManager.shared.playLightImpact()
                                }
                            }
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Summary Section
    
    private var summarySection: some View {
        VStack(spacing: 16) {
            Divider()
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your Booking")
                        .font(.headline)
                    
                    if let slot = selectedSlot {
                        Text("\(formatDate(viewModel.selectedDate)) at \(formatTime(slot.startTime))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("$\(Int(lesson.cost))")
                        .font(.title2.bold())
                        .foregroundColor(.purple)
                    
                    Text("\(lesson.durationMinutes) min")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color.purple.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    // MARK: - Formatters
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // MARK: - Book Button
    
    private var bookButton: some View {
        Button {
            if let slot = selectedSlot {
                viewModel.bookLesson(slot: slot)
            }
        } label: {
            HStack {
                if viewModel.isBooking {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Confirm Booking")
                }
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [.purple, .blue],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        }
        .disabled(viewModel.isBooking)
        .padding(20)
        .background(Color(.systemBackground))
    }
}

// MARK: - Supporting Views

struct TimeSlotButton: View {
    let slot: APIBookingSlot
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(slot.startTime, style: .time)
                .font(.subheadline.bold())
                .foregroundColor(foregroundColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(backgroundColor)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(borderColor, lineWidth: isSelected ? 2 : 1)
                )
        }
        .disabled(!slot.isAvailable)
    }
    
    private var foregroundColor: Color {
        if !slot.isAvailable {
            return .gray
        }
        return isSelected ? .white : .primary
    }
    
    private var backgroundColor: Color {
        if !slot.isAvailable {
            return Color(.systemGray5)
        }
        return isSelected ? .purple : Color(.systemGray6)
    }
    
    private var borderColor: Color {
        if !slot.isAvailable {
            return .clear
        }
        return isSelected ? .purple : Color(.systemGray4)
    }
}
