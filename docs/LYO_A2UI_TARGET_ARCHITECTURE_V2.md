# Lyo A2UI — Target Architecture v2

> **Status**: Proposal  
> **Authors**: Architecture Review  
> **Date**: June 2025  
> **Scope**: A2UI component model, response contract, producer role, migration path

---

## 1. Executive Summary

The current A2UI system has **150+ element types** across 17 categories, two incompatible response contracts (fast/deep), and a monolithic props bag with **180+ optional fields**. Most types route to `A2UIFallbackRenderer` because no one can keep up with the type explosion.

**Target state**: collapse to **22 composable primitives**, one unified response contract, semantic payloads, and a thin deterministic validation layer. The iOS client owns layout; the server sends *meaning*.

### Key Metrics

| Metric | Current | Target | Reduction |
|--------|---------|--------|-----------|
| Element types | 150+ | 22 | **85%** |
| Props fields | 180+ | ~40 common + scoped extras | **~70%** |
| Response contracts | 2 (fast + deep SSE) | 1 (works for both) | **50%** |
| Renderer switch cases | 120+ | 22 | **82%** |
| Backend type enum | 150+ raw values with snake_case bridge | 22 | **85%** |

---

## 2. Current State: What's Wrong

### 2.1 The Type Explosion

`A2UIElementType.swift` today — 150+ enum cases across 17 categories:

```
coreDisplay:     text, heading, paragraph, caption, label, markdown, richText, 
                 codeBlock, blockquote, callout, divider
media:           image, video, audio, lottieAnimation, icon, cameraPreview, 
                 audioPlayer, videoPlayer, waveform, model3D, gif, svgImage, 
                 imageCarousel, thumbnail
quiz:            quizMcq, quizTrueFalse, quizFillBlank, quizMatching, 
                 quizOrdering, quizOpenEnded, quizCodeChallenge, quizImageLabel, 
                 quizResult, quizProgress, quizFeedback, quizTimer, 
                 quizLeaderboard, quizBattle
studyPlan:       studyPlanOverview, studyPlanDay, studyPlanSession, 
                 studyPlanGoal, studyPlanProgress, studyPlanCalendar, ...
mistakeTracker:  mistakeCard, mistakePattern, mistakeHeatmap, mistakeTimeline, ...
homework:        homeworkCard, homeworkSubmission, homeworkRubric, ...
documents:       documentViewer, documentScanner, documentSummary, ...
course:          courseCard, courseModule, courseLesson, courseProgress, ...
layout:          vstack, hstack, zstack, grid, scrollView, card, section, 
                 accordion, carousel, tabContainer, ...
navigation:      breadcrumb, tabBar, pagination, toolbar, sidebarMenu, ...
widget:          progressBar, streakWidget, xpBar, levelIndicator, ...
gamification:    achievementBadge, energyMeter, questWidget, rewardChest, ...
aiAssistant:     chatBubble, thinkingIndicator, suggestionChip, insightCard, ...
social:          userProfile, studyGroup, comment, shareCard, ...
system:          toast, snackbar, banner, emptyState, loadingOverlay, ...
```

**Result**: The renderer is a 310-line switch statement where most cases hit `A2UIFallbackRenderer`:

```swift
// A2UIRenderer.swift — current state (simplified)
func renderContent() -> some View {
    switch component.type {
    case .text, .heading, .paragraph, .caption, .label:
        A2UITextRenderer(component: component)
    case .markdown, .richText:
        A2UIMarkdownRenderer(component: component)
    case .image:
        A2UIImageRenderer(component: component)
    case .button, .iconButton:
        A2UIButtonRenderer(component: component)
    case .quiz, .quizMcq:
        A2UIQuizRenderer(component: component)
    // ... 10 more cases with real renderers ...
    default:
        // 100+ types land here
        A2UIFallbackRenderer(component: component)
    }
}
```

### 2.2 The God Props Bag

`A2UIProps.swift` is **892 lines** with **180+ optional fields**. Every component receives the same bag, and each field is `nil` for 95% of components:

```swift
// Current — every component gets ALL of these
struct A2UIProps: Codable, Equatable {
    var text: String?
    var title: String?
    var subtitle: String?
    var body: String?
    var placeholder: String?
    var question: String?            // only for quiz
    var options: [A2UIQuizOption]?   // only for quiz
    var planId: String?              // only for study plan
    var mistakeType: String?         // only for mistake tracker
    var homeworkId: String?          // only for homework
    var documentUrl: String?         // only for documents
    var courseId: String?            // only for course
    var xp: Int?                     // only for gamification
    var streak: Int?                 // only for gamification
    var aiPersonality: String?       // only for AI assistant
    var username: String?            // only for social
    // ... 165 more fields ...
}
```

Every JSON payload carries the full CodingKeys table even when 95% of values are null. Every new feature adds more fields to this single struct.

### 2.3 Two Incompatible Response Contracts

**Fast path** (`/api/v1/chat`) returns:
```json
{
  "response": "Here's your explanation...",
  "type": "OPEN_CLASSROOM",
  "payload": { "course": { ... } },
  "ui_component": { "type": "vstack", "props": {...}, "children": [...] },
  "responseMode": "quick_explainer",
  "quickExplainer": { ... },
  "courseProposal": { ... },
  "lyoBlocks": [ ... ],
  "suggestions": [ ... ]
}
```

**Deep path** (`/api/v1/lyo2/chat/stream`) sends SSE events:
```
event: skeleton
data: {"blocks": ["TutorMessageBlock", "QuizBlock"]}

event: answer
data: {"type": "TutorMessageBlock", "title": "...", "content": {...}}

event: a2ui
data: {"type": "A2UIComponent", "content": {...}}

event: open_classroom
data: {"type": "OpenClassroomBlock", "content": {...}}

event: done
data: {}
```

**Problems**:
- iOS needs completely different parsing code for each path
- `BackendAIChatResponse` has 25+ fields, most nil per response
- `Lyo2StreamEvent` uses a separate `Lyo2UIBlockType` enum (8 cases) unrelated to `A2UIElementType` (150+ cases)
- Features built for one path often don't work on the other
- `OPEN_CLASSROOM` command is embedded in free text and parsed with regex (the "markdown trap")

### 2.4 The Rigid Producer

`a2ui_producer.py` (467 lines) is the **only** bridge between LLM output and A2UI. It has separate `produce_*` methods for each content type, each building hardcoded component trees:

```python
# Current — every content type has a bespoke method
class A2UIProducer:
    def produce_course(self, raw, topic="") -> Dict
    def produce_lesson(self, raw, index=0, total=1) -> A2UIComponent
    def produce_explanation(self, raw, topic="") -> A2UIComponent
    def produce_quiz(self, raw) -> A2UIComponent
    def produce_study_plan(self, raw, topic="") -> A2UIComponent
    def produce_skeleton(self, topic="") -> A2UIComponent
    def produce_error(self, message="") -> A2UIComponent
    def produce_auto(self, raw, ui_type="", topic="") -> A2UIComponent
```

Adding a new content type requires: (1) new normalized model, (2) new extractor, (3) new produce_* method, (4) new generator helper, (5) new A2UIElementType cases, (6) new iOS renderer, (7) new A2UIProps fields. **7 files across 2 repos.**

---

## 3. Target: 22 Composable Primitives

### 3.1 Design Principles

1. **Semantic over prescriptive** — send *what* the content is, not *how* to render it
2. **Variants over types** — `quiz(variant: "mcq")` not `quizMcq`, `quizTrueFalse`, `quizFillBlank`
3. **Scoped props** — each primitive defines only the props it uses
4. **Client-owned layout** — the backend says "here are 3 sections"; the client decides spacing, padding, colors
5. **Composable** — primitives can nest inside containers; no deep type hierarchies

### 3.2 The 22 Primitives

| # | Primitive | Replaces (current count) | Variants |
|---|-----------|--------------------------|----------|
| **Content** | | | |
| 1 | `text` | text, heading, paragraph, caption, label, markdown, richText, codeBlock, blockquote, callout (11) | `plain`, `heading`, `markdown`, `code`, `quote`, `callout` |
| 2 | `media` | image, video, audio, lottieAnimation, icon, gif, svgImage, model3D, waveform (9) | `image`, `video`, `audio`, `animation`, `icon` |
| 3 | `divider` | divider (1) | — |
| **Input** | | | |
| 4 | `input` | textInput, textArea, numberInput, slider, toggle, checkbox, radioGroup, dropdown, datePicker, colorPicker, ratingInput, voiceRecorder, cameraCapture, fileUpload, searchBar, tagInput, drawingCanvas, segmentedControl (18) | `text`, `number`, `slider`, `toggle`, `select`, `date`, `voice`, `camera`, `file`, `drawing` |
| 5 | `button` | button, iconButton, linkButton, fab, ctaButton (5) | `primary`, `secondary`, `link`, `icon`, `destructive` |
| **Layout** | | | |
| 6 | `container` | vstack, hstack, zstack, grid, scrollView, lazyStack, spacer, section, accordion, tabContainer, carousel (12) | `stack`, `grid`, `scroll`, `tabs`, `carousel`, `section`, `accordion` |
| 7 | `card` | card, expandableCard, swipeableCard, headerCard, statCard, featureCard (6) | `default`, `expandable`, `stat`, `feature` |
| 8 | `list` | listItem, checklist, timeline (3) | `item`, `checklist`, `timeline` |
| **Navigation** | | | |
| 9 | `nav` | breadcrumb, tabBar, pagination, toolbar, sidebarMenu, navigationBar, bottomBar, pageIndicator (8) | `breadcrumb`, `tabs`, `pagination`, `toolbar` |
| **Learning Domain** | | | |
| 10 | `quiz` | quizMcq, quizTrueFalse, quizFillBlank, quizMatching, quizOrdering, quizOpenEnded, quizCodeChallenge, quizImageLabel, quizResult, quizProgress, quizFeedback, quizTimer, quizLeaderboard, quizBattle (14) | `mcq`, `true_false`, `fill_blank`, `matching`, `ordering`, `code`, `open_ended` |
| 11 | `quiz_result` | quizResult, quizFeedback, quizProgress (3) | `score`, `feedback`, `progress` |
| 12 | `course` | courseCard, courseModule, courseLesson, courseProgress, courseCertificate, courseOverview, courseBanner, courseTimeline, courseSyllabus, courseEnrollment, courseRating, courseRecommendation (12) | `overview`, `module`, `lesson`, `progress`, `certificate` |
| 13 | `flashcard` | documentFlashcard, flashcardDeck (2+) | `single`, `deck`, `result` |
| 14 | `plan` | studyPlanOverview, studyPlanDay, studyPlanSession, studyPlanGoal, studyPlanProgress, studyPlanCalendar, studyPlanReminder, studyPlanStreak, studyPlanMilestone, studyPlanAdaptive, studyPlanReview, studyPlanCompletion, studyPlanResourceList (13) | `overview`, `session`, `goal`, `calendar`, `milestone` |
| 15 | `tracker` | mistakeCard, mistakePattern, mistakeHeatmap, mistakeTimeline, mistakeDetail, mistakeQuickFix, mistakePractice, mistakeInsight, mistakeComparison (9) | `card`, `pattern`, `heatmap`, `insight` |
| 16 | `assignment` | homeworkCard, homeworkSubmission, homeworkRubric, homeworkFeedback, homeworkCalendar, homeworkProgress, homeworkAttachment, homeworkGrade, homeworkPeerReview (9) | `card`, `submission`, `rubric`, `feedback` |
| 17 | `document` | documentViewer, documentScanner, documentSummary, documentAnnotation, documentSearch, documentOutline, documentHighlight, documentOCR, documentNote (9) | `viewer`, `summary`, `annotation` |
| **Engagement** | | | |
| 18 | `progress` | progressBar, streakWidget, xpBar, levelIndicator, achievementBadge, energyMeter, questWidget, dailyGoal, leaderboardRow, rewardChest, challengeCard, eventBanner, statCounter (13+) | `bar`, `xp`, `streak`, `level`, `achievement`, `leaderboard` |
| 19 | `ai_bubble` | chatBubble, thinkingIndicator, suggestionChip, aiMoodAvatar, explanationCard, contextPanel, sourceReference, feedbackCollector, personalityCard, tutorPrompt, insightCard, summaryPanel (12) | `message`, `thinking`, `suggestion`, `insight`, `source` |
| 20 | `social` | userProfile, studyGroup, comment, shareCard, activityFeed, reaction, mention, collaboratorList, inviteCard (9) | `profile`, `comment`, `feed`, `group` |
| **System** | | | |
| 21 | `alert` | toast, snackbar, banner, systemAlert, maintenanceNotice, updatePrompt, errorBoundary, emptyState, connectionStatus (9) | `toast`, `banner`, `error`, `empty`, `info` |
| 22 | `skeleton` | loadingOverlay, skeleton, debugOverlay, versionCheck (4) | `block`, `list`, `card`, `full` |

**Total: 22 primitives replacing 150+ types**

### 3.3 Variant + Props Model

Each primitive uses `variant` to select behavior and a **scoped** props object:

```swift
// Target — type-safe, scoped props
struct A2UIComponent: Codable, Identifiable {
    let id: String
    let type: A2UIPrimitive          // 22-case enum
    let variant: String?             // sub-type selector
    let content: ContentProps?       // text, title, subtitle, body
    let style: StyleProps?           // colors, spacing, radius (client can override)
    let data: [String: AnyCodable]?  // domain-specific payload (quiz options, course modules, etc.)
    let children: [A2UIComponent]?
    let actions: [A2UIAction]?
    let conditions: A2UIConditions?
    let meta: MetaProps?             // analytics, debug, version
}
```

**Props are split into 4 focused bags** instead of 1 God bag:

```swift
// Universally applicable
struct ContentProps: Codable {
    var text: String?
    var title: String?
    var subtitle: String?
    var body: String?            // markdown content
    var label: String?
    var placeholder: String?
    var hint: String?
    var icon: String?            // SF Symbol name
    var imageUrl: String?
    var mediaUrl: String?        // video/audio URL
}

// Client-side styling hints (client CAN ignore these)
struct StyleProps: Codable {
    var foreground: String?      // color
    var background: String?      // color
    var spacing: Double?
    var padding: EdgeInsets?
    var radius: Double?
    var axis: String?            // "h" or "v" for containers
    var columns: Int?            // for grid
    var fontSize: Double?
    var fontWeight: String?
    var alignment: String?
}

// Analytics / debug / versioning
struct MetaProps: Codable {
    var analyticsId: String?
    var debugLabel: String?
    var version: String?
    var tags: [String]?
    var speakableText: String?   // TTS override
}
```

**Domain data goes in `data: [String: AnyCodable]`** — a typed dictionary instead of 180 optional fields:

```json
// Quiz example — data carries quiz-specific fields
{
  "type": "quiz",
  "variant": "mcq",
  "content": {
    "title": "Quick Check",
    "text": "What is the time complexity of binary search?"
  },
  "data": {
    "options": [
      {"id": "a", "text": "O(n)", "is_correct": false},
      {"id": "b", "text": "O(log n)", "is_correct": true},
      {"id": "c", "text": "O(n²)", "is_correct": false}
    ],
    "max_attempts": 2,
    "show_feedback": true,
    "points": 10
  }
}
```

---

## 4. Unified Response Contract

### 4.1 One Shape, Two Speeds

Both fast and deep paths use the **same response envelope**. The difference is only delivery:
- **Fast**: returns the complete envelope in one HTTP response
- **Deep**: streams fragments of the same envelope via SSE

```typescript
// LyoResponse — the ONE contract
interface LyoResponse {
  // Metadata
  version: string;               // "2.0"
  request_id: string;
  
  // Content (always present)
  message: string;               // plain-text AI response (always renderable)
  
  // Structured UI (optional — only when AI decides to render rich UI)
  ui?: A2UIComponent;            // root component tree
  
  // Commands (optional — triggers native flows like classroom)
  command?: LyoCommand;
  
  // Context-aware suggestions
  suggestions?: Suggestion[];
  
  // Conversation state
  conversation_id?: string;
}

interface LyoCommand {
  action: string;                // "open_classroom" | "start_quiz" | "show_flashcards"
  payload: Record<string, any>;  // action-specific data
}

interface Suggestion {
  text: string;
  action_id?: string;
  icon?: string;
}
```

### 4.2 SSE Streaming Over the Same Shape

Deep path streams **fragments** that the client assembles into a `LyoResponse`:

```
event: start
data: {"version": "2.0", "request_id": "abc-123"}

event: message
data: {"delta": "Let me explain binary search"}

event: message
data: {"delta": " — it works by dividing the search space in half..."}

event: ui
data: {"type": "quiz", "variant": "mcq", "content": {"title": "Quick Check"}, ...}

event: command
data: {"action": "open_classroom", "payload": {"course_id": "xyz"}}

event: suggestions
data: [{"text": "Explain more"}, {"text": "Practice problems"}]

event: done
data: {}
```

**Key difference from current**: No more `Lyo2UIBlockType` enum (8 cases) separate from `A2UIElementType` (150 cases). The SSE `ui` event carries the **same** `A2UIComponent` tree that the fast path returns. One parser, one renderer.

### 4.3 Current vs Target: Side-by-Side

#### Fast path — current:
```json
{
  "response": "Binary search is an efficient algorithm...",
  "type": "OPEN_CLASSROOM",
  "payload": {
    "course": {
      "id": "abc",
      "title": "Algorithms 101",
      "topic": "Algorithms",
      "level": "Intermediate",
      "duration": "~45 min",
      "objectives": ["Understand divide-and-conquer", "Implement binary search"]
    }
  },
  "responseMode": "course_planner",
  "ui_component": {
    "type": "vstack",
    "props": {
      "spacing": 12,
      "padding": {"top": 20, "leading": 20, "bottom": 20, "trailing": 20}
    },
    "children": [
      {
        "type": "text",
        "props": {
          "text": "Binary search is an efficient algorithm...",
          "font_size": 16,
          "foreground_color": "#FFFFFF",
          "line_height": 1.5
        }
      },
      {
        "type": "course_card",
        "props": {
          "title": "Algorithms 101",
          "subtitle": "Intermediate · ~45 min",
          "completion_percentage": 0.0,
          "course_id": "abc",
          "objectives": ["Understand divide-and-conquer", "Implement binary search"],
          "icon_name": "book.fill"
        }
      }
    ]
  },
  "suggestions": [{"text": "Start course"}, {"text": "See outline"}]
}
```

**Problems**: `type` + `payload` is a parallel signaling mechanism. `ui_component` uses `course_card` (a type that falls to `A2UIFallbackRenderer`). `responseMode` duplicates the routing signal. Response has 25+ top-level fields.

#### Fast path — target:
```json
{
  "version": "2.0",
  "request_id": "req-abc-123",
  "message": "Binary search is an efficient algorithm...",
  "ui": {
    "type": "course",
    "variant": "overview",
    "content": {
      "title": "Algorithms 101",
      "subtitle": "Intermediate · ~45 min"
    },
    "data": {
      "course_id": "abc",
      "level": "Intermediate",
      "duration_minutes": 45,
      "objectives": ["Understand divide-and-conquer", "Implement binary search"]
    },
    "actions": [
      {"trigger": "tap", "type": "navigate", "payload": {"route": "classroom", "course_id": "abc"}}
    ]
  },
  "command": {
    "action": "open_classroom",
    "payload": {"course_id": "abc", "title": "Algorithms 101"}
  },
  "suggestions": [
    {"text": "Start learning", "action_id": "start_course"},
    {"text": "See full outline", "action_id": "view_outline"}
  ]
}
```

**Improvements**: One `ui` field with a renderable component. `command` is explicit (no regex parsing). `message` is always plain text. 8 top-level fields max.

---

## 5. Producer Evolution: Validator/Normalizer/Compiler

The deterministic producer **stays** but its role narrows:

### 5.1 Current Role (too broad)
```
LLM output → extract_course() → NormalizedCourse → _render_course_card() → A2UIComponent tree
```
The producer does extraction, normalization, AND layout/rendering. It decides spacing, colors, which children to include, button text.

### 5.2 Target Role (thin layer)
```
LLM structured output → validate(schema) → normalize(defaults) → LyoResponse
```

```python
# Target — a2ui_compiler.py (replaces a2ui_producer.py)
class A2UICompiler:
    """
    Validates, normalizes, and compiles LLM structured output into LyoResponse.
    
    Does NOT:
    - Decide layout (client's job)
    - Choose colors or spacing (client's job)
    - Build component trees (the LLM provides semantic structure)
    
    DOES:
    - Validate all required fields exist
    - Apply safe defaults for missing optional fields
    - Enforce schema version compatibility
    - Strip unsafe content (XSS, injection)
    - Apply feature flags (gate unreleased primitives)
    - Log/metric production quality
    """
    
    def compile(self, llm_output: dict, schema_version: str = "2.0") -> LyoResponse:
        # 1. Validate against schema
        validated = self._validate(llm_output, schema_version)
        
        # 2. Normalize (defaults, type coercion)
        normalized = self._normalize(validated)
        
        # 3. Safety check (strip dangerous content)
        safe = self._sanitize(normalized)
        
        # 4. Feature flag gate
        gated = self._apply_feature_flags(safe)
        
        return LyoResponse(**gated)
    
    def _validate(self, data: dict, version: str) -> dict:
        """Ensure required fields exist, types are correct."""
        if "message" not in data:
            data["message"] = "I'm working on that..."
        if "ui" in data:
            data["ui"] = self._validate_component(data["ui"])
        return data
    
    def _validate_component(self, comp: dict) -> dict:
        """Recursively validate a component and its children."""
        primitive = comp.get("type", "text")
        if primitive not in VALID_PRIMITIVES:
            comp["type"] = "text"  # safe fallback
            comp["variant"] = "plain"
        # Validate variant is legal for this primitive
        valid_variants = PRIMITIVE_VARIANTS.get(primitive, [])
        if comp.get("variant") and comp["variant"] not in valid_variants:
            comp["variant"] = valid_variants[0] if valid_variants else None
        # Recurse children
        for child in comp.get("children", []):
            self._validate_component(child)
        return comp
```

### 5.3 Governance Layer (preserved)

The compiler retains the governance functions of the current producer:

| Concern | Current Producer | Target Compiler |
|---------|-----------------|-----------------|
| **Safety** | Implicit (hardcoded output) | Explicit sanitize step |
| **Feature flags** | Not supported | `_apply_feature_flags()` gates unreleased primitives |
| **Schema versioning** | Manual snake_case bridge | Version field + validation per version |
| **Defaults** | Hardcoded in render methods | Centralized `_normalize()` |
| **Metrics** | Logging only | Structured quality metrics |
| **Fallback** | `produce_error()` | Same, but scoped to validation failures |

---

## 6. LLM Structured Output (Gradual Introduction)

### 6.1 Phase 1: Producer Still Builds Trees

The LLM returns natural language. The producer parses it and builds `A2UIComponent` trees (current behavior, but using 22 primitives instead of 150 types).

### 6.2 Phase 2: LLM Returns Semantic JSON

Use function calling / structured output to have the LLM return JSON conforming to the `LyoResponse` schema:

```python
# Gemini / OpenAI function call schema (simplified)
RESPONSE_SCHEMA = {
    "type": "object",
    "properties": {
        "message": {"type": "string", "description": "Plain text response"},
        "ui": {
            "type": "object",
            "description": "Optional rich UI component",
            "properties": {
                "type": {"type": "string", "enum": ["text", "quiz", "course", ...]},
                "variant": {"type": "string"},
                "content": {"$ref": "#/definitions/ContentProps"},
                "data": {"type": "object"},
                "children": {"type": "array", "items": {"$ref": "#/definitions/Component"}}
            }
        },
        "command": {
            "type": "object",
            "properties": {
                "action": {"type": "string", "enum": ["open_classroom", "start_quiz", ...]},
                "payload": {"type": "object"}
            }
        }
    },
    "required": ["message"]
}
```

The compiler validates this. The LLM doesn't need to get layout perfect — the client applies its own design system.

### 6.3 Phase 3: LLM-Driven but Validated

The LLM can compose component trees (e.g., a `container` with `text` + `quiz` children), but the compiler validates every node. Invalid primitives → `text` fallback. Invalid variants → first legal variant. Missing required fields → sensible defaults.

---

## 7. iOS Client Changes

### 7.1 New Renderer (22 cases)

```swift
// Target — A2UIRenderer.swift
struct A2UIRenderer: View {
    let component: A2UIComponent
    
    var body: some View {
        switch component.type {
        // Content
        case .text:      TextRenderer(component)
        case .media:     MediaRenderer(component)
        case .divider:   DividerRenderer()
        // Input
        case .input:     InputRenderer(component)
        case .button:    ButtonRenderer(component)
        // Layout
        case .container: ContainerRenderer(component)
        case .card:      CardRenderer(component)
        case .list:      ListRenderer(component)
        // Nav
        case .nav:       NavRenderer(component)
        // Learning
        case .quiz:      QuizRenderer(component)
        case .quizResult: QuizResultRenderer(component)
        case .course:    CourseRenderer(component)
        case .flashcard: FlashcardRenderer(component)
        case .plan:      PlanRenderer(component)
        case .tracker:   TrackerRenderer(component)
        case .assignment: AssignmentRenderer(component)
        case .document:  DocumentRenderer(component)
        // Engagement
        case .progress:  ProgressRenderer(component)
        case .aiBubble:  AIBubbleRenderer(component)
        case .social:    SocialRenderer(component)
        // System
        case .alert:     AlertRenderer(component)
        case .skeleton:  SkeletonRenderer(component)
        }
    }
}
```

Each renderer internally switches on `variant`:

```swift
// Example — QuizRenderer handles all quiz variants
struct QuizRenderer: View {
    let component: A2UIComponent
    
    var body: some View {
        switch component.variant {
        case "mcq":        MCQView(component.content, component.data)
        case "true_false": TrueFalseView(component.content, component.data)
        case "fill_blank": FillBlankView(component.content, component.data)
        case "matching":   MatchingView(component.content, component.data)
        case "ordering":   OrderingView(component.content, component.data)
        case "code":       CodeChallengeView(component.content, component.data)
        default:           MCQView(component.content, component.data) // safe default
        }
    }
}
```

### 7.2 Unified Response Parser

```swift
// Target — one parser for both paths
struct LyoResponse: Codable {
    let version: String
    let requestId: String
    let message: String
    let ui: A2UIComponent?
    let command: LyoCommand?
    let suggestions: [Suggestion]?
    let conversationId: String?
}

struct LyoCommand: Codable {
    let action: String        // "open_classroom", "start_quiz", etc.
    let payload: [String: AnyCodable]?
}

// Fast path
let response: LyoResponse = try decoder.decode(LyoResponse.self, from: data)

// Deep path — accumulate SSE fragments into the same struct
class LyoStreamAssembler {
    private var response = LyoResponseBuilder()
    
    func handleEvent(_ event: String, data: Data) {
        switch event {
        case "start":     response.setMeta(data)
        case "message":   response.appendMessage(data)    // delta text
        case "ui":        response.setUI(data)             // A2UIComponent
        case "command":   response.setCommand(data)
        case "suggestions": response.setSuggestions(data)
        case "done":      delegate?.didComplete(response.build())
        default: break
        }
    }
}
```

No more `Lyo2UIBlockType` mapping. No more `BackendAIChatResponse` with 25 fields. No more regex extraction of `OPEN_CLASSROOM` from markdown.

---

## 8. Migration Path

### Phase 0: Foundation (1 week)
- [ ] Define `A2UIPrimitive` enum (22 cases) alongside existing `A2UIElementType`
- [ ] Define `LyoResponse` struct alongside existing `BackendAIChatResponse`
- [ ] Add `variant` field to `A2UIComponent` (backward-compatible, optional)
- [ ] Backend: add `version: "2.0"` field to responses

### Phase 1: Parallel Rendering (2 weeks)
- [ ] Build 22 new renderers (one per primitive)
- [ ] Each renderer handles variants internally
- [ ] `A2UIRenderer` checks `version` field:
  - `"2.0"` → new primitive renderer
  - `"1.x"` or missing → legacy switch (current code)
- [ ] Backend adds mapping layer: old produce_* → new LyoResponse shape
- [ ] Ship with feature flag: `use_a2ui_v2 = false`

### Phase 2: Backend Migration (2 weeks)
- [ ] Replace `a2ui_producer.py` with `a2ui_compiler.py`
- [ ] All produce_* methods output `LyoResponse` format
- [ ] SSE events use new event names (`message`, `ui`, `command`, `done`)
- [ ] Keep backward-compatible SSE events during transition
- [ ] Feature flag: `use_a2ui_v2 = true` for beta users

### Phase 3: Props Cleanup (1 week)
- [ ] Replace `A2UIProps` (180 fields) with `ContentProps` + `StyleProps` + `data` dict
- [ ] Remove unused supporting types (reduce from 20+ to ~8)
- [ ] Delete `A2UIElementType` enum (150 cases)
- [ ] Delete `BackendAIChatResponse` struct
- [ ] Delete `Lyo2UIBlockType` enum

### Phase 4: LLM Structured Output (2 weeks)
- [ ] Add `LyoResponse` as function calling schema for Gemini/OpenAI
- [ ] A2UICompiler validates LLM output
- [ ] Measure quality: how often does the LLM produce valid components?
- [ ] Gradually reduce producer logic as LLM quality improves

### Phase 5: Cleanup (1 week)
- [ ] Remove legacy renderer code paths
- [ ] Remove snake_case→camelCase bridge (use `.convertFromSnakeCase` globally)
- [ ] Remove feature flags
- [ ] Final documentation update

---

## 9. Risk Mitigation

| Risk | Mitigation |
|------|-----------|
| LLM produces invalid component trees | Compiler validates every node; fallback to `text` primitive |
| New renderers have visual regressions | Feature flag `use_a2ui_v2` allows A/B testing; screenshot tests |
| Backend returns v1 format during migration | Version field check routes to correct parser |
| `data` dict loses type safety | Define TypeScript/Swift schemas per primitive for validation |
| Quiz/course features break during migration | Build Phase 1 renderers for domain primitives first (quiz, course, plan) |

---

## 10. Success Criteria

- [ ] `A2UIElementType` enum: **22 cases** (from 150+)
- [ ] `A2UIProps` struct: **deleted**, replaced by 3 focused structs + data dict
- [ ] One `LyoResponse` struct for both fast and deep paths
- [ ] No `OPEN_CLASSROOM` regex extraction from markdown
- [ ] Every primitive has a working renderer (0% fallback rate)
- [ ] New content type requires: backend schema update + one renderer file (2 files, not 7)
- [ ] Producer code: < 200 lines (validation/normalization only)

---

## Appendix A: Full Primitive ↔ Legacy Type Mapping

```
text        ← text, heading, paragraph, caption, label, markdown, richText, 
               codeBlock, blockquote, callout
media       ← image, video, audio, lottieAnimation, icon, cameraPreview, 
               audioPlayer, videoPlayer, waveform, model3D, gif, svgImage, 
               imageCarousel, thumbnail
divider     ← divider
input       ← textInput, textArea, numberInput, slider, toggle, checkbox, 
               radioGroup, dropdown, datePicker, colorPicker, segmentedControl, 
               ratingInput, voiceRecorder, cameraCapture, fileUpload, searchBar, 
               tagInput, drawingCanvas
button      ← button, iconButton, linkButton, fab, ctaButton
container   ← vstack, hstack, zstack, grid, scrollView, lazyStack, spacer, 
               section, accordion, tabContainer, carousel
card        ← card, expandableCard, swipeableCard, headerCard, statCard, featureCard
list        ← listItem, checklist, timeline
nav         ← breadcrumb, tabBar, pagination, toolbar, sidebarMenu, 
               navigationBar, segmentedTab, pageIndicator, bottomBar, fab
quiz        ← quizMcq, quizTrueFalse, quizFillBlank, quizMatching, 
               quizOrdering, quizOpenEnded, quizCodeChallenge, quizImageLabel
quiz_result ← quizResult, quizFeedback, quizProgress, quizTimer, 
               quizLeaderboard, quizBattle
course      ← courseCard, courseModule, courseLesson, courseProgress, 
               courseCertificate, courseObjective, courseOverview, courseBanner, 
               courseTimeline, courseSyllabus, courseEnrollment, courseRating, 
               courseRecommendation
flashcard   ← documentFlashcard, flashcardDeck, flashcardResult
plan        ← studyPlanOverview, studyPlanDay, studyPlanSession, studyPlanGoal, 
               studyPlanProgress, studyPlanCalendar, studyPlanReminder, 
               studyPlanStreak, studyPlanMilestone, studyPlanAdaptive, 
               studyPlanReview, studyPlanCompletion, studyPlanResourceList
tracker     ← mistakeCard, mistakePattern, mistakeHeatmap, mistakeTimeline, 
               mistakeDetail, mistakeQuickFix, mistakePractice, mistakeInsight, 
               mistakeComparison
assignment  ← homeworkCard, homeworkSubmission, homeworkRubric, homeworkFeedback, 
               homeworkCalendar, homeworkProgress, homeworkAttachment, 
               homeworkGrade, homeworkPeerReview
document    ← documentViewer, documentScanner, documentSummary, documentAnnotation, 
               documentSearch, documentOutline, documentCompare, documentHighlight, 
               documentOCR, documentNote, documentTag, documentShare, documentQuiz
progress    ← progressBar, streakWidget, xpBar, levelIndicator, achievementBadge, 
               energyMeter, questWidget, dailyGoal, leaderboardRow, rewardChest, 
               challengeCard, eventBanner, statCounter
ai_bubble   ← chatBubble, thinkingIndicator, suggestionChip, aiMoodAvatar, 
               explanationCard, contextPanel, sourceReference, feedbackCollector, 
               personalityCard, tutorPrompt, insightCard, summaryPanel
social      ← userProfile, studyGroup, comment, shareCard, activityFeed, 
               reaction, mention, collaboratorList, inviteCard
alert       ← toast, snackbar, banner, systemAlert, maintenanceNotice, 
               updatePrompt, featureFlag, errorBoundary, emptyState, 
               connectionStatus
skeleton    ← loadingOverlay, skeleton, debugOverlay, versionCheck
```

## Appendix B: Before/After Payload Examples

### B.1 Quiz — Before (current)

```json
{
  "type": "quiz_mcq",
  "props": {
    "question": "What is the time complexity of binary search?",
    "options": [
      {"id": "a", "text": "O(n)", "is_correct": false},
      {"id": "b", "text": "O(log n)", "is_correct": true},
      {"id": "c", "text": "O(n²)", "is_correct": false}
    ],
    "correct_answer": {"string": "b"},
    "explanation": "Binary search halves the search space each step.",
    "max_attempts": 2,
    "show_feedback": true,
    "points": 10,
    "difficulty": "medium",
    "shuffle_options": true,
    "time_limit": null,
    "matching_pairs": null,
    "order_items": null,
    "blanks": null,
    "code_language": null,
    "code_template": null,
    "test_cases": null,
    "text": null,
    "title": null,
    "subtitle": null,
    "body": null,
    "image_url": null,
    "video_url": null,
    "audio_url": null,
    "course_id": null,
    "xp": null,
    "streak": null,
    "username": null
  }
}
```

**18 null fields** included because `A2UIProps` is one big bag.

### B.2 Quiz — After (target)

```json
{
  "type": "quiz",
  "variant": "mcq",
  "content": {
    "title": "Quick Check",
    "text": "What is the time complexity of binary search?"
  },
  "data": {
    "options": [
      {"id": "a", "text": "O(n)", "is_correct": false},
      {"id": "b", "text": "O(log n)", "is_correct": true},
      {"id": "c", "text": "O(n²)", "is_correct": false}
    ],
    "explanation": "Binary search halves the search space each step.",
    "max_attempts": 2,
    "show_feedback": true,
    "points": 10,
    "difficulty": "medium"
  },
  "actions": [
    {"trigger": "on_submit", "type": "submit_answer", "payload": {"quiz_id": "q1"}}
  ]
}
```

**Zero null fields.** Only what's needed.

### B.3 Study Plan — Before (current)

```json
{
  "type": "study_plan_overview",
  "props": {
    "plan_id": "sp-123",
    "goal_title": "Master Calculus",
    "goal_description": "Complete all integration techniques",
    "target_date": "2025-07-15T00:00:00Z",
    "progress": 0.35,
    "completed_count": 7,
    "total_count": 20,
    "sessions": [...],
    "milestones": [...],
    "text": null,
    "title": null,
    "question": null,
    "options": null,
    "course_id": null,
    "homework_id": null,
    "mistake_type": null,
    "document_url": null,
    "xp": null
  }
}
```

### B.4 Study Plan — After (target)

```json
{
  "type": "plan",
  "variant": "overview",
  "content": {
    "title": "Master Calculus",
    "subtitle": "Complete all integration techniques"
  },
  "data": {
    "plan_id": "sp-123",
    "target_date": "2025-07-15",
    "progress": 0.35,
    "completed": 7,
    "total": 20,
    "sessions": [...],
    "milestones": [...]
  }
}
```

### B.5 Full Streaming Response — Before (current SSE)

```
event: skeleton
data: {"blocks": ["TutorMessageBlock", "QuizBlock"]}

event: answer
data: {"type": "TutorMessageBlock", "title": null, "priority": 0, 
       "content": {"text": "Let me explain binary search..."}}

event: artifact
data: {"type": "QuizBlock", "title": "Quick Check", "priority": 1, 
       "content": {"question": "What is...", "options": [...]}}

event: done
data: {}
```

### B.6 Full Streaming Response — After (target SSE)

```
event: start
data: {"version": "2.0", "request_id": "req-789"}

event: message
data: {"delta": "Let me explain binary search..."}

event: ui
data: {"type": "quiz", "variant": "mcq", "content": {"title": "Quick Check", 
       "text": "What is the time complexity?"}, 
       "data": {"options": [{"id": "a", "text": "O(n)"}]}}

event: suggestions
data: [{"text": "More practice"}, {"text": "Explain again"}]

event: done
data: {}
```

**One component model, one contract, both paths.**
