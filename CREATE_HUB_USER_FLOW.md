# Create Hub User Flow

## Visual Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         Main App                                │
│  ┌──────────┬──────────┬──────────┬──────────┬──────────┐      │
│  │  Focus   │  Clips   │    +     │Community │ Profile  │      │
│  └──────────┴──────────┴────┬─────┴──────────┴──────────┘      │
│                              │                                   │
│                         Tap + Button                             │
└──────────────────────────────┬──────────────────────────────────┘
                               │
                               ↓
┌─────────────────────────────────────────────────────────────────┐
│                     CreateHubView Opens                          │
│                    (Full Screen Cover)                           │
│                                                                  │
│  ╔════════════════════════════════════════════════════════╗     │
│  ║ [X]                    Reel                       [⚡][🔄]║     │
│  ║                                                        ║     │
│  ║                                                        ║     │
│  ║              CAMERA PREVIEW                            ║     │
│  ║                  or                                    ║     │
│  ║            GRADIENT CANVAS                             ║     │
│  ║                                                        ║     │
│  ║                                                        ║     │
│  ║                    [⭕ CAPTURE]                         ║     │
│  ║                                                        ║     │
│  ║                                                        ║     │
│  ║ ┌────────────────────────────────────────────────┐    ║     │
│  ║ │  MODE PICKER (Horizontal Scroll)               │    ║     │
│  ║ │  ●Reel  ○Story  ○Post  ○Course  ○Event        │    ║     │
│  ║ └────────────────────────────────────────────────┘    ║     │
│  ║              [Retake]  [Next →]                        ║     │
│  ╚════════════════════════════════════════════════════════╝     │
└─────────────────────────────────────────────────────────────────┘
```

## Mode Flow Details

### 1️⃣ REEL MODE (Video for Discover)
```
User Flow:
1. Camera preview active
2. Tap capture button to start recording
3. Hold to continue (shows duration timer)
4. Release or tap to stop
5. Preview captured video
6. Tap "Next" → MediaEditorView
7. Add caption
8. Add Learn Layers (optional)
9. Tap "Publish"
10. Video uploads → Posts to feed → Added to Stack

Learn Layers Example:
┌──────────────────────┐
│     Video Frame      │
│                      │
│  [📘 Definition]     │  ← Positioned sticker
│  "Variable: A        │
│   storage location"  │
│                      │
│        [⚡ Fact]      │  ← Another layer
│  "Python is 30+      │
│   years old!"        │
└──────────────────────┘
```

### 2️⃣ STORY MODE (24-Hour Ephemeral)
```
User Flow:
1. Camera preview active
2. Tap capture → Instant photo
3. Preview captured image
4. Tap "Next" → MediaEditorView
5. Add caption
6. Add Learn Layers (optional)
7. Tap "Publish"
8. Image uploads → Story created (24h expiry) → Added to Stack

Difference from Reel:
- Single photo vs video
- 24-hour expiry
- Faster capture (instant, no hold)
```

### 3️⃣ POST MODE (Feed Post)
```
User Flow:
1. Gradient canvas background (no camera)
2. Automatically shows PostComposeView
3. Type text content
4. Tap "Attach Files" (optional)
5. Select images/videos/documents
6. Tap "Publish"
7. Content uploads → Post created → Added to Stack

UI:
┌──────────────────────┐
│   [Type here...]     │
│                      │
│   Multi-line text    │
│   editor with auto   │
│   resize             │
│                      │
├──────────────────────┤
│  [📎 Attach Files]   │
├──────────────────────┤
│  Attached:           │
│  • image.jpg         │
│  • document.pdf      │
└──────────────────────┘
```

### 4️⃣ COURSE MODE (AI-Generated)
```
User Flow:
1. Gradient canvas background (green theme)
2. Automatically shows CourseGenerationView
3. Enter topic: "Python Programming"
4. Select level: [Beginner] [Intermediate] [Advanced]
5. (Optional) Add learning outcomes
6. Tap "Publish"
7. AI generates course (streaming progress)
8. Course saved to library → Added to Stack

Behind the Scenes:
- Calls CourseGenerationService
- Streams generation progress
- Uses backend Gemini AI
- Creates modules + lessons
- Generates interactive content

Progress UI:
┌──────────────────────┐
│ Generating Course... │
│ ████████░░░░░░  60%  │
│ Creating Module 2... │
└──────────────────────┘
```

### 5️⃣ EVENT/GROUP MODE (Community)
```
User Flow:
1. Gradient canvas background (pink theme)
2. Toggle: [Event] or [Group]
3. Fill form:
   - Title
   - Description
   - Date (if event)
   - Location (optional)
4. Tap "Publish"
5. Event/Group created → Added to Stack

Event vs Group:
┌──────────────────┬──────────────────┐
│      EVENT       │      GROUP       │
├──────────────────┼──────────────────┤
│ Has specific     │ Ongoing          │
│ date/time        │ No end date      │
│                  │                  │
│ Study session    │ Study buddy      │
│ Workshop         │ Discussion forum │
│ Exam prep party  │ Learning circle  │
└──────────────────┴──────────────────┘
```

## Mode Switching Animation

```
Current Mode: Reel (Purple)
User swipes right on mode picker →

┌──────────────────────────────────┐
│  ●Reel    ○Story                 │  Before
└──────────────────────────────────┘
         ↓ (Animated transition)
┌──────────────────────────────────┐
│  ○Reel    ●Story                 │  After
└──────────────────────────────────┘

Visual Changes:
- Reel icon: Purple → Gray, scales down
- Story icon: Gray → Orange, scales up
- Indicator line slides right
- Background transitions to orange gradient
- Camera mode stays active (both use camera)
```

## Capture States

```
State Machine:
┌──────┐   tap   ┌───────────┐   stop   ┌──────────┐
│ idle ├────────→│ recording ├─────────→│ captured │
└──────┘         └───────────┘          └────┬─────┘
   ↑                                         │
   │              retake                     │
   └─────────────────────────────────────────┘
```

## Backend Integration Points

```
┌────────────────┐
│  User Action   │
└───────┬────────┘
        │
        ↓
┌────────────────┐    1. Validate
│ CreateViewModel│───────────────→ [Check permissions]
└───────┬────────┘                 [Check content]
        │
        │ 2. Prepare
        ↓
┌────────────────┐
│ Convert media  │───→ [Compress image/video]
│ Build payload  │     [Create request body]
└───────┬────────┘
        │
        │ 3. Upload
        ↓
┌────────────────┐
│ NetworkClient  │───→ POST /api/v1/files/upload
└───────┬────────┘     └─→ Returns: { id, url }
        │
        │ 4. Publish
        ↓
┌────────────────┐
│ Create Post/   │───→ POST /api/v1/posts
│ Course/Event   │     (with attachment IDs)
└───────┬────────┘
        │
        │ 5. Stack
        ↓
┌────────────────┐
│ Add to Stack   │───→ POST /stack/items
└───────┬────────┘     └─→ Creates card in "Today"
        │
        ↓
    Success! 🎉
```

## Error Handling Flow

```
Any Step Fails
     │
     ↓
┌────────────────┐
│ State = .error │
│ Show alert     │
└───────┬────────┘
        │
        ↓
User taps "Retry"
     │
     ↓
Resume from last successful step
(e.g., if upload succeeded but post failed,
       retry only post creation)
```

## Learn Layers Deep Dive

```
Sticker Types:

📘 DEFINITION (Blue)
   "Variable: A storage location for data"

🔢 FORMULA (Purple)
   "E = mc²"

💡 FACT (Yellow)
   "Python was created in 1991"

❓ QUESTION (Orange)
   "What is polymorphism?"

🧠 QUIZ (Green)
   [Interactive quiz overlay]

Positioning:
- Drag to move
- Pinch to resize (future)
- Tap to edit text
- Long press to delete

Saved as:
{
  "id": "uuid",
  "type": "definition",
  "position": { "x": 0.3, "y": 0.5 }, // Relative 0-1
  "content": "Variable: A storage..."
}
```

## Key Interactions

```
✋ Gestures:
- Tap:        Capture photo / Start recording
- Hold:       Continue recording
- Swipe:      Switch modes (on mode picker)
- Drag:       Position Learn Layer
- Pinch:      Zoom camera (future)

⌨️ Keyboard:
- Appears for: Caption, Post text, Course topic
- Auto-hides:  When tapping outside
- Smart resize: Content scrolls above keyboard

🎯 Buttons:
- X (top-left):     Dismiss CreateHub
- Flash (top-right): Toggle camera flash
- Flip (top-right):  Switch front/back camera
- Capture (center):  Photo/Video capture
- Retake (bottom):   Reset to idle state
- Next (bottom):     Open detail editor
- Publish (sheet):   Submit to backend
```

## Performance Considerations

```
Optimization Points:

1. Camera Preview
   - Only initialize when mode.requiresCamera
   - Release session on dismiss
   - Use lower resolution for preview

2. Video Processing
   - Compress before upload (0.8 quality)
   - Max file size validation
   - Background upload queue

3. Image Handling
   - Resize to max dimensions
   - JPEG compression
   - Memory-efficient loading

4. UI Responsiveness
   - Async/await for all I/O
   - Progress indicators
   - Haptic feedback
   - Cancel support

5. State Management
   - Reset state on mode switch
   - Clean up temp files
   - Memory warnings handling
```

## Accessibility

```
VoiceOver Support:
- "Create Hub. Reel mode selected."
- "Capture button. Double tap to start recording."
- "Mode picker. Swipe to change mode."
- "Story mode. Capture photo for 24 hours."

Dynamic Type:
- All text scales with system settings
- Minimum tap targets: 44x44 pt
- High contrast mode support

Reduced Motion:
- Disable spring animations
- Use crossfade instead of slide
- Instant mode transitions
```

---

**Next:** Test on simulator and refine based on UX feedback!
