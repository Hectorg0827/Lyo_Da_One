import XCTest
@testable import Lyo

@MainActor
final class ClassroomRecoveryServiceTests: XCTestCase {
    func testOfflineActionsAreRejectedEvenWithAnInjectedTransport() {
        var sent: [String] = []
        let service = LivingClassroomService(actionSender: { sent.append($0) })
        XCTAssertFalse(service.sendUserAction(actionIntent: "continue", componentId: "continue"))
        XCTAssertTrue(sent.isEmpty)
        XCTAssertFalse(service.isGenerating)
    }

    func testSilentSocketGetsOneAutomaticNudgeThenStalls() throws {
        let suite = "ClassroomRecoveryServiceTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        var time = Date(timeIntervalSince1970: 1_000)
        var sent: [[String: Any]] = []
        let service = LivingClassroomService(
            sessionStore: ClassroomSessionStore(defaults: defaults),
            actionSender: { json in
                sent.append((try? JSONSerialization.jsonObject(with: Data(json.utf8))) as? [String: Any] ?? [:])
            },
            now: { time }
        )
        defer { service.disconnect() }
        service.connect(sessionId: "fractions", courseId: "fractions", topic: "Fractions")
        service.stallTick(now: time)
        time.addTimeInterval(12)
        service.stallTick(now: time)
        XCTAssertEqual(service.stallPhase, .slow)
        XCTAssertTrue(sent.isEmpty)
        time.addTimeInterval(18)
        service.stallTick(now: time)
        XCTAssertEqual(sent.count, 1)
        XCTAssertEqual(sent[0]["action_intent"] as? String, "continue")
        XCTAssertNil(sent[0]["answer_data"])
        time.addTimeInterval(30)
        service.stallTick(now: time)
        XCTAssertEqual(service.stallPhase, .stalled)
        time.addTimeInterval(120)
        service.stallTick(now: time)
        XCTAssertEqual(sent.count, 1, "Further ticks must not resend automatic requests")

        service.nudgeTeacher()
        XCTAssertEqual(sent.count, 2, "The learner may explicitly ask again")
        time.addTimeInterval(30)
        service.stallTick(now: time)
        XCTAssertEqual(service.stallPhase, .stalled)
        XCTAssertEqual(sent.count, 2, "A manual nudge must not arm another automatic one")
    }

    func testLateContentEndsTheWaitAndDoesNotAccuseAPausedLearner() async throws {
        var time = Date(timeIntervalSince1970: 1_000)
        var sent: [String] = []
        let service = LivingClassroomService(actionSender: { sent.append($0) }, now: { time })
        defer { service.disconnect() }
        service.isConnected = true
        XCTAssertTrue(service.sendUserAction(actionIntent: "submit_answer", componentId: "question",
                                            actionData: ["answer": "One quarter"]))
        time.addTimeInterval(30)
        service.stallTick(now: time)
        XCTAssertEqual(sent.count, 2)
        service.handleWebSocketMessage("{\"type\":\"scene_complete\"}")
        await Task.yield()
        await Task.yield()
        XCTAssertFalse(service.isGenerating)
        time.addTimeInterval(120)
        service.stallTick(now: time)
        XCTAssertEqual(service.stallPhase, .none)
        XCTAssertEqual(sent.count, 2)
    }

    func testCompletionMarksTheSavedSessionAndAReopenStartsFresh() async throws {
        let suite = "ClassroomRecoveryServiceTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = ClassroomSessionStore(defaults: defaults)
        let service = LivingClassroomService(sessionStore: store, actionSender: { _ in })
        defer { service.disconnect() }
        service.connect(sessionId: "fractions", courseId: "fractions", topic: "Fractions")
        service.handleWebSocketMessage("{\"type\":\"session_end\"}")
        await Task.yield()
        await Task.yield()
        XCTAssertTrue(service.lessonComplete)
        XCTAssertFalse(service.isGenerating)
        XCTAssertTrue(try XCTUnwrap(store.saved(courseKey: "fractions")).finished)
        XCTAssertFalse(ClassroomSessionContract.canResume(store.saved(courseKey: "fractions")))
        service.disconnect()
        service.connect(sessionId: "fractions", courseId: "fractions", topic: "Fractions", resume: true)
        XCTAssertFalse(service.lessonComplete)
        XCTAssertFalse(service.resumedSession)
        XCTAssertNil(service.resumableSession)
        XCTAssertEqual(store.saved(courseKey: "fractions")?.id, "fractions~2")
    }

    func testDirectorCompletionInTheLiveComponentStreamIsRecorded() async throws {
        let suite = "ClassroomRecoveryServiceTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = ClassroomSessionStore(defaults: defaults)
        let service = LivingClassroomService(sessionStore: store, actionSender: { _ in })
        service.voiceModeEnabled = false
        defer { service.disconnect() }
        service.connect(sessionId: "fractions", courseId: "fractions", topic: "Fractions")
        let component = SDUIComponent(id: "dismissal", type: .teacherMessage,
                                      content: "[{\"type\":\"session_end\",\"text\":\"Class dismissed\"}]")
        let encoded = try JSONEncoder().encode(component)
        let object = try JSONSerialization.jsonObject(with: encoded)
        let wire = try JSONSerialization.data(withJSONObject: ["type": "component_stream", "component": object])
        service.handleWebSocketMessage(String(decoding: wire, as: UTF8.self))
        await Task.yield()
        await Task.yield()
        XCTAssertTrue(service.lessonComplete)
        XCTAssertTrue(try XCTUnwrap(store.saved(courseKey: "fractions")).finished)
    }

    func testACompletionCannotFinishTheNewerSeat() throws {
        let suite = "ClassroomRecoveryServiceTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = ClassroomSessionStore(defaults: defaults)
        store.save(ClassroomSavedSession(id: "fractions~2", startedAt: Date(), generation: 2), courseKey: "fractions")
        store.markFinished(sessionId: "fractions", courseKey: "fractions")
        XCTAssertFalse(try XCTUnwrap(store.saved(courseKey: "fractions")).finished)
    }

    func testGuidedCompletionMetadataUsesTheSamePersistedCompletionPath() async throws {
        let suite = "ClassroomRecoveryServiceTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = ClassroomSessionStore(defaults: defaults)
        let service = LivingClassroomService(sessionStore: store, actionSender: { _ in })
        defer { service.disconnect() }
        service.connect(sessionId: "fractions", courseId: "fractions", topic: "Fractions")
        service.handleWebSocketMessage("{\"type\":\"scene_start\",\"scene\":{\"scene_id\":\"done\",\"scene_type\":\"instruction\",\"components\":[],\"metadata\":{\"course_complete\":true}}}")
        await Task.yield()
        await Task.yield()
        XCTAssertTrue(service.lessonComplete)
        XCTAssertTrue(try XCTUnwrap(store.saved(courseKey: "fractions")).finished)
    }

    func testAnOlderSavedSessionWithoutFinishedStillDecodes() throws {
        let data = Data("{\"id\":\"fractions\",\"startedAt\":1000,\"generation\":1}".utf8)
        let saved = try JSONDecoder().decode(ClassroomSavedSession.self, from: data)
        XCTAssertFalse(saved.finished)
    }
}
