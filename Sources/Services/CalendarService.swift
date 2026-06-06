import Foundation
import EventKit
import SwiftUI

// MARK: - Calendar Service

@MainActor
class CalendarService: ObservableObject {
    static let shared = CalendarService()
    
    private let eventStore = EKEventStore()
    @Published var isAccessGranted = false
    
    // MARK: - Initialization
    
    private init() {
        checkAccess()
    }
    
    func checkAccess() {
        let status = EKEventStore.authorizationStatus(for: .event)
        if #available(iOS 17.0, *) {
            switch status {
            case .fullAccess, .writeOnly:
                isAccessGranted = true
            default:
                isAccessGranted = false
            }
        } else {
            isAccessGranted = (status == .authorized)
        }
    }
    
    // MARK: - Authorization
    
    func requestAccess() async -> Bool {
        do {
            if #available(iOS 17.0, *) {
                // Prefer full access for creating events
                let granted = try await eventStore.requestFullAccessToEvents()
                self.isAccessGranted = granted
                return granted
            } else {
                let granted = try await eventStore.requestAccess(to: .event)
                self.isAccessGranted = granted
                return granted
            }
        } catch {
            Log.general.error("Failed to request calendar access: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Events
    
    func addStudySession(title: String, notes: String, date: Date, durationMinutes: Int) async throws -> Bool {
        if !isAccessGranted {
            let granted = await requestAccess()
            if !granted { return false }
        }
        
        // Find Lyo calendar or use default
        let event = EKEvent(eventStore: eventStore)
        event.title = "📚 Study: \(title)"
        event.notes = notes
        event.startDate = date
        event.endDate = date.addingTimeInterval(TimeInterval(durationMinutes * 60))
        event.calendar = eventStore.defaultCalendarForNewEvents
        
        // Add alarm 15 mins before
        event.addAlarm(EKAlarm(relativeOffset: -900))
        
        do {
            try eventStore.save(event, span: .thisEvent)
            return true
        } catch {
            Log.general.error("Failed to save event: \(error.localizedDescription)")
            throw error
        }
    }
    
    func addStudyPlan(_ plan: CalendarStudyPlan) async -> Int {
        var addedCount = 0
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let sessionCount = plan.sessions.count

        let scheduledStartDate: Date
        if let testDate = plan.testDate {
            let daysBefore = max(sessionCount, 1)
            scheduledStartDate = calendar.date(byAdding: .day, value: -daysBefore, to: calendar.startOfDay(for: testDate)) ?? today.addingTimeInterval(86400)
        } else {
            scheduledStartDate = today.addingTimeInterval(86400)
        }

        for (index, session) in plan.sessions.enumerated() {
            let dayOffset = index
            let baseDate = calendar.date(byAdding: .day, value: dayOffset, to: scheduledStartDate) ?? scheduledStartDate.addingTimeInterval(TimeInterval(dayOffset * 86400))
            let sessionDate = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: baseDate) ?? baseDate

            do {
                let success = try await addStudySession(
                    title: session.title,
                    notes: session.description,
                    date: sessionDate,
                    durationMinutes: session.durationMinutes
                )
                if success { addedCount += 1 }
            } catch {
                print("Error adding session: \(error)")
            }
        }

        return addedCount
    }
}

// MARK: - Models (Mirroring Backend)

struct CalendarStudyPlan: Codable, Identifiable {
    let id: String
    let title: String
    let testDate: Date?
    let sessions: [CalendarStudySession]
    
    enum CodingKeys: String, CodingKey {
        case id = "planId"
        case title
        case testDate
        case sessions
    }
}

struct CalendarStudySession: Codable, Identifiable {
    let id: String
    let title: String
    let description: String
    let topic: String
    let durationMinutes: Int
    let activityType: String
}
