import XCTest
@testable import Lyo

final class IntegrationTests: XCTestCase {
    
    let repository = LyoRepository.shared
    
    override func setUp() async throws {
        // Ensure we are using the correct base URL (already set in AppConfig)
        print("Testing against: \(AppConfig.baseURL)")
    }
    
    func testDiscoverCourses() async throws {
        do {
            let courses = try await repository.getDiscoverCourses()
            print("✅ Fetched \(courses.count) courses")
            XCTAssertFalse(courses.isEmpty, "Should return courses (or at least not fail)")
        } catch {
            print("❌ Failed to fetch courses: \(error)")
            // If it's 401, it means we connected but need auth. That's "working" connectivity.
            // But public endpoints should work.
            throw error
        }
    }
    
    func testDiscoverEvents() async throws {
        do {
            let events = try await repository.getDiscoverEvents()
            print("✅ Fetched \(events.count) events")
        } catch {
            print("❌ Failed to fetch events: \(error)")
            throw error
        }
    }
    
    func testCampusBeacons() async throws {
        do {
            // Use a default location (e.g., San Francisco)
            let beacons = try await repository.getBeacons(latitude: 37.7749, longitude: -122.4194)
            print("✅ Fetched \(beacons.count) beacons")
        } catch {
            print("❌ Failed to fetch beacons: \(error)")
            throw error
        }
    }
    
    // Stack requires auth, so we expect 401 or need to login first.
    // Since we don't have credentials, we'll skip or expect error.
    func testStackItems_Unauthenticated() async {
        do {
            _ = try await repository.getStackItems()
            XCTFail("Should fail without auth")
        } catch {
            print("✅ Correctly failed (expected 401/Auth error): \(error)")
        }
    }
}
