
import XCTest
@testable import Lyo

@MainActor
final class A2AIntegrationTests: XCTestCase {
    
    override func setUp() async throws {
        print("🌍 Testing against environment: \(AppConfig.baseURL)")
    }
    
    // Test A2A Discovery Endpoint (No Auth Required)
    func testFetchAgentDiscovery() async throws {
        let service = A2ACourseService.shared
        
        do {
            let discovery = try await service.fetchProtocolDiscovery()
            
            print("✅ Successfully fetched A2A agent discovery")
            print("   - Protocol Version: \(discovery.protocolVersion)")
            print("   - Server Version: \(discovery.serverVersion)")
            print("   - Agents Found: \(discovery.agents.count)")
            
            XCTAssertFalse(discovery.agents.isEmpty, "Should return at least one agent")
            
            if let firstAgent = discovery.agents.first {
                print("   - First Agent: \(firstAgent.name) (\(firstAgent.version))")
                XCTAssertFalse(firstAgent.name.isEmpty)
            }
            
        } catch {
            print("❌ Failed to fetch agent discovery: \(error)")
            throw error
        }
    }
}
