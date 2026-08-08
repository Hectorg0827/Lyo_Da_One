package com.lyo.app.ui.classroom.a2ui

import androidx.compose.runtime.Composable
import com.google.gson.JsonElement
import com.lyo.app.data.a2ui.A2uiAction
import com.lyo.app.data.a2ui.A2uiComponent
import com.lyo.app.data.a2ui.A2uiMessage
import com.lyo.app.data.a2ui.A2uiSurfaceState
import com.lyo.app.data.a2ui.A2uiValue
import com.lyo.app.data.a2ui.isoTimestampNowA2ui

/**
 * A catalog is a named-lookup table of component-type → renderer. Mirrors
 * A2UI's "the client maintains a catalog of trusted, pre-approved
 * components" design (a2ui_protocol.md) — the renderer never executes
 * arbitrary agent-supplied code, only dispatches on a `component` string to
 * one of these pre-registered composables.
 *
 * Two catalogs are merged for the classroom screen: `BasicCatalog` (a
 * subset of A2UI's own 18-component basic catalog) and `ClassroomCatalog`
 * (classroom-specific components — the chalkboard, mascot, quiz card, etc.
 * — see ui.classroom.catalog.ClassroomCatalog).
 */
fun interface A2uiComponentRenderer {
    @Composable
    fun A2uiRenderScope.Render()
}

class A2uiCatalog(val renderers: Map<String, A2uiComponentRenderer>) {
    operator fun plus(other: A2uiCatalog): A2uiCatalog =
        A2uiCatalog(renderers + other.renderers)
}

/**
 * Everything one catalog renderer needs: the component it's rendering, the
 * surface it belongs to (for resolving bound properties and reading/writing
 * the data model), the current template/iteration scope, a way to dispatch
 * an outgoing action, and recursive rendering helpers for container
 * components (Column/Row/Card/etc.) to render their children without
 * needing to know about A2uiRenderer's internals.
 */
class A2uiRenderScope(
    val component: A2uiComponent,
    val surface: A2uiSurfaceState,
    val scopePath: String,
    val onAction: (A2uiAction) -> Unit,
    val renderChild: @Composable (String?) -> Unit,
    val renderChildren: @Composable (List<String>) -> Unit,
    /** The catalog this component was resolved from — carried through so a
     *  container renderer (e.g. List's template/iteration form) can recurse
     *  using the SAME merged catalog the surface was rendered with, rather
     *  than hardcoding a reference to any specific catalog. This is what
     *  keeps BasicCatalog genuinely classroom-agnostic: it never needs to
     *  import ui.classroom.catalog.ClassroomCatalog to recurse correctly. */
    val catalog: A2uiCatalog,
) {
    /** Resolves a declared property (literal / path-ref / call) to its
     *  current value, or null if the property is absent or unresolved. */
    fun resolve(propertyName: String): JsonElement? =
        surface.resolve(component.properties[propertyName], scopePath)

    fun resolveString(propertyName: String, default: String? = null): String? =
        resolve(propertyName)?.takeIf { it.isJsonPrimitive }?.asString ?: default

    fun resolveBoolean(propertyName: String, default: Boolean = false): Boolean =
        resolve(propertyName)?.takeIf { it.isJsonPrimitive }?.asBoolean ?: default

    fun resolveStringList(propertyName: String): List<String> =
        resolve(propertyName)?.takeIf { it.isJsonArray }
            ?.asJsonArray
            ?.mapNotNull { if (it.isJsonPrimitive) it.asString else null }
            ?: emptyList()

    /** Literal (non-bindable) property — for values a component declares
     *  directly rather than through the data model, e.g. ChoicePicker's
     *  `displayStyle`/`variant`. Falls back to resolve() so a bound value
     *  also works if a future turn wants to make it dynamic. */
    fun literalString(propertyName: String, default: String? = null): String? {
        val prop = component.properties[propertyName]
        if (prop is A2uiValue.Literal && prop.value.isJsonPrimitive) return prop.value.asString
        return resolveString(propertyName, default)
    }

    /**
     * Two-way binding contract (a2ui_protocol.md): when the user interacts
     * with an input component, the renderer updates the LOCAL data model at
     * the bound path immediately — this does not touch the network. Network
     * sync only happens when fireAction() is explicitly called.
     */
    fun writeLocalDataModel(path: String, value: JsonElement) {
        surface.applyUpdateDataModel(A2uiMessage.UpdateDataModel(surface.surfaceId, path, value))
    }

    /**
     * The explicit renderer→agent Action message — fired on a genuine user
     * action (a button press, a chip tap, a submit), never on every
     * keystroke. `extraContext` is merged with the component's own bound
     * properties resolved at the moment of firing, giving
     * ClassroomBridge.actionToUserAction everything it needs to build the
     * real backend's user_action envelope.
     */
    fun fireAction(name: String, extraContext: Map<String, JsonElement> = emptyMap()) {
        val resolvedContext = component.properties.mapNotNull { (key, value) ->
            surface.resolve(value, scopePath)?.let { key to it }
        }.toMap()
        onAction(
            A2uiAction(
                name = name,
                surfaceId = surface.surfaceId,
                sourceComponentId = component.id,
                timestamp = isoTimestampNowA2ui(),
                context = resolvedContext + extraContext,
            ),
        )
    }
}
