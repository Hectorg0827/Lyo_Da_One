import Foundation

/// Starting a class, starting it over, and noticing when it has stopped.
///
/// The Swift twin of `web/src/lib/classroom-contract.mjs`. The rules here are
/// not presentation: the session id decides whether the backend teaches a
/// lesson or resumes one, and the stall thresholds decide when a class stops
/// claiming the next step is coming. Three platforms disagreeing about either
/// is three different products, so the numbers and the copy live in one place
/// per platform and are held together by `scripts/verify-classroom-parity.mjs`.

/// A live session a learner could still return to.
struct ClassroomSavedSession: Codable, Equatable {
    let id: String
    let startedAt: Date
    let generation: Int
    /// The class reached its end, so it is not an unfinished one to resume.
    /// Decoded as `false` for a seat saved before this field existed.
    var finished: Bool = false

    init(id: String, startedAt: Date, generation: Int, finished: Bool = false) {
        self.id = id
        self.startedAt = startedAt
        self.generation = generation
        self.finished = finished
    }

    private enum CodingKeys: String, CodingKey {
        case id, startedAt, generation, finished
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id)
        startedAt = try values.decode(Date.self, forKey: .startedAt)
        generation = try values.decode(Int.self, forKey: .generation)
        finished = try values.decodeIfPresent(Bool.self, forKey: .finished) ?? false
    }
}

/// Which session this entry connects with, and whether it is a continuation.
struct ClassroomSessionStart: Equatable {
    let sessionId: String
    let generation: Int
    let resumed: Bool
}

/// How far past "the next step is coming" a wait has gone.
///
/// `slow` is still a wait. `stalled` is the admission that the step is not
/// arriving, and is the only one that puts recovery controls on screen.
enum ClassroomStallPhase: Equatable {
    case none
    case slow
    case stalled
}

/// What the learner is told before the teaching starts.
struct ClassroomOpening: Equatable {
    let title: String
    let objective: String
    let facts: [String]
    let note: String
    let resumed: Bool
}

enum ClassroomSessionContract {
    /// How long a half-finished class stays worth offering back. Past this,
    /// "pick up where you left off" is a promise about a lesson the learner
    /// no longer remembers sitting, so the class simply starts.
    static let resumeWindow: TimeInterval = 6 * 60 * 60

    /// Say out loud that this step is taking longer than it should.
    static let stallNoticeSeconds: TimeInterval = 12
    /// The step is not coming: ask after it once, then hand the learner
    /// controls that can actually get the class moving again.
    static let stallRecoverySeconds: TimeInterval = 30

    static let stallNotice = "This step is taking longer than it should. Still working on it…"
    static let stallRecovery =
        "The next step didn't arrive. Nothing you've done is lost, and this is not a wrong answer."
    static let openingNote =
        "You can stop Lyo at any time — raise your hand, ask a question, or say you are lost."

    /// Free-topic entries arrive as `GENERATE:<topic>`; the stored key is the
    /// topic itself, so the same topic typed twice finds its own history.
    static func normalizedSessionId(_ rawSessionId: String) -> String {
        rawSessionId.hasPrefix("GENERATE:")
            ? String(rawSessionId.dropFirst("GENERATE:".count))
            : rawSessionId
    }

    static func courseKey(courseId: String?, topic: String?) -> String {
        let course = (courseId ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !course.isEmpty { return normalizedSessionId(course) }
        let subject = (topic ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return subject.isEmpty ? "general" : normalizedSessionId(subject)
    }

    static func storageKey(courseKey: String) -> String {
        "lyo_classroom_session:\(courseKey)"
    }

    static func canResume(_ saved: ClassroomSavedSession?, now: Date = Date()) -> Bool {
        guard let saved, !saved.id.isEmpty else { return false }
        // A class that reached its end is not unfinished, however recent.
        if saved.finished { return false }
        let age = now.timeIntervalSince(saved.startedAt)
        return age >= 0 && age <= resumeWindow
    }

    /// The session id this entry should connect with.
    ///
    /// The first class on a topic still sends exactly the id every client sent
    /// before this contract existed, so nothing changes for a learner meeting
    /// a topic for the first time. Opening the same topic again starts a new
    /// session beside it, and resuming is something the learner asks for
    /// rather than the only thing on offer.
    static func sessionStart(
        courseKey rawKey: String,
        saved: ClassroomSavedSession?,
        resume: Bool = false,
        now: Date = Date()
    ) -> ClassroomSessionStart {
        let trimmed = rawKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = trimmed.isEmpty ? "general" : trimmed
        if resume, canResume(saved, now: now), let saved {
            return ClassroomSessionStart(
                sessionId: saved.id,
                generation: max(1, saved.generation),
                resumed: true
            )
        }
        guard let saved, !saved.id.isEmpty else {
            return ClassroomSessionStart(sessionId: key, generation: 1, resumed: false)
        }
        let generation = max(1, saved.generation) + 1
        return ClassroomSessionStart(
            sessionId: "\(key)~\(generation)",
            generation: generation,
            resumed: false
        )
    }

    static func opening(
        topic: String?,
        objective: String?,
        durationMinutes: Int?,
        difficulty: String?,
        mode: String?,
        resumed: Bool = false
    ) -> ClassroomOpening {
        let trimmedTopic = (topic ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let subject = trimmedTopic.isEmpty ? "this topic" : trimmedTopic
        let minutes = min(max(durationMinutes ?? 10, 3), 60)
        var facts = ["\(minutes) min"]
        if let difficulty, !difficulty.isEmpty { facts.append("\(difficulty) level") }
        let lessonMode = ["solo", "classroom", "challenge", "review"].contains(mode ?? "")
            ? (mode ?? "solo") : "solo"
        if lessonMode != "solo" { facts.append("\(lessonMode) mode") }
        let trimmedObjective = (objective ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return ClassroomOpening(
            title: resumed ? "Back to \(subject)" : "Today: \(subject)",
            objective: trimmedObjective.isEmpty
                ? defaultObjective(topic: subject) : trimmedObjective,
            facts: facts,
            note: openingNote,
            resumed: resumed
        )
    }

    static func defaultObjective(topic: String) -> String {
        "Understand and apply \(topic)"
    }
}

/// Where a surface remembers the last live session for a course.
///
/// `UserDefaults`, because the id only has to outlive the screen that made
/// it; an unreadable or absent record simply means this is a first class,
/// which is the behaviour every client had before any of this existed.
struct ClassroomSessionStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func saved(courseKey: String) -> ClassroomSavedSession? {
        guard let data = defaults.data(forKey: ClassroomSessionContract.storageKey(courseKey: courseKey))
        else { return nil }
        return try? JSONDecoder().decode(ClassroomSavedSession.self, from: data)
    }

    func save(_ session: ClassroomSavedSession, courseKey: String) {
        guard let data = try? JSONEncoder().encode(session) else { return }
        defaults.set(data, forKey: ClassroomSessionContract.storageKey(courseKey: courseKey))
    }

    func markFinished(sessionId: String, courseKey: String) {
        guard var session = saved(courseKey: courseKey), session.id == sessionId else { return }
        session.finished = true
        save(session, courseKey: courseKey)
    }
}
