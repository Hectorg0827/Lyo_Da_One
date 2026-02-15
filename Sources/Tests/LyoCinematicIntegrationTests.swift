import XCTest
import os
@testable import Lyo

final class LyoCinematicIntegrationTests: XCTestCase {

    // The exact JSON payload returned by the Backend Smoke Test
    let backendPayload = """
    {
      "id": "4dad7879-8e63-4e30-8295-f6acab67dc82",
      "type": "concept",
      "role": "hook",
      "presentation_hint": "cinematic",
      "content": {
        "kind": "cinematic",
        "title": "Chasing Echoes: The Chrononaut's Gambit",
        "subtitle": "What if the past isn't truly gone?",
        "mood": "epic",
        "videoUrl": null
      },
      "requires_interaction": false,
      "interaction_id": null,
      "mood": "neutral"
    }
    """

    func testCinematicDetailedParsing() throws {
        // 1. Decode the Raw JSON into LyoBlock (simulating Network Client)
        let data = backendPayload.data(using: .utf8)!
        let decoder = JSONDecoder()
        
        // Ensure snake_case decoding strategy matches backend
        decoder.keyDecodingStrategy = .convertFromSnakeCase 
        
        let block = try decoder.decode(LyoBlock.self, from: data)
        
        // 2. Verify Block Properties
        XCTAssertEqual(block.type, .concept)
        XCTAssertEqual(block.presentationHint, .cinematic)
        
        // 3. Run through LyoAdapter (The "Integration" step)
        let a2uiContent = LyoAdapter.render(block)
        
        // 4. Assert A2UI Content Type
        XCTAssertEqual(a2uiContent.type, A2UIContentType.cinematic, "Adapter should map hook/cinematic to .cinematic type")
        
        // 5. Assert Cinematic Data Model (What the View sees)
        XCTAssertNotNil(a2uiContent.cinematic, "Cinematic payload should not be nil")
        XCTAssertEqual(a2uiContent.cinematic?.title, "Chasing Echoes: The Chrononaut's Gambit")
        XCTAssertEqual(a2uiContent.cinematic?.subtitle, "What if the past isn't truly gone?")
        XCTAssertEqual(a2uiContent.cinematic?.mood, "epic")
        
        Log.general.info("Frontend Integration Verified: JSON -> LyoBlock -> LyoAdapter -> A2UIContent")
    }
}
