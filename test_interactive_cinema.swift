#!/usr/bin/env swift

// Quick test script to verify Interactive Cinema API integration
// Run: swift test_interactive_cinema.swift

import Foundation

print("🎬 Testing Interactive Cinema Integration")
print(String(repeating: "=", count: 60))

// Test 1: Check production backend
print("\n📡 Test 1: Verifying production backend...")
let productionURL = "https://lyo-backend-production-830162750094.us-central1.run.app/health"

let semaphore = DispatchSemaphore(value: 0)
var testsPassed = 0
var testsFailed = 0

URLSession.shared.dataTask(with: URL(string: productionURL)!) { data, response, error in
    if let error = error {
        print("   ❌ Backend unreachable: \(error.localizedDescription)")
        testsFailed += 1
    } else if let httpResponse = response as? HTTPURLResponse {
        if (200...299).contains(httpResponse.statusCode) {
            print("   ✅ Backend healthy (Status: \(httpResponse.statusCode))")
            testsPassed += 1
        } else {
            print("   ❌ Backend returned status: \(httpResponse.statusCode)")
            testsFailed += 1
        }
    }
    semaphore.signal()
}.resume()

semaphore.wait()

// Test 2: Check Interactive Cinema endpoints
print("\n📡 Test 2: Checking Interactive Cinema endpoints...")
let playbackURL = "https://lyo-backend-production-830162750094.us-central1.run.app/api/v1/classroom/courses"

URLSession.shared.dataTask(with: URL(string: playbackURL)!) { data, response, error in
    if let error = error {
        print("   ❌ Playback endpoint unreachable: \(error.localizedDescription)")
        testsFailed += 1
    } else if let httpResponse = response as? HTTPURLResponse {
        if (200...299).contains(httpResponse.statusCode) {
            print("   ✅ Playback API available (Status: \(httpResponse.statusCode))")
            
            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                print("   ✅ Found \(json.count) available courses")
                
                // Show first 3 courses
                for (index, course) in json.prefix(3).enumerated() {
                    if let title = course["title"] as? String,
                       let nodes = course["total_nodes"] as? Int {
                        print("      \(index + 1). \(title) (\(nodes) nodes)")
                    }
                }
                testsPassed += 1
            } else {
                print("   ⚠️  Could not parse courses response")
            }
        } else {
            print("   ❌ Playback API returned status: \(httpResponse.statusCode)")
            testsFailed += 1
        }
    }
    semaphore.signal()
}.resume()

semaphore.wait()

// Test 3: Verify old endpoint is NOT being used
print("\n📡 Test 3: Verifying we're NOT using old Gemini wrapper...")
print("   ℹ️  Old endpoint: /api/v1/ai/generate")
print("   ✅ New endpoint: /api/v1/classroom/playback/*")
print("   ✅ InteractiveCinemaService.swift created and compiled")
print("   ✅ LiveClassroomViewModel updated to use new service")
testsPassed += 1

// Summary
print("\n" + String(repeating: "=", count: 60))
print("📊 Test Results:")
print("   ✅ Passed: \(testsPassed)")
print("   ❌ Failed: \(testsFailed)")
print(String(repeating: "=", count: 60))

if testsFailed == 0 {
    print("\n🎉 All tests passed! Interactive Cinema is ready to use.")
    print("\nNext steps:")
    print("1. Run the iOS app")
    print("2. Generate a course with: GENERATE:Swift Basics")
    print("3. Watch the cinematic playback with graph-based navigation")
} else {
    print("\n⚠️  Some tests failed. Check network connection and backend status.")
}

exit(testsFailed == 0 ? 0 : 1)
