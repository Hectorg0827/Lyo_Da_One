import SwiftUI

/// The accounts this learner has blocked, each with Unblock.
///
/// A block hides both people from each other in Discover, and it is made
/// from Report on one of their videos (ReportClipSheet). Unblocking brings
/// their videos and comments back. Mirrors web BlockedAccounts.tsx.
struct BlockedAccountsView: View {
    private enum LoadState { case loading, ready, failed }

    @State private var state: LoadState = .loading
    @State private var accounts: [BlockedAccount] = []
    @State private var busyIds: Set<Int> = []
    @State private var message: String?

    var body: some View {
        List {
            switch state {
            case .loading:
                HStack {
                    ProgressView()
                    Text("Loading…")
                        .foregroundStyle(.secondary)
                }
            case .failed:
                VStack(alignment: .leading, spacing: 8) {
                    Text("Couldn't load your blocked accounts.")
                        .foregroundStyle(.secondary)
                    Button("Try again") { Task { await load() } }
                }
            case .ready:
                if accounts.isEmpty {
                    Text("You haven't blocked anyone. To block someone, tap Report on one of their Discover videos.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(accounts) { account in
                        HStack {
                            Image(systemName: "person.fill.xmark")
                                .foregroundStyle(.secondary)
                            Text(account.userName)
                                .lineLimit(1)
                            Spacer()
                            Button("Unblock") { Task { await unblock(account) } }
                                .buttonStyle(.bordered)
                                .disabled(busyIds.contains(account.userId))
                        }
                    }
                }
            }

            if let message {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Blocked accounts")
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        if accounts.isEmpty { state = .loading }
        do {
            accounts = try await LyoAPIClient.shared.fetchBlockedAccounts()
            state = .ready
        } catch {
            state = accounts.isEmpty ? .failed : .ready
        }
    }

    private func unblock(_ account: BlockedAccount) async {
        guard !busyIds.contains(account.userId) else { return }
        busyIds.insert(account.userId)
        let status = await LyoAPIClient.shared.unblockUser(userId: account.userId)
        busyIds.remove(account.userId)
        // 404: the block is already gone, which is what was asked for.
        if status == 200 || status == 404 {
            accounts.removeAll { $0.userId == account.userId }
            message = "Unblocked \(account.userName)."
        } else {
            message = "Couldn't unblock \(account.userName). Please try again."
        }
    }
}
