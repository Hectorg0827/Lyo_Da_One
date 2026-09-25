package com.lyo.app.ui.screens.community

import android.util.Log
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.google.gson.GsonBuilder
import com.lyo.app.data.api.ApiClient
import com.lyo.app.data.api.CommunityAnalyticsEventDto
import com.lyo.app.data.api.CommunityEventRecordDto
import com.lyo.app.data.api.CommunityPostDto
import com.lyo.app.data.api.CreateCommunityEventRequest
import com.lyo.app.data.api.EventGuestCreateRequest
import com.lyo.app.data.api.EventGuestDto
import com.lyo.app.data.api.EventInviteCreateRequest
import com.lyo.app.data.api.EventInviteDto
import com.lyo.app.data.api.EventInvitesResponseDto
import com.lyo.app.data.api.EventReportRequest
import com.lyo.app.data.api.InvitePreviewDto
import com.lyo.app.data.api.LearningNodeDetailDto
import com.lyo.app.data.api.LearningNodeDto
import com.lyo.app.data.api.LearningNodeSaveRequest
import com.lyo.app.data.api.MyCommunityResponseDto
import com.lyo.app.data.api.NearbyLearningResponseDto
import com.lyo.app.data.api.PlaceSuggestionDto
import com.lyo.app.data.api.RsvpRequest
import com.lyo.app.data.api.SearchUserDto
import com.lyo.app.data.sync.SyncClient
import java.util.TimeZone
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.launch
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.RequestBody.Companion.toRequestBody
import retrofit2.HttpException
import retrofit2.Response

enum class LocationState { LOCATING, GRANTED, DENIED, UNAVAILABLE }

enum class SheetDetent { COLLAPSED, MEDIUM, EXPANDED }

/** A request to move the map camera; `token` makes a repeat move distinct. */
data class MapCommand(val latitude: Double, val longitude: Double, val zoom: Int, val token: Int)

private const val TAG = "LyoCommunity"

private fun Response<Unit>.requireSuccess() {
    if (!isSuccessful) throw HttpException(this)
}

/** Round the viewer's own position to ~100 m: enough for distances, no more. */
private fun Double.coarse(): Double = (this * 1000).roundToInt() / 1000.0

/**
 * Learning Around Me on Android. Everything that belongs to the learner
 * (saves, RSVPs, groups, hosted events) is read from and written to the
 * backend by account; this object only holds what is on screen. It lives
 * with the Community destination, so opening a detail page and coming back
 * keeps the map, search, and filters where the learner left them.
 */
class CommunityMapViewModel : ViewModel() {
    private val api = ApiClient.api
    private val zoneId: String get() = TimeZone.getDefault().id
    private val nullsGson = GsonBuilder().serializeNulls().create()

    // ── Where we are looking ──────────────────────────────────────────────────
    var locationState by mutableStateOf(LocationState.LOCATING)
        private set
    var userLocation by mutableStateOf<Pair<Double, Double>?>(null)
        private set
    var area by mutableStateOf(
        CommunityDiscovery.SearchArea(
            CommunityDiscovery.DEFAULT_LATITUDE,
            CommunityDiscovery.DEFAULT_LONGITUDE,
            CommunityDiscovery.DEFAULT_RADIUS_KM,
        ),
    )
        private set
    var areaLabel by mutableStateOf(CommunityDiscovery.DEFAULT_LABEL)
        private set
    var mapCommand by mutableStateOf(
        MapCommand(
            CommunityDiscovery.DEFAULT_LATITUDE,
            CommunityDiscovery.DEFAULT_LONGITUDE,
            CommunityDiscovery.zoomForRadius(CommunityDiscovery.DEFAULT_RADIUS_KM),
            0,
        ),
    )
        private set
    var showAreaSearch by mutableStateOf(false)
        private set
    var locationNoticeDismissed by mutableStateOf(false)
    /** The permission prompt is shown once per visit, not on every return. */
    var locationRequested = false
    private var baseline: CommunityDiscovery.SearchArea? = null
    private var pendingVisible: CommunityDiscovery.SearchArea? = null
    private var awaitingBaseline = true
    private var moveToUserOnFix = true
    private var trackedDenied = false

    // ── What we are looking for ───────────────────────────────────────────────
    var queryText by mutableStateOf("")
    var activeQuery by mutableStateOf("")
        private set
    var resolving by mutableStateOf(false)
        private set
    var filters by mutableStateOf(emptySet<String>())
        private set

    // ── Results ───────────────────────────────────────────────────────────────
    var nodes by mutableStateOf<List<LearningNodeDto>>(emptyList())
        private set
    var degradedSources by mutableStateOf<List<String>>(emptyList())
        private set
    var loading by mutableStateOf(false)
        private set
    var hasLoaded by mutableStateOf(false)
        private set
    var loadError by mutableStateOf<CommunityDiscovery.FriendlyError?>(null)
        private set
    var staleSince by mutableStateOf<Long?>(null)
        private set

    // ── Account ───────────────────────────────────────────────────────────────
    var myCommunity by mutableStateOf<MyCommunityResponseDto?>(null)
        private set
    var accountError by mutableStateOf<CommunityDiscovery.FriendlyError?>(null)
        private set
    var posts by mutableStateOf<List<CommunityPostDto>>(emptyList())
        private set
    var busyKeys by mutableStateOf(emptySet<String>())
        private set
    private val details = mutableStateMapOf<String, LearningNodeDetailDto>()
    /** Bumped after a create, edit, or delete so open detail pages re-read. */
    var revision by mutableIntStateOf(0)
        private set

    // ── Selection ─────────────────────────────────────────────────────────────
    var selectedKey by mutableStateOf<String?>(null)
        private set
    var clusterKeys by mutableStateOf<List<String>?>(null)
        private set
    var sheet by mutableStateOf(SheetDetent.COLLAPSED)

    private val _messages = MutableSharedFlow<String>(extraBufferCapacity = 8)
    /** Short confirmations and failures for a snackbar. */
    val messages: SharedFlow<String> = _messages

    private val cache = LinkedHashMap<String, Pair<NearbyLearningResponseDto, Long>>()
    private var nearbyJob: Job? = null
    private var accountJob: Job? = null
    private var started = false

    init {
        // Another device changed this account's Community: re-read it.
        viewModelScope.launch {
            SyncClient.events.collect { event ->
                if (event.eventType in setOf("community_updated", "context_updated")) refreshAll()
            }
        }
    }

    // ── Derived state ─────────────────────────────────────────────────────────

    val filterQuery: CommunityDiscovery.FilterQuery get() = CommunityDiscovery.query(filters)

    val effectiveRadiusKm: Double
        get() = if (filterQuery.nearby) min(area.radiusKm, CommunityDiscovery.NEARBY_RADIUS_KM) else area.radiusKm

    val listNodes: List<LearningNodeDto>
        get() = clusterKeys?.let { keys -> nodes.filter { it.key in keys } } ?: nodes

    val selectedNode: LearningNodeDto?
        get() = selectedKey?.let { key ->
            details[key]?.node ?: nodes.firstOrNull { it.key == key } ?: accountNodes().firstOrNull { it.key == key }
        }

    val resultsTitle: String
        get() {
            val place = when (areaLabel) {
                "Near you" -> "near you"
                "This area" -> "in this area"
                else -> "around $areaLabel"
            }
            if (loading && nodes.isEmpty()) return "Finding learning $place…"
            clusterKeys?.let { return "${listNodes.size} here" }
            if (loadError != null && nodes.isEmpty()) return "Learning opportunities"
            val count = nodes.size
            return "$count learning ${if (count == 1) "opportunity" else "opportunities"} $place"
        }

    fun isBusy(key: String) = key in busyKeys

    fun detail(kind: String, id: String): LearningNodeDetailDto? = details["$kind:$id"]

    /** The freshest copy of a node this screen knows about. */
    fun current(node: LearningNodeDto): LearningNodeDto =
        details[node.key]?.node ?: nodes.firstOrNull { it.key == node.key } ?: node

    private fun accountNodes(): List<LearningNodeDto> = myCommunity?.let {
        it.savedNodes + it.hosting.orEmpty() + it.going.orEmpty() + it.interested.orEmpty()
    }.orEmpty()

    // ── Lifecycle ─────────────────────────────────────────────────────────────

    /** First open: record it, read the account, and never wait on a permission prompt. */
    fun start() {
        if (started) return
        started = true
        track("community_opened", mapOf("surface" to "android"))
        refreshAccount()
        viewModelScope.launch {
            delay(1_500)
            if (!hasLoaded && !loading) loadNearby()
        }
    }

    fun refreshAll() {
        if (!started) return
        cache.clear()
        loadNearby(force = true)
        refreshAccount()
    }

    // ── Location (an ephemeral query input; never stored) ─────────────────────

    fun onLocating() {
        locationState = LocationState.LOCATING
        moveToUserOnFix = true
    }

    fun onLocation(latitude: Double, longitude: Double) {
        userLocation = latitude to longitude
        locationState = LocationState.GRANTED
        if (moveToUserOnFix) {
            moveToUserOnFix = false
            moveTo(latitude, longitude, CommunityDiscovery.DEFAULT_RADIUS_KM, "Near you")
            refreshAccount()
        }
    }

    fun onLocationDenied() {
        locationState = LocationState.DENIED
        if (!trackedDenied) {
            trackedDenied = true
            track("community_location_permission_denied")
        }
        if (!hasLoaded && !loading) loadNearby()
    }

    fun onLocationUnavailable() {
        if (userLocation == null) locationState = LocationState.UNAVAILABLE
        if (!hasLoaded && !loading) loadNearby()
    }

    /** The locate button: jump back to the learner, or false to ask for location. */
    fun centerOnUser(): Boolean {
        val here = userLocation ?: return false
        moveTo(here.first, here.second, CommunityDiscovery.DEFAULT_RADIUS_KM, "Near you")
        return true
    }

    // ── Map area ──────────────────────────────────────────────────────────────

    fun moveTo(latitude: Double, longitude: Double, radiusKm: Double, label: String) {
        area = CommunityDiscovery.SearchArea(latitude, longitude, radiusKm)
        areaLabel = label
        mapCommand = MapCommand(latitude, longitude, CommunityDiscovery.zoomForRadius(radiusKm), mapCommand.token + 1)
        awaitingBaseline = true
        pendingVisible = null
        showAreaSearch = false
        clusterKeys = null
        loadNearby()
    }

    /**
     * The map settled. Panning never loads anything by itself; it only decides
     * whether to offer "Search this area".
     */
    fun onViewportChanged(north: Double, south: Double, east: Double, west: Double, programmatic: Boolean) {
        val visible = CommunityDiscovery.areaForBounds(north, south, east, west)
        if (programmatic || awaitingBaseline || baseline == null) {
            baseline = visible
            awaitingBaseline = false
            showAreaSearch = false
            return
        }
        pendingVisible = visible
        showAreaSearch = CommunityDiscovery.shouldOfferAreaSearch(baseline, visible)
    }

    fun searchThisArea() {
        val visible = pendingVisible ?: return
        track("community_search_area", mapOf("radius_km" to visible.radiusKm.roundToInt().toString()))
        area = visible
        baseline = visible
        areaLabel = "This area"
        showAreaSearch = false
        selectedKey = null
        clusterKeys = null
        loadNearby()
    }

    fun widenSearch() = moveTo(
        area.latitude,
        area.longitude,
        min(CommunityDiscovery.MAX_SEARCH_RADIUS_KM, max(5.0, area.radiusKm * 2)),
        areaLabel,
    )

    // ── Search and filters ────────────────────────────────────────────────────

    fun submitSearch() {
        val text = queryText.trim()
        if (text.isEmpty()) {
            clearSearch()
            return
        }
        resolving = true
        selectedKey = null
        clusterKeys = null
        track("community_search", mapOf("length" to text.length.toString()))
        val origin = area
        viewModelScope.launch {
            try {
                val resolution = api.resolveCommunitySearch(text, origin.latitude, origin.longitude)
                val place = resolution.place
                if (place != null && (resolution.intent == "place" || resolution.intent == "mixed")) {
                    activeQuery = if (resolution.intent == "mixed") resolution.topic.orEmpty() else ""
                    moveTo(place.latitude, place.longitude, place.radiusKm.coerceIn(2.0, 30.0), place.name)
                } else {
                    activeQuery = resolution.topic?.takeIf { it.isNotBlank() } ?: text
                    loadNearby()
                }
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                // Resolution is a convenience; a plain topic search always works.
                activeQuery = text
                loadNearby()
            } finally {
                resolving = false
                sheet = SheetDetent.MEDIUM
            }
        }
    }

    fun clearSearch() {
        queryText = ""
        if (activeQuery.isEmpty()) return
        activeQuery = ""
        loadNearby()
    }

    fun toggleFilter(id: String) {
        val turningOn = id !in filters
        filters = CommunityDiscovery.toggle(filters, id)
        selectedKey = null
        clusterKeys = null
        if (turningOn) track("community_filter_selected", mapOf("filter" to id))
        val here = userLocation
        if (id == "nearby" && turningOn && here != null) {
            moveTo(here.first, here.second, CommunityDiscovery.NEARBY_RADIUS_KM, "Near you")
        } else {
            loadNearby()
        }
    }

    fun clearFilters() {
        if (filters.isEmpty()) return
        filters = emptySet()
        clusterKeys = null
        loadNearby()
    }

    // ── Loading ───────────────────────────────────────────────────────────────

    fun retry() = loadNearby(force = true)

    fun loadNearby(force: Boolean = false) {
        val query = filterQuery
        val where = area
        val radius = effectiveRadiusKm
        val topic = activeQuery
        val key = listOf(where.latitude, where.longitude, radius, filters.sorted(), topic).joinToString("|")
        val cached = cache[key]
        if (cached != null) {
            apply(cached.first)
            if (!force && System.currentTimeMillis() - cached.second < 60_000) {
                nearbyJob?.cancel()
                loading = false
                loadError = null
                staleSince = null
                return
            }
        }
        nearbyJob?.cancel()
        loading = true
        loadError = null
        nearbyJob = viewModelScope.launch {
            try {
                val response = api.nearbyLearning(
                    latitude = where.latitude,
                    longitude = where.longitude,
                    radiusKm = radius,
                    categories = query.categories.takeIf { it.isNotEmpty() }?.joinToString(","),
                    query = topic.ifBlank { null },
                    includeOnline = true,
                    includeInstitutions = true,
                    limit = 200,
                    timeWindow = query.timeWindow,
                    freeOnly = if (query.freeOnly) true else null,
                    placeTypes = query.placeTypes.takeIf { it.isNotEmpty() }?.joinToString(","),
                    timeZone = zoneId,
                )
                if (cache.size >= 24) cache.keys.firstOrNull()?.let { cache.remove(it) }
                cache[key] = response to System.currentTimeMillis()
                apply(response)
                staleSince = null
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                Log.w(TAG, "Community nearby request failed", e)
                val friendly = CommunityDiscovery.friendlyError(e)
                loadError = friendly
                track("community_load_failed", mapOf("reason" to if (friendly == CommunityDiscovery.offlineError) "offline" else "error"))
                if (cached != null) staleSince = cached.second else nodes = emptyList()
            }
            hasLoaded = true
            loading = false
        }
    }

    private fun apply(response: NearbyLearningResponseDto) {
        nodes = response.items
        degradedSources = response.degradedSources.orEmpty()
        hasLoaded = true
    }

    fun refreshAccount() {
        accountJob?.cancel()
        accountJob = viewModelScope.launch { reloadAccount() }
    }

    suspend fun reloadAccount() {
        try {
            val here = userLocation
            myCommunity = api.myCommunity(
                latitude = here?.first?.coarse(),
                longitude = here?.second?.coarse(),
                timeZone = zoneId,
            )
            accountError = null
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            Log.w(TAG, "Community account refresh failed", e)
            accountError = CommunityDiscovery.friendlyError(e, "load your Community")
        }
    }

    fun loadPosts() {
        viewModelScope.launch {
            try {
                posts = api.communityPosts(1, 30).items.orEmpty()
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                Log.w(TAG, "Community activity failed", e)
            }
        }
    }

    // ── Selection ─────────────────────────────────────────────────────────────

    fun select(node: LearningNodeDto) {
        selectedKey = node.key
        sheet = SheetDetent.MEDIUM
        track("community_marker_opened", mapOf("kind" to node.kind, "category" to node.category))
    }

    fun selectByKey(key: String) {
        nodes.firstOrNull { it.key == key }?.let(::select)
    }

    fun selectCluster(keys: List<String>) {
        selectedKey = null
        clusterKeys = keys
        sheet = SheetDetent.MEDIUM
    }

    fun showEverything() {
        clusterKeys = null
    }

    fun closePreview() {
        selectedKey = null
    }

    // ── Detail ────────────────────────────────────────────────────────────────

    suspend fun loadDetail(kind: String, id: String): LearningNodeDetailDto {
        val here = userLocation
        val loaded = api.learningNodeDetail(kind, id, here?.first?.coarse(), here?.second?.coarse(), zoneId)
        details[loaded.node.key] = loaded
        patch(loaded.node.key) { merge(loaded.node, it) }
        track(
            if (loaded.node.kind == "event") "community_event_opened" else "community_place_opened",
            mapOf("kind" to loaded.node.kind, "category" to loaded.node.category),
        )
        return loaded
    }

    // ── Save, RSVP, join: instant on screen, confirmed by the server ──────────

    fun toggleSave(node: LearningNodeDto) {
        val latest = current(node)
        val saving = !latest.isSaved
        track("community_event_saved", mapOf("kind" to latest.kind, "saved" to saving.toString()))
        runOptimistic(
            latest,
            verb = if (saving) "save this" else "remove this from your saved items",
            success = if (saving) "Saved to your Lyo account" else "Removed from saved",
            optimistic = { it.copy(isSaved = saving) },
        ) {
            if (saving) ApiClient.api.saveLearningNode(latest.kind, latest.id, LearningNodeSaveRequest(latest))
            else ApiClient.api.unsaveLearningNode(latest.kind, latest.id).requireSuccess()
            null
        }
    }

    /** `status` is "going", "interested", or null to remove the RSVP. */
    fun setRsvp(node: LearningNodeDto, status: String?) {
        val latest = current(node)
        if (latest.kind != "event") return
        track("community_event_rsvp", mapOf("status" to (status ?: "none")))
        val guess = CommunityDiscovery.applyingRsvp(status, latest)
        runOptimistic(
            latest,
            verb = "update your RSVP",
            success = when (status) {
                "going" -> "You're going"
                "interested" -> "Marked as interested"
                else -> "RSVP removed"
            },
            optimistic = { merge(guess, it) },
        ) {
            if (status != null) {
                api.setEventRsvp(latest.id, RsvpRequest(status))
            } else {
                api.clearEventRsvp(latest.id).requireSuccess()
                null
            }
        }
    }

    fun toggleMembership(node: LearningNodeDto) {
        val latest = current(node)
        if (latest.kind != "study_group") return
        val joining = !latest.isJoined
        runOptimistic(
            latest,
            verb = if (joining) "join this group" else "leave this group",
            success = if (joining) "You joined the group" else "You left the group",
            optimistic = { it.copy(isJoined = joining, memberCount = max(0, (it.memberCount ?: 0) + if (joining) 1 else -1)) },
        ) {
            if (joining) api.joinGroup(latest.id) else api.leaveGroup(latest.id).requireSuccess()
            null
        }
    }

    /**
     * The UI changes at once; the server's answer then replaces the guess (so
     * counts match every other device), and a failure puts it back.
     */
    private fun runOptimistic(
        node: LearningNodeDto,
        verb: String,
        success: String,
        optimistic: (LearningNodeDto) -> LearningNodeDto,
        action: suspend () -> LearningNodeDto?,
    ) {
        if (node.key in busyKeys) return
        busyKeys = busyKeys + node.key
        val before = node
        patch(node.key, optimistic)
        viewModelScope.launch {
            try {
                val confirmed = action()
                if (confirmed != null) patch(node.key) { merge(confirmed, it) }
                cache.clear()
                _messages.tryEmit(success)
                reloadAccount()
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                Log.w(TAG, "Community action failed", e)
                patch(node.key) { restoreParticipation(before, it) }
                _messages.tryEmit(CommunityDiscovery.friendlyError(e, verb).message)
            } finally {
                busyKeys = busyKeys - node.key
            }
        }
    }

    /** Apply `transform` to every on-screen copy of a node. */
    private fun patch(key: String, transform: (LearningNodeDto) -> LearningNodeDto) {
        fun List<LearningNodeDto>.patched() = map { if (it.key == key) transform(it) else it }
        nodes = nodes.patched()
        details[key]?.let { details[key] = it.copy(node = transform(it.node)) }
        myCommunity?.let { me ->
            myCommunity = me.copy(
                savedNodes = me.savedNodes.patched(),
                hosting = me.hosting?.patched(),
                going = me.going?.patched(),
                interested = me.interested?.patched(),
            )
        }
    }

    /** A server copy wins, except for the viewer-relative distance it may omit. */
    private fun merge(incoming: LearningNodeDto, existing: LearningNodeDto): LearningNodeDto =
        if (incoming.distanceKm == null) incoming.copy(distanceKm = existing.distanceKm) else incoming

    private fun restoreParticipation(before: LearningNodeDto, node: LearningNodeDto) = node.copy(
        isSaved = before.isSaved,
        isJoined = before.isJoined,
        isAttending = before.isAttending,
        rsvpStatus = before.rsvpStatus,
        goingCount = before.goingCount,
        interestedCount = before.interestedCount,
        memberCount = before.memberCount,
        attendeeCount = before.attendeeCount,
    )

    // ── Create, edit, delete, report ──────────────────────────────────────────

    suspend fun createEvent(request: CreateCommunityEventRequest): CommunityEventRecordDto {
        val record = api.createCommunityEvent(request)
        track(
            "community_event_created",
            mapOf(
                "event_type" to request.eventType,
                "mode" to (request.attendanceMode ?: if (request.isOnline) "online" else "in_person"),
                "visibility" to (request.visibility ?: "public"),
            ),
        )
        afterEventChange()
        return record
    }

    /** `fields` holds every field the form shows; a null clears that detail. */
    suspend fun updateEvent(id: Long, fields: Map<String, Any?>): CommunityEventRecordDto {
        val body = nullsGson.toJson(fields).toRequestBody("application/json".toMediaType())
        val record = api.updateCommunityEvent(id.toString(), body)
        track("community_event_updated", mapOf("event_type" to record.eventType, "visibility" to (record.visibility ?: "public")))
        afterEventChange()
        return record
    }

    fun cancelEvent(id: Long) {
        viewModelScope.launch {
            try {
                updateEvent(id, mapOf("status" to "cancelled"))
                _messages.tryEmit("Event cancelled. Attendees will see it as cancelled.")
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                _messages.tryEmit(CommunityDiscovery.friendlyError(e, "cancel this event").message)
            }
        }
    }

    suspend fun deleteEvent(id: Long) {
        api.deleteCommunityEvent(id.toString()).requireSuccess()
        track("community_event_deleted")
        val key = "event:$id"
        details.remove(key)
        nodes = nodes.filterNot { it.key == key }
        if (selectedKey == key) selectedKey = null
        _messages.tryEmit("Event deleted")
        afterEventChange()
    }

    fun reportEvent(node: LearningNodeDto, reason: String) {
        track("community_event_reported", mapOf("reason" to reason))
        viewModelScope.launch {
            try {
                val response = api.reportCommunityEvent(node.id, EventReportRequest(reason))
                _messages.tryEmit(response.message)
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                _messages.tryEmit(CommunityDiscovery.friendlyError(e, "send your report").message)
            }
        }
    }

    // ── Invitations (private and unlisted events) ─────────────────────────────

    /** The host's invite links and guest list. */
    suspend fun loadInvitations(eventId: String): EventInvitesResponseDto = api.eventInvitations(eventId)

    suspend fun createInvite(eventId: String, maxUses: Int?, expiresInDays: Int): EventInviteDto {
        val link = api.createEventInvite(eventId, EventInviteCreateRequest(maxUses, expiresInDays))
        track("community_invite_created", mapOf("max_uses" to (maxUses?.toString() ?: "any"), "days" to expiresInDays.toString()))
        return link
    }

    suspend fun revokeInvite(eventId: String, inviteId: Long) {
        api.revokeEventInvite(eventId, inviteId).requireSuccess()
    }

    /** Invites one Lyo member by account; the backend notifies them everywhere. */
    suspend fun inviteMember(eventId: String, userId: Long): EventGuestDto =
        api.inviteEventGuest(eventId, EventGuestCreateRequest(userId))

    suspend fun removeGuest(eventId: String, userId: Long) {
        api.removeEventGuest(eventId, userId).requireSuccess()
    }

    /** Lyo members matching a name, for inviting by name (never the host). */
    suspend fun searchMembers(text: String, excludingId: Long?): List<SearchUserDto> =
        api.search(text, "users", 8).users.orEmpty().filter { it.idStr.isNotEmpty() && it.idStr != excludingId?.toString() }

    suspend fun previewInvite(token: String): InvitePreviewDto = api.invitePreview(token)

    /**
     * Puts this account on the guest list, so every device sees the event.
     * Safe to repeat: accepting twice returns the same event.
     */
    suspend fun acceptInvite(token: String): LearningNodeDto {
        val node = api.acceptInvite(token, zoneId)
        track("community_invite_accepted", mapOf("visibility" to (node.visibility ?: "private")))
        details.remove(node.key)
        revision += 1
        if (started) refreshAccount()
        return node
    }

    /** Address suggestions for the event location picker, biased to the map. */
    suspend fun geocode(query: String): List<PlaceSuggestionDto> =
        api.geocodeCommunityPlace(query, area.latitude, area.longitude)

    fun announce(message: String) {
        _messages.tryEmit(message)
    }

    private fun afterEventChange() {
        revision += 1
        cache.clear()
        // A create sheet opened outside Community has nothing on screen to refresh.
        if (started) {
            loadNearby(force = true)
            refreshAccount()
        }
    }

    // ── Analytics: an allow-listed name and small properties, never a location ─

    fun track(name: String, properties: Map<String, String> = emptyMap()) {
        viewModelScope.launch {
            try {
                api.trackCommunityEvent(CommunityAnalyticsEventDto(name, "android", properties))
            } catch (e: CancellationException) {
                throw e
            } catch (_: Exception) {
                // Analytics never interrupts learning.
            }
        }
    }
}
