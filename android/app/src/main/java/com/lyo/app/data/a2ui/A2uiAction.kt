package com.lyo.app.data.a2ui

import com.google.gson.JsonElement
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

/**
 * Renderer→Agent Action message (A2UI protocol v1.0). Fired when the user
 * interacts with a component that declares an `action` (e.g. a ChoicePicker
 * chip tap, a Button press, a TransferInput submit). `context` carries the
 * component's resolved data bindings at the moment of the action — e.g. a
 * ChoicePicker's selected option id/label — which is exactly the
 * information ui.classroom.ClassroomBridge.actionToUserAction needs to
 * build the real backend's `user_action` envelope.
 *
 * `wantResponse`/`actionId` (the protocol's request/response extension) are
 * modeled for completeness but unused by this classroom — every classroom
 * action is fire-and-forget from the renderer's point of view; the *reply*
 * comes back later as an ordinary `component_render` on the classroom
 * socket, not as an A2UI actionResponse.
 */
data class A2uiAction(
    val name: String,
    val surfaceId: String,
    val sourceComponentId: String,
    val timestamp: String,
    val context: Map<String, JsonElement> = emptyMap(),
    val wantResponse: Boolean = false,
    val actionId: String? = null,
)

/** ISO-8601 UTC timestamp for A2uiAction.timestamp — kept separate from
 *  data.classroom's isoTimestampNow() so the a2ui package stays classroom-
 *  agnostic (it's a two-line formatter, not worth a cross-package import). */
fun isoTimestampNowA2ui(): String {
    val format = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US)
    format.timeZone = TimeZone.getTimeZone("UTC")
    return format.format(Date())
}
