# Backend patches for LyoBackendJune

These four patches are the backend work from this branch's sessions. They
could not be pushed to `Hectorg0827/LyoBackendJune` from the development
environment (no push access), so they are preserved here.

1. **0001** — Adds the messaging (`/messages/*`), notifications
   (`/notifications`), and discover (`/discover/*`) routers, registers them in
   `enhanced_main.py`, and adds the matching iOS `Endpoints.swift` cases.
2. **0002** — Emits in-app notifications on comment / reaction / follow /
   achievement-unlock so the notifications feed actually populates.
3. **0003** — Five bug fixes found by end-to-end testing the full stack
   locally (unmounted feeds router, 500-instead-of-401 on missing auth,
   broken `/community/events`, MissingGreenlet on comment serialization,
   silent no-op profile renames).
4. **0004** — Makes init_db's schema sync resilient to individual model
   import failures and registers the new social/notifications/skills models,
   so the notifications, conversations, and messages tables are created
   automatically on startup (verified: 133 tables on a fresh database).

## To apply

```bash
cd LyoBackendJune
git checkout -b claude/analyze-production-readiness-1pGKe
git am path/to/LYO_Da_ONE/backend-patches/*.patch
git push -u origin claude/analyze-production-readiness-1pGKe
```

Verified against a local boot of the backend: 43/43 API checks and 21/21
Playwright browser checks passed (see the web repo's commit `a1c867f` for the
matching client-side fixes).

Deployment note: patch 0004 resolves the earlier caveat — `init_db()` now
creates the new tables automatically on startup, so no manual migration is
required before these endpoints go live. One data prerequisite: an
`organizations` row with `id=1` must exist (the TenantMixin default);
production databases created via the normal seed path already have it.

## AI Classroom: rubric-leak fix and hesitation scaffolding

Unlike the patches above, this change was pushed directly to
`Hectorg0827/LyoBackendJune` (branch `claude/multi-agent-rubric-separation-rs6iaf`,
same name as this repo's branch) since push access was available this time —
no `.patch` file needed. Noting it here for discoverability since the actual
AI tutor/classroom logic lives in that repo, not this one.

**Bug:** `SceneLifecycleEngine.handle_transfer_submission()` in
`lyo_app/ai_classroom/scene_lifecycle_engine.py` built the learner-facing
correction text by joining the deterministic Evaluator's raw missing-keyword
list directly into the message (e.g. "Add the missing reasoning link around
ratio, scale..."), and that string flowed straight into the visible
`TeacherMessage` with no persona/LLM filtering — handing the learner the
exact words the grading rubric was scoring for.

**Fix:**
- `describe_transfer_gap()` replaces the keyword-joining feedback: it
  reports the *category* of gap (too short vs. not yet on-target) without
  ever quoting a rubric keyword. `score_transfer_response()` (the hidden
  Evaluator) is unchanged — only what gets surfaced to the visible Tutor
  text changes.
- `remediation_hint` on a transfer submission is now always `None` instead
  of the joined keyword list (author-curated quiz-distractor remediation
  hints, a separate code path, are untouched).
- `detect_hesitation()` is a lightweight keyword classifier ("not sure",
  "idk", "help", ...) that shifts the Director from Assessment into
  Scaffolding: skip scoring/correction entirely and give one small hint
  instead, regardless of frustration state or how the Evaluator scored the
  response.
- `director_prompt.py` and the instruction-generation system prompt gained
  matching guardrails so the LLM-authored path never quotes rubric keywords
  and treats a hesitant signal as "hint, not evaluation."

The client-visible `InputField.expected_keywords` field is untouched — that
is an intentional, separately-tested "transparent server rubric" (see
`test_transfer_input_carries_a_transparent_server_rubric`); the bug was
specifically the keywords bleeding into spoken/chat text, not their presence
as structured data.

Verified: `tests/test_ai_classroom_teaching_loop.py` (21/21, including 7 new
tests for the gap-description leak regression and hesitation routing).

**Follow-up fix, same branch:** `context.learning_objective` prioritized the
one-time, session-wide "objective" the learner typed at course creation
(e.g. "Learn the basic concepts of algebra") over the specific resolved
`lesson_title`, for every scene in the session. That generic string fed
both the visible transfer question and `expected_transfer_keywords()`,
producing junk pseudo-concepts like "learn"/"basic"/"concepts" and broken
instructional text ("Revise your application of Learn the basic
concepts..."). Flipped the priority to prefer the current lesson's
specific title, matching the pattern already used in the lesson-advance
branch elsewhere in the same file.
