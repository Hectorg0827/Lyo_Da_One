import Foundation

extension Notification.Name {
    // MARK: - Classroom & Learning
    static let openClassroom = Notification.Name("openClassroom")
    static let openLivingClassroom = Notification.Name("openLivingClassroom")
    static let triggerTutorMode = Notification.Name("TriggerTutorMode")
    static let triggerLiveLesson = Notification.Name("TriggerLiveLesson")
    static let saveCourseToLibrary = Notification.Name("SaveCourseToLibrary")
    
    // MARK: - UI Navigation
    static let triggerLioChat = Notification.Name("TriggerLioChat")
    static let resetInactivityTimer = Notification.Name("ResetInactivityTimer")
    static let dismissLyoOverlay = Notification.Name("DismissLyoOverlay")
}
