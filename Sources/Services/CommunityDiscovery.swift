import Foundation

// Pure Community discovery rules for the iOS screens and their tests.
// Mirrors web/src/lib/community-contract.mjs so a filter, a "Search this area"
// decision, a price, or an error message reads the same on every platform.
// No SwiftUI and no networking: everything is a function of its inputs.

/// Query for `GET /community/nearby`.
struct CommunityNearbyParams: Hashable {
    var latitude: Double
    var longitude: Double
    var radiusKm: Double
    var categories: [String] = []
    var placeTypes: [String] = []
    var query: String? = nil
    var when: String? = nil
    var freeOnly = false
    var includeOnline = true
    var includeInstitutions = true
    var limit = 200
    var timeZone = TimeZone.current.identifier

    var queryItems: [URLQueryItem] {
        var items = [
            URLQueryItem(name: "lat", value: String(format: "%.4f", latitude)),
            URLQueryItem(name: "lng", value: String(format: "%.4f", longitude)),
            URLQueryItem(name: "radius_km", value: String(format: "%.1f", radiusKm)),
            URLQueryItem(name: "include_online", value: includeOnline ? "true" : "false"),
            URLQueryItem(name: "include_institutions", value: includeInstitutions ? "true" : "false"),
            URLQueryItem(name: "limit", value: String(limit)),
        ]
        if !categories.isEmpty {
            items.append(URLQueryItem(name: "categories", value: categories.joined(separator: ",")))
        }
        if let query = query?.trimmingCharacters(in: .whitespacesAndNewlines), !query.isEmpty {
            items.append(URLQueryItem(name: "q", value: query))
        }
        if let when {
            items.append(URLQueryItem(name: "when", value: when))
        }
        if freeOnly {
            items.append(URLQueryItem(name: "free_only", value: "true"))
        }
        if !placeTypes.isEmpty {
            items.append(URLQueryItem(name: "place_types", value: placeTypes.joined(separator: ",")))
        }
        if !timeZone.isEmpty {
            items.append(URLQueryItem(name: "tz", value: timeZone))
        }
        return items
    }
}

/// A map item the detail screen can open by kind and id.
struct CommunityNodeRoute: Hashable {
    let kind: String
    let id: String

    init(kind: String, id: String) {
        self.kind = kind
        self.id = id
    }

    init(_ node: APILearningNode) {
        self.init(kind: node.kind, id: node.id)
    }

    var key: String { "\(kind):\(id)" }
}

enum CommunityDiscovery {
    static let defaultLatitude = 40.7128
    static let defaultLongitude = -74.006
    static let defaultLabel = "New York City"
    static let defaultRadiusKm = 12.0
    static let nearbyRadiusKm = 3.0
    static let maxSearchRadiusKm = 50.0
    static let webBaseURL = "https://lyoai.app"

    /// Every map category, in the order the filter row shows them.
    static let nodeCategories = [
        "event", "workshop", "class", "study_group", "tutor", "library", "museum", "educational_center",
    ]
    static let schoolPlaceTypes = ["university", "college"]
    static let learningCenterPlaceTypes = [
        "language_school", "music_school", "prep_school", "training", "community_centre",
    ]

    // MARK: - Filters

    enum Modifier: Hashable {
        case free
        case when(String)
        case nearby
    }

    /// A filter chip. `categories` / `placeTypes` narrow *what* appears; the
    /// modifiers narrow *which* of those appear, so any combination is
    /// meaningful: "Workshops + Free + This week".
    struct Filter: Identifiable, Hashable {
        let id: String
        let label: String
        let icon: String
        var categories: [String] = []
        var placeTypes: [String] = []
        var modifier: Modifier? = nil

        var isTimeWindow: Bool {
            if case .some(.when(_)) = modifier { return true }
            return false
        }
    }

    static let filters: [Filter] = [
        Filter(id: "events", label: "Events", icon: "calendar", categories: ["event"]),
        Filter(id: "libraries", label: "Libraries", icon: "books.vertical.fill", categories: ["library"]),
        Filter(id: "museums", label: "Museums", icon: "building.columns.fill", categories: ["museum"]),
        Filter(id: "classes", label: "Classes", icon: "graduationcap.fill", categories: ["class"]),
        Filter(id: "workshops", label: "Workshops", icon: "hammer.fill", categories: ["workshop"]),
        Filter(id: "study_groups", label: "Study groups", icon: "person.3.fill", categories: ["study_group"]),
        Filter(id: "schools", label: "Schools & universities", icon: "building.2.fill",
               categories: ["educational_center"], placeTypes: schoolPlaceTypes),
        Filter(id: "learning_centers", label: "Learning centers", icon: "lightbulb.fill",
               categories: ["educational_center"], placeTypes: learningCenterPlaceTypes),
        Filter(id: "tutors", label: "Tutors", icon: "person.crop.circle.badge.checkmark", categories: ["tutor"]),
        Filter(id: "free", label: "Free", icon: "tag.fill", modifier: .free),
        Filter(id: "today", label: "Today", icon: "sun.max.fill", modifier: .when("today")),
        Filter(id: "week", label: "This week", icon: "calendar.badge.clock", modifier: .when("week")),
        Filter(id: "nearby", label: "Nearby", icon: "location.fill", modifier: .nearby),
    ]

    static func filter(id: String) -> Filter? {
        filters.first { $0.id == id }
    }

    /// Toggle a chip. "Today" and "This week" are mutually exclusive.
    static func toggle(_ active: Set<String>, _ id: String) -> Set<String> {
        var next = active
        if next.contains(id) {
            next.remove(id)
            return next
        }
        guard let chosen = Self.filter(id: id) else { return next }
        if chosen.isTimeWindow {
            for other in filters where other.isTimeWindow {
                next.remove(other.id)
            }
        }
        next.insert(id)
        return next
    }

    struct FilterQuery: Equatable {
        var categories: [String] = []
        var placeTypes: [String] = []
        var freeOnly = false
        var when: String? = nil
        var nearby = false
    }

    /// Translate the active chips into `/community/nearby` parameters.
    static func query(for active: Set<String>) -> FilterQuery {
        var categories = Set<String>()
        var placeTypes = Set<String>()
        var broadPlaces = false
        var result = FilterQuery()
        for filter in filters where active.contains(filter.id) {
            if !filter.categories.isEmpty {
                categories.formUnion(filter.categories)
                if !filter.placeTypes.isEmpty {
                    placeTypes.formUnion(filter.placeTypes)
                } else if filter.categories.contains("educational_center") {
                    broadPlaces = true
                }
            }
            switch filter.modifier {
            case .some(.free): result.freeOnly = true
            case .some(.when(let value)): result.when = value
            case .some(.nearby): result.nearby = true
            case .none: break
            }
        }
        result.categories = categories.sorted()
        result.placeTypes = broadPlaces ? [] : placeTypes.sorted()
        return result
    }

    static func activeFilterLabels(_ active: Set<String>) -> [String] {
        filters.filter { active.contains($0.id) }.map(\.label)
    }

    // MARK: - Geography

    private static let earthRadiusKm = 6371.0088

    static func distanceKm(_ latitudeA: Double, _ longitudeA: Double, _ latitudeB: Double, _ longitudeB: Double) -> Double {
        let toRadians = { (degrees: Double) in degrees * .pi / 180 }
        let dLat = toRadians(latitudeB - latitudeA)
        let dLng = toRadians(longitudeB - longitudeA)
        let h = pow(sin(dLat / 2), 2)
            + cos(toRadians(latitudeA)) * cos(toRadians(latitudeB)) * pow(sin(dLng / 2), 2)
        return 2 * earthRadiusKm * asin(min(1, sqrt(h)))
    }

    struct SearchArea: Hashable {
        var latitude: Double
        var longitude: Double
        var radiusKm: Double
    }

    /// Search area covering a visible map viewport: its center and half-diagonal.
    static func area(
        centerLatitude: Double,
        centerLongitude: Double,
        latitudeDelta: Double,
        longitudeDelta: Double
    ) -> SearchArea {
        let north = centerLatitude + latitudeDelta / 2
        let east = centerLongitude + longitudeDelta / 2
        let radius = min(maxSearchRadiusKm, max(0.5, distanceKm(centerLatitude, centerLongitude, north, east)))
        return SearchArea(
            latitude: centerLatitude,
            longitude: centerLongitude,
            radiusKm: (radius * 10).rounded() / 10
        )
    }

    /// Whether the visible map differs enough from the searched area to offer
    /// "Search this area". Small pans and zooms never trigger a request.
    static func shouldOfferAreaSearch(searched: SearchArea?, visible: SearchArea?) -> Bool {
        guard let searched, let visible else { return false }
        let moved = distanceKm(searched.latitude, searched.longitude, visible.latitude, visible.longitude)
        let larger = max(searched.radiusKm, visible.radiusKm)
        let smaller = max(0.1, min(searched.radiusKm, visible.radiusKm))
        return moved > searched.radiusKm * 0.35 || larger / smaller > 1.8
    }

    // MARK: - Clustering

    struct Cluster: Identifiable {
        let id: String
        let latitude: Double
        let longitude: Double
        let members: [APILearningNode]
        let north: Double
        let south: Double
        let east: Double
        let west: Double
    }

    /// Web-Mercator position of a coordinate on a world `worldSize` points wide.
    static func project(latitude: Double, longitude: Double, worldSize: Double) -> (x: Double, y: Double) {
        let x = (longitude + 180) / 360 * worldSize
        let clamped = min(max(latitude, -85.05112878), 85.05112878)
        let sinLat = sin(clamped * .pi / 180)
        let y = (0.5 - log((1 + sinLat) / (1 - sinLat)) / (4 * .pi)) * worldSize
        return (x, y)
    }

    /// World width in points when `longitudeDelta` degrees fill `viewWidth` points.
    static func worldSize(longitudeDelta: Double, viewWidth: Double) -> Double {
        guard longitudeDelta > 0, viewWidth > 0 else { return 256 }
        return 360 / longitudeDelta * viewWidth
    }

    /// Group markers that would overlap on screen. `project` maps a node to
    /// points at the current zoom, so one function serves every zoom level.
    /// Nodes without coordinates are skipped.
    static func cluster(
        _ nodes: [APILearningNode],
        cellPoints: Double = 52,
        project: (APILearningNode) -> (x: Double, y: Double)
    ) -> [Cluster] {
        var order: [String] = []
        var cells: [String: [APILearningNode]] = [:]
        for node in nodes {
            guard let latitude = node.latitude, let longitude = node.longitude,
                  latitude.isFinite, longitude.isFinite else { continue }
            let point = project(node)
            let key = "\(Int(floor(point.x / cellPoints))):\(Int(floor(point.y / cellPoints)))"
            if cells[key] == nil {
                order.append(key)
                cells[key] = [node]
            } else {
                cells[key]?.append(node)
            }
        }
        return order.compactMap { key -> Cluster? in
            guard let members = cells[key], !members.isEmpty else { return nil }
            let latitudes = members.compactMap(\.latitude)
            let longitudes = members.compactMap(\.longitude)
            return Cluster(
                id: members.map(\.key).sorted().joined(separator: "|"),
                latitude: latitudes.reduce(0, +) / Double(latitudes.count),
                longitude: longitudes.reduce(0, +) / Double(longitudes.count),
                members: members,
                north: latitudes.max() ?? 0,
                south: latitudes.min() ?? 0,
                east: longitudes.max() ?? 0,
                west: longitudes.min() ?? 0
            )
        }
    }

    // MARK: - Presentation

    static let categoryLabels: [String: String] = [
        "event": "Event",
        "workshop": "Workshop",
        "class": "Class",
        "study_group": "Study group",
        "tutor": "Tutor",
        "library": "Library",
        "museum": "Museum",
        "educational_center": "Learning center",
    ]

    static let placeTypeLabels: [String: String] = [
        "university": "University",
        "college": "College",
        "language_school": "Language school",
        "music_school": "Music school",
        "prep_school": "Tutoring center",
        "training": "Training center",
        "community_centre": "Community learning center",
        "planetarium": "Planetarium",
        "museum": "Museum",
        "library": "Library",
        "tutoring": "Tutoring",
    ]

    static func categoryLabel(category: String, placeType: String? = nil) -> String {
        if let placeType, let label = placeTypeLabels[placeType] { return label }
        return categoryLabels[category] ?? "Learning"
    }

    static let lifecycleLabels: [String: String] = [
        "upcoming": "Upcoming",
        "today": "Today",
        "live": "Happening now",
        "past": "Ended",
        "cancelled": "Cancelled",
    ]

    static func formatDistance(_ km: Double?) -> String? {
        guard let km, km.isFinite else { return nil }
        if km < 0.1 { return "Here" }
        if km < 1 { return "\(Int((km * 100).rounded()) * 10) m" }
        if km < 10 { return String(format: "%.1f km", km) }
        return "\(Int(km.rounded())) km"
    }

    static func formatPrice(isFree: Bool?, amount: Double?, currency: String?) -> String? {
        if isFree == true { return "Free" }
        if let amount {
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.locale = Locale(identifier: "en_US")
            formatter.currencyCode = (currency?.isEmpty == false ? currency : nil) ?? "USD"
            let whole = amount.rounded() == amount
            formatter.minimumFractionDigits = whole ? 0 : 2
            formatter.maximumFractionDigits = 2
            return formatter.string(from: NSNumber(value: amount)) ?? "\(formatter.currencyCode ?? "USD") \(amount)"
        }
        if isFree == false { return "Paid" }
        return nil
    }

    /// Server instants: ISO-8601 with or without fractional seconds. A value
    /// without a timezone is a legacy UTC timestamp.
    static func parseDate(_ value: String?) -> Date? {
        guard let value, !value.isEmpty else { return nil }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: value) { return date }
        if let date = ISO8601DateFormatter().date(from: value) { return date }
        let naive = DateFormatter()
        naive.locale = Locale(identifier: "en_US_POSIX")
        naive.timeZone = TimeZone(identifier: "UTC")
        for format in ["yyyy-MM-dd'T'HH:mm:ss.SSSSSS", "yyyy-MM-dd'T'HH:mm:ss"] {
            naive.dateFormat = format
            if let date = naive.date(from: value) { return date }
        }
        return nil
    }

    /// "Sun, Sep 27 · 6:00 PM – 8:00 PM" in the viewer's own timezone.
    static func formatWhen(
        _ startsAt: String?,
        _ endsAt: String?,
        timeZone: TimeZone = .current,
        locale: Locale = .current
    ) -> String? {
        guard let start = parseDate(startsAt) else { return nil }
        let day = DateFormatter()
        day.locale = locale
        day.timeZone = timeZone
        day.setLocalizedDateFormatFromTemplate("EEEMMMd")
        let time = DateFormatter()
        time.locale = locale
        time.timeZone = timeZone
        time.setLocalizedDateFormatFromTemplate("jmm")
        let clean = { (text: String) in text.replacingOccurrences(of: "\u{202F}", with: " ") }
        let startText = "\(clean(day.string(from: start))) · \(clean(time.string(from: start)))"
        guard let end = parseDate(endsAt) else { return startText }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        if calendar.isDate(start, inSameDayAs: end) {
            return "\(startText) – \(clean(time.string(from: end)))"
        }
        let endDay = DateFormatter()
        endDay.locale = locale
        endDay.timeZone = timeZone
        endDay.setLocalizedDateFormatFromTemplate("MMMd")
        return "\(startText) – \(clean(endDay.string(from: end))), \(clean(time.string(from: end)))"
    }

    /// A plain http(s) URL, or nil for anything else (javascript:, data:, …).
    static func safeWebURL(_ value: String?) -> URL? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty,
              let url = URL(string: value),
              let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http",
              let host = url.host, !host.isEmpty else { return nil }
        return url
    }

    /// Apple Maps directions to a node's public location. The viewer's own
    /// position is never part of the link; Maps asks the device itself.
    static func directionsURL(_ node: APILearningNode) -> URL? {
        var components = URLComponents(string: "https://maps.apple.com/")
        if let latitude = node.latitude, let longitude = node.longitude {
            components?.queryItems = [URLQueryItem(name: "daddr", value: "\(latitude),\(longitude)")]
            return components?.url
        }
        guard node.attendanceMode != "online", !node.isOnline || node.attendanceMode == "hybrid" else { return nil }
        let place = [node.address, node.locationName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
        guard let place else { return nil }
        components?.queryItems = [URLQueryItem(name: "daddr", value: place)]
        return components?.url
    }

    private static let uriComponentAllowed = CharacterSet(
        charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.!~*'()"
    )

    /// The same stable path the web app serves for this item.
    static func detailPath(kind: String, id: String) -> String {
        let encoded = id.addingPercentEncoding(withAllowedCharacters: uriComponentAllowed) ?? id
        if kind == "event" { return "/community/events/\(encoded)" }
        return "/community/places/\(kind)/\(encoded)"
    }

    static func shareURL(kind: String, id: String) -> URL? {
        URL(string: webBaseURL + detailPath(kind: kind, id: id))
    }

    /// Optimistic RSVP: the counts a learner sees the instant they tap.
    static func applyingRSVP(_ status: String?, to node: APILearningNode) -> APILearningNode {
        var next = node
        let previous = node.rsvpStatus
        let going = (node.goingCount ?? 0) + (status == "going" ? 1 : 0) - (previous == "going" ? 1 : 0)
        let interested = (node.interestedCount ?? 0)
            + (status == "interested" ? 1 : 0) - (previous == "interested" ? 1 : 0)
        next.rsvpStatus = status
        next.isAttending = status != nil
        next.goingCount = max(0, going)
        next.interestedCount = max(0, interested)
        return next
    }

    // MARK: - Errors

    struct FriendlyError: Equatable {
        let title: String
        let body: String
        let retry: Bool

        /// One line for a toast: the specific reason when there is one.
        var message: String {
            title == "That didn't work" ? body : "\(title) \(body)"
        }
    }

    static let offlineError = FriendlyError(
        title: "You're offline",
        body: "Check your connection and try again.",
        retry: true
    )

    /// Learner-facing copy for a failed Community request. Technical details
    /// are logged by the caller, never shown as the message.
    static func friendlyError(_ error: Error, action: String = "load nearby learning opportunities") -> FriendlyError {
        let generic = FriendlyError(title: "We couldn't \(action).", body: "Please try again in a moment.", retry: true)
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .timedOut,
                 .cannotConnectToHost, .cannotFindHost, .dataNotAllowed:
                return offlineError
            default:
                return generic
            }
        }
        guard let lyoError = error as? LyoError else { return generic }
        switch lyoError {
        case .offlineMode,
             .network(.noInternetConnection),
             .network(.connectionFailed(_)),
             .network(.timeout):
            return offlineError
        case .network(.unauthorized):
            return FriendlyError(title: "Please sign in again", body: "Your session ended.", retry: false)
        case .network(.notFound):
            return FriendlyError(
                title: "This is no longer available",
                body: "It may have been removed or made private.",
                retry: false
            )
        case .network(.forbidden), .network(.unknown(403)):
            return FriendlyError(title: "That didn't work", body: "You don't have permission to do that.", retry: false)
        case .rateLimitExceeded:
            return FriendlyError(
                title: "That didn't work",
                body: "You're going a little fast. Please wait a moment and try again.",
                retry: true
            )
        case .serverError(let message):
            // A 409/422 reason from the backend envelope ("This event is full").
            let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
            return FriendlyError(
                title: "That didn't work",
                body: trimmed.isEmpty ? "Please check the details and try again." : trimmed,
                retry: false
            )
        case .validation(_), .network(.badRequest), .network(.unknown(409)), .network(.unknown(422)):
            return FriendlyError(title: "That didn't work", body: "Please check the details and try again.", retry: false)
        default:
            return generic
        }
    }
}
