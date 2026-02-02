import Foundation
import Combine

/// Observer for synchronizing client UI state with the backend
class A2UIStateObserver: ObservableObject {
    static let shared = A2UIStateObserver()
    
    // Dependencies
    private let apiClient = LyoAPIClient.shared
    
    // State
    @Published var currentState: A2UIClientState?
    
    // Private
    private var cancellables = Set<AnyCancellable>()
    private let stateSubject = PassthroughSubject<A2UIClientState, Never>()
    
    private init() {
        setupDebouncer()
    }
    
    /// Update the current state of the client
    func updateState(
        screenId: String,
        componentId: String? = nil,
        scrollPosition: Double? = nil,
        interactedElementId: String? = nil,
        metadata: [String: String]? = nil
    ) {
        let state = A2UIClientState(
            screenId: screenId,
            timestamp: Date(),
            componentId: componentId,
            scrollPosition: scrollPosition,
            interactedElementId: interactedElementId,
            metadata: metadata
        )
        
        self.currentState = state
        stateSubject.send(state)
    }
    
    private func setupDebouncer() {
        // Debounce state updates to avoid flooding the backend
        stateSubject
            .debounce(for: .seconds(2.0), scheduler: RunLoop.main)
            .sink { [weak self] state in
                self?.syncStateToBackend(state)
            }
            .store(in: &cancellables)
    }
    
    private func syncStateToBackend(_ state: A2UIClientState) {
        print("🔄 Syncing UI state to backend: \(state.screenId)")
        
        Task {
            do {
                // In a real implementation, this would hit a dedicated endpoint
                // await apiClient.syncClientState(state)
                
                // For now, we simulate the sync success
                try await Task.sleep(nanoseconds: 500_000_000)
                print("✅ State synced successfully")
            } catch {
                print("⚠️ Failed to sync state: \(error)")
            }
        }
    }
}

/// Snapshot of the client's current UI state
struct A2UIClientState: Codable {
    let screenId: String
    let timestamp: Date
    let componentId: String?
    let scrollPosition: Double?
    let interactedElementId: String?
    let metadata: [String: String]?
}
