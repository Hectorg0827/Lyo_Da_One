# Adaptive classroom workspace

The explanation and the board have different jobs. Lyo's real mascot sits beside
the explanation, above the supporting teaching tools. The board uses the global
brand and surface tokens; it does not introduce a new classroom palette.

## Shared display contract

The backend can attach `board_document: {version: 1, blocks: [...]}` to an existing
`ExampleBlock`. Its original `content` remains the complete fallback for older
clients. New clients reject a malformed or unsupported document as a whole and
render that fallback. These fields affect presentation only.

| Block | Authored material | Rendering |
| --- | --- | --- |
| `text` | A short anchor or explanation | Readable notes; supporting prose can expand beside a visual |
| `steps` | A numbered worked process | Ordered steps |
| `bullets` | Key terms, evidence, rules | Compact anchors |
| `code` | A complete fenced example and its language | A code surface that preserves indentation; no execution |
| `table` | Column labels and rectangular rows | A horizontally scrollable comparison or data table |

Selection follows the material's structure, not a course-name lookup. Existing
`TeachingVisual` renderers still handle fractions, comparisons, sequences, graphs,
processes, timelines, number lines and approved images. Existing server-paced
teaching beats reveal the next explanation and tool together. This change adds no
model call, generated script, grading rule or independent client lesson advance.

## Distinct teaching roles

Components can carry `presentation_role`. Legacy recovery and memory IDs also
resolve to the correct role while the two repositories roll out independently.

| Role | Classroom area |
| --- | --- |
| `narration` | Lyo explains; one caption renderer and an accessible full transcript |
| `board` | Teaching workspace |
| `reference` | Keep in view; remembered visuals do not mutate the active activity |
| `practice` | Your turn; existing answer controls and server evidence gates |
| `feedback` | Feedback on the learner's reasoning |
| `recovery` | Lesson paused; the scene's Retry or ungraded continuation action stays reachable |
| `details` | Expandable supporting notes and sources |

The web retains its audio-clock caption synchronization. Native clients retain
their existing narration services and expose complete explanations through the
transcript. The iOS board now scrolls independently of the explanation and has a
visible Continue/Retry button in addition to its existing gestures. Android keeps
its existing orientation policy; this change does not force a new one.

## Verification

Behavioral tests cover mixed subjects, malformed documents, code indentation,
legacy fallbacks, role grouping, recovery, adapter/bridge propagation and preserved
answer routing. Web tests render the actual board JSX and markdown libraries to
check list/table semantics and escaped content. Native compilation and tests run
in the repository's iOS and Android CI jobs.

Production model output and physical-device visual validation remain separate
from scripted fixtures and build checks.
