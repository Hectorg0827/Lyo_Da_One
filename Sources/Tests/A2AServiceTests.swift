
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
}
