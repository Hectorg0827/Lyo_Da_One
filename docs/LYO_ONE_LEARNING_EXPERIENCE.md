# Lyo One Learning Experience — product & integration contract

Status: incremental rollout. The goal-first Home routing and existing Coach /today
mission entry are the first implementation slice; the complete cross-surface
journey is **not yet shipped**.

## Product invariants

1. One learner, one authenticated source of truth. Chat, Classroom and Test
   Prep remain distinct execution engines but share canonical goals, learner
   evidence, and continuity. No client may infer readiness or mutate mastery.
2. A learner never has to choose an engine before making a request. The
   explicit request takes precedence over Coach and teaching suggestions.
3. All three engines remain directly accessible; manual navigation may never
   be intercepted by an intent router.
4. A quick answer remains a quick answer. An ANSWER may suggest Classroom,
   but may not forcibly become TEACH/QUIZ, and a QUIZ may not become a lecture.
5. Exam intake must never silently reactivate or overwrite another profile.
   Distinct tests keep independent IDs, documents, schedules, and evidence.
6. A teaching handoff preserves the original journey, return location, user
   input, course/lesson identity, and current work. It never fabricates success.
7. The Coach decides WHAT to do based on recorded goals/evidence; teaching
   policy decides HOW. Coach is a control plane, not a fourth LLM or route.
8. Breadth is not restricted by a subject allowlist: fall back to general
   multimodal instruction when a dedicated interactive teaching tool is absent.
9. Structured visuals are validated, versioned and rendered natively; no new
   subject-specific hardcoded app screens for each discipline.
10. Accessibility, reduced motion, caption ownership and voice interruption
    must survive every capability transition.

## Release phases

### Slice 1 — Goal-first Home and Coach next step (this PR)

- Route explicit questions to existing Chat, teaching intents to Classroom,
  and exam intents into the canonical Chat/Test Prep intake without dropping
  the learner's original wording.
- Three clearly visible direct links: Chat, Classroom and I Have a Test.
- Coach mission card uses authenticated /api/v1/me/coach/today evidence,
  accepts no synthesized percentages and hides on failed reads.
- Preserve legacy Home, courses, independent exam profiles, and regular
  Classroom sessions. The backend InteractionContract remains authoritative.

### Slice 2 — Native entry parity

- Implement the same semantic decision table in iOS and Android through
  platform-native routing, not copied divergent AI heuristics.
- Native Coach next-step UI consumes the same authenticated /today response.
- Run the existing native CI plus direct-touch-device and accessibility tests.

### Slice 3 — Coach as canonical Chat workflow

- Reconcile backend PR #106 and frontend PR #97 with current main.
- Preserve EXAM / TEST_PREP precedence over Coach for exam intake.
- Emit typed coach_mission + stable normal text fallback.
- Reuse canonical voice and existing Classroom/Review execution for missions.
- Verify expired/missing evidence never becomes an invented recommendation.

### Slice 4 — Durable cross-engine journey context

Introduce an authenticated, versioned journey contract with:
- goal_id, journey_id, session_id, origin_surface and origin_ref;
- optional test_profile_id, course_id, lesson_id, concept_id and artifact refs;
- activity state: pending, active, paused, completed, failed;
- a typed next_action with target surface and allowed action;
- idempotency/request_id, revision and event_id for safe retries/replay.

The server owns journey storage and transitions. Clients only hold navigation
state and cached revisions. Save and reload must rehydrate the same journey.
No raw URL-provided user/goal ID is trusted without ownership verification.
No data is copied between goals unless learner-authorized and semantically
appropriate; unrelated Chat questions must not pollute an exam's evidence.

Write one durable transition event before presenting the new surface; retrying
a handoff must not duplicate a course, exam, or graded interaction. On failure
offer retry and back-to-origin. Expired or missing state fails closed rather than
silently starting a different goal.

### Slice 5 — Adaptive workspace presentation

- Mobile: one primary activity, compact persistent input and reversible
  context switcher; web/tablet: optional sidecar Chat/notebook/plan.
- Classroom board, captions, teacher and practice use existing display roles.
- Goal-specific tools and visual components are selected by learning context,
  not by a subject-name whitelist or a second AI response channel.
- Persist knowledge/evidence as supported, with independent delayed retrieval
  before claiming durable mastery.

## Acceptance journeys

A. "What is cellular respiration?" answers in Chat with no forced lesson.
B. "Teach me cellular respiration" opens Classroom with a reversible transition.
C. "I have a chemistry exam Friday..." retains text, creates/uses the proper
   exam profile, and protects unrelated exams.
D. Exam question -> linked Classroom reteaching -> return to exact exam item,
   without duplicate grade or lost attachments.
E. "What should I study for 20 minutes?" uses Coach only when evidenced;
   user may decline and ask an unrelated question.
F. Spanish/English voice handoff, interrupt, resume, retries and lost network
   preserve learner intent and live/caption/board state.
G. New subject with no special widget remains teachable through the generic
   visual + conversation component registry.
H. Sign-out/account switch never flashes another learner's mission or data.
I. Reload and cross-device handoff preserve authenticated goal/session IDs.
J. Existing client versions remain functional during staged deployment.

## Rollout gates

- Complete course persistence and authenticated save/reopen checks before
  making saved journeys depend on it (backend #130, frontend #132).
- Fresh CI against current main for every touched surface.
- Authenticated staging flows across the three engines; capture event IDs
  and teaching/evidence deltas for diagnosis.
- Backend-first for additive wire changes; keep backwards-compatible fields.
- Feature flag each new routing/continuity behavior; monitor fail, retry,
  latency, cross-user isolation and false-praise regressions.
- Physical iOS and Android validation before mobile release.
- Never treat a merged PR as proof of deployment or production readiness.

## Current dependencies

- Coach Chat backend: Hectorg0827/LyoBackendJune#106, open.
- Coach Chat UI: Hectorg0827/Lyo_Da_One#97, open.
- Course persistence: Hectorg0827/LyoBackendJune#130 and
  Hectorg0827/Lyo_Da_One#132, drafts.
- Existing Test Prep multi-profile flow: backend #126 and client #131, merged.
- Existing adaptive Classroom board: backend #124 and client #128, merged.

This document is a behavior contract, not a claim that the later slices are
implemented or deployed.
