import XCTest
import os
@testable import Lyo

final class IntegrationTests: XCTestCase {
    
    let repository = LyoRepository.shared
    
    override func setUp() async throws {
        // Ensure we are using the correct base URL (already set in AppConfig)
        Log.general.info("Testing against: \(AppConfig.baseURL)")
    }
    
    func testDiscoverCourses() async throws {
        do {
            let courses = try await repository.getDiscoverCourses()
            Log.general.info("Fetched \(courses.count) courses")
            XCTAssertFalse(courses.isEmpty, "Should return courses (or at least not fail)")
        } catch {
            Log.general.error("Failed to fetch courses: \(error)")
            // If it's 401, it means we connected but need auth. That's "working" connectivity.
            // But public endpoints should work.
            throw error
        }
    }
    
    func testDiscoverEvents() async throws {
        do {
            let events = try await repository.getDiscoverEvents()
            Log.general.info("Fetched \(events.count) events")
        } catch {
            Log.general.error("Failed to fetch events: \(error)")
            throw error
        }
    }
    
    func testCampusBeacons() async throws {
        do {
            // Use a default location (e.g., San Francisco)
            let beacons = try await repository.getBeacons(latitude: 37.7749, longitude: -122.4194)
            Log.general.info("Fetched \(beacons.count) beacons")
        } catch {
            Log.general.error("Failed to fetch beacons: \(error)")
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
            Log.general.error("Correctly failed (expected 401/Auth error): \(error)")
        }
    }
}
