import SwiftUI
import MapKit
import EventKit
import EventKitUI

/// Full page for one event, group, tutor, or place. Opened from a preview,
/// My Community, a related item, or a shared link; it reads the item from the
/// backend so it also works for past, cancelled, and private events.
struct CommunityNodeDetailView: View {
    let route: CommunityNodeRoute
    @ObservedObject var viewModel: CommunityViewModel
    let openRoute: (CommunityNodeRoute) -> Void
    let editEvent: (APICommunityEventRecord) -> Void
    let onDeleted: () -> Void

    @State private var loadError: CommunityDiscovery.FriendlyError?
    @State private var showCalendar = false
    @State private var showReport = false
    @State private var showInvites = false
    @State private var confirmation: Confirmation?
    @State private var working = false
    @Environment(\.openURL) private var openURL

    private enum Confirmation: Equatable {
        case cancel, delete
    }

    private struct ReportReason: Identifiable {
        let id: String
        let label: String
    }

    private static let reportReasons = [
        ReportReason(id: "spam", label: "Spam or advertising"),
        ReportReason(id: "misinformation", label: "Misleading or fake event"),
        ReportReason(id: "inappropriate", label: "Inappropriate content"),
        ReportReason(id: "harassment", label: "Harassment or hate"),
        ReportReason(id: "other", label: "Something else"),
    ]

    private var detail: APILearningNodeDetail? { viewModel.cachedDetail(route) }

    var body: some View {
        Group {
            if let detail {
                content(detail)
            } else if let loadError {
                CommunityStateView(
                    icon: loadError == CommunityDiscovery.offlineError ? "wifi.slash" : "exclamationmark.magnifyingglass",
                    title: loadError.title,
                    message: loadError.body,
                    actions: loadError.retry ? [("Try again", { Task { await load() } })] : []
                )
                .frame(maxHeight: .infinity)
            } else {
                ProgressView("Loading…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(DesignTokens.Colors.background)
        .navigationTitle(detail?.node.categoryLabel ?? "Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let url = CommunityDiscovery.shareURL(kind: route.kind, id: route.id), let node = detail?.node {
                    ShareLink(item: url, subject: Text(node.title), message: Text(shareMessage(node))) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .simultaneousGesture(TapGesture().onEnded {
                        viewModel.track("community_event_shared", ["kind": node.kind])
                    })
                    .accessibilityLabel("Share")
                }
            }
        }
        .task(id: viewModel.revision) { await load() }
        .sheet(isPresented: $showCalendar) {
            if let node = detail?.node {
                CommunityCalendarSheet(
                    node: node,
                    pageURL: CommunityDiscovery.shareURL(kind: node.kind, id: node.id),
                    onFinish: { showCalendar = false }
                )
                .ignoresSafeArea()
            }
        }
        .sheet(isPresented: $showInvites) {
            if let node = detail?.node {
                CommunityInviteManagerView(node: node, viewModel: viewModel)
            }
        }
        .confirmationDialog("Report this event", isPresented: $showReport, titleVisibility: .visible) {
            ForEach(Self.reportReasons) { reason in
                Button(reason.label) {
                    guard let node = detail?.node else { return }
                    Task { await viewModel.reportEvent(node, reason: reason.id, note: nil) }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Our team reviews every report. The host isn't told who reported it.")
        }
        .alert(
            confirmation == .delete ? "Delete this event?" : "Cancel this event?",
            isPresented: Binding(get: { confirmation != nil }, set: { if !$0 { confirmation = nil } }),
            presenting: confirmation
        ) { kind in
            if kind == .delete {
                Button("Delete", role: .destructive) { Task { await deleteEvent() } }
                Button("Keep it", role: .cancel) {}
            } else {
                Button("Cancel event", role: .destructive) { Task { await cancelEvent() } }
                Button("Keep it", role: .cancel) {}
            }
        } message: { kind in
            Text(kind == .delete
                 ? "It will be removed for everyone. This can't be undone."
                 : "It stays visible as cancelled to people who RSVP'd, and leaves the map.")
        }
    }

    // MARK: Content

    @ViewBuilder
    private func content(_ detail: APILearningNodeDetail) -> some View {
        let node = detail.node
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let image = CommunityDiscovery.safeWebURL(node.imageUrl) {
                    AsyncImage(url: image) { phase in
                        if case .success(let loaded) = phase {
                            loaded.resizable().aspectRatio(contentMode: .fill)
                        } else {
                            node.categoryColor.opacity(0.15)
                        }
                    }
                    .frame(height: 190)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .accessibilityHidden(true)
                }

                header(node, canEdit: detail.canEdit)

                if loadError != nil {
                    Label("Couldn't refresh. Showing what we had.", systemImage: "clock.arrow.circlepath")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if node.lifecycle == "cancelled" {
                    Text("This event was cancelled by the host.")
                        .font(.subheadline)
                        .foregroundStyle(DesignTokens.Colors.danger)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(DesignTokens.Colors.danger.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                }

                CommunityPrimaryActions(node: node, viewModel: viewModel)

                infoCard(node)

                secondaryActions(node)

                if let description = node.description, !description.isEmpty {
                    section("About") {
                        Text(description)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
                if let relevance = node.relevance, !relevance.isEmpty {
                    section("Why it's here") {
                        Text(relevance).font(.body).foregroundStyle(.secondary)
                    }
                }

                if detail.canEdit, let record = detail.event {
                    section("Your event") {
                        VStack(spacing: 8) {
                            if CommunityDiscovery.canManageInvites(node, canEdit: detail.canEdit) {
                                ownerButton("Invite people", icon: "person.crop.circle.badge.plus") {
                                    showInvites = true
                                }
                            }
                            ownerButton("Edit event", icon: "pencil") { editEvent(record) }
                            if node.lifecycle != "cancelled" && node.lifecycle != "past" {
                                ownerButton("Cancel event", icon: "xmark.circle", color: DesignTokens.Colors.warning) {
                                    confirmation = .cancel
                                }
                            }
                            ownerButton("Delete event", icon: "trash", color: DesignTokens.Colors.danger) {
                                confirmation = .delete
                            }
                        }
                        .disabled(working)
                    }
                } else if node.kind == "event" && node.isOwner != true {
                    Button { showReport = true } label: {
                        Label("Report this event", systemImage: "flag")
                            .font(.subheadline)
                            .frame(minHeight: 44)
                    }
                    .foregroundStyle(.secondary)
                }

                if !detail.related.isEmpty {
                    section("More like this nearby") {
                        VStack(spacing: 10) {
                            ForEach(detail.related, id: \.key) { related in
                                LearningNodeRow(node: related) { openRoute(CommunityNodeRoute(related)) }
                            }
                        }
                    }
                }
            }
            .padding(16)
            .padding(.bottom, 40)
        }
        .refreshable { await load() }
    }

    private func header(_ node: APILearningNode, canEdit: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Label(node.categoryLabel, systemImage: node.categoryIcon)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(node.categoryColor)
                if let badge = node.statusBadge {
                    Text(badge)
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(node.statusBadgeColor.opacity(0.18), in: Capsule())
                        .foregroundStyle(node.statusBadgeColor)
                }
                if node.isInvited == true && !canEdit {
                    Text("You're invited")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(DesignTokens.Colors.accent.opacity(0.2), in: Capsule())
                        .foregroundStyle(DesignTokens.Colors.accent)
                }
            }
            Text(node.title)
                .font(.title2.weight(.bold))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
        }
    }

    private func infoCard(_ node: APILearningNode) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let when = node.whenText {
                CommunityInfoLine(icon: "clock", text: when)
            }
            if let place = node.placeLine {
                CommunityInfoLine(
                    icon: node.attendanceMode == "online" ? "video" : "mappin.and.ellipse",
                    text: [place, node.distanceText].compactMap { $0 }.joined(separator: " · ")
                )
            }
            if let organizer = node.organizerLine {
                CommunityInfoLine(icon: "person", text: organizer)
            }
            if let price = node.priceText {
                CommunityInfoLine(icon: "tag", text: price)
            }
            if let people = node.peopleLine {
                CommunityInfoLine(icon: "person.2", text: people)
            }
            if let hours = node.openingHours, !hours.isEmpty {
                CommunityInfoLine(icon: "clock.badge.checkmark", text: hours)
            }
            if let latitude = node.latitude, let longitude = node.longitude {
                let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                Map(
                    initialPosition: .region(MKCoordinateRegion(
                        center: coordinate,
                        latitudinalMeters: 900,
                        longitudinalMeters: 900
                    )),
                    interactionModes: []
                ) {
                    Marker(node.title, coordinate: coordinate)
                        .tint(node.categoryColor)
                }
                .frame(height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .accessibilityLabel("Map showing \(node.placeLine ?? node.title)")
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignTokens.Colors.surface, in: RoundedRectangle(cornerRadius: 16))
    }

    private func secondaryActions(_ node: APILearningNode) -> some View {
        let calendarAvailable = node.kind == "event" && !node.hasEnded && node.startsAt != nil
        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], spacing: 8) {
            if let directions = CommunityDiscovery.directionsURL(node) {
                actionTile("Directions", icon: "arrow.triangle.turn.up.right.diamond") {
                    viewModel.track("community_directions_opened", ["kind": node.kind])
                    openURL(directions)
                }
            }
            if calendarAvailable {
                actionTile("Add to calendar", icon: "calendar.badge.plus") { showCalendar = true }
            }
            if let meeting = CommunityDiscovery.safeWebURL(node.meetingUrl), !node.hasEnded {
                actionTile("Join online", icon: "video") { openURL(meeting) }
            }
            if let website = CommunityDiscovery.safeWebURL(node.websiteUrl ?? node.sourceUrl) {
                actionTile("Website", icon: "safari") { openURL(website) }
            }
            if let phone = node.phone, let url = URL(string: "tel:" + phone.filter { "0123456789+".contains($0) }),
               phone.contains(where: \.isNumber) {
                actionTile("Call", icon: "phone") { openURL(url) }
            }
            if let email = node.email, email.contains("@"),
               let url = URL(string: "mailto:" + (email.addingPercentEncoding(withAllowedCharacters: .urlUserAllowed) ?? email)) {
                actionTile("Email", icon: "envelope") { openURL(url) }
            }
            if let courseId = node.courseId {
                actionTile("Open course", icon: "graduationcap") {
                    NotificationCenter.default.post(
                        name: .openClassroom,
                        object: nil,
                        userInfo: ["courseId": String(courseId), "courseTitle": node.title]
                    )
                }
            }
            actionTile("Ask Lyo", icon: "sparkles") {
                NotificationCenter.default.post(name: NSNotification.Name("TriggerLioChat"), object: nil)
            }
        }
    }

    private func actionTile(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private func ownerButton(_ title: String, icon: String, color: Color = .primary, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(color)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .padding(.horizontal, 12)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            content()
        }
    }

    private func shareMessage(_ node: APILearningNode) -> String {
        [node.title, node.whenText, node.placeLine].compactMap { $0 }.joined(separator: " · ")
    }

    // MARK: Actions

    @MainActor
    private func load() async {
        do {
            _ = try await viewModel.loadDetail(route)
            loadError = nil
        } catch {
            guard !(error is CancellationError) else { return }
            loadError = CommunityDiscovery.friendlyError(error, action: "load this")
        }
    }

    @MainActor
    private func cancelEvent() async {
        guard let id = detail?.event?.id else { return }
        working = true
        await viewModel.cancelEvent(id: id)
        working = false
    }

    @MainActor
    private func deleteEvent() async {
        guard let id = detail?.event?.id else { return }
        working = true
        do {
            try await viewModel.deleteEvent(id: id)
            working = false
            onDeleted()
        } catch {
            working = false
            viewModel.showToast(CommunityDiscovery.friendlyError(error, action: "delete this event").message)
        }
    }
}

// MARK: - Add to calendar

/// The system's own "New Event" screen, prefilled. On iOS 17 it runs out of
/// process, so Lyo never needs to read the learner's calendar.
struct CommunityCalendarSheet: UIViewControllerRepresentable {
    let node: APILearningNode
    let pageURL: URL?
    let onFinish: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    func makeUIViewController(context: Context) -> EKEventEditViewController {
        let store = EKEventStore()
        let controller = EKEventEditViewController()
        controller.eventStore = store
        controller.editViewDelegate = context.coordinator

        let event = EKEvent(eventStore: store)
        event.title = node.title
        let start = CommunityDiscovery.parseDate(node.startsAt) ?? Date()
        event.startDate = start
        event.endDate = CommunityDiscovery.parseDate(node.endsAt) ?? start.addingTimeInterval(3_600)
        let place = [node.venueName, node.address ?? node.locationName]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
        if !place.isEmpty { event.location = place }
        event.notes = node.description
        event.url = pageURL
        controller.event = event
        return controller
    }

    func updateUIViewController(_ controller: EKEventEditViewController, context: Context) {}

    final class Coordinator: NSObject, EKEventEditViewDelegate {
        let onFinish: () -> Void

        init(onFinish: @escaping () -> Void) {
            self.onFinish = onFinish
        }

        func eventEditViewController(_ controller: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction) {
            onFinish()
        }
    }
}
