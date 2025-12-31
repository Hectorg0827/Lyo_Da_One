# Lyo App - Complete Testing Guide

## 🎯 Overview

This guide covers testing all newly implemented features:
- **Course Sharing** (Week 2)
- **Social Features** (Week 3): Likes, Ratings, Stats
- **Course Discovery** (Week 4): My Courses Library
- **Deep Linking** (lyoapp:// URL scheme)

---

## 📱 Pre-Testing Setup

### 1. Backend Requirements

Ensure your backend has these endpoints:

```bash
# Social APIs
POST   /api/v1/courses/{id}/like
DELETE /api/v1/courses/{id}/like
POST   /api/v1/courses/{id}/rating
GET    /api/v1/courses/{id}/social-stats
POST   /api/v1/courses/bulk-social-stats

# Course APIs (already existing)
GET    /api/v1/chat/courses
GET    /api/v1/classroom/courses
```

### 2. Build the App

```bash
cd /Users/hectorgarcia/LYO_Da_ONE

# Option 1: Using VS Code task
# Run task: "Build+Install Lyo (Simulator, Workspace DD)"

# Option 2: Command line
xcodebuild -project Lyo.xcodeproj \
  -scheme Lyo \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  build
```

### 3. Launch Simulator

```bash
# Boot simulator
xcrun simctl boot "iPhone 15 Pro"

# Install app
APP=$(find build/lyo_sim_dd/Build/Products -name 'Lyo.app' | head -1)
xcrun simctl install booted "$APP"

# Launch app
xcrun simctl launch booted com.lyo.app
```

---

## ✅ Test Suite 1: Course Sharing

### Test 1.1: Share Button Visibility
**Location:** FocusView (main Clips feed)

**Steps:**
1. Launch app
2. Navigate to FocusView (Clips tab)
3. Locate share button (top-right of course card)

**Expected:**
- ✅ Share button visible with share icon
- ✅ Button positioned in top-right corner
- ✅ Button accessible (VoiceOver: "Share course")

### Test 1.2: iOS Share Sheet
**Location:** FocusView

**Steps:**
1. Tap share button on any course
2. Observe iOS share sheet

**Expected:**
- ✅ Share sheet appears from bottom
- ✅ Options include: Messages, Mail, Copy, etc.
- ✅ Course title appears in share preview
- ✅ Deep link format: `lyoapp://course/{courseId}`

### Test 1.3: Deep Link Format
**Location:** Share content

**Steps:**
1. Share course via "Copy Link"
2. Paste into Notes app
3. Verify URL format

**Expected:**
- ✅ URL: `lyoapp://course/{courseId}`
- ✅ courseId matches actual course ID
- ✅ No extra parameters or encoding issues

### Test 1.4: Deep Link Handler
**Location:** App-wide

**Steps:**
```bash
# From terminal, open deep link:
xcrun simctl openurl booted "lyoapp://course/test123"
```

**Expected:**
- ✅ App opens (if closed)
- ✅ App comes to foreground (if backgrounded)
- ✅ Navigates to course detail (TODO: implement navigation)
- ✅ Console shows: "🔗 Deep link opened: course/test123"

**Note:** Deep link navigation is pending implementation. Current behavior: app opens, logs URL, but doesn't navigate yet.

---

## ✅ Test Suite 2: Social Features - Likes

### Test 2.1: Like Button Visibility
**Location:** FocusView (back of card after flip)

**Steps:**
1. Navigate to FocusView
2. Flip card (swipe or tap)
3. Locate like button (heart icon)

**Expected:**
- ✅ Heart icon visible
- ✅ Like count displayed below heart
- ✅ Button state: empty heart (not liked) or filled heart (liked)

### Test 2.2: Like Course (Optimistic Update)
**Location:** FocusView

**Steps:**
1. Tap heart button on unliked course
2. Observe UI update

**Expected:**
- ✅ **Instant**: Heart fills with red color
- ✅ **Instant**: Like count increments (+1)
- ✅ **Background**: Backend API called (check console)
- ✅ Console: "✅ Liked course: {courseId} (total: X)"

### Test 2.3: Unlike Course (Rollback on Error)
**Location:** FocusView

**Steps:**
1. Disconnect from internet (Airplane mode)
2. Tap heart on liked course
3. Wait 5 seconds

**Expected:**
- ✅ **Instant**: Heart empties (gray)
- ✅ **Instant**: Like count decrements (-1)
- ✅ **After network fails**: Heart refills (rollback)
- ✅ **After network fails**: Count returns to original
- ✅ Console: Error message about network failure

### Test 2.4: Like Persistence
**Location:** App-wide

**Steps:**
1. Like a course
2. Kill app (swipe up in app switcher)
3. Relaunch app
4. Navigate to same course

**Expected:**
- ✅ Heart still filled
- ✅ Like count same as before
- ✅ UserDefaults cache loaded on launch

### Test 2.5: Backend Sync Verification
**Location:** Backend logs

**Steps:**
1. Like a course
2. Check backend logs

**Expected Backend Request:**
```http
POST /api/v1/courses/abc123/like
Headers:
  Authorization: Bearer {token}
  X-API-Key: {api_key}
  X-Tenant-Id: {tenant_id}
  Content-Type: application/json

Response (200 OK):
{
  "total_likes": 42,
  "user_has_liked": true
}
```

**Expected Client Console:**
```
📤 POST /api/v1/courses/abc123/like
✅ Liked course: abc123 (total: 42)
```

---

## ✅ Test Suite 3: Social Features - Ratings

### Test 3.1: Star Rating Visibility
**Location:** FocusView (back of card)

**Steps:**
1. Flip card to back
2. Locate star rating component (below like button)

**Expected:**
- ✅ 5 stars displayed horizontally
- ✅ Current rating shown (yellow filled stars)
- ✅ Average rating displayed (e.g., "4.2 (15)")

### Test 3.2: Rate Course
**Location:** FocusView

**Steps:**
1. Tap on 4th star (to rate 4/5)
2. Observe update

**Expected:**
- ✅ **Instant**: Stars 1-4 fill yellow
- ✅ **Instant**: Star 5 remains empty
- ✅ **Background**: Backend API called
- ✅ Console: "✅ Rated course {courseId}: 4 stars (avg: X.X)"

### Test 3.3: Update Rating
**Location:** FocusView

**Steps:**
1. Rate course 3 stars
2. Wait for backend sync
3. Rate same course 5 stars

**Expected:**
- ✅ Previous rating (3) replaced with new (5)
- ✅ Backend receives new rating
- ✅ Average recalculated on backend
- ✅ No duplicate ratings stored

### Test 3.4: Rating Persistence
**Location:** App-wide

**Steps:**
1. Rate a course 5 stars
2. Kill and relaunch app
3. Navigate to same course

**Expected:**
- ✅ Your rating still shows 5 stars
- ✅ Average rating updated (if others rated)
- ✅ UserDefaults cache preserved

### Test 3.5: Backend Rating Sync
**Location:** Backend logs

**Expected Request:**
```http
POST /api/v1/courses/abc123/rating
Headers: [same as likes]
Body:
{
  "rating": 4
}

Response (200 OK):
{
  "average_rating": 4.3,
  "total_ratings": 16,
  "user_rating": 4
}
```

**Expected Console:**
```
📤 POST /api/v1/courses/abc123/rating {"rating": 4}
✅ Rated course abc123: 4 stars (avg: 4.3)
```

---

## ✅ Test Suite 4: Social Stats Fetching

### Test 4.1: Single Course Stats
**Location:** CourseSocialService

**Steps:**
```swift
// In Xcode console or test:
Task {
    try await CourseSocialService.shared.fetchCourseSocialStats(courseId: "test123")
}
```

**Expected:**
- ✅ GET request to `/api/v1/courses/test123/social-stats`
- ✅ Response cached in CourseSocialService
- ✅ UI updates with new stats

**Expected Response:**
```json
{
  "likes": 42,
  "rating": 4.5,
  "rating_count": 18,
  "user_has_liked": true,
  "user_rating": 5
}
```

### Test 4.2: Bulk Stats Fetching
**Location:** Course list views

**Steps:**
1. Navigate to My Courses screen
2. Observe initial load

**Expected:**
- ✅ Single POST request to `/api/v1/courses/bulk-social-stats`
- ✅ Request body: `{"course_ids": ["id1", "id2", ...]}`
- ✅ All course stats updated simultaneously
- ✅ No individual requests per course

**Expected Response:**
```json
{
  "course1": {
    "likes": 10,
    "rating": 4.0,
    "rating_count": 5,
    "user_has_liked": false,
    "user_rating": null
  },
  "course2": { ... }
}
```

---

## ✅ Test Suite 5: Course Discovery

### Test 5.1: My Courses Screen Navigation
**Location:** Main navigation

**Steps:**
1. Launch app
2. Navigate to "My Courses" tab (if added to MainTabView)
3. Or access via menu/discovery flow

**Expected:**
- ✅ MyCoursesView loads
- ✅ Tab selector shows: In Progress | Saved | Completed | Trending
- ✅ Search bar visible at top
- ✅ Filter button in toolbar

### Test 5.2: Course List Loading
**Location:** MyCoursesView

**Steps:**
1. Open My Courses screen
2. Observe initial load

**Expected:**
- ✅ Loading spinner appears
- ✅ "Loading courses..." text
- ✅ After 1-3 seconds: courses appear
- ✅ Console: "✅ Fetched X courses"

### Test 5.3: Tab Switching
**Location:** MyCoursesView

**Steps:**
1. Tap "In Progress" tab
2. Tap "Saved" tab
3. Tap "Completed" tab
4. Tap "Trending" tab

**Expected:**
- ✅ Each tab shows correct courses
- ✅ Tab counts update (e.g., "In Progress (3)")
- ✅ Grid layout adapts to content
- ✅ No duplicate courses across tabs

### Test 5.4: Search Functionality
**Location:** MyCoursesView search bar

**Steps:**
1. Type "Python" in search bar
2. Wait for results

**Expected:**
- ✅ Search debounced (waits for typing to stop)
- ✅ Backend query: `/api/v1/chat/courses?topic=Python`
- ✅ Results filtered to Python-related courses
- ✅ Clear button (X) appears
- ✅ Tap X clears search and restores all courses

### Test 5.5: Course Card Interaction
**Location:** MyCoursesView grid

**Steps:**
1. Tap on any course card
2. Observe course detail sheet

**Expected:**
- ✅ Sheet slides up from bottom
- ✅ Hero image displayed
- ✅ Course title, duration, level shown
- ✅ Description expandable ("Show More")
- ✅ Tags displayed in flow layout
- ✅ Social buttons: Like, Rate, Share
- ✅ "Start Course" button at bottom

### Test 5.6: Filters
**Location:** MyCoursesView filter sheet

**Steps:**
1. Tap filter button (toolbar)
2. Select "Intermediate" level
3. Toggle "AI" tag
4. Tap "Done"

**Expected:**
- ✅ Filter sheet appears
- ✅ Level picker shows all levels
- ✅ Tag toggles update
- ✅ After "Done": courses filtered
- ✅ Only Intermediate + AI tagged courses shown

### Test 5.7: Trending Algorithm
**Location:** Trending tab

**Steps:**
1. Navigate to Trending tab
2. Observe course order

**Expected:**
- ✅ Courses sorted by popularity score
- ✅ Score = likes + (rating * 10)
- ✅ Most popular courses first
- ✅ Maximum 10 courses shown

### Test 5.8: Save Course
**Location:** Course detail view

**Steps:**
1. Open course detail
2. Tap "Save" button (if added)
3. Navigate to "Saved" tab

**Expected:**
- ✅ Course appears in Saved tab
- ✅ Backend stack item created
- ✅ Save persists across app restarts

---

## ✅ Test Suite 6: Error Handling

### Test 6.1: Network Timeout
**Location:** Any backend call

**Steps:**
1. Enable network link conditioner (slow network)
2. Try to like a course
3. Wait 60+ seconds

**Expected:**
- ✅ Optimistic update shows immediately
- ✅ After timeout: rollback occurs
- ✅ User sees error toast/alert
- ✅ Console: Network timeout error

### Test 6.2: 401 Unauthorized
**Location:** Any authenticated endpoint

**Steps:**
1. Manually delete auth token (Keychain)
2. Try to like a course

**Expected:**
- ✅ Request fails with 401
- ✅ App prompts to re-login
- ✅ No crash or infinite retry loop

### Test 6.3: 429 Rate Limited
**Location:** Rapid actions

**Steps:**
1. Rapidly tap like button 20 times
2. Observe behavior

**Expected:**
- ✅ Backend returns 429 after N requests
- ✅ App shows "Too many requests" message
- ✅ Retry-After header respected
- ✅ No crashes or data corruption

### Test 6.4: Invalid Course ID
**Location:** Deep link or direct navigation

**Steps:**
```bash
xcrun simctl openurl booted "lyoapp://course/invalid_id_999"
```

**Expected:**
- ✅ App opens
- ✅ Attempts to load course
- ✅ Shows "Course not found" error
- ✅ User can navigate back gracefully

---

## 📊 Performance Testing

### Test P.1: Cold Start Time
**Steps:**
1. Kill app completely
2. Launch app
3. Measure time to interactive

**Expected:**
- ✅ < 3 seconds to show login/main screen
- ✅ No ANR (Application Not Responding)

### Test P.2: Scroll Performance
**Location:** MyCoursesView grid

**Steps:**
1. Load 50+ courses
2. Scroll rapidly up and down

**Expected:**
- ✅ 60 FPS maintained
- ✅ No jank or stuttering
- ✅ LazyVGrid loads cells on-demand

### Test P.3: Memory Usage
**Location:** Xcode Instruments

**Steps:**
1. Profile app with Instruments
2. Navigate through all screens
3. Monitor memory graph

**Expected:**
- ✅ No memory leaks
- ✅ < 200 MB RAM usage
- ✅ No retain cycles in published properties

---

## 🔐 Security Testing

### Test S.1: API Key Storage
**Location:** Keychain

**Steps:**
1. Check Keychain for API keys
2. Verify encryption

**Expected:**
- ✅ API key stored in Keychain (not UserDefaults)
- ✅ kSecAttrAccessibleAfterFirstUnlock used
- ✅ No keys in plain text in code

### Test S.2: Token Refresh
**Location:** NetworkClient

**Steps:**
1. Use expired access token
2. Make API request

**Expected:**
- ✅ 401 detected
- ✅ Token refresh endpoint called
- ✅ New token stored
- ✅ Original request retried
- ✅ User not logged out

---

## 📝 Automated Testing

### Unit Tests (XCTest)

```swift
// Tests/CourseSocialServiceTests.swift

import XCTest
@testable import Lyo

class CourseSocialServiceTests: XCTestCase {
    
    var service: CourseSocialService!
    
    override func setUp() {
        service = CourseSocialService()
    }
    
    func testLikeCourse() async throws {
        // Given
        let courseId = "test123"
        XCTAssertFalse(service.hasLiked(courseId: courseId))
        
        // When
        try await service.likeCourse(courseId: courseId)
        
        // Then
        XCTAssertTrue(service.hasLiked(courseId: courseId))
        XCTAssertEqual(service.getLikeCount(for: courseId), 1)
    }
    
    func testRateCourse() async throws {
        // Given
        let courseId = "test123"
        
        // When
        try await service.rateCourse(courseId: courseId, rating: 5)
        
        // Then
        XCTAssertEqual(service.getUserRating(for: courseId), 5)
    }
    
    func testOptimisticUpdateRollback() async throws {
        // Given: Mock network failure
        // When: Like course with network error
        // Then: Like should rollback
        // TODO: Implement with mock NetworkClient
    }
}
```

### UI Tests (XCUITest)

```swift
// UITests/SocialFeaturesUITests.swift

import XCTest

class SocialFeaturesUITests: XCTestCase {
    
    let app = XCUIApplication()
    
    override func setUp() {
        app.launch()
    }
    
    func testLikeButton() {
        // Navigate to FocusView
        app.tabBars.buttons["Clips"].tap()
        
        // Find like button
        let likeButton = app.buttons["like_button"]
        XCTAssertTrue(likeButton.exists)
        
        // Tap like
        likeButton.tap()
        
        // Verify filled heart
        XCTAssertTrue(likeButton.images["heart.fill"].exists)
    }
    
    func testShareSheet() {
        app.tabBars.buttons["Clips"].tap()
        app.buttons["share_button"].tap()
        
        // Verify share sheet
        XCTAssertTrue(app.otherElements["ActivityListView"].exists)
    }
}
```

---

## 🐛 Known Issues / TODO

### High Priority
- [ ] Deep link navigation not implemented (app opens but doesn't navigate to course)
- [ ] SceneDelegate URL handler needs completion
- [ ] Bulk stats fetching optimization (currently may make individual requests)

### Medium Priority
- [ ] Rate limiting not implemented (rapid taps send multiple requests)
- [ ] Offline queue for failed API calls
- [ ] Analytics tracking for social events

### Low Priority
- [ ] Animation polish for like/rating interactions
- [ ] Haptic feedback on social actions
- [ ] Skeleton loaders for course grid

---

## 📞 Support

### Backend Issues
- Check backend health: `curl https://your-backend.app/health`
- Verify endpoints exist: `curl https://your-backend.app/docs`
- Check logs in Google Cloud Console

### Client Issues
- Check Xcode console for errors
- Enable network logging: `UserDefaults.standard.set(true, forKey: "NetworkLogging")`
- Clear UserDefaults cache: `UserDefaults.standard.removePersistentDomain(forName: "com.lyo.app")`

### Debugging Commands

```bash
# View device logs
xcrun simctl spawn booted log stream --predicate 'processImagePath contains "Lyo"'

# Reset simulator
xcrun simctl erase all

# List all simulators
xcrun simctl list devices

# Open simulator data directory
open ~/Library/Developer/CoreSimulator/Devices/
```

---

## ✅ Test Completion Checklist

### Week 2: Sharing
- [ ] Share button visible
- [ ] iOS share sheet appears
- [ ] Deep link format correct
- [ ] Deep link opens app

### Week 3: Social
- [ ] Like button works
- [ ] Unlike button works
- [ ] Rating stars interactive
- [ ] Stats sync with backend
- [ ] Optimistic updates instant
- [ ] Rollback on error
- [ ] Persistence across restarts

### Week 4: Discovery
- [ ] My Courses screen loads
- [ ] Tab switching works
- [ ] Search filters courses
- [ ] Filters apply correctly
- [ ] Course cards clickable
- [ ] Course detail shows
- [ ] Trending algorithm works
- [ ] Save/unsave courses

### General
- [ ] No crashes
- [ ] No memory leaks
- [ ] 60 FPS maintained
- [ ] Network errors handled
- [ ] Auth tokens refresh
- [ ] All console logs clean (no errors)

---

**Last Updated:** December 29, 2025
**Test Coverage:** Weeks 2, 3, 4 (Sharing, Social, Discovery)
**Status:** ✅ All features implemented, ready for testing
