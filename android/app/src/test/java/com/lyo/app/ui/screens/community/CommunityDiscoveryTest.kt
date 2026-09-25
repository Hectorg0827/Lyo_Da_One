package com.lyo.app.ui.screens.community

import com.google.gson.Gson
import com.lyo.app.data.api.CreateCommunityEventRequest
import com.lyo.app.data.api.EventGuestCreateRequest
import com.lyo.app.data.api.EventGuestDto
import com.lyo.app.data.api.EventInviteCreateRequest
import com.lyo.app.data.api.EventInviteDto
import com.lyo.app.data.api.EventInvitesResponseDto
import com.lyo.app.data.api.InvitePreviewDto
import com.lyo.app.data.api.LearningNodeDetailDto
import com.lyo.app.data.api.LearningNodeDto
import com.lyo.app.data.api.MyCommunityResponseDto
import com.lyo.app.data.api.NearbyLearningResponseDto
import java.io.IOException
import java.time.Instant
import java.time.ZoneId
import java.util.Locale
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.ResponseBody.Companion.toResponseBody
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import retrofit2.HttpException
import retrofit2.Response

/**
 * The Community rules the Android screens depend on, driven directly. They
 * mirror web/src/lib/community-contract.test.mjs and the iOS
 * CommunityDiscoveryTests so every platform is checked the same way.
 */
class CommunityDiscoveryTest {
    private val gson = Gson()

    private fun node(extra: String = ""): LearningNodeDto = gson.fromJson(
        """{"key":"event:1","kind":"event","category":"event","id":"1","title":"SAT Prep, Session 1",
           "latitude":40.713,"longitude":-74.005,"is_online":false,"starts_at":"2026-09-27T22:00:00Z",
           "ends_at":"2026-09-28T00:00:00Z","is_joined":false,"is_attending":false,"is_saved":false,
           "source":"lyo"$extra}""",
        LearningNodeDto::class.java,
    )

    @Test
    fun everyMapCategoryHasAFilterThatCanShowIt() {
        val reachable = CommunityDiscovery.filters.flatMap { it.categories }.toSet()
        CommunityDiscovery.nodeCategories.forEach { assertTrue(it, it in reachable) }
        assertEquals(13, CommunityDiscovery.filters.size)
    }

    @Test
    fun filtersCombineCategoriesAndNarrowWithModifiers() {
        var active = emptySet<String>()
        listOf("workshops", "libraries", "free", "week").forEach { active = CommunityDiscovery.toggle(active, it) }
        assertEquals(
            CommunityDiscovery.FilterQuery(
                categories = listOf("library", "workshop"),
                placeTypes = emptyList(),
                freeOnly = true,
                timeWindow = "week",
                nearby = false,
            ),
            CommunityDiscovery.query(active),
        )
    }

    @Test
    fun todayAndThisWeekAreExclusiveAndChipsToggleOff() {
        var active = CommunityDiscovery.toggle(emptySet(), "today")
        active = CommunityDiscovery.toggle(active, "week")
        assertEquals(setOf("week"), active)
        assertTrue(CommunityDiscovery.toggle(active, "week").isEmpty())
    }

    @Test
    fun schoolsAndLearningCentersNarrowByPlaceType() {
        val schools = CommunityDiscovery.query(setOf("schools"))
        assertEquals(listOf("educational_center"), schools.categories)
        assertEquals(listOf("college", "university"), schools.placeTypes)
        val both = CommunityDiscovery.query(setOf("schools", "learning_centers"))
        assertTrue("language_school" in both.placeTypes && "university" in both.placeTypes)
        assertEquals(CommunityDiscovery.FilterQuery(), CommunityDiscovery.query(emptySet()))
    }

    @Test
    fun viewportAreaAndSearchThisArea() {
        val area = CommunityDiscovery.areaForBounds(north = 40.8, south = 40.6, east = -73.9, west = -74.1)
        assertEquals(40.7, area.latitude, 1e-9)
        assertTrue(area.radiusKm > 12 && area.radiusKm < 16)
        assertEquals(50.0, CommunityDiscovery.areaForBounds(60.0, 20.0, 10.0, -60.0).radiusKm, 0.0)

        val searched = CommunityDiscovery.SearchArea(40.7128, -74.006, 10.0)
        assertFalse(CommunityDiscovery.shouldOfferAreaSearch(searched, searched.copy(latitude = 40.72)))
        assertTrue(CommunityDiscovery.shouldOfferAreaSearch(searched, searched.copy(latitude = 40.8)))
        assertTrue(CommunityDiscovery.shouldOfferAreaSearch(searched, searched.copy(radiusKm = 25.0)))
        assertFalse(CommunityDiscovery.shouldOfferAreaSearch(searched, searched.copy(radiusKm = 12.0)))
        assertFalse(CommunityDiscovery.shouldOfferAreaSearch(null, searched))
    }

    @Test
    fun distancesPricesAndLabelsReadNaturally() {
        assertEquals("Here", CommunityDiscovery.formatDistance(0.05))
        assertEquals("460 m", CommunityDiscovery.formatDistance(0.456))
        assertEquals("3.2 km", CommunityDiscovery.formatDistance(3.24))
        assertEquals("19 km", CommunityDiscovery.formatDistance(18.6))
        assertNull(CommunityDiscovery.formatDistance(null))
        assertEquals("Free", CommunityDiscovery.formatPrice(true, null, null))
        assertEquals("$15", CommunityDiscovery.formatPrice(false, 15.0, "USD"))
        assertEquals("$12.50", CommunityDiscovery.formatPrice(false, 12.5, "USD"))
        assertNull(CommunityDiscovery.formatPrice(null, null, null))
        assertEquals("University", CommunityDiscovery.categoryLabel("educational_center", "university"))
        assertEquals("Library", CommunityDiscovery.categoryLabel("library"))
        assertEquals(111.2, CommunityDiscovery.distanceKm(0.0, 0.0, 0.0, 1.0), 0.2)
    }

    @Test
    fun eventTimesShowInTheViewersTimezone() {
        assertEquals(
            "Sun, Sep 27 · 6:00 PM – 8:00 PM",
            CommunityDiscovery.formatWhen(
                "2026-09-27T22:00:00Z",
                "2026-09-28T00:00:00Z",
                ZoneId.of("America/New_York"),
                Locale.US,
            ),
        )
        assertNull(CommunityDiscovery.formatWhen(null, null))
        assertNull(CommunityDiscovery.formatWhen("not a date", null))
        assertEquals(
            CommunityDiscovery.parseInstant("2026-09-27T22:00:00Z"),
            CommunityDiscovery.parseInstant("2026-09-27T22:00:00"),
        )
    }

    @Test
    fun linksAreOnlyEverPlainWebUrls() {
        assertNull(CommunityDiscovery.safeWebUrl("javascript:alert(1)"))
        assertNull(CommunityDiscovery.safeWebUrl("data:text/html,hi"))
        assertEquals("https://lyoai.app/x", CommunityDiscovery.safeWebUrl("https://lyoai.app/x"))
    }

    @Test
    fun directionsUseThePublicPlaceNeverTheViewer() {
        assertEquals(
            "https://www.google.com/maps/dir/?api=1&destination=40.713,-74.005",
            CommunityDiscovery.directionsUrl(node()),
        )
        val byAddress = node().copy(latitude = null, longitude = null, address = "455 5th Ave")
        assertEquals(
            "https://www.google.com/maps/dir/?api=1&destination=455%205th%20Ave",
            CommunityDiscovery.directionsUrl(byAddress),
        )
        val online = node().copy(latitude = null, longitude = null, attendanceMode = "online", isOnline = true)
        assertNull(CommunityDiscovery.directionsUrl(online))
    }

    @Test
    fun shareLinksMatchTheWebRoutes() {
        assertEquals("/community/events/42", CommunityDiscovery.detailPath("event", "42"))
        assertEquals(
            "/community/places/institution/osm%3Anode%3A7",
            CommunityDiscovery.detailPath("institution", "osm:node:7"),
        )
        assertEquals("https://lyoai.app/community/events/42", CommunityDiscovery.shareUrl("event", "42"))
    }

    @Test
    fun optimisticRsvpMovesCountsBetweenGoingAndInterested() {
        val start = node(""","going_count":3,"interested_count":1""")
        val going = CommunityDiscovery.applyingRsvp("going", start)
        assertEquals("going", going.rsvpStatus)
        assertTrue(going.isAttending)
        assertEquals(4, going.goingCount)
        val interested = CommunityDiscovery.applyingRsvp("interested", going)
        assertEquals(3, interested.goingCount)
        assertEquals(2, interested.interestedCount)
        val cleared = CommunityDiscovery.applyingRsvp(null, interested)
        assertFalse(cleared.isAttending)
        assertEquals(1, cleared.interestedCount)
    }

    private fun httpError(code: Int, body: String): HttpException =
        HttpException(Response.error<Unit>(code, body.toResponseBody("application/json".toMediaType())))

    @Test
    fun errorsBecomeLearnerFacingCopy() {
        val server = CommunityDiscovery.friendlyError(httpError(500, """{"error":{"message":"Internal Server Error"}}"""))
        assertEquals("We couldn't load nearby learning opportunities.", server.title)
        assertTrue(server.retry)
        assertFalse(server.body.contains("500"))
        assertEquals(CommunityDiscovery.offlineError, CommunityDiscovery.friendlyError(IOException("Unable to resolve host")))
        assertEquals(
            "This event is full",
            CommunityDiscovery.friendlyError(httpError(409, """{"error":{"code":"conflict","message":"This event is full"}}"""), "update your RSVP").message,
        )
        assertFalse(CommunityDiscovery.friendlyError(httpError(404, "{}")).retry)
        assertEquals(
            "You're going a little fast. Please wait a moment and try again.",
            CommunityDiscovery.friendlyError(httpError(429, """{"error":{"message":"HTTP error occurred"}}""")).body,
        )
        assertEquals(
            "You've reached today's event limit.",
            CommunityDiscovery.friendlyError(httpError(429, """{"error":{"message":"You've reached today's event limit."}}""")).body,
        )
        assertEquals(
            "Please check the details and try again.",
            CommunityDiscovery.friendlyError(httpError(422, """{"error":{"message":"Request validation failed"}}""")).body,
        )
        assertEquals("Event not found", CommunityDiscovery.envelopeMessage("""{"detail":"Event not found"}"""))
        assertNull(CommunityDiscovery.envelopeMessage("not json"))
    }

    @Test
    fun contractFourPayloadsDecodeAndOlderOnesStillDo() {
        val rich = node(
            ""","lifecycle":"today","rsvp_status":"interested","going_count":12,"is_free":false,
               "price_amount":15,"venue_name":"Main Library","attendance_mode":"hybrid","is_owner":true""",
        )
        assertEquals("today", rich.lifecycle)
        assertTrue(rich.isInterested)
        assertEquals(12, rich.goingCount)
        assertEquals("Main Library", rich.venueName)
        assertEquals(true, rich.isOwner)
        assertNull(node().lifecycle)

        val nearby = gson.fromJson(
            """{"items":[],"center_latitude":1,"center_longitude":2,"radius_km":3,"fetched_at":"2026-09-25T00:00:00Z","degraded_sources":["places"]}""",
            NearbyLearningResponseDto::class.java,
        )
        assertEquals(listOf("places"), nearby.degradedSources)

        val detail = gson.fromJson(
            """{"node":{"key":"event:7","kind":"event","category":"workshop","id":"7","title":"Intro",
               "is_online":false,"is_joined":false,"is_attending":true,"is_saved":true,"source":"lyo"},
               "related":[],"can_edit":true,
               "event":{"id":7,"title":"Intro","event_type":"workshop","is_online":false,"max_attendees":20,
               "start_time":"2026-10-01T22:00:00Z","end_time":"2026-10-02T00:00:00Z","status":"scheduled","organizer_id":3}}""",
            LearningNodeDetailDto::class.java,
        )
        assertTrue(detail.canEdit)
        assertEquals(20, detail.event?.maxAttendees)
        assertTrue(detail.node.isGoing)

        val me = gson.fromJson(
            """{"joined_groups":[],"attending_events":[],"saved_nodes":[],"following":[],"updated_at":"x","going":[{"key":"event:7","kind":"event","category":"event","id":"7","title":"Intro","source":"lyo"}]}""",
            MyCommunityResponseDto::class.java,
        )
        assertEquals("event:7", me.going?.first()?.key)
        assertNull(me.hosting)
    }

    @Test
    fun eventCreationCarriesAnIdempotencyKey() {
        val json = gson.toJson(
            CreateCommunityEventRequest(
                title = "Robotics night",
                startTime = "2026-10-01T22:00:00Z",
                endTime = "2026-10-02T00:00:00Z",
                timezone = "America/New_York",
                attendanceMode = "in_person",
                clientRequestId = "android-123",
            ),
        )
        assertTrue(json, json.contains("\"client_request_id\":\"android-123\""))
        assertTrue(json, json.contains("\"attendance_mode\":\"in_person\""))
        assertFalse("unset optional fields are not sent", json.contains("max_attendees"))
    }

    // ── Private event invitations: the same rules as the web and iOS ─────────

    private val token = "Ab3_xY-9Ab3_xY-9Ab3_xY-9"

    @Test
    fun inviteCodesAreReadFromALinkOrABareCodeAndNothingElse() {
        assertEquals(token, CommunityDiscovery.inviteTokenFromText("https://lyoai.app/community/invite/$token"))
        assertEquals(token, CommunityDiscovery.inviteTokenFromText("  https://lyoai.app/community/invite/$token?utm=x  "))
        assertEquals(token, CommunityDiscovery.inviteTokenFromText("lyoapp://community/invite/$token"))
        assertEquals(token, CommunityDiscovery.inviteTokenFromText("Join me! https://lyoai.app/community/invite/$token"))
        assertEquals(token, CommunityDiscovery.inviteTokenFromText(token))
        assertNull(CommunityDiscovery.inviteTokenFromText("https://lyoai.app/community/events/42"))
        assertNull(CommunityDiscovery.inviteTokenFromText("https://lyoai.app/community/invite/$token thanks"))
        assertNull(CommunityDiscovery.inviteTokenFromText("short"))
        assertNull(CommunityDiscovery.inviteTokenFromText(""))
        assertNull(CommunityDiscovery.inviteTokenFromText(null))
        assertNull(CommunityDiscovery.inviteTokenFromText("https://lyoai.app/community/invite/<script>alert(1)</script>"))
        assertEquals("/community/invite/$token", CommunityDiscovery.invitePath(token))
        assertEquals("https://lyoai.app/community/invite/$token", CommunityDiscovery.inviteUrl(token))
    }

    private fun link(fields: String): EventInviteDto = gson.fromJson(
        """{"id":1,"token":"t","url":"https://lyoai.app/community/invite/t","created_at":"2026-09-01T00:00:00Z",$fields}""",
        EventInviteDto::class.java,
    )

    @Test
    fun inviteLinksSayHowTheyAreUsedAndWhyTheyStopped() {
        val now = Instant.parse("2026-09-20T12:00:00Z")
        val utc = ZoneId.of("UTC")
        assertEquals(
            "Used 2 of 5 · Expires Sep 30",
            CommunityDiscovery.describeInviteLink(
                link(""""expires_at":"2026-09-30T12:00:00Z","max_uses":5,"use_count":2,"active":true"""), now, utc, Locale.US,
            ),
        )
        assertEquals("Used 1 time", CommunityDiscovery.describeInviteLink(link(""""use_count":1,"active":true"""), now, utc, Locale.US))
        assertEquals("Used 1 of 1 · Used up", CommunityDiscovery.describeInviteLink(link(""""max_uses":1,"use_count":1,"active":false"""), now))
        assertEquals(
            "Used 0 times · Expired",
            CommunityDiscovery.describeInviteLink(link(""""expires_at":"2026-09-10T00:00:00Z","use_count":0,"active":false"""), now),
        )
        assertEquals(
            "Used 3 times · Turned off",
            CommunityDiscovery.describeInviteLink(link(""""expires_at":"2026-09-30T00:00:00Z","use_count":3,"active":false"""), now),
        )
    }

    @Test
    fun guestRowsAndClosedInvitesReadPlainly() {
        val going = gson.fromJson(
            """{"user":{"id":7,"name":"Ana"},"source":"link","invited_at":"2026-09-01T00:00:00Z","rsvp_status":"going"}""",
            EventGuestDto::class.java,
        )
        assertEquals("Going · Joined with a link", CommunityDiscovery.describeGuest(going))
        val named = gson.fromJson(
            """{"user":{"id":8,"name":"Cara"},"source":"direct","invited_at":"2026-09-01T00:00:00Z"}""",
            EventGuestDto::class.java,
        )
        assertEquals("No reply yet · Invited by name", CommunityDiscovery.describeGuest(named))

        assertNull(CommunityDiscovery.inviteNotice("valid"))
        listOf("expired", "revoked", "used_up", "ended", "cancelled", "something_new").forEach {
            assertNotNull(it, CommunityDiscovery.inviteNotice(it))
        }
        assertEquals("This invite was turned off", CommunityDiscovery.inviteNotice("revoked")?.title)
        val notFound = HttpException(Response.error<Any>(404, "{}".toResponseBody("application/json".toMediaType())))
        assertEquals("This invite link isn't valid", CommunityDiscovery.inviteError(notFound).title)
        assertEquals(CommunityDiscovery.offlineError, CommunityDiscovery.inviteError(IOException("offline")))
    }

    @Test
    fun onlyHostsOfOpenPrivateOrUnlistedEventsManageInvites() {
        val privateEvent = node(""","visibility":"private","lifecycle":"upcoming"""")
        assertTrue(CommunityDiscovery.canManageInvites(privateEvent, canEdit = true))
        assertFalse(CommunityDiscovery.canManageInvites(privateEvent, canEdit = false))
        assertTrue(CommunityDiscovery.canManageInvites(node(""","visibility":"unlisted""""), canEdit = true))
        assertFalse(CommunityDiscovery.canManageInvites(node(""","visibility":"public""""), canEdit = true))
        assertFalse(CommunityDiscovery.canManageInvites(node(""","visibility":"private","lifecycle":"cancelled""""), canEdit = true))
        assertFalse(CommunityDiscovery.canManageInvites(node(""","visibility":"private","lifecycle":"past""""), canEdit = true))
    }

    @Test
    fun inviteRequestsAndResponsesMatchTheBackend() {
        assertEquals("""{"expires_in_days":30}""", gson.toJson(EventInviteCreateRequest(maxUses = null, expiresInDays = 30)))
        assertEquals("""{"max_uses":5,"expires_in_days":7}""", gson.toJson(EventInviteCreateRequest(maxUses = 5, expiresInDays = 7)))
        assertEquals("""{"user_id":12}""", gson.toJson(EventGuestCreateRequest(12)))

        val preview = gson.fromJson(
            """{"status":"valid","already_guest":false,"is_host":false,"event_id":42,"title":"Private chemistry lab",
               "starts_at":"2026-09-27T22:00:00Z","ends_at":null,"location_name":"Hunter College","attendance_mode":"in_person",
               "visibility":"private","host":{"id":3,"name":"Ben","avatar":null},"organizer_name":"Ben Okafor"}""",
            InvitePreviewDto::class.java,
        )
        assertEquals(42L, preview.eventId)
        assertEquals("Ben Okafor", preview.organizerName)

        val list = gson.fromJson("""{"links":[],"guests":[]}""", EventInvitesResponseDto::class.java)
        assertTrue(list.links.isEmpty() && list.guests.isEmpty())

        assertEquals(true, node(""","is_invited":true""").isInvited)
        assertNull("older payloads without the flag still decode", node().isInvited)
        val me = gson.fromJson(
            """{"joined_groups":[],"attending_events":[],"saved_nodes":[],"following":[],"updated_at":"x","invited":[{"key":"event:9","kind":"event","category":"event","id":"9","title":"Lab","source":"lyo","is_invited":true}]}""",
            MyCommunityResponseDto::class.java,
        )
        assertEquals("event:9", me.invited?.first()?.key)
    }

    @Test
    fun onlyInviteLinksAreKeptFromTheLinkTheAppWasOpenedWith() {
        assertNull(CommunityDiscovery.inviteTokenFromAppLink("lyoapp://community/events/42"))
        assertNull("a bare code is not a link", CommunityDiscovery.inviteTokenFromAppLink(token))
        assertNull(CommunityDiscovery.inviteTokenFromAppLink(null))
        assertEquals(token, CommunityDiscovery.inviteTokenFromAppLink("lyoapp://community/invite/$token"))
    }
}
