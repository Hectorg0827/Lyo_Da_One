package com.lyo.app.ui.screens.community

import com.google.gson.JsonParser
import com.lyo.app.data.api.EventGuestDto
import com.lyo.app.data.api.EventInviteDto
import com.lyo.app.data.api.LearningNodeDto
import java.io.IOException
import java.net.URI
import java.net.URLEncoder
import java.nio.charset.StandardCharsets
import java.text.NumberFormat
import java.time.Instant
import java.time.LocalDateTime
import java.time.OffsetDateTime
import java.time.ZoneId
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter
import java.util.Currency
import java.util.Locale
import kotlin.math.asin
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.roundToInt
import kotlin.math.sin
import kotlin.math.sqrt
import retrofit2.HttpException

/**
 * Pure Community discovery rules for the Android screens and their tests.
 * Mirrors web/src/lib/community-contract.mjs and iOS CommunityDiscovery.swift
 * so a filter, a "Search this area" decision, or an error message reads the
 * same on every platform. No Android or Compose types: plain JVM code.
 */
object CommunityDiscovery {
    const val DEFAULT_LATITUDE = 40.7128
    const val DEFAULT_LONGITUDE = -74.006
    const val DEFAULT_LABEL = "New York City"
    const val DEFAULT_RADIUS_KM = 12.0
    const val NEARBY_RADIUS_KM = 3.0
    const val MAX_SEARCH_RADIUS_KM = 50.0
    const val WEB_BASE_URL = "https://lyoai.app"

    /** Every map category, in the order the filter row shows them. */
    val nodeCategories = listOf(
        "event", "workshop", "class", "study_group", "tutor", "library", "museum", "educational_center",
    )
    val schoolPlaceTypes = listOf("university", "college")
    val learningCenterPlaceTypes = listOf(
        "language_school", "music_school", "prep_school", "training", "community_centre",
    )

    // ── Filters ──────────────────────────────────────────────────────────────

    enum class FilterModifier { FREE, TODAY, WEEK, NEARBY }

    /**
     * A filter chip. `categories` / `placeTypes` narrow *what* appears; the
     * modifiers narrow *which* of those appear, so any combination is
     * meaningful: "Workshops + Free + This week".
     */
    data class Filter(
        val id: String,
        val label: String,
        val categories: List<String> = emptyList(),
        val placeTypes: List<String> = emptyList(),
        val modifier: FilterModifier? = null,
    ) {
        val isTimeWindow: Boolean get() = modifier == FilterModifier.TODAY || modifier == FilterModifier.WEEK
    }

    val filters = listOf(
        Filter("events", "Events", listOf("event")),
        Filter("libraries", "Libraries", listOf("library")),
        Filter("museums", "Museums", listOf("museum")),
        Filter("classes", "Classes", listOf("class")),
        Filter("workshops", "Workshops", listOf("workshop")),
        Filter("study_groups", "Study groups", listOf("study_group")),
        Filter("schools", "Schools & universities", listOf("educational_center"), schoolPlaceTypes),
        Filter("learning_centers", "Learning centers", listOf("educational_center"), learningCenterPlaceTypes),
        Filter("tutors", "Tutors", listOf("tutor")),
        Filter("free", "Free", modifier = FilterModifier.FREE),
        Filter("today", "Today", modifier = FilterModifier.TODAY),
        Filter("week", "This week", modifier = FilterModifier.WEEK),
        Filter("nearby", "Nearby", modifier = FilterModifier.NEARBY),
    )

    fun filter(id: String): Filter? = filters.firstOrNull { it.id == id }

    /** Toggle a chip. "Today" and "This week" are mutually exclusive. */
    fun toggle(active: Set<String>, id: String): Set<String> {
        if (id in active) return active - id
        val chosen = filter(id) ?: return active
        var next = active
        if (chosen.isTimeWindow) next = next - filters.filter { it.isTimeWindow }.map { it.id }.toSet()
        return next + id
    }

    data class FilterQuery(
        val categories: List<String> = emptyList(),
        val placeTypes: List<String> = emptyList(),
        val freeOnly: Boolean = false,
        val timeWindow: String? = null,
        val nearby: Boolean = false,
    )

    /** Translate the active chips into `/community/nearby` parameters. */
    fun query(active: Set<String>): FilterQuery {
        val categories = sortedSetOf<String>()
        val placeTypes = sortedSetOf<String>()
        var broadPlaces = false
        var freeOnly = false
        var timeWindow: String? = null
        var nearby = false
        for (filter in filters) {
            if (filter.id !in active) continue
            if (filter.categories.isNotEmpty()) {
                categories += filter.categories
                if (filter.placeTypes.isNotEmpty()) placeTypes += filter.placeTypes
                else if ("educational_center" in filter.categories) broadPlaces = true
            }
            when (filter.modifier) {
                FilterModifier.FREE -> freeOnly = true
                FilterModifier.TODAY -> timeWindow = "today"
                FilterModifier.WEEK -> timeWindow = "week"
                FilterModifier.NEARBY -> nearby = true
                null -> Unit
            }
        }
        return FilterQuery(
            categories = categories.toList(),
            placeTypes = if (broadPlaces) emptyList() else placeTypes.toList(),
            freeOnly = freeOnly,
            timeWindow = timeWindow,
            nearby = nearby,
        )
    }

    fun activeFilterLabels(active: Set<String>): List<String> =
        filters.filter { it.id in active }.map { it.label }

    // ── Geography ────────────────────────────────────────────────────────────

    private const val EARTH_RADIUS_KM = 6371.0088

    fun distanceKm(latitudeA: Double, longitudeA: Double, latitudeB: Double, longitudeB: Double): Double {
        fun radians(degrees: Double) = degrees * Math.PI / 180
        val dLat = radians(latitudeB - latitudeA)
        val dLng = radians(longitudeB - longitudeA)
        val h = sin(dLat / 2).pow(2) +
            cos(radians(latitudeA)) * cos(radians(latitudeB)) * sin(dLng / 2).pow(2)
        return 2 * EARTH_RADIUS_KM * asin(min(1.0, sqrt(h)))
    }

    data class SearchArea(val latitude: Double, val longitude: Double, val radiusKm: Double)

    /** Search area covering a visible map viewport: its center and half-diagonal. */
    fun areaForBounds(north: Double, south: Double, east: Double, west: Double): SearchArea {
        val latitude = (north + south) / 2
        val longitude = (east + west) / 2
        val radius = min(MAX_SEARCH_RADIUS_KM, max(0.5, distanceKm(latitude, longitude, north, east)))
        return SearchArea(latitude, longitude, (radius * 10).roundToInt() / 10.0)
    }

    /**
     * Whether the visible map differs enough from the searched area to offer
     * "Search this area". Small pans and zooms never trigger a request.
     */
    fun shouldOfferAreaSearch(searched: SearchArea?, visible: SearchArea?): Boolean {
        if (searched == null || visible == null) return false
        val moved = distanceKm(searched.latitude, searched.longitude, visible.latitude, visible.longitude)
        val larger = max(searched.radiusKm, visible.radiusKm)
        val smaller = max(0.1, min(searched.radiusKm, visible.radiusKm))
        return moved > searched.radiusKm * 0.35 || larger / smaller > 1.8
    }

    /** Leaflet zoom that shows roughly `radiusKm` around a point on a phone. */
    fun zoomForRadius(radiusKm: Double): Int = when {
        radiusKm <= 1.5 -> 15
        radiusKm <= 3.5 -> 14
        radiusKm <= 7 -> 13
        radiusKm <= 15 -> 12
        radiusKm <= 30 -> 11
        else -> 10
    }

    // ── Presentation ─────────────────────────────────────────────────────────

    private val categoryLabels = mapOf(
        "event" to "Event",
        "workshop" to "Workshop",
        "class" to "Class",
        "study_group" to "Study group",
        "tutor" to "Tutor",
        "library" to "Library",
        "museum" to "Museum",
        "educational_center" to "Learning center",
    )

    private val placeTypeLabels = mapOf(
        "university" to "University",
        "college" to "College",
        "language_school" to "Language school",
        "music_school" to "Music school",
        "prep_school" to "Tutoring center",
        "training" to "Training center",
        "community_centre" to "Community learning center",
        "planetarium" to "Planetarium",
        "museum" to "Museum",
        "library" to "Library",
        "tutoring" to "Tutoring",
    )

    private val lifecycleLabels = mapOf(
        "upcoming" to "Upcoming",
        "today" to "Today",
        "live" to "Happening now",
        "past" to "Ended",
        "cancelled" to "Cancelled",
    )

    fun categoryLabel(category: String, placeType: String? = null): String =
        placeType?.let { placeTypeLabels[it] } ?: categoryLabels[category] ?: "Learning"

    fun lifecycleLabel(lifecycle: String?): String? = lifecycle?.let { lifecycleLabels[it] }

    fun formatDistance(km: Double?): String? {
        if (km == null || !km.isFinite()) return null
        if (km < 0.1) return "Here"
        if (km < 1) return "${(km * 100).roundToInt() * 10} m"
        if (km < 10) return String.format(Locale.US, "%.1f km", km)
        return "${km.roundToInt()} km"
    }

    fun formatPrice(isFree: Boolean?, amount: Double?, currency: String?): String? {
        if (isFree == true) return "Free"
        if (amount != null) {
            val code = currency?.takeIf { it.isNotBlank() } ?: "USD"
            return runCatching {
                val format = NumberFormat.getCurrencyInstance(Locale.US)
                format.currency = Currency.getInstance(code)
                val whole = amount == Math.floor(amount)
                format.minimumFractionDigits = if (whole) 0 else 2
                format.maximumFractionDigits = 2
                format.format(amount)
            }.getOrElse { "$code $amount" }
        }
        if (isFree == false) return "Paid"
        return null
    }

    /** Server instants: ISO-8601 with an offset, or a legacy UTC timestamp without one. */
    fun parseInstant(value: String?): Instant? {
        if (value.isNullOrBlank()) return null
        return runCatching { OffsetDateTime.parse(value).toInstant() }
            .recoverCatching { LocalDateTime.parse(value).toInstant(ZoneOffset.UTC) }
            .getOrNull()
    }

    /** "Sun, Sep 27 · 6:00 PM – 8:00 PM" in the viewer's own timezone. */
    fun formatWhen(
        startsAt: String?,
        endsAt: String?,
        zone: ZoneId = ZoneId.systemDefault(),
        locale: Locale = Locale.getDefault(),
    ): String? {
        val start = parseInstant(startsAt)?.atZone(zone) ?: return null
        val day = DateTimeFormatter.ofPattern("EEE, MMM d", locale)
        val time = DateTimeFormatter.ofPattern("h:mm a", locale)
        val startText = "${start.format(day)} · ${start.format(time)}"
        val end = parseInstant(endsAt)?.atZone(zone) ?: return startText
        if (start.toLocalDate() == end.toLocalDate()) return "$startText – ${end.format(time)}"
        return "$startText – ${end.format(DateTimeFormatter.ofPattern("MMM d", locale))}, ${end.format(time)}"
    }

    /** A plain http(s) URL, or null for anything else (javascript:, data:, …). */
    fun safeWebUrl(value: String?): String? {
        val trimmed = value?.trim().orEmpty()
        if (trimmed.isEmpty()) return null
        val uri = runCatching { URI(trimmed) }.getOrNull() ?: return null
        val scheme = uri.scheme?.lowercase() ?: return null
        if (scheme != "https" && scheme != "http") return null
        if (uri.host.isNullOrBlank()) return null
        return trimmed
    }

    private fun encodeComponent(value: String): String =
        URLEncoder.encode(value, StandardCharsets.UTF_8.name())
            .replace("+", "%20")
            .replace("%21", "!")
            .replace("%27", "'")
            .replace("%28", "(")
            .replace("%29", ")")
            .replace("%7E", "~")

    /** Directions to a node's public location; never includes the viewer's position. */
    fun directionsUrl(node: LearningNodeDto): String? {
        val latitude = node.latitude
        val longitude = node.longitude
        if (latitude != null && longitude != null) {
            return "https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude"
        }
        if (node.attendanceMode == "online" || (node.isOnline && node.attendanceMode != "hybrid")) return null
        val place = listOf(node.address, node.locationName).firstOrNull { !it.isNullOrBlank() } ?: return null
        return "https://www.google.com/maps/dir/?api=1&destination=${encodeComponent(place)}"
    }

    /** The same stable path the web app serves for this item. */
    fun detailPath(kind: String, id: String): String =
        if (kind == "event") "/community/events/${encodeComponent(id)}"
        else "/community/places/$kind/${encodeComponent(id)}"

    fun shareUrl(kind: String, id: String): String = WEB_BASE_URL + detailPath(kind, id)

    // ── Invitations ──────────────────────────────────────────────────────────

    private val inviteTokenPattern = Regex("^[A-Za-z0-9_-]{16,64}$")
    private val inviteInUrlPattern = Regex("/community/invite/([A-Za-z0-9_-]{16,64})(?:[/?#]|$)")

    /**
     * The invite code in a pasted link (https://lyoai.app/community/invite/…,
     * lyoapp://community/invite/…) or a bare code; null for anything else.
     */
    fun inviteTokenFromText(text: String?): String? {
        val value = text?.trim().orEmpty()
        if (value.isEmpty()) return null
        if (inviteTokenPattern.matches(value)) return value
        return inviteInUrlPattern.find(value)?.groupValues?.get(1)
    }

    /** The invite code in a link the app was opened with; a bare code or any other link is ignored. */
    fun inviteTokenFromAppLink(data: String?): String? {
        if (data.isNullOrBlank() || "/community/invite/" !in data) return null
        return inviteTokenFromText(data)
    }

    fun invitePath(token: String): String = "/community/invite/$token"

    fun inviteUrl(token: String): String = WEB_BASE_URL + invitePath(token)

    data class InviteNotice(val title: String, val body: String)

    /** What someone holding a link that no longer works is told. */
    val inviteStatusNotices: Map<String, InviteNotice> = mapOf(
        "expired" to InviteNotice("This invite has expired", "Ask the host to send you a new link."),
        "revoked" to InviteNotice("This invite was turned off", "The host turned off this link. Ask them for a new one."),
        "used_up" to InviteNotice(
            "This invite has been used up",
            "It was used as many times as the host allowed. Ask them for a new one.",
        ),
        "ended" to InviteNotice("This event has ended", "You can still browse other learning events near you."),
        "cancelled" to InviteNotice("This event was cancelled", "The host cancelled it, so it no longer takes guests."),
    )

    /** Why a link can't be used, or null when it can ("valid"). */
    fun inviteNotice(status: String): InviteNotice? {
        if (status == "valid") return null
        return inviteStatusNotices[status]
            ?: InviteNotice("This invite can't be used", "Ask the host to send you a new link.")
    }

    /** A wrong or deleted link reads differently from a network problem. */
    fun inviteError(error: Throwable): FriendlyError {
        if (error is HttpException && error.code() == 404) {
            return FriendlyError(
                "This invite link isn't valid",
                "Check that you copied the whole link, or ask the host for a new one.",
                retry = false,
            )
        }
        return friendlyError(error, "open this invite")
    }

    /** "Used 2 of 5 · Expires Sep 30", or why a link stopped working. */
    fun describeInviteLink(
        link: EventInviteDto,
        now: Instant = Instant.now(),
        zone: ZoneId = ZoneId.systemDefault(),
        locale: Locale = Locale.getDefault(),
    ): String {
        val maxUses = link.maxUses
        val uses = if (maxUses != null) {
            "Used ${link.useCount} of $maxUses"
        } else {
            "Used ${link.useCount} ${if (link.useCount == 1) "time" else "times"}"
        }
        val expires = parseInstant(link.expiresAt)
        if (!link.active) {
            if (maxUses != null && link.useCount >= maxUses) return "$uses · Used up"
            if (expires != null && !expires.isAfter(now)) return "$uses · Expired"
            return "$uses · Turned off"
        }
        if (expires == null) return uses
        return "$uses · Expires ${expires.atZone(zone).format(DateTimeFormatter.ofPattern("MMM d", locale))}"
    }

    /** "Going · Joined with a link" for one row of the host's guest list. */
    fun describeGuest(guest: EventGuestDto): String {
        val answer = when (guest.rsvpStatus) {
            "going" -> "Going"
            "interested" -> "Interested"
            else -> "No reply yet"
        }
        return "$answer · ${if (guest.source == "direct") "Invited by name" else "Joined with a link"}"
    }

    /** Hosts manage invitations for private and unlisted events that are still on. */
    fun canManageInvites(node: LearningNodeDto, canEdit: Boolean): Boolean {
        if (!canEdit || node.kind != "event") return false
        if (node.visibility != "private" && node.visibility != "unlisted") return false
        return node.lifecycle != "past" && node.lifecycle != "cancelled"
    }

    /** Optimistic RSVP: the counts a learner sees the instant they tap. */
    fun applyingRsvp(status: String?, node: LearningNodeDto): LearningNodeDto {
        val previous = node.rsvpStatus ?: if (node.isAttending) "going" else null
        val going = (node.goingCount ?: 0) + (if (status == "going") 1 else 0) - (if (previous == "going") 1 else 0)
        val interested = (node.interestedCount ?: 0) +
            (if (status == "interested") 1 else 0) - (if (previous == "interested") 1 else 0)
        return node.copy(
            rsvpStatus = status,
            isAttending = status != null,
            goingCount = max(0, going),
            interestedCount = max(0, interested),
        )
    }

    // ── Errors ───────────────────────────────────────────────────────────────

    data class FriendlyError(val title: String, val body: String, val retry: Boolean) {
        /** One line for a snackbar: the specific reason when there is one. */
        val message: String get() = if (title == "That didn't work") body else "$title $body"
    }

    val offlineError = FriendlyError("You're offline", "Check your connection and try again.", retry = true)

    /**
     * Learner-facing copy for a failed Community request. Technical details
     * are logged by the caller, never shown as the message.
     */
    fun friendlyError(error: Throwable, action: String = "load nearby learning opportunities"): FriendlyError {
        if (error is IOException) return offlineError
        if (error is HttpException) {
            val body = runCatching { error.response()?.errorBody()?.string() }.getOrNull()
            return friendlyForStatus(error.code(), envelopeMessage(body), action)
        }
        return FriendlyError("We couldn't $action.", "Please try again in a moment.", retry = true)
    }

    fun friendlyForStatus(status: Int, serverMessage: String?, action: String): FriendlyError = when (status) {
        401 -> FriendlyError("Please sign in again", "Your session ended.", retry = false)
        403 -> FriendlyError("That didn't work", serverMessage ?: "You don't have permission to do that.", retry = false)
        404 -> FriendlyError("This is no longer available", "It may have been removed or made private.", retry = false)
        429 -> FriendlyError(
            "That didn't work",
            serverMessage ?: "You're going a little fast. Please wait a moment and try again.",
            retry = true,
        )
        400, 409, 422 -> FriendlyError("That didn't work", serverMessage ?: "Please check the details and try again.", retry = false)
        else -> FriendlyError("We couldn't $action.", "Please try again in a moment.", retry = true)
    }

    /**
     * The specific message from `{"error": {"message": …}}` or FastAPI's
     * `{"detail": "…"}`, skipping the envelope's generic placeholders.
     */
    fun envelopeMessage(body: String?): String? {
        if (body.isNullOrBlank()) return null
        val root = runCatching { JsonParser.parseString(body).asJsonObject }.getOrNull() ?: return null
        val nested = root.get("error")?.takeIf { it.isJsonObject }?.asJsonObject?.get("message")
        val detail = root.get("detail")
        val raw = when {
            nested != null && nested.isJsonPrimitive -> nested.asString
            detail != null && detail.isJsonPrimitive -> detail.asString
            else -> null
        }?.trim()
        if (raw.isNullOrEmpty()) return null
        if (raw.startsWith("HTTP ") || raw == "HTTP error occurred" || raw == "Request validation failed") return null
        return raw
    }
}
