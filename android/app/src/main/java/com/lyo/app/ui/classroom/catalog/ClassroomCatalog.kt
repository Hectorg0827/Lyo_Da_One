package com.lyo.app.ui.classroom.catalog

import com.lyo.app.ui.classroom.a2ui.A2uiCatalog
import com.lyo.app.ui.classroom.a2ui.A2uiComponentRenderer

/**
 * The classroom-specific component catalog, merged with
 * ui.classroom.a2ui.BasicCatalog by ClassroomScreen
 * (`BasicCatalog + ClassroomCatalog`). Every component type here is emitted
 * exclusively by ui.classroom.ClassroomBridge — see that file's
 * `directorTurnToA2ui`/`onServerEvent` for exactly which wire-contract shape
 * produces which of these.
 *
 * Component-type-name ↔ renderer mapping, and how each was designed per the
 * implementation plan's catalog-design pass:
 * - ChalkboardText, SummaryBlock, SourceLine, BulletsBlock: data-bound
 *   custom components (their content flows through the generic
 *   literal/path-ref resolution the same way basic-catalog components do).
 * - HighlightSpotlight, MascotAvatar, DismissalCard, ChartBlock: opaque
 *   native views (bespoke animation/layout with no useful further
 *   decomposition into generic bindable sub-properties).
 * - QuizCard, TransferInput: hybrid — bespoke shells that internally reuse
 *   BasicCatalog primitives (ChoicePicker's ClassroomChipRow, TextField-style
 *   input) rather than duplicating that rendering.
 * - MermaidBlock, LatexBlock: v1 fallback (styled raw-source text, see each
 *   file's doc comment) pending a possible v2 WebView upgrade.
 * - ExplorableBlock: v1 static (no live parameter re-plotting yet).
 */
val ClassroomCatalog: A2uiCatalog = A2uiCatalog(
    mapOf(
        "ChalkboardText" to A2uiComponentRenderer { ChalkboardTextRenderer() },
        "HighlightSpotlight" to A2uiComponentRenderer { HighlightSpotlightRenderer() },
        "MascotAvatar" to A2uiComponentRenderer { MascotAvatarRenderer() },
        "QuizCard" to A2uiComponentRenderer { QuizCardRenderer() },
        "TransferInput" to A2uiComponentRenderer { TransferInputRenderer() },
        "SummaryBlock" to A2uiComponentRenderer { SummaryBlockRenderer() },
        "SourceLine" to A2uiComponentRenderer { SourceLineRenderer() },
        "DismissalCard" to A2uiComponentRenderer { DismissalCardRenderer() },
        "CelebrationCard" to A2uiComponentRenderer { CelebrationCardRenderer() },
        "ChartBlock" to A2uiComponentRenderer { ChartBlockRenderer() },
        "ExplorableBlock" to A2uiComponentRenderer { ExplorableBlockRenderer() },
        "MermaidBlock" to A2uiComponentRenderer { MermaidBlockRenderer() },
        "LatexBlock" to A2uiComponentRenderer { LatexBlockRenderer() },
        "CodeBlock" to A2uiComponentRenderer { CodeBlockRenderer() },
        "BulletsBlock" to A2uiComponentRenderer { BulletsBlockRenderer() },
        "ImageBlock" to A2uiComponentRenderer { ImageBlockRenderer() },
    ),
)
