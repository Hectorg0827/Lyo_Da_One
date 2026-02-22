
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
        isAccessGranted = (status == .authorized)
    }
    
    // MARK: - Authorization
    
    func requestAccess() async -> Bool {
        do {
            let granted = try await eventStore.requestAccess(to: .event)
            self.isAccessGranted = granted
            return granted
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
        
        // Start from tomorrow if no date specified, or use plan date
        let baseDate = plan.testDate ?? Date().addingTimeInterval(86400)
        
        // If test date is set, schedule backwards. If not, schedule forwards.
        // For simplicity, let's just schedule them sequentially from tomorrow for now 
        // unless they have specific dates in the payload (which our backend schema supports but simpler to plan here)
        
        var scheduledDate = Date().addingTimeInterval(86400) // Start tomorrow
        if let testDate = plan.testDate {
             // Basic logic: spread sessions before test date
             // This is complex, so for V1 we'll stick to sequential days
        }
        
        for (index, session) in plan.sessions.enumerated() {
            // Schedule 1 session per day
            let sessionDate = scheduledDate.addingTimeInterval(TimeInterval(index * 86400))
            
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
    let sessions: [StudySession]
    
    enum CodingKeys: String, CodingKey {
        case id = "planId"
        case title
        case testDate
        case sessions
    }
}

struct StudySession: Codable, Identifiable {
    let id: String
    let title: String
    let description: String
    let topic: String
    let durationMinutes: Int
    let activityType: String
}
