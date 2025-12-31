# 🎯 Implementation Priorities for Lyo iOS

Based on the deep-dive analysis, here's what needs to be implemented **immediately** to make the AI course pipeline fully functional:

---

## ✅ ALREADY IMPLEMENTED (From Previous Session)

### 1. Backend Progress Sync ✅
**Status:** COMPLETE - Already wired in code

**What Works:**
- `LiveClassroomViewModel` automatically syncs progress on every block advance
- Calls `repository.saveClassroomProgress()` to backend
- Marks lesson complete with `repository.markLessonComplete()` when reaching final block
- Awards XP through backend API
- `UIStackStore` syncs course progress to backend on every update

**Code Locations:**
- `Sources/ViewModels/LiveClassroomViewModel.swift` (lines 465-495)
- `Sources/Services/UIStackStore.swift` (lines 175-186)

**Backend APIs Wired:**
- ✅ `POST /learning/lesson-completions` (progress sync)
- ✅ `POST /learning/completions` (lesson completion + XP)
- ✅ `GET /learning/users/me/courses/{id}/progress` (cross-device sync)

---

## 🚨 CRITICAL GAPS TO FIX (Week 1-2 Priority)

### 2. Course Sharing Feature ❌
**Status:** COMPLETELY MISSING

**What's Missing:**
- No `CourseShareService` exists
- No share button in UI
- No deep linking for "lyoapp://course/{id}"
- No achievement sharing ("I completed X course!")
- No native iOS `UIActivityViewController` integration

**Required Implementation:**
1. **Create `CourseShareService.swift`:**
   ```swift
   @MainActor
   final class CourseShareService {
       static let shared = CourseShareService()
       
       func shareCourse(courseId: String, title: String, description: String?) {
           // Build share text + deep link
           // Present UIActivityViewController
       }
       
       func shareCompletion(courseId: String, title: String, score: Int) {
           // Share "I completed {course} with {score}% score!"
       }
   }
   ```

2. **Add Share Button to FocusView Cards:**
   - Add overlay button with share icon
   - Trigger `CourseShareService.shared.shareCourse()`

3. **Register Deep Link URL Scheme:**
   - Add to `Info.plist`: `CFBundleURLSchemes` → `lyoapp`
   - Handle incoming deep links in `SceneDelegate` or `AppDelegate`

**Priority:** 🔴 HIGH - Essential for viral growth and user acquisition

---

### 3. Course Rating & Liking ❌
**Status:** DISPLAYS FAKE DATA - NO FUNCTIONALITY

**What's Wrong:**
- `FocusView.swift` line 906: Shows likes/dislikes but they're **DISPLAY ONLY**
- No interactive buttons to like/unlike
- No star rating UI
- No way for users to actually rate courses
- Uses `CourseSocialService` but no UI hooked up

**Current Code (line 906):**
```swift
HStack(spacing: 4) {
    Image(systemName: "hand.thumbsup.fill")
        .foregroundColor(.green.opacity(0.8))
    Text("\(card.likes)")  // ❌ Display only, no button!
        .font(.subheadline.bold())
        .foregroundColor(.white)
}
```

**Required Implementation:**
1. **Add Interactive Like Button:**
   ```swift
   Button(action: {
       Task {
           try await socialService.toggleLike(courseId: card.courseId)
       }
   }) {
       HStack(spacing: 4) {
           Image(systemName: socialService.hasLiked(card.courseId) ? "heart.fill" : "heart")
               .foregroundColor(socialService.hasLiked(card.courseId) ? .red : .white)
           Text("\(socialService.getLikeCount(courseId: card.courseId))")
       }
   }
   ```

2. **Add Star Rating UI:**
   ```swift
   StarRatingView(rating: socialService.getUserRating(courseId: card.courseId) ?? 0) { newRating in
       Task {
           try await socialService.rateCourse(courseId: card.courseId, rating: newRating)
       }
   }
   ```

3. **Update Backend to Support:**
   - `POST /api/v1/courses/{id}/like`
   - `DELETE /api/v1/courses/{id}/like`
   - `POST /api/v1/courses/{id}/rating` with body `{rating: 1-5}`
   - `GET /api/v1/courses/{id}/social-stats` → `{likes: Int, rating: Double}`

**Priority:** 🔴 HIGH - Currently misleads users with fake non-interactive data

---

### 4. Course Discovery in Community Screen ❌
**Status:** WRONG CONTENT - Shows events instead of courses

**What's Wrong:**
- `CampusView` (Community screen) shows **educational events**
- No way to browse/discover shared courses
- No search for courses
- No "trending courses" section

**Current Implementation:**
```swift
// Sources/Views/Main/CampusView.swift
var body: some View {
    ScrollView {
        // ❌ Only shows EducationalEvent objects, not courses!
        ForEach(events) { event in
            EventCard(event: event)
        }
    }
}
```

**Required Implementation:**
1. **Add "Shared Courses" Tab:**
   ```swift
   enum CommunityTab {
       case courses    // NEW!
       case events
       case groups
   }
   ```

2. **Create `CourseDiscoveryView`:**
   - Grid of course cards with thumbnails
   - Search bar for courses
   - Filters: trending, newest, highest rated
   - "Created by community" vs "Created by Lyo AI"

3. **Backend API:**
   - `GET /api/v1/courses/discover?sort={trending|newest|highest_rated}&limit=20`

**Priority:** 🟡 MEDIUM - Important for community engagement

---

### 5. Course Storage & Retrieval ⚠️
**Status:** PARTIALLY BROKEN - Not fully persisted

**What's Wrong:**
- AI-generated courses saved to `UIStackStore` (UserDefaults only - no backend)
- Courses disappear if user reinstalls app
- No "My Courses" library view
- No way to resume an in-progress course from anywhere except Focus

**Required Implementation:**
1. **Persist Generated Courses to Backend:**
   ```swift
   // After CourseGenerationService completes
   let courseId = try await repository.saveCourse(
       title: course.title,
       description: course.description,
       modules: course.modules
   )
   ```

2. **Add Backend Endpoints:**
   - `POST /api/v1/courses` (save generated course)
   - `GET /api/v1/courses/mine` (fetch user's courses)
   - `GET /api/v1/courses/{id}` (fetch specific course)

3. **Create "My Courses" Screen:**
   - Accessible from Profile or Hub
   - Shows: In Progress, Completed, Saved
   - Tap to resume where left off

**Priority:** 🟡 MEDIUM - Data loss risk

---

## 📊 Implementation Timeline

### Week 1 (Critical Functionality)
- ✅ ~~Backend progress sync~~ (DONE)
- ❌ **Create CourseShareService + UI** (2-3 days)
- ❌ **Add Like/Rate buttons to cards** (2 days)
- ❌ **Backend APIs for social features** (2 days)

### Week 2 (Social Features)
- ❌ **Implement course liking** (1 day)
- ❌ **Implement star rating system** (1 day)
- ❌ **Add "Share Course" button** (1 day)
- ❌ **Deep link handler** (1 day)

### Week 3 (Discovery)
- ❌ **Refactor CampusView tabs** (2 days)
- ❌ **Create CourseDiscoveryView** (2 days)
- ❌ **Backend discovery API** (1 day)

### Week 4 (Storage & Library)
- ❌ **Persist courses to backend** (2 days)
- ❌ **Create "My Courses" screen** (2 days)
- ❌ **Add resume functionality** (1 day)

---

## 🔥 Quick Wins (Can Be Done Today)

### 1. Add Share Button to Cards
**File:** `Sources/Views/Main/FocusView.swift`
**Location:** Inside `frontSide` view (around line 780)

**Add This Code:**
```swift
// Share Button Overlay (top-right corner)
.overlay(alignment: .topTrailing) {
    Button(action: {
        CourseShareService.shared.shareCourse(
            courseId: card.courseId,
            title: card.title,
            description: card.description
        )
    }) {
        Image(systemName: "square.and.arrow.up")
            .font(.system(size: 18, weight: .semibold))
            .foregroundColor(.white)
            .padding(12)
            .background(.ultraThinMaterial)
            .clipShape(Circle())
    }
    .padding(16)
}
```

### 2. Make Like Count Interactive
**File:** `Sources/Views/Main/FocusView.swift`
**Location:** Back side of card (line 904-913)

**Replace Static Display With Button:**
```swift
Button(action: {
    Task {
        try? await socialService.toggleLike(courseId: card.courseId ?? card.id)
    }
}) {
    HStack(spacing: 4) {
        Image(systemName: socialService.hasLiked(card.courseId ?? card.id) ? "heart.fill" : "heart")
            .foregroundColor(socialService.hasLiked(card.courseId ?? card.id) ? .red : .green.opacity(0.8))
        Text("\(socialService.getLikeCount(courseId: card.courseId ?? card.id))")
            .font(.subheadline.bold())
            .foregroundColor(.white)
    }
}
```

### 3. Add Star Rating UI
**File:** `Sources/Views/Main/FocusView.swift`
**Location:** Next to likes/dislikes (line 920)

**Add Rating Stars:**
```swift
VStack(alignment: .leading, spacing: 4) {
    Text("RATE THIS COURSE")
        .font(.caption2.bold())
        .foregroundColor(.white.opacity(0.5))
        .tracking(1)
    
    HStack(spacing: 8) {
        ForEach(1...5, id: \.self) { star in
            Button(action: {
                Task {
                    try? await socialService.rateCourse(courseId: card.courseId ?? card.id, rating: star)
                }
            }) {
                Image(systemName: star <= (socialService.getUserRating(courseId: card.courseId ?? card.id) ?? 0) ? "star.fill" : "star")
                    .foregroundColor(.yellow)
            }
        }
    }
}
```

---

## 🎯 Next Steps

**Option A: Implement Quick Wins First**
- Add share button (30 min)
- Make like button interactive (30 min)
- Add star rating UI (1 hour)
- Test on simulator

**Option B: Build Full Infrastructure**
- Create `CourseShareService.swift` (2-3 hours)
- Add all backend APIs (4-6 hours)
- Comprehensive UI updates (4 hours)
- Testing + polish (2 hours)

**Recommendation:** Start with Option A quick wins to immediately improve UX, then move to Option B for full implementation.

---

## 📝 Notes

- **CourseSocialService** already exists but has no UI wired up
- **Backend progress sync** is already working - don't need to touch that
- Focus on **user-facing features** that provide immediate value
- **Deep linking** is important for viral growth but can wait until Week 2

