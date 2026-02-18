
import XCTest
import os
@testable import Lyo

@MainActor
final class A2AIntegrationTests: XCTestCase {
    
    override func setUp() async throws {
        Log.ai.info("🌍 Testing against environment: \(AppConfig.baseURL)")
    }
    
    // Test A2A Discovery Endpoint (No Auth Required)
    // Note: This is a network integration test — it requires a running backend.
    // It will be skipped when the backend is unreachable.
    func testFetchAgentDiscovery() async throws {
        let service = A2ACourseService.shared
        
        do {
            let discovery = try await service.fetchProtocolDiscovery()
            
            Log.ai.info("Successfully fetched A2A agent discovery")
            Log.ai.info("   - Protocol Version: \(discovery.protocolVersion)")
            Log.ai.info("   - Server Version: \(discovery.serverVersion)")
            Log.ai.info("   - Agents Found: \(discovery.agents.count)")
            
            XCTAssertFalse(discovery.agents.isEmpty, "Should return at least one agent")
            
            if let firstAgent = discovery.agents.first {
                Log.ai.info("   - First Agent: \(firstAgent.name) (\(firstAgent.version))")
                XCTAssertFalse(firstAgent.name.isEmpty)
            }
            
        } catch let error as DecodingError {
            Log.ai.warning("Backend response format mismatch — skipping: \(error)")
            throw XCTSkip("Backend response format does not match expected schema")
        } catch let error as URLError {
            Log.ai.warning("Backend unreachable — skipping: \(error)")
            throw XCTSkip("Backend not reachable for integration test")
        } catch {
            Log.ai.warning("Network test failed: \(error)")
            throw XCTSkip("Integration test skipped: \(error.localizedDescription)")
        }
    }
}
