o, AI Chat to Classroom - Visual Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                              │
│                        USER TYPES IN CHAT                                    │
│                   "Create a course on Python"                                │
│                                                                              │
└──────────────────────────────────┬──────────────────────────────────────────┘
                                   │
                                   │ User taps send
                                   ▼
                    ┌──────────────────────────────┐
                    │   LyoAIViewModel.swift       │
                    │   func sendMessage()         │
                    │   • Creates user message     │
                    │   • Adds to chat history     │
                    │   • Calls LioChatService     │
                    └──────────────┬───────────────┘
                                   │
                                   │ HTTP POST
                                   ▼
                    ┌──────────────────────────────┐
                    │   Backend AI Service         │
                    │   /api/v1/chat               │
                    │   • Detects course intent    │
                    │   • Generates OPEN_CLASSROOM │
                    │   • Returns JSON response    │
                    └──────────────┬───────────────┘
                                   │
                                   │ Returns JSON
                                   ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                       BACKEND RESPONSE JSON                                  │
│  {                                                                           │
│    "type": "OPEN_CLASSROOM",                                                │
│    "payload": {                                                              │
│      "stack_item": {                                                         │
│        "category": "Course",                                                 │
│        "title": "Introduction to Python",                                    │
│        "subtitle": "Master Python fundamentals",                             │
│        "status": "active"                                                    │
│      },                                                                      │
│      "course": {                                                             │
│        "title": "Introduction to Python",                                    │
│        "topic": "Python Programming",                                        │
│        "level": "beginner",                                                  │
│        "objectives": [...]                                                   │
│      }                                                                       │
│    }                                                                         │
│  }                                                                           │
└──────────────────────────────────┬──────────────────────────────────────────┘
                                   │
                                   │ Response received
                                   ▼
                    ┌──────────────────────────────┐
                    │   LyoAIViewModel.swift       │
                    │   • Receives response.text   │
                    │   • Calls AICommandHandler   │
                    │     processResponse()        │
                    └──────────────┬───────────────┘
                                   │
                                   │ Parse command
                                   ▼
                    ┌──────────────────────────────┐
                    │   AICommandHandler.swift     │
                    │   func processResponse()     │
                    │   • Calls AICommandParser    │
                    │   • Extracts JSON from text  │
                    └──────────────┬───────────────┘
                                   │
                                   │ Parse JSON
                                   ▼
                    ┌──────────────────────────────┐
                    │   AICommandParser            │
                    │   (in AICommandResponse.swift)│
                    │   • Validates JSON           │
                    │   • Decodes to struct        │
                    │   • Returns .command()       │
                    └──────────────┬───────────────┘
                                   │
                                   │ Command detected
                                   ▼
                    ┌──────────────────────────────┐
                    │   AICommandHandler.swift     │
                    │   func handleCommand()       │
                    │   • case .openClassroom:     │
                    │   • Sets published props:    │
                    │     - pendingClassroomCourse │
                    │     - shouldOpenClassroom    │
                    └──────────────┬───────────────┘
                                   │
                                   │ @Published triggers
                                   ▼
        ┌──────────────────────────────────────────────┐
        │         LioChatSheet.swift                    │
        │  .onChange(of: commandHandler.                │
        │            shouldOpenClassroom)               │
        │  • Observes change                            │
        │  • Sets showingClassroom = true               │
        │  • Calls clearPendingNavigation()             │
        └──────────────┬───────────────────────────────┘
                       │
                       │ State change
                       ▼
        ┌──────────────────────────────────────────────┐
        │         LioChatSheet.swift                    │
        │  .fullScreenCover(isPresented:                │
        │                   $showingClassroom)          │
        │  • Presents modal                             │
        │  • Passes course data from                    │
        │    pendingClassroomCourse                     │
        └──────────────┬───────────────────────────────┘
                       │
                       │ Modal presents
                       ▼
        ┌──────────────────────────────────────────────┐
        │  CourseGenerationIntermediateView.swift      │
        │  • Shows loading animation                    │
        │  • Displays Lio avatar                        │
        │  • Shows progress bar                         │
        │  • Previews objectives                        │
        │  • Calls CourseGenerationService              │
        └──────────────┬───────────────────────────────┘
                       │
                       │ Generate course
                       ▼
        ┌──────────────────────────────────────────────┐
        │  CourseGenerationService.shared               │
        │  func generateCourse()                        │
        │  • Calls backend course generator             │
        │  • Parses course structure                    │
        │  • Creates modules and lessons                │
        │  • Returns GeneratedCourseResponse            │
        └──────────────┬───────────────────────────────┘
                       │
                       │ Course ready
                       ▼
        ┌──────────────────────────────────────────────┐
        │  AIGeneratedClassroomView.swift               │
        │  • Displays course title                      │
        │  • Shows module navigation                    │
        │  • Renders lesson content                     │
        │  • Handles lesson progression                 │
        │  • onDismiss: closes modal                    │
        └──────────────────────────────────────────────┘



═══════════════════════════════════════════════════════════════════════════════
                            KEY COMPONENTS
═══════════════════════════════════════════════════════════════════════════════

┌─────────────────────────────────────────────────────────────────────────────┐
│ 1. LyoAIViewModel.swift                                                      │
│    Role: Main chat view model                                                │
│    Changes: Added AI command detection in sendMessage()                      │
│    Key Code:                                                                 │
│      let (displayText, wasCommand) =                                         │
│          AICommandHandler.shared.processResponse(response.text)              │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│ 2. AICommandHandler.swift                                                    │
│    Role: Parses AI commands and triggers navigation                          │
│    Changes: Fixed to use AICommandParser instead of AIResponseParser         │
│    Key Properties:                                                           │
│      @Published var pendingClassroomCourse: CoursePayload?                   │
│      @Published var shouldOpenClassroom: Bool                                │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│ 3. AICommandParser (in AICommandResponse.swift)                              │
│    Role: Extracts and validates JSON commands from AI text                   │
│    Methods:                                                                  │
│      static func parse(_ responseText: String) -> ParsedResponse             │
│    Returns: .command(AICommandResponse) or .chat(String)                     │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│ 4. LioChatSheet.swift                                                        │
│    Role: Main chat UI, observes command handler                              │
│    Navigation:                                                               │
│      .onChange(of: commandHandler.shouldOpenClassroom)                       │
│      .fullScreenCover(isPresented: $showingClassroom)                        │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│ 5. CourseGenerationIntermediateView.swift                                    │
│    Role: Loading screen during course generation                             │
│    Features: Progress animation, objectives preview, error handling          │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│ 6. AIGeneratedClassroomView.swift                                            │
│    Role: Displays generated course content                                   │
│    Features: Module/lesson navigation, content display, progress tracking    │
└─────────────────────────────────────────────────────────────────────────────┘



═══════════════════════════════════════════════════════════════════════════════
                            DATA FLOW
═══════════════════════════════════════════════════════════════════════════════

┌────────────┐
│ User Input │ → "Create a course on Python"
└────────────┘
      ↓
┌────────────┐
│  Backend   │ → Detects course intent
└────────────┘
      ↓
┌────────────┐
│   JSON     │ → { "type": "OPEN_CLASSROOM", "payload": {...} }
└────────────┘
      ↓
┌────────────┐
│   Parser   │ → Extracts and validates JSON
└────────────┘
      ↓
┌────────────┐
│  Handler   │ → Sets @Published properties
└────────────┘
      ↓
┌────────────┐
│    UI      │ → Observes changes, triggers navigation
└────────────┘
      ↓
┌────────────┐
│ Generator  │ → Creates full course structure
└────────────┘
      ↓
┌────────────┐
│ Classroom  │ → Displays course to user
└────────────┘



═══════════════════════════════════════════════════════════════════════════════
                            TESTING POINTS
═══════════════════════════════════════════════════════════════════════════════

☑ Test 1: Parser Detection
   Input: Backend returns OPEN_CLASSROOM JSON
   Check: Console shows "🎯 Parsed AI command: OPEN_CLASSROOM"
   
☑ Test 2: Handler State
   Input: Parser returns .command()
   Check: commandHandler.shouldOpenClassroom becomes true
   
☑ Test 3: UI Observer
   Input: shouldOpenClassroom changes to true
   Check: showingClassroom state updates
   
☑ Test 4: Modal Presentation
   Input: showingClassroom = true
   Check: CourseGenerationIntermediateView appears
   
☑ Test 5: Course Generation
   Input: CourseGenerationService.generateCourse() called
   Check: Backend generates course structure
   
☑ Test 6: Classroom Display
   Input: Course generated successfully
   Check: AIGeneratedClassroomView shows content



═══════════════════════════════════════════════════════════════════════════════
                            CONSOLE LOGS TO MONITOR
═══════════════════════════════════════════════════════════════════════════════

✅ "🎯 LioChatService Intent: courseCreation"
   → Intent classifier detected course creation request

✅ "🎯 Parsed AI command: OPEN_CLASSROOM"
   → AICommandParser successfully extracted JSON command

✅ "🎓 Opening AI Classroom for: [Topic]"
   → AICommandHandler triggered navigation

✅ "✅ Added to Stack: [Title]"
   → Stack item created successfully

✅ "🎓 Generating course: [Topic] at [level] level"
   → Course generation started

✅ "✅ Course generated: [Title]"
   → Course generation completed



═══════════════════════════════════════════════════════════════════════════════
                         IMPLEMENTATION STATUS
═══════════════════════════════════════════════════════════════════════════════

✅ COMPLETE: Response detection in LyoAIViewModel
✅ COMPLETE: Command parsing in AICommandHandler
✅ COMPLETE: Parser fix (AICommandParser usage)
✅ COMPLETE: Navigation observer in LioChatSheet
✅ COMPLETE: Modal presentation setup
✅ COMPLETE: Course generation view
✅ COMPLETE: Classroom display view
✅ COMPLETE: Documentation and test guide

🔄 PENDING: Backend testing
🔄 PENDING: End-to-end flow verification
🔄 PENDING: Error handling validation
🔄 PENDING: Stack integration testing

```
