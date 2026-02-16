
import XCTest
@testable import Lyo

final class A2AServiceTests: XCTestCase {
    
    @MainActor
    func testStreamingEventParsing() async throws {
        let service = A2ACourseService.shared
        
        // Reset state
        service.streamingEvents = []
        service.progress = 0
        
        // Define test events in SSE format with snake_case keys (as expected by decoder)
        // Must include all non-optional fields: type, timestamp, pipeline_id, progress, message
        
        let event1 = """
        data: {"type": "pipeline_started", "pipeline_id": "pipeline_123", "timestamp": "2026-01-11T12:00:00Z", "agent_name": "orchestrator", "message": "Starting pipeline", "progress": 0}
        """
        
        let event2 = """
        data: {"type": "phase_started", "pipeline_id": "pipeline_123", "timestamp": "2026-01-11T12:00:01Z", "phase": "pedagogy", "progress": 15, "message": "Pedagogy analysis"}
        """
        // Note: phase enum raw values are lowercase "pedagogy" to match backend.
        
        let event3 = """
        data: {"type": "phase_progress", "pipeline_id": "pipeline_123", "timestamp": "2026-01-11T12:00:02Z", "progress": 50, "message": "Applying styles"}
        """
        
        // construct pipeline_completed with payload
        let event4 = """
        data: {"type": "pipeline_completed", "pipeline_id": "pipeline_123", "timestamp": "2026-01-11T12:00:05Z", "progress": 100, "message": "Done"}
        """
        
        let lines = [event1, event2, event3, event4]
        
        let stream = AsyncStream<String> { continuation in
            for line in lines {
                continuation.yield(line)
            }
            continuation.finish()
        }
        
        var receivedEvents: [A2AStreamingEvent] = []
        
        // Execute parsing
        try await service.parseStreamingEvents(stream) { event in
            receivedEvents.append(event)
        }
        
        // Assertions
        XCTAssertEqual(receivedEvents.count, 4, "Should receive 4 events")
        
        if receivedEvents.count >= 4 {
            XCTAssertEqual(receivedEvents[0].type.rawValue, "pipeline_started")
            XCTAssertEqual(receivedEvents[1].type.rawValue, "phase_started")
            XCTAssertEqual(receivedEvents[1].phase?.rawValue, "pedagogy")
            XCTAssertEqual(receivedEvents[3].type.rawValue, "pipeline_completed")
        }
        
        // Verify Service State Updates (ObservableObject)
        XCTAssertEqual(service.progress, 100)
        XCTAssertEqual(service.streamingEvents.count, 4)
        XCTAssertEqual(service.phases.count, 1) // Only one phase started (pedagogy)
        XCTAssertEqual(service.phases.first?.phase.rawValue, "pedagogy")
        XCTAssertEqual(service.phases.first?.status, .running)
    }

    @MainActor
    func testNewA2AEventTypes() async throws {
        let service = A2ACourseService.shared
        service.streamingEvents = []

        // Test Thinking Event
        let thinkingEvent = """
        data: {"type": "thinking", "pipeline_id": "p1", "timestamp": "2026-01-11T12:00:00Z", "progress": 10, "thinking_content": "Analyzing user request...", "message": "Thinking"}
        """
        
        // Test Content Chunk Event
        let chunkEvent = """
        data: {"type": "content_chunk", "pipeline_id": "p1", "timestamp": "2026-01-11T12:00:01Z", "progress": 20, "chunk_content": "Here is the first part...", "message": "Streaming"}
        """
        
        // Test Artifact Created Event
        let artifactEvent = """
        data: {"type": "artifact_created", "pipeline_id": "p1", "timestamp": "2026-01-11T12:00:02Z", "progress": 30, "message": "Artifact ready", "artifact": {"id": "a1", "type": "course_module", "name": "Mod 1", "created_by": "pedagogy_agent"}}
        """
        
        let stream = AsyncStream<String> { continuation in
            continuation.yield(thinkingEvent)
            continuation.yield(chunkEvent)
            continuation.yield(artifactEvent)
            continuation.finish()
        }
        
        // Execute parsing
        try await service.parseStreamingEvents(stream) { _ in }
        
        let events = service.streamingEvents
        XCTAssertEqual(events.count, 3)
        
        XCTAssertEqual(events[0].type, .thinking)
        XCTAssertEqual(events[0].thinkingContent, "Analyzing user request...")
        
        XCTAssertEqual(events[1].type, .contentChunk)
        XCTAssertEqual(events[1].chunkContent, "Here is the first part...")
        
        XCTAssertEqual(events[2].type, .artifactCreated)
        XCTAssertEqual(events[2].artifact?.name, "Mod 1")
    }
}
