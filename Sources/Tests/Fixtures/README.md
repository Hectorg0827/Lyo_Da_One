# Guided classroom payloads

`GuidedTeaching.json` contains deterministic, authored scenes exported through
the production `AdaptiveSession` runner in `Hectorg0827/LyoBackendJune`:

```sh
python -m tests.export_guided_fixtures ../Lyo_Da_One/Sources/Tests/Fixtures/GuidedTeaching.json
```

iOS `GuidedTeachingTests`, Android `GuidedTeachingTest` and web
`teaching-activity.test.mjs` consume this same file. These fixtures verify the
wire contract and rendering adapters, not the quality of live model output.

Continue uses the server's CTA component ID. Teaching tools use their own
`visual:<beat or checkpoint ID>` and send `update_activity`, never an answer or
completion signal. The existing typed/dictated input stays available after the
modelled example and supported choice. All worked examples remain visible beside
the current question. Graph axes are fixed while parameters change.

The Android production navigation uses `ui/screens/classroom/ClassroomScreen.kt`;
the same `TeachingVisualCard` is also registered with the A2UI catalog.
