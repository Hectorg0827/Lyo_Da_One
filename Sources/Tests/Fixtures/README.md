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
and a real question, before anything has been taught. It carries no CTA — a
Continue there would make answering optional — and no teaching visual, because
a visual whose description explains why the answer is the answer would hand the
answer over above the question. Its board may carry the situation; never the
reasoning. What the learner does with it decides where the unit starts, so
`orientation` and the modelled example that follow are the route for a learner
who does not have the skill yet, not the unconditional opening they used to be.

Continue uses the server's CTA component ID. Teaching tools use their own
`visual:<beat or checkpoint ID>` and send `update_activity`, never an answer or
completion signal. The existing typed/dictated input stays available after the
modelled example and supported choice. All worked examples remain visible beside
the current question. Graph axes are fixed while parameters change.

The Android production navigation uses `ui/screens/classroom/ClassroomScreen.kt`;
the same `TeachingVisualCard` is also registered with the A2UI catalog.
