# Guided classroom payloads

`GuidedTeaching.json` contains deterministic, authored scenes exported through
the production `AdaptiveSession` runner in `Hectorg0827/LyoBackendJune`:

```sh
python -m tests.export_guided_fixtures ../Lyo_Da_One/Sources/Tests/Fixtures/GuidedTeaching.json
```

iOS `GuidedTeachingTests`, Android `GuidedTeachingTest` and web
`teaching-activity.test.mjs` consume this same file. These fixtures verify the
wire contract and rendering adapters, not the quality of live model output.

`diagnostic` is the scene every unit now opens with: one short teacher line
and one real question, before anything has been taught. It is a `QuizCard`,
answerable with a single tap — a learner who has never met the skill can still
answer, where a blank box in front of an unfamiliar skill reads as a test. Its
four options are the answer, two distractors and "I'm not sure yet", so not
knowing never forces a guess. It carries no CTA — a Continue there would make
answering optional — and no teaching visual, because a visual whose description
explains why the answer is the answer would hand the answer over above the
question. Its board may carry the situation; never the reasoning.

Everything that makes the tap *diagnostic* stays server-side, and the fixture
is the proof: every option arrives with `is_correct`, both feedback fields and
`misconception_tag` null. The key would otherwise sit on the device while the
learner is still deciding, and the misconception each distractor reveals is a
judgement about them, made for the next teaching turn.

What the learner taps decides where the unit starts, one rung below what the
answer suggests. `orientation` and the modelled example that follow are the
route for a learner who does not have the skill yet, not the unconditional
opening they used to be. `focused_example` is the same opening compressed to a
single beat: what a near miss earns, since that learner has the idea and
slipped on one step, and being taught what you already know is how a learner
stops listening. Both carry the example and the visual, and both end in
Continue; the difference is how much teacher comes before the next question.

Continue uses the server's CTA component ID. Teaching tools use their own
`visual:<beat or checkpoint ID>` and send `update_activity`, never an answer or
completion signal. The existing typed/dictated input stays available after the
modelled example and supported choice. All worked examples remain visible beside
the current question. Graph axes are fixed while parameters change.

The Android production navigation uses `ui/screens/classroom/ClassroomScreen.kt`;
the same `TeachingVisualCard` is also registered with the A2UI catalog.
