import SwiftUI
import Network

// MARK: - Offline Indicator
/// Banner shown when device loses internet connection
struct OfflineIndicator: View {

    @StateObject private var monitor = NetworkMonitor.shared

    var body: some View {
        VStack(spacing: 0) {
            if !monitor.isConnected {
                HStack(spacing: 12) {
                    Image(systemName: "wifi.slash")
                        .font(.body.bold())

                    Text("No Internet Connection")
                        .font(.subheadline.bold())

                    Spacer()

                    // Reconnecting indicator
                    if monitor.isReconnecting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    }
                }
                .foregroundColor(.white)
                .padding()
                .background(Color.orange)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(), value: monitor.isConnected)
    }
}

// MARK: - Network Monitor
/// Monitors network connectivity status
class NetworkMonitor: ObservableObject {

    static let shared = NetworkMonitor()

    @Published var isConnected = true
    @Published var isReconnecting = false
    @Published var connectionType: NWInterface.InterfaceType?

    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "NetworkMonitor")

    private init() {
        monitor = NWPathMonitor()

        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                let wasConnected = self?.isConnected ?? true
                self?.isConnected = path.status == .satisfied

                // Detect connection type
                if path.status == .satisfied {
                    if path.usesInterfaceType(.wifi) {
                        self?.connectionType = .wifi
                    } else if path.usesInterfaceType(.cellular) {
                        self?.connectionType = .cellular
                    } else {
                        self?.connectionType = nil
                    }

                    // Reset reconnecting flag
                    self?.isReconnecting = false
                } else {
                    self?.connectionType = nil

                    // If we were connected before, we're now reconnecting
                    if wasConnected {
                        self?.isReconnecting = true
                    }
                }

                // Post notification for other parts of the app
                NotificationCenter.default.post(
                    name: .networkStatusChanged,
                    object: nil,
                    userInfo: ["isConnected": self?.isConnected ?? false]
                )
            }
        }

        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }

    // MARK: - Helper Methods

    var isOnWiFi: Bool {
        connectionType == .wifi
    }

    var isOnCellular: Bool {
        connectionType == .cellular
    }

    func waitForConnection() async -> Bool {
        if isConnected {
            return true
        }

        // Wait up to 10 seconds for connection
        for _ in 0..<20 {
            if isConnected {
                return true
            }
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        }

        return false
    }
}

// MARK: - Connection Quality Indicator
/// Shows current connection quality (WiFi, 4G, 5G, etc.)
struct ConnectionQualityIndicator: View {

    @StateObject private var monitor = NetworkMonitor.shared

    var body: some View {
        HStack(spacing: 4) {
            if monitor.isConnected {
                Image(systemName: connectionIcon)
                    .font(.caption)
                    .foregroundColor(.secondary)

                if let type = monitor.connectionType {
                    Text(connectionLabel(for: type))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                Image(systemName: "wifi.slash")
                    .font(.caption)
                    .foregroundColor(.red)

                Text("Offline")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }

    private var connectionIcon: String {
        guard let type = monitor.connectionType else {
            return "wifi.slash"
        }

        switch type {
        case .wifi:
            return "wifi"
        case .cellular:
            return "antenna.radiowaves.left.and.right"
        default:
            return "network"
        }
    }

    private func connectionLabel(for type: NWInterface.InterfaceType) -> String {
        switch type {
        case .wifi:
            return "WiFi"
        case .cellular:
            return "Cellular"
        default:
            return "Connected"
        }
    }
}

// MARK: - Offline Mode View
/// Full-screen view shown when critical features require internet
struct OfflineModeView: View {

    let message: String
    let onRetry: () -> Void

    @StateObject private var monitor = NetworkMonitor.shared
    @State private var isRetrying = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Offline Icon
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.1))
                    .frame(width: 120, height: 120)

                Image(systemName: "wifi.slash")
                    .font(.system(size: 60))
                    .foregroundColor(.orange)
            }

            // Message
            VStack(spacing: 12) {
                Text("No Internet Connection")
                    .font(.title.bold())

                Text(message)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            // Connection Status
            if monitor.isReconnecting {
                HStack(spacing: 8) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())

                    Text("Reconnecting...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }

            Spacer()

            // Retry Button
            Button(action: {
                isRetrying = true
                onRetry()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    isRetrying = false
                }
            }) {
                HStack {
                    if isRetrying {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                    Text("Try Again")
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(isRetrying)
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
        .background(Color(.systemBackground))
    }
}

// MARK: - View Modifier for Offline Detection
struct OfflineDetection: ViewModifier {

    @StateObject private var monitor = NetworkMonitor.shared

    func body(content: Content) -> some View {
        ZStack {
            content

            VStack {
                OfflineIndicator()
                Spacer()
            }
        }
    }
}

extension View {
    func detectOffline() -> some View {
        modifier(OfflineDetection())
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let networkStatusChanged = Notification.Name("networkStatusChanged")
}

// MARK: - Preview
#Preview("Offline Indicator") {
    VStack {
        OfflineIndicator()
        Spacer()
    }
}

#Preview("Offline Mode View") {
    OfflineModeView(
        message: "This feature requires an internet connection. Please check your connection and try again.",
        onRetry: {}
    )
}

#Preview("Connection Quality") {
    ConnectionQualityIndicator()
        .padding()
}
