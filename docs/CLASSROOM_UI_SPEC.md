# LYO CLASSROOM — UI TRANSFORMATION SPEC

End-to-end brief for rebuilding the Classroom's interface across web, iOS and
Android. Written after reading the live code on `main`; every claim in §2 was
verified, not inferred.

---

## 0. How to use this

Work the phases in §7 in order. Before writing code, read §2 — it contains
findings that will otherwise cost you a day rediscovering, including three
code comments that are actively wrong.

Do not start a phase whose open question in §6 is unanswered. Ask the human.

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

## 2. What is actually true today (verified on `main`)

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

### 2.4 Already built — do not rebuild these

- **Speaking state**: the participant avatar already gets a purple glow
  (`shadow-[0_0_18px_rgba(139,92,246,0.45)]`), a scale pulse and a 4px lift
  when `activeSpeaker` matches.
- **Participant row**: already 44px circles (`w-11 h-11`) with names beneath
  and a purple ring on the speaker.

Both are invisible in practice because `visibleCast` filters to the Teacher
alone unless `mode === 'classroom'`. What looks like a missing feature is a
mode that is never entered.

- **TTS caption sync**: `ClassroomCaptionSync.tsx` is ~300 lines that patch
  `HTMLMediaElement.prototype.play` and `speechSynthesis.speak` to pace the
  word reveal against *real audio* — weighting words by length and
  punctuation, using `boundary` events where available, with a specific
  fallback for **Android engines that do not emit them**. Any caption redesign
  must carry this forward or drop it deliberately. Do not delete it by
  accident while fixing §2.2.

### 2.5 Content, not CSS

Run-on lesson text ("1. … 2. … 3. …" as one paragraph) is composed
**server-side**. Progressive reveal requires the server to send structured
steps. Restyling the card will not split that paragraph.

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

One teacher, anchored beside the speech — the thing talking sits next to what
it is saying. Delete the large idle mascot. Replace the 🧑‍🏫 emoji with the
teacher mascot (assets land in `web/public/mascot/` as
`teacher_idle|speaking|thinking|celebrating.png`; each platform's own asset
folder mirrors it).

Full-size mascot appears only for **moments that earn it** — a correct
demonstration, a checkpoint, the loading state. Never as permanent furniture.

### 4.3 Orientation

**Portrait is primary.** Landscape is an *expand gesture for the board* — a
wide canvas for diagrams, schema comparisons, figures — not the default and
not a lock.

**Remove the iOS force-landscape.** Taking a learner's orientation away is too
strong a move to make on their behalf, and it is the reason the platforms
diverged.

### 4.4 Chrome and exit

**Hide chrome. Never hide escape.**

Always visible, never fades:
- One exit affordance, top-left, ≥44px touch target. May rest at ~40% opacity.
  May not be absent.
- The caption.
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

### 4.6 The card reinforces; it does not duplicate the lecture

The teacher teaches; the card anchors. Reveal steps progressively rather than
dumping a numbered paragraph. Requires §2.5 server work.

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

The engine already works this way — it generates a teaching scene, then a
question, grades it, and adapts. **The UI does not express it.** Make the card
*become* the question rather than sitting beside it. This is mostly client
work over machinery that already exists, and it is the product's strongest
differentiator from a slide viewer.

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

## 6. Open questions — do not guess

**a. ~~Do classmates actually speak?~~ ANSWERED — no, and they cannot.**
`_get_peer_states` returns a single hard-coded stub ("AI peers are synthetic —
no DB table") and nothing on the wire can make a peer a speaker. The row was
removed in Phase 1. Building real peer participation is a feature, not a
layout fix; the CAST colour map is kept so a peer would be identifiable the
day it exists.

**b. What does the classroom look like with sound off?** If the teacher
speaks and the card only reinforces, then with audio off the teacher says
nothing and the card is all there is. On a phone, in public, most people have
sound off. This mode is currently undesigned.

**c. Are sessions resumable?** Exit is `router.back()`; the socket closes. If
leaving at minute 3 of 45 loses the session, nobody will risk the exit button
and §4.4 is moot. Resumability is the prerequisite that makes an immersive
mode safe.

**d. What replaces the written answer?** The human has decided typed answers
create too much friction. That removes the top rung of the evidence ladder —
the strongest claim left becomes "picked the right option", and recognition is
explicitly not mastery in this product.

Recommended: **spoken answers.** The classroom is already voice-first and iOS
already ships `VoiceInputService`; the same evidence rung, no keyboard.
Alternatives that avoid typing: ordering steps, or constructing an answer from
tiles. **Not yet agreed — confirm before building.** If the decision is
multiple-choice only, readiness must say plainly what it is based on.

---

## 6b. The largest unused backend capability

The Classroom now writes, per graded answer: an evidence rung (recognition →
application → transfer → retention), a confidence damped by how many hints
were used, a misconception tag, and an updated mastery score per concept.

**The learner is shown none of it.** Nothing says "you have now shown you can
*apply* this, not just recognise it"; nothing indicates a hint lowered what an
answer counted for; nothing shows which concepts are solid.

That is the biggest gap between what the backend knows and what the interface
says — bigger than any component. It is also the easiest place to start
claiming things nothing measured, so whatever is shown must read off the same
rungs the server recorded. *Recognised* is not *applied*.

Component-level gaps are small by comparison: `Celebration` is emitted by the
engine and dropped by the web store; `TextBlock`, `ChatBubble`,
`TypingIndicator` and `ReflectionPrompt` are in the backend enum but never
emitted, so they are dead registry entries rather than client gaps.

---

## 7. Order of work

**Phase 1 — Stop the bleeding** — ✅ SHIPPED
1. Collapse the two caption renderers into one; build the 56–72px two-line
   strip (§4.1); restore the `sr-only` span; preserve the TTS sync.
2. Delete the duplicate teacher representations; one presence beside the
   speech (§4.2).
3. Fix the safe-area collision and secondary-text contrast.

**Phase 2 — Structure** — ✅ SHIPPED
4. Header consolidation (§4.5) and the colour system (§4.7).
5. Action bar (§4.8).
6. Correct or delete the three stale parity comments (§2.1); extend the parity
   gate (§5.4).

**Phase 3 — Immersion** *(needs 6c)*
7. Auto-hiding chrome on web with a permanent exit (§4.4), matching the
   existing Android/iOS timeout.
8. Remove the iOS force-landscape; add rotate-to-expand-the-board (§4.3).

**Phase 4 — The real differentiator** *(needs 6a, 6b, 6d)*
9. Card-becomes-the-question (§4.9).
10. Server-side structured lesson steps (§2.5).

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
