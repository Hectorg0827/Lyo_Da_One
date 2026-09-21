# LYO CLASSROOM — UI TRANSFORMATION SPEC

Design contract for the Classroom across web, iOS and Android. Updated on
14 September 2026 after the guided-teaching and UI pull requests merged. §2
preserves the original diagnostic baseline; §6 records approved decisions and
remaining validation, and §7 distinguishes implementation from acceptance.

---

## 0. How to use this

Work the prerequisites in §7 in order. Read §6 before treating a product
choice as unresolved: silent teaching and optional voice with typing retained
are already approved. Resumability is an implementation and validation
requirement, not a request for the learner to accept lost progress. Keep new
immersion and orientation changes deferred until that requirement passes.

---

## 1. The principle

**The student should always know what the teacher is saying, what they are
learning, and what they can do next.**

Hold every screen against it. If something on screen does not serve one of
those three, it is competing with them.

A second rule, inherited from the rest of this product and non-negotiable:
**never show a learner something nothing measured.** It applies to interface
as much as data — a silent avatar implying a classmate, a countdown implying
a schedule, a progress bar implying a plan.

---

## 2. Original diagnostic baseline

The caption, teacher duplication and stale-comment findings below describe
the implementation before Phases 1–2. [Client PR #57](https://github.com/Hectorg0827/Lyo_Da_One/pull/57)
fixes those issues. Do not reintroduce the removed participant row.

### 2.1 The three platforms disagree, and the comments lie about it

| Behaviour | Web | iOS | Android |
| --- | --- | --- | --- |
| Orientation | none | **force-locks landscape** | none |
| Auto-hiding chrome | **none** | yes (`resetChromeTimer`) | yes (`rememberChromeVisibility`) |
| Exit affordance | always-visible back arrow | — | in top bar |

Three comments in the codebase claim parity with web for behaviour **web does
not have**:

- `Sources/Views/Main/Classroom/LivingClassroomView.swift` (~L362):
  `// Netflix/YouTube-style classroom: default to landscape full-screen,`
  `// matching the web classroom's behavior.` — web has no orientation code.
- `android/.../classroom/ClassroomChrome.kt` (~L50): "matching the 3s idle
  timeout already shipped on web (classroom/page.tsx's `resetHideTimer`)" —
  no such symbol exists.
- `Sources/Views/Classroom/ActiveLessonView.swift` (~L109): same citation,
  same non-existent symbol.

Either web once had these and they were removed, or the comments were
aspirational. **Trust the code, not the comments.** Correct or delete each of
these three as you pass them; leaving them is how the next person is misled.

`scripts/verify-classroom-parity.mjs` did not catch any of it — it pins voice,
locale, interruption and learner-gating, not layout or orientation.

### 2.2 The caption is drawn twice — this is the visible "jumbled text" bug

Two components render the caption into the same 24px strip, both
`absolute inset-y-0 right-0 … whitespace-nowrap`:

1. `web/src/app/(main)/classroom/page.tsx` (~L502) — word-by-word ticker.
2. `web/src/components/classroom/ClassroomCaptionSync.tsx` — its own ticker,
   portalled into the same container.

`ClassroomCaptionSync` tries to hide the page's ticker by finding "the first
child that isn't mine" and setting `visibility: hidden`. That effect keys on
`[target]` only, and **runs before the page's ticker exists** (the page renders
it only when `caption` is truthy). So it hides the `sr-only` screen-reader
span instead — breaking assistive output — and the real ticker mounts
afterwards, unhidden. Two sentences, one line, on top of each other.

The container also forces a single line regardless: `h-6`,
`whitespace-nowrap`, `overflow-hidden`. It was built as a news ticker.

**Restyling the strip without collapsing the two renderers will still double.**

### 2.3 The teacher is drawn three times

- Small Lyo mascot beside the caption — `LYO_STATE_IMG` (page.tsx ~L484).
- The participant circle — `CAST`, where the Teacher is the **🧑‍🏫 emoji**,
  labelled "Lyo".
- A large idle mascot lower on the screen.

So the same mascot appears twice and the teacher is an emoji. Mascot PNGs live
at `web/public/mascot/`.

### 2.4 Preserve the working foundations

- **One caption owner:** the page renders the caption; the headless
  `ClassroomCaptionSync` controller updates the shared reveal count. Preserve
  audio pacing, speech boundary events and the fallback for engines without
  them. Do not restore the portal or DOM-hiding workaround.
- **One teacher:** the decorative participant row is removed. The `CAST`
  speaker-to-colour map remains available for actual speaker events; its
  existence does not establish live peer participation.
- **Accessible output:** the complete caption remains available to screen
  readers while the visual reveal stays decorative.

### 2.5 Structured teaching now exists

The original run-on lesson text required a server change. That foundation is
now implemented by [backend PR #48](https://github.com/Hectorg0827/LyoBackendJune/pull/48)
and [client PR #56](https://github.com/Hectorg0827/Lyo_Da_One/pull/56):
orientation, a worked example in 2–4 learner-paced beats, guided choice,
fading support, then a fresh, concise application.

The same server-owned sequence supplies audio and silent presentations.
Validated fraction bars, comparisons, sequences and parameterised graphs
have client renderers. A visual adjustment saves the activity state without
grading, advancing the lesson or replaying narration.

Use the [guided teaching contract](https://github.com/Hectorg0827/LyoBackendJune/blob/main/docs/CLASSROOM_GUIDED_TEACHING.md).
The remaining card transformation and silent hierarchy should consume those
steps, not start another teaching pipeline.

---

## 3. The bugs to fix

1. **Caption double-render** (§2.2). Highest priority — it makes the product
   look broken rather than unpolished.
2. **`sr-only` caption hidden**, breaking screen readers — same root cause.
3. **Duplicate teacher representations** (§2.3).
4. **Bottom mascot collides with the Android navigation area** — respect safe
   area insets.
5. **Insufficient contrast on secondary text.**
6. **Stale parity comments** (§2.1).

---

## 4. Design decisions (settled — build to these)

### 4.1 Caption

A dedicated transcript strip, **56–72px**, directly below the lesson card.
Translucent dark background. **Two lines maximum.** Old text is replaced, not
accumulated. One renderer, never two.

Format: `Lyo: "Normalization keeps each fact in one place."`

### 4.2 One teacher presence

One teacher, anchored beside the current teaching beat. The shipped web page
uses exactly five existing files in `web/public/mascot/`:
`mascot_reading_1.png` through `mascot_reading_4.png`, and
`mascot_standing.png`. There is no missing-asset upload requirement.

Distinct teacher artwork is a future design choice, not a broken dependency.
Map teacher states to known events: explaining, waiting, receiving an answer
and confirmed feedback. Do not infer learning or emotions from prose.

Full-size mascot appears only for **moments that earn it** — a correct
demonstration, a checkpoint, the loading state. Never as permanent furniture.

### 4.3 Orientation

**Portrait is primary.** Landscape is an *expand gesture for the board* — a
wide canvas for diagrams, schema comparisons, figures — not the default and
not a lock.

This is the intended direction for Phase 3. Changing the iOS orientation
lock and adding rotate-to-expand remain deferred until the resumption and
real-device checks in §6c pass.

### 4.4 Chrome and exit

**Hide chrome. Never hide escape.**

Always visible, never fades:
- One exit affordance, top-left, ≥44px touch target. May rest at ~40% opacity.
  May not be absent.
- The audio-mode caption; in silent mode, the current teaching beat is
  visible in the main card (§6b).
- Any question awaiting an answer.

Auto-hides after ~3s idle (match the existing Android/iOS timeout constant):
- Course title, goal, progress
- Sound toggle, settings, notes
- The participant row
- Secondary actions

Returns on a tap **anywhere** on the canvas. Never hides while a checkpoint or
question is active — Android already models this as `blockAutoHide`; reuse the
concept, do not invent a second one.

### 4.5 Header

Consolidate to three lines, with a thin progress bar beneath:

```
SQL for a Job Interview
Lesson 3 · Data Normalization
● Live
```

The goal moves behind an info affordance. **Do not show a countdown unless it
is real** — the classroom recently shipped a hard-coded 10-minute plan against
sessions the learner was told were 45.

### 4.6 One teaching stage, two delivery modes

With audio on, the voice leads and the card carries the relevant worked
example or visual. With audio off, the card carries the complete teaching
beat and the learner controls when to continue. The small caption strip is
hidden in that mode. Use the existing structured steps (§2.5).

### 4.7 Colour system

- **Purple** — interaction
- **Teal / green** — learning and success
- **Gold** — achievements and special actions only

No screen carries more than these three accents at once.

### 4.8 Action bar

`❓ Help    ⚡ Challenge    ✋ Raise hand`

Equal touch targets, ≥48px tall. "Harder case" becomes "Challenge". If a
`Continue` action exists on the surface, it is the primary and Raise hand is
prominent-secondary.

### 4.9 Teach → Check → Respond → Continue

Use the gradual-release sequence in §2.5. The card should transform from a
modeled step to a supported decision, then feedback and the next useful
practice step. Keep the relevant worked example or visual available while
the learner answers. Do not replace the first explanation with a difficult
unassisted recall test.

The primary teacher responds to difficulty with a hint, a different example
or prerequisite teaching and then returns to the same objective. Extra help
requires a fresh faded attempt before independent practice. Do not introduce
a visible peer teacher automatically.

---

## 5. Rules you may not break

1. **Never claim what nothing measured.** No silent avatars implying
   classmates, no countdown implying a schedule, no progress implying a plan.
2. **Preserve or deliberately drop the TTS sync** (§2.4) — never silently.
3. **Keep the `sr-only` caption working.** Screen readers get the whole line;
   the visual ticker is decorative.
4. **Extend `scripts/verify-classroom-parity.mjs`** with the layout and
   orientation rules this spec settles. Mutation-test every new rule: break
   the code it guards and confirm the gate fails. A passing gate after an edit
   proves nothing about what the edit removed.
5. **Works at 400px wide, and with voice off.**
6. **Respect safe areas** — Android navigation, iOS home indicator.
7. **Respect reduced motion** — the page already has `animationsOff`.
8. Leaving the classroom must close the socket, stop audio and release any
   orientation lock — including via browser back and the Android back gesture.

---

## 6. Approved decisions and remaining validation

**a. ~~Do classmates actually speak?~~ ANSWERED — no, and they cannot.**
`_get_peer_states` returns a single hard-coded stub ("AI peers are synthetic —
no DB table") and nothing on the wire can make a peer a speaker. The row was
removed in Phase 1. Building real peer participation is a feature, not a
layout fix; the CAST colour map is kept so a peer would be identifiable the
day it exists.

**b. Silent teaching — APPROVED; hierarchy and device validation remain.**
Use guided lesson dialogue: one teacher, one bite-sized teaching beat, one
relevant visual and one clear next action. Hide the 56–72px caption strip and
put the full teaching text into the central card. Continue is learner-paced;
the checkpoint transforms that same surface. Audio and silent modes consume
the same pedagogical state.

Select silent mode when the learner requests it, Classroom voice is disabled,
usable output volume is zero where the platform exposes it, or audio/TTS is
unavailable. A hardware mute-switch signal is not a required cross-platform
contract. Derive mascot reactions from known teaching and grading events.
Use native haptics for meaningful feedback, respecting device preferences.

**c. Resumability — REQUIRED; persistence implemented, acceptance outstanding.**
The merged version 2 guided state saves the current teaching batch and beat,
target coverage, paused example, pending question, support history and visual
values in the existing learner-owned session context. Re-entry restores the
saved scene without generating a new turn or grading again.

Before enabling further immersion, demonstrate: leave during an example,
return on another supported client, and see the same beat; repeat with an
unanswered checkpoint, a help detour and an adjusted visual. Confirm duplicate
Continue/answer submissions neither skip teaching nor commit evidence twice.
Exercise failed saves and interrupted connections. An unsent offline action
must not be described as saved.

Updated clients send the actual CTA ID; installed clients using legacy static
Continue IDs do not have the same duplicate-tap guarantee. A passing backend
round-trip test does not replace web/iOS/Android acceptance testing.

**d. Answer modality — retain typing and optional voice.**
Keep choices for early guided practice, short completion tasks while support
fades, and clear, concise application prompts when the learner is ready.
Typed answers and available dictation remain usable. Do not require speech
or replace open responses with tiles in this tranche.

The evidence rung follows the task and the server's judgment of the response,
including assistance used. Neither choosing an option nor using a microphone
establishes independent application or retention. Any future modality
experiment must preserve that distinction.

---

## 6e. Show the learner their evidence

The Classroom now writes, per graded answer: an evidence rung (recognition →
application → transfer → retention), a confidence damped by how many hints
were used, a misconception tag, and an updated mastery score per concept.

**The Classroom still needs a clear learner-facing record of that evidence.**
Show what the learner demonstrated, where support was used, and what should be
practised next. Read those claims from committed server evidence, not local
answer counters, lesson completion or visual interactions.

That is the biggest gap between what the backend knows and what the interface
says — bigger than any component. It is also the easiest place to start
claiming things nothing measured, so whatever is shown must read off the same
rungs the server recorded. *Recognised* is not *applied*.

The production adaptive path does **not** emit a `Celebration` component.
Its constructors belong to inactive Director/coach code. There is no live
celebration being dropped by the web store. Deliberate, proportionate
acknowledgment of a demonstrated skill remains work to design against actual
evidence; it must not imply long-term mastery.

`ChatBubble`, `TypingIndicator` and `ReflectionPrompt` are unused wire-type
cleanup candidates, not missing client experiences. Confirm imports, exports,
tests and persisted-payload compatibility before removing them. Keep that
cleanup separate from the teaching and evidence UI.

---

## 7. Order of work

**Phase 1 — Stop the bleeding** — implemented and merged; phone acceptance pending
1. Collapse the two caption renderers into one; build the 56–72px two-line
   strip (§4.1); restore the `sr-only` span; preserve the TTS sync.
2. Delete the duplicate teacher representations; one presence beside the
   speech (§4.2).
3. Fix the safe-area collision and secondary-text contrast.

**Phase 2 — Structure** — implemented and merged; phone acceptance pending
4. Header consolidation (§4.5) and the colour system (§4.7).
5. Action bar (§4.8).
6. Correct or delete the three stale parity comments (§2.1); extend the parity
   gate (§5.4).

**Phase 3 — Immersion** *(deferred until §6c acceptance passes)*
7. Auto-hiding chrome on web with a permanent exit (§4.4), matching the
   existing Android/iOS timeout.
8. Remove the iOS force-landscape; add rotate-to-expand-the-board (§4.3).

**Teaching foundation — implemented and merged**
[Backend #48](https://github.com/Hectorg0827/LyoBackendJune/pull/48),
[test fixes #49](https://github.com/Hectorg0827/LyoBackendJune/pull/49), and
[clients #56](https://github.com/Hectorg0827/Lyo_Da_One/pull/56) supply the paced
sequence, guided practice, interactive visuals and durable teaching state.
[UI #57](https://github.com/Hectorg0827/Lyo_Da_One/pull/57) supplies Phases 1–2.
All four are merged. Build/test CI passed on their reviewed heads; that alone
does not establish real-device usability or learning outcomes.

**Phase 4 — The teaching surface** *(decisions in §6b and §6d are settled)*
9. Finish card-becomes-the-question (§4.9), retaining the relevant example.
10. Complete the silent hierarchy using existing structured steps (§2.5).
11. Expose a learner-facing evidence record (§6e).

---

## 8. Definition of done

A phase is done when:

- The web suite, typecheck and build pass.
- Both gates pass — `verify-product-trust.mjs` and
  `verify-classroom-parity.mjs` — with new rules added for what the phase
  settled, **each mutation-tested**.
- iOS and Android compile and their tests pass in CI.
- The screen holds against §1 at 400px, with voice off, and with reduced
  motion on.
- No comment claims cross-platform parity that the code does not deliver.

And the part no test covers: **somebody has actually looked at it on a phone.**
Every bug found in this product over the last week was a case nobody had
imagined, not a case someone got wrong. Tests only cover what was thought of.
