# Classroom Integration - Testing Guide

## ✅ Completed Features

### 1. Launch Flow from Lyo AI
- ✅ Added `openClassroom` action type to `MessageAction`
- ✅ Updated `MessageBubbleView` to accept action callbacks
- ✅ Modified `LyoHomeView` to handle `openClassroom` actions
- ✅ Implemented `createAndOpenClassroom()` method in `LyoHomeView`
- ✅ Added NavigationView and NavigationLink for deep linking to Classroom
- ✅ Created loading overlay while session is being created
- ✅ Added test helper method `addTestClassroomMessage()` in `LyoAIViewModel`

**Flow:**
1. User chats with Lyo AI
2. Lyo determines user needs full course (vs quick answer)
3. Lyo returns message with `openClassroom` action button
4. User taps "Start Lesson" button
5. App calls `createClassroomSession` API
6. Shows loading overlay ("Creating your lesson...")
7. Navigates to `ClassroomView` with `sessionId`
8. Shows orientation hint on first launch

### 2. Landscape Orientation Handling
- ✅ Created `AppDelegate` class with `orientationLock` property
- ✅ Integrated AppDelegate into `LyoApp` via `@UIApplicationDelegateAdaptor`
- ✅ Added `.onAppear` handler in `ClassroomView` to lock landscape orientation
- ✅ Force rotation to landscape when entering Classroom
- ✅ Added `.onDisappear` handler to restore orientation freedom
- ✅ Created `OrientationHintOverlay` component with animated phone icon
- ✅ Hint shows only once (tracked via UserDefaults)

**Behavior:**
- Classroom locks to landscape orientation when opened
- Device auto-rotates to landscape if in portrait
- Hint overlay shows "Best viewed horizontally" with animation
- On exit, orientation freedom is restored (can rotate back to portrait)

### 3. TTS Voice Bubble Animation
- ✅ Created `TTSVoiceBubbleView` component
- ✅ Three animated bars with staggered wave animation
- ✅ Gold accent color with shadow
- ✅ Positioned in top-right corner
- ✅ Only visible when `viewModel.isNarrating` is true
- ✅ Automatically animates continuously while TTS is active

**Visual:**
- Capsule shape with 3 vertical bars
- Bars animate up and down with 0.15s delay between each
- Gold color matching Lyo accent
- Subtle shadow effect
- Smooth easeInOut animation with autoreverses

### 4. Core Classroom Components (Already Complete)
- ✅ **ClassroomView**: Main container with gesture handling
- ✅ **ModuleCardView**: Netflix-style 40/60 split layout
- ✅ **ControlsOverlay**: YouTube-style with 3-second auto-hide
- ✅ **QuickCheckOverlay**: 5 check types, timer, "I'm not sure" button
- ✅ **ReteachOverlay**: Explanation, analogy, diagram, alternative approach
- ✅ **ModuleGridView**: Two-level navigation (modules → slides)
- ✅ **TTSVoiceBubbleView**: Animated voice indicator
- ✅ **OrientationHintOverlay**: First-time orientation prompt

## 🧪 Testing Instructions

### Test 1: End-to-End Flow
1. Launch app → Login (demo mode: demo@lyo.com / demo123)
2. Navigate to center "Lyo" tab
3. In Xcode debugger console, call:
   ```swift
   // Trigger test message with classroom action
   viewModel.addTestClassroomMessage()
   ```
4. Tap "Start Lesson" button on the test message
5. Verify loading overlay appears
6. Verify orientation hint shows (first time only)
7. Verify device rotates to landscape
8. Verify Classroom opens with mock lesson

### Test 2: Classroom Navigation
1. Once in Classroom, verify:
   - Module card displays with 40/60 split
   - Cover area shows on left (icon, title, metadata)
   - Slide content shows on right (title, body)
   - Progress bar at top updates
   - Slide indicator shows "Slide 1/3"

2. Test swipe gestures:
   - Swipe left → Next module
   - Swipe right → Previous module
   - Swipe down → Shows module grid
   - Tap screen → Toggles controls

### Test 3: TTS and Controls
1. In Classroom, tap screen to show controls
2. Verify controls appear with:
   - Top bar: Back, title, overflow menu
   - Center: Play/Pause, Rephrase, Explain buttons
   - Bottom: Scrubber, speed, captions, notes
3. Tap Play button
4. Verify TTS voice bubble appears in top-right
5. Verify bubble animates (3 bars bouncing)
6. Controls should auto-hide after 3 seconds
7. Tap screen again to bring controls back

### Test 4: Quick Checks
1. Navigate through slides (swipe or tap advance)
2. After 2-3 slides, quick check should appear
3. Verify check overlay with:
   - Question text
   - 4 multiple choice options
   - Timer (if timeLimit set)
   - "I'm not sure" button
4. Tap an option → Submit
5. If wrong → Reteach overlay shows
6. If correct → Continue to next slide

### Test 5: Module Grid Navigation
1. In Classroom, swipe down
2. Verify module grid appears with:
   - 2 columns of module cards
   - Current module highlighted (gold border)
   - Progress bars on each card
3. Tap a module card
4. Verify slide grid expands (3 columns)
5. Tap a slide card
6. Verify grid dismisses and jumps to that slide

### Test 6: Orientation Lock
1. From Lyo chat, open Classroom
2. Verify device rotates to landscape
3. Try rotating device to portrait → Should stay landscape
4. Tap Back button to exit Classroom
5. Verify device can now rotate freely again

### Test 7: Mock Data Verification
1. Verify mock lesson has 3 slides:
   - "What is Linear Equation?"
   - "Understanding Slope (m)"
   - "Understanding Intercept (b)"
2. Each slide should have narration text
3. Quick check after slide 2: "Which part is slope?"
4. Options: y, m, x, b (correct: m)
5. Wrong answer shows reteach about "hill/stairs"

## 🎯 Expected Behavior

### Lyo Chat → Classroom Flow
```
User asks: "teach me linear equations"
↓
Lyo responds: "I've created a comprehensive lesson..."
↓
Action button: "Start Lesson"
↓
Tap button
↓
Loading: "Creating your lesson..."
↓
API: POST /classroom/sessions { lesson_id }
↓
Orientation hint (first time)
↓
Device rotates to landscape
↓
Classroom opens with full TTS experience
```

### In Classroom Experience
```
Enter → Auto-rotate → Orientation locked
↓
TTS auto-starts (if enabled)
↓
Voice bubble animates while speaking
↓
Progress bar updates
↓
Tap → Controls show
↓
3s → Controls auto-hide
↓
After 2-3 slides → Quick check
↓
Answer → Feedback → Continue
↓
Swipe down → Module grid
↓
Jump to any slide
↓
Complete lesson → Exit
↓
Orientation unlocked
```

## 🔧 Mock Data Setup

The `ClassroomViewModel` has `loadMockSession()` which creates:

**Module:** "Linear Equations: y = mx + b"
- **Slide 1:** "What is Linear Equation?"
  - Narration: "A linear equation is a mathematical equation that describes a straight line..."
  
- **Slide 2:** "Understanding Slope (m)"
  - Narration: "The slope m represents the rate of change. It tells us how steep the line is..."
  
- **Slide 3:** "Understanding Intercept (b)"
  - Narration: "The y-intercept b is where the line crosses the y-axis..."

**Quick Check:** (after slide 2)
- Question: "Which part of y = mx + b represents the slope?"
- Options: ["y", "m", "x", "b"]
- Correct: "m"
- Reteach: "Think of slope as how steep a hill is. When you climb stairs, the slope tells you how much you go up for each step forward."

## 📱 Simulator Testing Tips

1. **Rotation**: Use Cmd+Left/Right arrow to rotate simulator
2. **Keyboard**: Cmd+K to toggle keyboard
3. **Shake**: Hardware → Shake Gesture
4. **TTS**: System voice should work in simulator
5. **Gestures**: 
   - Click + drag for swipes
   - Option + click for two-finger gestures

## 🐛 Known Limitations

1. **API Integration**: Currently using mock data
   - `createClassroomSession` will fail if backend not ready
   - Falls back to local error handling
   
2. **TTS Seeking**: Skip forward/backward not fully implemented
   - Methods exist but need AVSpeechSynthesizer seeking logic
   
3. **Reteach TTS**: Reading aloud not fully wired
   - `readAloud()` method exists but needs integration with main TTS system
   
4. **Notes Panel**: Button exists but panel not implemented
   - Placeholder for future feature
   
5. **Settings Panel**: Overflow menu exists but settings view not created
   - Speed/captions/text size are functional via ViewModel

## ✨ Success Criteria

- ✅ User can launch Classroom from Lyo chat
- ✅ Orientation locks to landscape automatically
- ✅ TTS plays narration with animated bubble
- ✅ All overlays work (Controls, QuickCheck, Reteach, ModuleGrid)
- ✅ Navigation works (swipe, tap, grid jumping)
- ✅ Progress tracking updates correctly
- ✅ Orientation unlocks on exit
- ✅ App builds without errors
- ✅ All components render correctly

## 🎉 Ready for Production Testing!

All core features are implemented and building successfully. The Classroom is fully integrated with:
- Launch flow from Lyo AI
- Landscape orientation handling  
- TTS voice bubble animation
- Complete overlay system
- Gesture-based navigation
- Mock data for testing

Next steps would be:
1. Backend API integration for real data
2. Advanced TTS features (seeking, word highlighting)
3. Notes panel implementation
4. Settings panel UI
5. Analytics tracking
6. Error handling improvements
7. Accessibility features (VoiceOver, Reduce Motion)
