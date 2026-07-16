import Foundation
import EventKit
import UserNotifications
import os

/// Service for managing Test Prep related system integrations (Calendar, Notifications).
public class TestPrepService {
    public static let shared = TestPrepService()
    
    private let eventStore = EKEventStore()
    
    private init() {}
    
    // MARK: - Permissions
    
    public func requestPermissions() async -> Bool {
        let calendarGranted = await requestCalendarPermission()
        let notificationsGranted = await requestNotificationPermission()
        return calendarGranted && notificationsGranted
    }
    
    private func requestCalendarPermission() async -> Bool {
        if #available(iOS 17.0, *) {
            do {
                return try await eventStore.requestFullAccessToEvents()
            } catch {
                Log.ai.error("❌ Calendar access denied: \(error.localizedDescription)")
                return false
            }
        } else {
            return await withCheckedContinuation { continuation in
                eventStore.requestAccess(to: .event) { granted, error in
                    continuation.resume(returning: granted)
                }
            }
        }
    }
    
    private func requestNotificationPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            Log.ai.error("❌ Notification permission denied: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Calendar Integration
    
    public func scheduleExamInCalendar(title: String, date: Date, description: String?) async -> Bool {
        let granted = await requestCalendarPermission()
        guard granted else { return false }
        
        let event = EKEvent(eventStore: eventStore)
        event.title = "Exam: \(title)"
        event.startDate = date
        event.endDate = date.addingTimeInterval(3600) // Default 1 hour
        event.notes = description
        if let calendar = eventStore.defaultCalendarForNewEvents {
            event.calendar = calendar
        } else {
            Log.ai.error("❌ No default calendar found for user.")
            return false
        }
        
        // Add an alarm 1 day before
        let alarm = EKAlarm(relativeOffset: -86400)
        event.addAlarm(alarm)
        
        do {
            try eventStore.save(event, span: .thisEvent)
            Log.ai.info("✅ Exam scheduled in calendar: \(title)")
            return true
        } catch {
            Log.ai.error("❌ Failed to save calendar event: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Notifications
    
    public func scheduleStudyReminders(sessions: [StudySession]) async {
        let granted = await requestNotificationPermission()
        guard granted else { return }
        
        let center = UNUserNotificationCenter.current()
        
        for session in sessions {
            let content = UNMutableNotificationContent()
            content.title = "Study Time: \(session.title)"
            content.body = "Ready to dive into \(session.description)? Let's go! 🚀"
            content.sound = .default
            
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: session.date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            
            let request = UNNotificationRequest(
                identifier: "study_\(session.id.uuidString)",
                content: content,
                trigger: trigger
            )
            
            do {
                try await center.add(request)
                Log.ai.info("✅ Study reminder scheduled: \(session.title) at \(session.date)")
            } catch {
                Log.ai.error("❌ Failed to schedule study reminder: \(error.localizedDescription)")
            }
        }
    }
    
    public func scheduleMotivationalMessage(examDate: Date, topic: String) async {
        let granted = await requestNotificationPermission()
        guard granted else { return }
        
        let center = UNUserNotificationCenter.current()
        
        let content = UNMutableNotificationContent()
        content.title = "It's Exam Day! ✨"
        content.body = "You've got this! Good luck with your \(topic) exam today. Lyo is rooting for you! 🍀"
        content.sound = .default
        
        // Schedule for 8:00 AM on the day of the exam
        var components = Calendar.current.dateComponents([.year, .month, .day], from: examDate)
        components.hour = 8
        components.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "motivation_\(topic)",
            content: content,
            trigger: trigger
        )
        
        do {
            try await center.add(request)
            Log.ai.info("✅ Motivational message scheduled for \(topic) exam")
        } catch {
            Log.ai.error("❌ Failed to schedule motivational message: \(error.localizedDescription)")
        }
    }
}
