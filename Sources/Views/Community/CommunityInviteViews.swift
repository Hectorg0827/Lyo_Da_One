import SwiftUI
import UIKit

// MARK: - Host: invite people

/// Host-only: who can get into a private or unlisted event. Invite links can
/// be limited and turned off; Lyo members can be invited by name (the backend
/// notifies them on every device); anyone on the guest list can be removed.
/// Links and guests live on the backend, never only on this iPhone.
struct CommunityInviteManagerView: View {
    let node: APILearningNode
    @ObservedObject var viewModel: CommunityViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var invitations: APIEventInvitesResponse?
    @State private var loadError: CommunityDiscovery.FriendlyError?
    /// 0 means anyone with the link can use it until it expires.
    @State private var maxUses = 0
    @State private var expiresInDays = 30
    @State private var creating = false
    @State private var busy: String?
    @State private var copiedId: Int?
    @State private var query = ""
    @State private var results: [APISearchUser] = []
    @State private var searching = false
    @State private var notice: String?
    @State private var noticeTask: Task<Void, Never>?

    private struct Option: Identifiable {
        let value: Int
        let label: String
        var id: Int { value }
    }

    private static let useOptions = [
        Option(value: 0, label: "Anyone"),
        Option(value: 1, label: "1 person"),
        Option(value: 5, label: "Up to 5"),
        Option(value: 25, label: "Up to 25"),
    ]

    private static let expiryOptions = [
        Option(value: 7, label: "7 days"),
        Option(value: 30, label: "30 days"),
        Option(value: 90, label: "90 days"),
    ]

    private var guests: [APIEventGuest] { invitations?.guests ?? [] }
    private var links: [APIEventInvite] { invitations?.links ?? [] }
    private var trimmedQuery: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(node.visibility == "private"
                         ? "This event is private: only you and the people you invite can see it."
                         : "This event is unlisted: it isn't on the map, so share an invite with the people you want.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Section("New invite link") {
                    Picker("Who can use it", selection: $maxUses) {
                        ForEach(Self.useOptions) { option in
                            Text(option.label).tag(option.value)
                        }
                    }
                    Picker("Link works for", selection: $expiresInDays) {
                        ForEach(Self.expiryOptions) { option in
                            Text(option.label).tag(option.value)
                        }
                    }
                    Button {
                        Task { await createLink() }
                    } label: {
                        HStack(spacing: 8) {
                            if creating {
                                ProgressView()
                            } else {
                                Image(systemName: "link")
                            }
                            Text("Create and copy invite link")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .disabled(creating)
                }

                if !links.isEmpty {
                    Section("Invite links") {
                        ForEach(links) { link in
                            linkRow(link)
                        }
                    }
                }

                Section {
                    TextField("Name or username", text: $query)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityLabel("Invite a Lyo member by name")
                    if searching {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else if trimmedQuery.count >= 2 && results.isEmpty {
                        Text("No Lyo members match “\(trimmedQuery)”.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(results) { member in
                        memberRow(member)
                    }
                } header: {
                    Text("Invite a Lyo member by name")
                } footer: {
                    Text("They get a notification and find the event in My Community on every device.")
                }

                Section {
                    if invitations == nil && loadError == nil {
                        ProgressView("Loading guests…")
                            .frame(maxWidth: .infinity)
                    } else if invitations == nil {
                        Button("We couldn't load your guest list. Try again") {
                            Task { await load() }
                        }
                    } else if guests.isEmpty {
                        Text("No guests yet. Invite someone by link or by name.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(guests) { guest in
                            guestRow(guest)
                        }
                    }
                } header: {
                    Text(guests.isEmpty ? "Guest list" : "Guest list · \(guests.count)")
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(DesignTokens.Colors.background)
            .navigationTitle("Invite people")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .refreshable { await load() }
            .task { await load() }
            .task(id: trimmedQuery) { await search(trimmedQuery) }
            .overlay(alignment: .bottom) {
                if let notice {
                    CommunityToast(message: notice)
                        .padding(.bottom, 24)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.85), value: notice)
        }
        .tint(DesignTokens.Colors.accent)
        .preferredColorScheme(.dark)
    }

    // MARK: Rows

    private func linkRow(_ link: APIEventInvite) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(CommunityDiscovery.describeInviteLink(link))
                .font(.subheadline)
            if link.active, let url = shareableURL(link) {
                HStack(spacing: 8) {
                    Button {
                        copy(link)
                    } label: {
                        Label(copiedId == link.id ? "Copied" : "Copy",
                              systemImage: copiedId == link.id ? "checkmark" : "doc.on.doc")
                    }
                    ShareLink(
                        item: url,
                        subject: Text(node.title),
                        message: Text("You're invited to \(node.title) on Lyo")
                    ) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    Button(role: .destructive) {
                        Task { await turnOff(link) }
                    } label: {
                        Label("Turn off", systemImage: "xmark")
                    }
                    .disabled(busy == "link:\(link.id)")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .font(.caption)
            }
        }
        .padding(.vertical, 4)
        .opacity(link.active ? 1 : 0.6)
    }

    private func memberRow(_ member: APISearchUser) -> some View {
        let already = guests.contains { $0.user.id == member.id }
        let name = member.name ?? member.username ?? "Lyo member"
        return HStack(spacing: 10) {
            AvatarBubble(name: name, url: member.avatarURL, size: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                if let username = member.username {
                    Text("@\(username)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            Button {
                Task { await invite(member, name: name) }
            } label: {
                Label(already ? "Invited" : "Invite", systemImage: already ? "checkmark" : "person.badge.plus")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(already || busy == "user:\(member.id)")
            .accessibilityLabel(already ? "\(name) is invited" : "Invite \(name)")
        }
    }

    private func guestRow(_ guest: APIEventGuest) -> some View {
        HStack(spacing: 10) {
            AvatarBubble(name: guest.user.name, url: guest.user.avatar, size: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(guest.user.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(CommunityDiscovery.describeGuest(guest))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(role: .destructive) {
                Task { await remove(guest) }
            } label: {
                Label("Remove", systemImage: "person.badge.minus")
            }
            .buttonStyle(.borderless)
            .font(.caption)
            .disabled(busy == "guest:\(guest.user.id)")
            .accessibilityLabel("Remove \(guest.user.name) from the guest list")
        }
    }

    // MARK: Actions

    private func shareableURL(_ link: APIEventInvite) -> URL? {
        CommunityDiscovery.safeWebURL(link.url) ?? CommunityDiscovery.inviteURL(link.token)
    }

    @MainActor
    private func load() async {
        do {
            invitations = try await viewModel.loadInvitations(eventId: node.id)
            loadError = nil
        } catch {
            loadError = CommunityDiscovery.friendlyError(error, action: "load your guest list")
        }
    }

    @MainActor
    private func search(_ text: String) async {
        guard text.count >= 2 else {
            results = []
            searching = false
            return
        }
        // Wait for a pause in typing; a new keystroke cancels this search.
        try? await Task.sleep(nanoseconds: 300_000_000)
        guard !Task.isCancelled else { return }
        searching = true
        do {
            let found = try await viewModel.searchMembers(text, excluding: node.host?.id)
            guard !Task.isCancelled else { return }
            results = found
        } catch {
            guard !Task.isCancelled else { return }
            results = []
        }
        searching = false
    }

    @MainActor
    private func createLink() async {
        creating = true
        defer { creating = false }
        do {
            let link = try await viewModel.createInvite(
                eventId: node.id,
                maxUses: maxUses == 0 ? nil : maxUses,
                expiresInDays: expiresInDays
            )
            copy(link)
            await load()
        } catch {
            show(CommunityDiscovery.friendlyError(error, action: "create an invite link").message)
        }
    }

    @MainActor
    private func copy(_ link: APIEventInvite) {
        guard let url = shareableURL(link) else { return }
        UIPasteboard.general.string = url.absoluteString
        copiedId = link.id
        show("Invite link copied")
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if copiedId == link.id { copiedId = nil }
        }
    }

    @MainActor
    private func turnOff(_ link: APIEventInvite) async {
        busy = "link:\(link.id)"
        defer { busy = nil }
        do {
            try await viewModel.revokeInvite(eventId: node.id, inviteId: link.id)
            show("Link turned off. People who already joined keep their spot.")
            await load()
        } catch {
            show(CommunityDiscovery.friendlyError(error, action: "turn off this link").message)
        }
    }

    @MainActor
    private func invite(_ member: APISearchUser, name: String) async {
        busy = "user:\(member.id)"
        defer { busy = nil }
        do {
            _ = try await viewModel.inviteMember(eventId: node.id, userId: member.id)
            show("Invited \(name)")
            query = ""
            results = []
            await load()
        } catch {
            show(CommunityDiscovery.friendlyError(error, action: "send this invitation").message)
        }
    }

    @MainActor
    private func remove(_ guest: APIEventGuest) async {
        busy = "guest:\(guest.user.id)"
        defer { busy = nil }
        do {
            try await viewModel.removeGuest(eventId: node.id, userId: guest.user.id)
            show("\(guest.user.name) was removed from the guest list")
            await load()
        } catch {
            show(CommunityDiscovery.friendlyError(error, action: "remove this guest").message)
        }
    }

    @MainActor
    private func show(_ message: String) {
        noticeTask?.cancel()
        notice = message
        noticeTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if !Task.isCancelled { notice = nil }
        }
    }
}

// MARK: - Guest: accept an invitation

/// Where an invite link lands in the app: what the invitation is for, then
/// one tap puts this account on the guest list (so every device sees the
/// event) and opens it.
struct CommunityInviteAcceptView: View {
    let token: String
    @ObservedObject var viewModel: CommunityViewModel
    let openEvent: (CommunityNodeRoute) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var preview: APIInvitePreview?
    @State private var loadError: CommunityDiscovery.FriendlyError?
    @State private var accepting = false
    @State private var acceptError: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                Group {
                    if let preview {
                        content(preview)
                    } else if let loadError {
                        CommunityStateView(
                            icon: loadError == CommunityDiscovery.offlineError ? "wifi.slash" : "envelope.badge",
                            title: loadError.title,
                            message: loadError.body,
                            actions: loadError.retry ? [("Try again", { Task { await load() } })] : []
                        )
                        .padding(.top, 40)
                    } else {
                        ProgressView("Opening your invitation…")
                            .frame(maxWidth: .infinity)
                            .padding(.top, 80)
                    }
                }
                .padding(16)
            }
            .background(DesignTokens.Colors.background)
            .navigationTitle("Invitation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task { await load() }
        }
        .tint(DesignTokens.Colors.accent)
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func content(_ invite: APIInvitePreview) -> some View {
        let hostName = invite.organizerName ?? invite.host?.name
        let notice = CommunityDiscovery.inviteNotice(for: invite.status)
        VStack(alignment: .leading, spacing: 18) {
            if let image = CommunityDiscovery.safeWebURL(invite.imageUrl) {
                AsyncImage(url: image) { phase in
                    if case .success(let loaded) = phase {
                        loaded.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        DesignTokens.Colors.surface
                    }
                }
                .frame(height: 160)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(invite.isHost ? "Your event" : (invite.visibility == "private" ? "Private invitation" : "Invitation"))
                    .font(.caption.weight(.bold))
                    .textCase(.uppercase)
                    .foregroundStyle(DesignTokens.Colors.accent)
                Text(invite.title)
                    .font(.title2.weight(.bold))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                if let hostName, !invite.isHost {
                    Text("\(hostName) invited you")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                if let when = CommunityDiscovery.formatWhen(invite.startsAt, invite.endsAt) {
                    CommunityInfoLine(icon: "clock", text: when)
                }
                if invite.attendanceMode == "online" {
                    CommunityInfoLine(icon: "video", text: "Online")
                } else if let place = invite.locationName, !place.isEmpty {
                    CommunityInfoLine(
                        icon: "mappin.and.ellipse",
                        text: invite.attendanceMode == "hybrid" ? "\(place) · also online" : place
                    )
                }
                if let hostName {
                    CommunityInfoLine(icon: "person", text: "Hosted by \(hostName)")
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DesignTokens.Colors.surface, in: RoundedRectangle(cornerRadius: 16))

            if invite.alreadyGuest || invite.isHost {
                Text(invite.isHost ? "You're the host of this event." : "You're already on the guest list.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button {
                    openEvent(CommunityNodeRoute(kind: "event", id: String(invite.eventId)))
                } label: {
                    Text("Open event")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(.borderedProminent)
            } else if let notice {
                VStack(alignment: .leading, spacing: 6) {
                    Text(notice.title).font(.headline)
                    Text(notice.body).font(.subheadline).foregroundStyle(.secondary)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
                .accessibilityElement(children: .combine)
                Button("Browse Community") { dismiss() }
                    .frame(minHeight: 44)
            } else {
                Button {
                    Task { await accept() }
                } label: {
                    HStack(spacing: 8) {
                        if accepting { ProgressView() }
                        Text("Accept invitation").fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(.borderedProminent)
                .disabled(accepting)
                if let acceptError {
                    Text(acceptError)
                        .font(.footnote)
                        .foregroundStyle(DesignTokens.Colors.danger)
                }
                Text("Accepting adds this event to your Lyo account on every device. You can RSVP next.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
            }
        }
    }

    @MainActor
    private func load() async {
        do {
            preview = try await viewModel.previewInvite(token: token)
            loadError = nil
        } catch {
            if preview == nil { loadError = CommunityDiscovery.inviteError(error) }
        }
    }

    @MainActor
    private func accept() async {
        accepting = true
        acceptError = nil
        do {
            let node = try await viewModel.acceptInvite(token: token)
            viewModel.showToast("You're on the guest list")
            openEvent(CommunityNodeRoute(node))
        } catch {
            acceptError = CommunityDiscovery.friendlyError(error, action: "accept this invite").message
            accepting = false
            // The link may have just expired or filled up: show why.
            await load()
        }
    }
}

// MARK: - My Community: paste a link

/// Paste an invite link (or code) someone sent in a message or email.
struct CommunityInviteLinkField: View {
    @ObservedObject var viewModel: CommunityViewModel
    @State private var text = ""
    @State private var invalid = false

    private var isEmpty: Bool { text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Have an invite link?", systemImage: "link")
                .font(.subheadline.weight(.semibold))
            HStack(spacing: 8) {
                TextField("Paste it here", text: $text)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .submitLabel(.go)
                    .onSubmit { openLink() }
                    .onChange(of: text) { _, _ in invalid = false }
                    .padding(.horizontal, 12)
                    .frame(minHeight: 44)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityLabel("Invite link")
                Button("Open invite") { openLink() }
                    .buttonStyle(.borderedProminent)
                    .frame(minHeight: 44)
                    .disabled(isEmpty)
            }
            if invalid {
                Text("That doesn't look like a Lyo invite link.")
                    .font(.caption)
                    .foregroundStyle(DesignTokens.Colors.warning)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignTokens.Colors.surface, in: RoundedRectangle(cornerRadius: 16))
    }

    @MainActor
    private func openLink() {
        guard !isEmpty else { return }
        if viewModel.openInvite(fromText: text) {
            text = ""
        } else {
            invalid = true
        }
    }
}
