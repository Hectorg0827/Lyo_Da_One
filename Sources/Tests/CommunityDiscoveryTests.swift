import XCTest
@testable import Lyo

// The Community rules the iOS screens depend on, driven directly. They mirror
// web/src/lib/community-contract.test.mjs so a filter, a "Search this area"
// decision, or an error message is checked the same way on both platforms.

private func makeNode(_ overrides: [String: Any] = [:]) throws -> APILearningNode {
    var object: [String: Any] = [
        "key": "event:1",
        "kind": "event",
        "category": "event",
        "id": "1",
        "title": "SAT Prep, Session 1",
        "latitude": 40.713,
        "longitude": -74.005,
        "is_online": false,
        "starts_at": "2026-09-27T22:00:00Z",
        "ends_at": "2026-09-28T00:00:00Z",
        "is_joined": false,
        "is_attending": false,
        "is_saved": false,
        "source": "lyo",
    ]
    for (key, value) in overrides { object[key] = value }
    let data = try JSONSerialization.data(withJSONObject: object)
    return try JSONDecoder.lyoDecoder.decode(APILearningNode.self, from: data)
}

final class CommunityFilterTests: XCTestCase {
    func testEveryMapCategoryHasAFilterThatCanShowIt() {
        let reachable = Set(CommunityDiscovery.filters.flatMap(\.categories))
        for category in CommunityDiscovery.nodeCategories {
            XCTAssertTrue(reachable.contains(category), category)
        }
        XCTAssertEqual(CommunityDiscovery.filters.count, 13)
    }

    func testFiltersCombineCategoriesAndNarrowWithModifiers() {
        var active = Set<String>()
        for id in ["workshops", "libraries", "free", "week"] {
            active = CommunityDiscovery.toggle(active, id)
        }
        XCTAssertEqual(
            CommunityDiscovery.query(for: active),
            CommunityDiscovery.FilterQuery(
                categories: ["library", "workshop"],
                placeTypes: [],
                freeOnly: true,
                when: "week",
                nearby: false
            )
        )
    }

    func testTodayAndThisWeekAreExclusiveAndChipsToggleOff() {
        var active = CommunityDiscovery.toggle([], "today")
        active = CommunityDiscovery.toggle(active, "week")
        XCTAssertEqual(active, ["week"])
        active = CommunityDiscovery.toggle(active, "week")
        XCTAssertTrue(active.isEmpty)
    }

    func testSchoolsAndLearningCentersNarrowByPlaceType() {
        let schools = CommunityDiscovery.query(for: ["schools"])
        XCTAssertEqual(schools.categories, ["educational_center"])
        XCTAssertEqual(schools.placeTypes, ["college", "university"])
        let both = CommunityDiscovery.query(for: ["schools", "learning_centers"])
        XCTAssertTrue(both.placeTypes.contains("language_school"))
        XCTAssertTrue(both.placeTypes.contains("university"))
    }

    func testNoChipsMeansEverything() {
        XCTAssertEqual(CommunityDiscovery.query(for: []), CommunityDiscovery.FilterQuery())
    }

    func testNearbyQueryCarriesOnlyWhatWasChosen() {
        let params = CommunityNearbyParams(
            latitude: 40.71284,
            longitude: -74.00601,
            radiusKm: 3,
            categories: ["library", "workshop"],
            query: "  robotics ",
            when: "today",
            freeOnly: true,
            timeZone: "America/New_York"
        )
        let items = Dictionary(uniqueKeysWithValues: params.queryItems.map { ($0.name, $0.value ?? "") })
        XCTAssertEqual(items["lat"], "40.7128")
        XCTAssertEqual(items["lng"], "-74.0060")
        XCTAssertEqual(items["radius_km"], "3.0")
        XCTAssertEqual(items["categories"], "library,workshop")
        XCTAssertEqual(items["q"], "robotics")
        XCTAssertEqual(items["when"], "today")
        XCTAssertEqual(items["free_only"], "true")
        XCTAssertEqual(items["tz"], "America/New_York")
        XCTAssertNil(items["place_types"])

        let plain = CommunityNearbyParams(latitude: 1, longitude: 2, radiusKm: 12)
        let names = plain.queryItems.map(\.name)
        XCTAssertFalse(names.contains("free_only"))
        XCTAssertFalse(names.contains("q"))
        XCTAssertFalse(names.contains("when"))
    }
}

final class CommunityMapLogicTests: XCTestCase {
    func testViewportAreaIsCenterAndHalfDiagonalCapped() {
        let area = CommunityDiscovery.area(centerLatitude: 40.7, centerLongitude: -74.0, latitudeDelta: 0.2, longitudeDelta: 0.2)
        XCTAssertEqual(area.latitude, 40.7, accuracy: 1e-9)
        XCTAssertTrue(area.radiusKm > 12 && area.radiusKm < 16, "\(area.radiusKm)")
        let huge = CommunityDiscovery.area(centerLatitude: 40, centerLongitude: -25, latitudeDelta: 40, longitudeDelta: 70)
        XCTAssertEqual(huge.radiusKm, 50)
    }

    func testSearchThisAreaOnlyAfterAMeaningfulMoveOrZoom() {
        let searched = CommunityDiscovery.SearchArea(latitude: 40.7128, longitude: -74.006, radiusKm: 10)
        var moved = searched
        moved.latitude = 40.72
        XCTAssertFalse(CommunityDiscovery.shouldOfferAreaSearch(searched: searched, visible: moved))
        moved.latitude = 40.8
        XCTAssertTrue(CommunityDiscovery.shouldOfferAreaSearch(searched: searched, visible: moved))
        var zoomed = searched
        zoomed.radiusKm = 25
        XCTAssertTrue(CommunityDiscovery.shouldOfferAreaSearch(searched: searched, visible: zoomed))
        zoomed.radiusKm = 12
        XCTAssertFalse(CommunityDiscovery.shouldOfferAreaSearch(searched: searched, visible: zoomed))
        XCTAssertFalse(CommunityDiscovery.shouldOfferAreaSearch(searched: nil, visible: searched))
    }

    func testOverlappingMarkersClusterAndDistantOnesDoNot() throws {
        let nodes = [
            try makeNode(["key": "a", "latitude": 40.7130, "longitude": -74.0050]),
            try makeNode(["key": "b", "latitude": 40.7131, "longitude": -74.0051]),
            try makeNode(["key": "c", "latitude": 40.9, "longitude": -73.8]),
            try makeNode(["key": "online", "latitude": NSNull(), "longitude": NSNull()]),
        ]
        let clusters = CommunityDiscovery.cluster(nodes, cellPoints: 56) { node in
            ((node.longitude ?? 0) * 1000, (node.latitude ?? 0) * 1000)
        }
        XCTAssertEqual(clusters.map(\.members.count).sorted(), [1, 2])
        let pair = try XCTUnwrap(clusters.first { $0.members.count == 2 })
        XCTAssertEqual(pair.id, "a|b")
        XCTAssertGreaterThanOrEqual(pair.north, pair.south)
    }

    func testMercatorProjectionKeepsNorthUp() {
        let world = CommunityDiscovery.worldSize(longitudeDelta: 0.1, viewWidth: 390)
        let north = CommunityDiscovery.project(latitude: 40.8, longitude: -74, worldSize: world)
        let south = CommunityDiscovery.project(latitude: 40.6, longitude: -74, worldSize: world)
        XCTAssertLessThan(north.y, south.y)
        let east = CommunityDiscovery.project(latitude: 40.7, longitude: -73.9, worldSize: world)
        let west = CommunityDiscovery.project(latitude: 40.7, longitude: -74.1, worldSize: world)
        XCTAssertEqual(east.x - west.x, 0.2 / 0.1 * 390, accuracy: 0.001)
    }
}

final class CommunityPresentationTests: XCTestCase {
    func testDistancesPricesAndLabelsReadNaturally() {
        XCTAssertEqual(CommunityDiscovery.formatDistance(0.05), "Here")
        XCTAssertEqual(CommunityDiscovery.formatDistance(0.456), "460 m")
        XCTAssertEqual(CommunityDiscovery.formatDistance(3.24), "3.2 km")
        XCTAssertEqual(CommunityDiscovery.formatDistance(18.6), "19 km")
        XCTAssertNil(CommunityDiscovery.formatDistance(nil))
        XCTAssertEqual(CommunityDiscovery.formatPrice(isFree: true, amount: nil, currency: nil), "Free")
        XCTAssertEqual(CommunityDiscovery.formatPrice(isFree: false, amount: 15, currency: "USD"), "$15")
        XCTAssertEqual(CommunityDiscovery.formatPrice(isFree: false, amount: 12.5, currency: "USD"), "$12.50")
        XCTAssertNil(CommunityDiscovery.formatPrice(isFree: nil, amount: nil, currency: nil))
        XCTAssertEqual(CommunityDiscovery.categoryLabel(category: "educational_center", placeType: "university"), "University")
        XCTAssertEqual(CommunityDiscovery.categoryLabel(category: "library"), "Library")
        XCTAssertEqual(CommunityDiscovery.distanceKm(0, 0, 0, 1), 111.2, accuracy: 0.2)
    }

    func testEventTimesShowInTheViewersTimezone() {
        let text = CommunityDiscovery.formatWhen(
            "2026-09-27T22:00:00Z",
            "2026-09-28T00:00:00Z",
            timeZone: TimeZone(identifier: "America/New_York")!,
            locale: Locale(identifier: "en_US")
        )
        XCTAssertEqual(text, "Sun, Sep 27 · 6:00 PM – 8:00 PM")
        XCTAssertNil(CommunityDiscovery.formatWhen(nil, nil))
        XCTAssertNil(CommunityDiscovery.formatWhen("not a date", nil))
    }

    func testLegacyTimestampsWithoutAZoneAreUTC() {
        let date = CommunityDiscovery.parseDate("2026-09-27T22:00:00")
        XCTAssertEqual(date, CommunityDiscovery.parseDate("2026-09-27T22:00:00Z"))
    }

    func testLinksAreOnlyEverPlainWebURLs() {
        XCTAssertNil(CommunityDiscovery.safeWebURL("javascript:alert(1)"))
        XCTAssertNil(CommunityDiscovery.safeWebURL("data:text/html,hi"))
        XCTAssertNil(CommunityDiscovery.safeWebURL("https://"))
        XCTAssertEqual(CommunityDiscovery.safeWebURL("https://lyoai.app/x")?.absoluteString, "https://lyoai.app/x")
    }

    func testDirectionsUseThePublicPlaceNeverTheViewer() throws {
        XCTAssertEqual(
            CommunityDiscovery.directionsURL(try makeNode())?.absoluteString,
            "https://maps.apple.com/?daddr=40.713,-74.005"
        )
        let byAddress = try makeNode(["latitude": NSNull(), "longitude": NSNull(), "address": "455 5th Ave"])
        XCTAssertEqual(
            CommunityDiscovery.directionsURL(byAddress)?.absoluteString,
            "https://maps.apple.com/?daddr=455%205th%20Ave"
        )
        let online = try makeNode(["latitude": NSNull(), "longitude": NSNull(), "attendance_mode": "online", "is_online": true])
        XCTAssertNil(CommunityDiscovery.directionsURL(online))
    }

    func testShareLinksMatchTheWebRoutes() {
        XCTAssertEqual(CommunityDiscovery.detailPath(kind: "event", id: "42"), "/community/events/42")
        XCTAssertEqual(
            CommunityDiscovery.detailPath(kind: "institution", id: "osm:node:7"),
            "/community/places/institution/osm%3Anode%3A7"
        )
        XCTAssertEqual(
            CommunityDiscovery.shareURL(kind: "event", id: "42")?.absoluteString,
            "https://lyoai.app/community/events/42"
        )
        XCTAssertEqual(CommunityNodeRoute(kind: "event", id: "42").key, "event:42")
    }

    func testOptimisticRSVPMovesCountsBetweenGoingAndInterested() throws {
        let node = try makeNode(["going_count": 3, "interested_count": 1])
        let going = CommunityDiscovery.applyingRSVP("going", to: node)
        XCTAssertEqual(going.rsvpStatus, "going")
        XCTAssertTrue(going.isAttending)
        XCTAssertEqual(going.goingCount, 4)
        let interested = CommunityDiscovery.applyingRSVP("interested", to: going)
        XCTAssertEqual(interested.goingCount, 3)
        XCTAssertEqual(interested.interestedCount, 2)
        let cleared = CommunityDiscovery.applyingRSVP(nil, to: interested)
        XCTAssertFalse(cleared.isAttending)
        XCTAssertEqual(cleared.interestedCount, 1)
    }
}

final class CommunityErrorCopyTests: XCTestCase {
    func testErrorsBecomeLearnerFacingCopy() {
        let server = CommunityDiscovery.friendlyError(LyoError.network(.serverError(500)))
        XCTAssertEqual(server.title, "We couldn't load nearby learning opportunities.")
        XCTAssertTrue(server.retry)
        XCTAssertFalse(server.body.contains("500"))
        XCTAssertEqual(CommunityDiscovery.friendlyError(LyoError.network(.noInternetConnection)), CommunityDiscovery.offlineError)
        XCTAssertEqual(CommunityDiscovery.friendlyError(URLError(.notConnectedToInternet)), CommunityDiscovery.offlineError)
        XCTAssertEqual(CommunityDiscovery.friendlyError(LyoError.serverError("This event is full")).body, "This event is full")
        XCTAssertFalse(CommunityDiscovery.friendlyError(LyoError.network(.notFound)).retry)
        XCTAssertEqual(
            CommunityDiscovery.friendlyError(LyoError.rateLimitExceeded(retryAfter: nil)).body,
            "You're going a little fast. Please wait a moment and try again."
        )
        XCTAssertEqual(
            CommunityDiscovery.friendlyError(LyoError.network(.unknown(422))).body,
            "Please check the details and try again."
        )
        XCTAssertEqual(
            CommunityDiscovery.friendlyError(LyoError.serverError("This event is full"), action: "update your RSVP").message,
            "This event is full"
        )
    }

    func testBackendEnvelopeMessagesSkipGenericPlaceholders() {
        let full = Data("{\"error\":{\"code\":\"conflict\",\"message\":\"This event is full\"}}".utf8)
        XCTAssertEqual(NetworkClient.envelopeMessage(from: full), "This event is full")
        let generic = Data("{\"error\":{\"message\":\"HTTP error occurred\"}}".utf8)
        XCTAssertNil(NetworkClient.envelopeMessage(from: generic))
        let validation = Data("{\"error\":{\"message\":\"Request validation failed\"}}".utf8)
        XCTAssertNil(NetworkClient.envelopeMessage(from: validation))
        XCTAssertEqual(NetworkClient.envelopeMessage(from: Data("{\"detail\":\"Event not found\"}".utf8)), "Event not found")
        XCTAssertNil(NetworkClient.envelopeMessage(from: Data("not json".utf8)))
    }
}

final class CommunityContractDecodingTests: XCTestCase {
    func testContractFourNodeFieldsDecodeAndOlderPayloadsStillDo() throws {
        let rich = try makeNode([
            "lifecycle": "today",
            "rsvp_status": "interested",
            "going_count": 12,
            "interested_count": 4,
            "is_free": false,
            "price_amount": 15,
            "currency": "USD",
            "venue_name": "Main Library",
            "attendance_mode": "hybrid",
            "place_type": "university",
            "is_owner": true,
            "is_full": false,
            "opening_hours": "Mo-Fr 09:00-18:00",
        ])
        XCTAssertEqual(rich.lifecycle, "today")
        XCTAssertEqual(rich.rsvpStatus, "interested")
        XCTAssertEqual(rich.goingCount, 12)
        XCTAssertEqual(rich.priceAmount, 15)
        XCTAssertEqual(rich.venueName, "Main Library")
        XCTAssertEqual(rich.attendanceMode, "hybrid")
        XCTAssertEqual(rich.isOwner, true)
        XCTAssertEqual(rich.openingHours, "Mo-Fr 09:00-18:00")

        let legacy = try makeNode()
        XCTAssertNil(legacy.lifecycle)
        XCTAssertNil(legacy.rsvpStatus)
    }

    func testDetailAndAccountResponsesDecode() throws {
        let node: [String: Any] = [
            "key": "event:7", "kind": "event", "category": "workshop", "id": "7", "title": "Intro to Python",
            "is_online": false, "is_joined": false, "is_attending": true, "is_saved": true, "source": "lyo",
            "rsvp_status": "going",
        ]
        let detailJSON: [String: Any] = [
            "node": node,
            "related": [],
            "can_edit": true,
            "event": [
                "id": 7, "title": "Intro to Python", "description": NSNull(), "event_type": "workshop",
                "location": "Main Library", "is_online": false, "meeting_url": NSNull(), "max_attendees": 20,
                "start_time": "2026-10-01T22:00:00Z", "end_time": "2026-10-02T00:00:00Z", "timezone": "America/New_York",
                "status": "scheduled", "organizer_id": 3, "latitude": 40.75, "longitude": -73.98,
                "visibility": "public", "price_type": "free", "attendance_mode": "in_person",
            ],
        ]
        let detail = try JSONDecoder.lyoDecoder.decode(
            APILearningNodeDetail.self,
            from: JSONSerialization.data(withJSONObject: detailJSON)
        )
        XCTAssertTrue(detail.canEdit)
        XCTAssertEqual(detail.event?.maxAttendees, 20)
        XCTAssertEqual(detail.node.rsvpStatus, "going")

        let meJSON: [String: Any] = [
            "joined_groups": [], "attending_events": [], "saved_nodes": [node], "following": [],
            "updated_at": "2026-09-25T12:00:00Z", "hosting": [], "going": [node], "interested": [],
        ]
        let me = try JSONDecoder.lyoDecoder.decode(
            APICommunityMeResponse.self,
            from: JSONSerialization.data(withJSONObject: meJSON)
        )
        XCTAssertEqual(me.going?.first?.key, "event:7")
        XCTAssertEqual(me.savedNodes.count, 1)
    }

    func testEventEditsSendOnlyChangesAndExplicitClears() throws {
        var request = APIUpdateEventRequest(title: "New title")
        request.cleared = ["website_url", "status"]
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder.lyoEncoder.encode(request)) as? [String: Any]
        )
        XCTAssertEqual(object["title"] as? String, "New title")
        XCTAssertTrue(object["website_url"] is NSNull, "an emptied optional field is cleared")
        XCTAssertNil(object["status"], "required fields are never sent as null")
        XCTAssertNil(object["description"], "untouched fields are not sent")
    }

    func testEventCreationCarriesAnIdempotencyKeyAndUTCInstants() throws {
        let request = APICreateEducationalEventRequest(
            title: "Robotics night",
            description: nil,
            eventType: "workshop",
            location: "Main Library",
            isOnline: false,
            meetingUrl: nil,
            maxAttendees: nil,
            startTime: Date(timeIntervalSince1970: 1_790_000_000),
            endTime: Date(timeIntervalSince1970: 1_790_007_200),
            timezone: "America/New_York",
            latitude: 40.75,
            longitude: -73.98,
            attendanceMode: "in_person",
            priceType: "free",
            visibility: "public",
            clientRequestId: "ios-123"
        )
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder.lyoEncoder.encode(request)) as? [String: Any]
        )
        XCTAssertEqual(object["client_request_id"] as? String, "ios-123")
        XCTAssertEqual(object["attendance_mode"] as? String, "in_person")
        let start = try XCTUnwrap(object["start_time"] as? String)
        XCTAssertNotNil(CommunityDiscovery.parseDate(start))
        XCTAssertTrue(start.hasSuffix("Z") || start.contains("+"), start)
    }
}

// Private event invitations: the same rules as the web invite page and panel.
final class CommunityInviteTests: XCTestCase {
    private let token = "Ab3_xY-9Ab3_xY-9Ab3_xY-9"

    func testInviteCodesAreReadFromALinkOrABareCodeAndNothingElse() {
        XCTAssertEqual(CommunityDiscovery.inviteToken(from: "https://lyoai.app/community/invite/\(token)"), token)
        XCTAssertEqual(CommunityDiscovery.inviteToken(from: "  https://lyoai.app/community/invite/\(token)?utm=x  "), token)
        XCTAssertEqual(CommunityDiscovery.inviteToken(from: "lyoapp://community/invite/\(token)"), token)
        XCTAssertEqual(CommunityDiscovery.inviteToken(from: "Join me! https://lyoai.app/community/invite/\(token)"), token)
        XCTAssertEqual(CommunityDiscovery.inviteToken(from: token), token)
        XCTAssertNil(CommunityDiscovery.inviteToken(from: "https://lyoai.app/community/events/42"))
        XCTAssertNil(CommunityDiscovery.inviteToken(from: "https://lyoai.app/community/invite/\(token) thanks"))
        XCTAssertNil(CommunityDiscovery.inviteToken(from: "short"))
        XCTAssertNil(CommunityDiscovery.inviteToken(from: ""))
        XCTAssertNil(CommunityDiscovery.inviteToken(from: "https://lyoai.app/community/invite/<script>alert(1)</script>"))
        XCTAssertEqual(CommunityDiscovery.invitePath(token), "/community/invite/\(token)")
        XCTAssertEqual(CommunityDiscovery.inviteURL(token)?.absoluteString, "https://lyoai.app/community/invite/\(token)")
    }

    private func link(_ json: String) throws -> APIEventInvite {
        try JSONDecoder.lyoDecoder.decode(APIEventInvite.self, from: Data(json.utf8))
    }

    func testInviteLinksSayHowTheyAreUsedAndWhyTheyStopped() throws {
        let utc = try XCTUnwrap(TimeZone(identifier: "UTC"))
        let locale = Locale(identifier: "en_US")
        let now = try XCTUnwrap(CommunityDiscovery.parseDate("2026-09-20T12:00:00Z"))
        let base = #""id":1,"token":"t","url":"https://lyoai.app/community/invite/t","created_at":"2026-09-01T00:00:00Z""#
        let limited = try link("{\(base),\"expires_at\":\"2026-09-30T12:00:00Z\",\"max_uses\":5,\"use_count\":2,\"active\":true}")
        XCTAssertEqual(CommunityDiscovery.describeInviteLink(limited, now: now, timeZone: utc, locale: locale), "Used 2 of 5 · Expires Sep 30")
        let unlimited = try link("{\(base),\"use_count\":1,\"active\":true}")
        XCTAssertEqual(CommunityDiscovery.describeInviteLink(unlimited, now: now, timeZone: utc, locale: locale), "Used 1 time")
        let full = try link("{\(base),\"max_uses\":1,\"use_count\":1,\"active\":false}")
        XCTAssertEqual(CommunityDiscovery.describeInviteLink(full, now: now), "Used 1 of 1 · Used up")
        let expired = try link("{\(base),\"expires_at\":\"2026-09-10T00:00:00Z\",\"use_count\":0,\"active\":false}")
        XCTAssertEqual(CommunityDiscovery.describeInviteLink(expired, now: now), "Used 0 times · Expired")
        let revoked = try link("{\(base),\"expires_at\":\"2026-09-30T00:00:00Z\",\"use_count\":3,\"active\":false}")
        XCTAssertEqual(CommunityDiscovery.describeInviteLink(revoked, now: now), "Used 3 times · Turned off")
    }

    func testGuestRowsAndClosedInvitesReadPlainly() throws {
        let guest = try JSONDecoder.lyoDecoder.decode(
            APIEventGuest.self,
            from: Data(#"{"user":{"id":7,"name":"Ana"},"source":"link","invited_at":"2026-09-01T00:00:00Z","rsvp_status":"going"}"#.utf8)
        )
        XCTAssertEqual(CommunityDiscovery.describeGuest(guest), "Going · Joined with a link")
        let named = try JSONDecoder.lyoDecoder.decode(
            APIEventGuest.self,
            from: Data(#"{"user":{"id":8,"name":"Cara"},"source":"direct","invited_at":"2026-09-01T00:00:00Z"}"#.utf8)
        )
        XCTAssertEqual(CommunityDiscovery.describeGuest(named), "No reply yet · Invited by name")

        XCTAssertNil(CommunityDiscovery.inviteNotice(for: "valid"))
        for status in ["expired", "revoked", "used_up", "ended", "cancelled", "something_new"] {
            XCTAssertNotNil(CommunityDiscovery.inviteNotice(for: status), status)
        }
        XCTAssertEqual(CommunityDiscovery.inviteNotice(for: "revoked")?.title, "This invite was turned off")
        XCTAssertEqual(CommunityDiscovery.inviteError(LyoError.network(.notFound)).title, "This invite link isn't valid")
    }

    func testOnlyHostsOfOpenPrivateOrUnlistedEventsManageInvites() throws {
        let privateEvent = try makeNode(["visibility": "private", "lifecycle": "upcoming"])
        XCTAssertTrue(CommunityDiscovery.canManageInvites(privateEvent, canEdit: true))
        XCTAssertFalse(CommunityDiscovery.canManageInvites(privateEvent, canEdit: false))
        XCTAssertTrue(CommunityDiscovery.canManageInvites(try makeNode(["visibility": "unlisted"]), canEdit: true))
        XCTAssertFalse(CommunityDiscovery.canManageInvites(try makeNode(["visibility": "public"]), canEdit: true))
        XCTAssertFalse(CommunityDiscovery.canManageInvites(
            try makeNode(["visibility": "private", "lifecycle": "cancelled"]), canEdit: true))
        XCTAssertFalse(CommunityDiscovery.canManageInvites(
            try makeNode(["visibility": "private", "lifecycle": "past"]), canEdit: true))
    }

    func testInviteRequestsAndResponsesMatchTheBackend() throws {
        let anyone = try XCTUnwrap(JSONSerialization.jsonObject(
            with: JSONEncoder.lyoEncoder.encode(APIInviteCreateRequest(maxUses: nil, expiresInDays: 30))
        ) as? [String: Any])
        XCTAssertTrue(anyone["max_uses"] is NSNull, "anyone is sent as an explicit null")
        XCTAssertEqual(anyone["expires_in_days"] as? Int, 30)
        let guest = try XCTUnwrap(JSONSerialization.jsonObject(
            with: JSONEncoder.lyoEncoder.encode(APIGuestCreateRequest(userId: 12))
        ) as? [String: Any])
        XCTAssertEqual(guest["user_id"] as? Int, 12)

        let preview = try JSONDecoder.lyoDecoder.decode(APIInvitePreview.self, from: Data(#"""
        {"status":"valid","already_guest":false,"is_host":false,"event_id":42,"title":"Private chemistry lab",
         "starts_at":"2026-09-27T22:00:00Z","ends_at":null,"timezone":"America/New_York","location_name":"Hunter College",
         "attendance_mode":"in_person","visibility":"private","host":{"id":3,"name":"Ben","avatar":null},
         "organizer_name":"Ben Okafor","image_url":null}
        """#.utf8))
        XCTAssertEqual(preview.eventId, 42)
        XCTAssertEqual(preview.organizerName, "Ben Okafor")

        let invited = try makeNode(["is_invited": true, "visibility": "private"])
        XCTAssertEqual(invited.isInvited, true)
        XCTAssertNil(try makeNode().isInvited, "older payloads without the flag still decode")
    }
}
