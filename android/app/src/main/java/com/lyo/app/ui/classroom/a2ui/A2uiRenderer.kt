package com.lyo.app.ui.classroom.a2ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.lyo.app.data.a2ui.A2uiAction
import com.lyo.app.data.a2ui.A2uiSurfaceState
import com.lyo.app.data.a2ui.resolvePointer

/**
 * The generic A2UI Compose renderer — the entirety of the flat-component/
 * ID-graph resolution algorithm from the protocol spec (a2ui_protocol.md,
 * "Flat Component Structure & ID References") lives in this file and
 * nowhere else. Nothing here is classroom-specific; it would work for any
 * A2UI surface given any A2uiCatalog. Classroom-specific composables live
 * in ui.classroom.catalog.ClassroomCatalog and are merged with
 * ui.classroom.a2ui.BasicCatalog by ClassroomScreen.
 */
@Composable
fun A2uiSurface(
    state: A2uiSurfaceState,
    catalog: A2uiCatalog,
    onAction: (A2uiAction) -> Unit,
    modifier: Modifier = Modifier,
) {
    val rootId = state.rootId ?: return
    // No surface created yet (e.g. before the classroom's first turn
    // arrives) — render nothing; ClassroomScreen owns its own
    // "preparing your classroom…" loading state for that gap.
    RenderNode(
        componentId = rootId,
        state = state,
        catalog = catalog,
        scopePath = "/",
        onAction = onAction,
    )
}

@Composable
internal fun RenderNode(
    componentId: String,
    state: A2uiSurfaceState,
    catalog: A2uiCatalog,
    scopePath: String,
    onAction: (A2uiAction) -> Unit,
) {
    val component = state.components[componentId] ?: return
    val renderer = catalog.renderers[component.component]
    if (renderer == null) {
        // Never crash on an unrecognized component type — surface it
        // visibly (useful during development) and move on, matching the
        // resilience philosophy of the rest of the wire parsing.
        Text(
            text = "Unknown component: ${component.component}",
            color = Color.Red,
            style = MaterialTheme.typography.labelSmall,
            modifier = Modifier
                .padding(4.dp)
                .background(Color.Black.copy(alpha = 0.4f)),
        )
        return
    }

    val scope = A2uiRenderScope(
        component = component,
        surface = state,
        scopePath = scopePath,
        onAction = onAction,
        renderChild = { childId ->
            if (childId != null) {
                RenderNode(childId, state, catalog, scopePath, onAction)
            }
        },
        renderChildren = { childIds ->
            childIds.forEach { childId -> RenderNode(childId, state, catalog, scopePath, onAction) }
        },
        catalog = catalog,
    )
    with(renderer) { scope.Render() }
}

/**
 * Renders one instance of `componentId` per element of the data-model array
 * at `templatePath` (which must be an absolute "/"-prefixed path — template
 * binding always anchors to the surface root, never to a relative scope),
 * each with its own `scopePath` set to that element's absolute path (e.g.
 * "/board/history/0", "/board/history/1", ...) so relative PathRefs inside
 * the template resolve against the right array element. Used by
 * BasicCatalog's `List` renderer when its `children` is
 * A2uiChildren.Template rather than A2uiChildren.Fixed.
 */
@Composable
internal fun RenderTemplateChildren(
    templatePath: String,
    componentId: String,
    state: A2uiSurfaceState,
    catalog: A2uiCatalog,
    onAction: (A2uiAction) -> Unit,
) {
    val array = state.dataModel.resolvePointer(templatePath)
    val count = array?.takeIf { it.isJsonArray }?.asJsonArray?.size() ?: 0
    for (index in 0 until count) {
        RenderNode(
            componentId = componentId,
            state = state,
            catalog = catalog,
            scopePath = "$templatePath/$index",
            onAction = onAction,
        )
    }
}
