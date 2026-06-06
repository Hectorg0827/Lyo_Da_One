
import XCTest
@testable import Lyo

final class A2ATaskManagerTests: XCTestCase {
    
    @MainActor
    func testTaskStreamingParsing() async throws {
        let manager = A2ATaskManager.shared
        manager.startNewSession()
        
        let taskId = "test-task-123"
        // Pre-populate task
        manager.activeTasks[taskId] = A2ATask(
            id: taskId,
            sessionId: manager.getCurrentSessionId(),
            state: .submitted,
            message: A2AMessage(role: "user", parts: []),
            artifacts: [],
            history: nil,
            metadata: nil
        )
        
        // Mock SSE Data
        let event1 = """
        data: {"type": "task", "task": {"state": "working", "message": {"role": "agent", "parts": [{"type": "text", "text": "I am working on it..."}]}}}
        """
        
        // Note: Artifact event structure matches private A2ASSEEvent in A2ATaskManager
        let event2 = """
        data: {"type": "artifact", "artifact": {"name": "Test Artifact", "description": "A test file", "parts": [{"type": "text", "text": "Artifact Content"}], "index": 0}}
        """
        
        let event3 = """
        data: {"type": "task", "task": {"state": "completed", "message": {"role": "agent", "parts": [{"type": "text", "text": "Done."}]}}}
        """
        
        let stream = AsyncStream<String> { continuation in
            continuation.yield(event1)
            continuation.yield(event2)
            continuation.yield(event3)
            continuation.finish()
        }
        
        var updatesRequest: [A2ATaskState] = []
        var artifactsReceived: [String] = []
        
        try await manager.parseTaskStream(
            stream,
            taskId: taskId,
            onUpdate: { response in
                updatesRequest.append(response.state)
            },
            onArtifact: { artifact in
                artifactsReceived.append(artifact.name)
            },
            onComplete: { task in
                XCTAssertEqual(task.state, .completed)
            }
        )
        
        // Assertions
        XCTAssertEqual(updatesRequest.count, 2)
        XCTAssertEqual(updatesRequest, [.working, .completed])
        
        XCTAssertEqual(artifactsReceived.count, 1)
        XCTAssertEqual(artifactsReceived.first, "Test Artifact")
        
        let finalTask = manager.activeTasks[taskId]
        XCTAssertEqual(finalTask?.state, .completed)
        XCTAssertEqual(finalTask?.artifacts?.count, 1)
    }
}
