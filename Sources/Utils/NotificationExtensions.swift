import Foundation

extension Notification.Name {
    // MARK: - Classroom & Learning
    static let openClassroom = Notification.Name("openClassroom")
    static let openLivingClassroom = Notification.Name("openLivingClassroom")
    static let triggerTutorMode = Notification.Name("TriggerTutorMode")
    static let triggerLiveLesson = Notification.Name("TriggerLiveLesson")
    static let saveCourseToLibrary = Notification.Name("SaveCourseToLibrary")
    static let classroomAdvance = Notification.Name("ClassroomAdvance")

    // MARK: - UI Navigation
    static let triggerLioChat = Notification.Name("TriggerLioChat")
    static let resetInactivityTimer = Notification.Name("ResetInactivityTimer")
    static let dismissLyoOverlay = Notification.Name("DismissLyoOverlay")

    /// Open the Lio overlay — the surface whose input bar renders attachments
    /// and runs the voice session. Focus's create composer posts this for its
    /// Speak / Photo / File modes, because the chat sheet's own attach button
    /// is still a stub. `userInfo["mode"]` is "voice" or "attachment".
    static let presentLyoOverlay = Notification.Name("PresentLyoOverlay")
}
