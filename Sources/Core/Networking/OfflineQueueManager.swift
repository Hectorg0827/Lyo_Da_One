//
//  OfflineQueueManager.swift
//  Lyo
//
//  Manages queued network requests when offline and retries when connection restored
//

import Foundation
import os

// MARK: - Offline Queue Manager
/// Actor-based manager for queuing and retrying network requests when offline
actor OfflineQueueManager {
    
    static let shared = OfflineQueueManager()
    
    // MARK: - Types
    
    struct QueuedRequest: Codable, Identifiable {
        let id: UUID
        let endpointPath: String
        let method: String
        let body: Data?
        let createdAt: Date
        let priority: Priority
        let maxRetries: Int
        var retryCount: Int
        
        enum Priority: Int, Codable, Comparable {
            case low = 0
            case normal = 1
            case high = 2
            
            static func < (lhs: Priority, rhs: Priority) -> Bool {
                lhs.rawValue < rhs.rawValue
            }
        }
    }
    
    // MARK: - Properties
    
    private var queue: [QueuedRequest] = []
    private let maxQueueSize = 50
    private let persistenceKey = "lyo_offline_queue"
    private var isProcessing = false
    
    // MARK: - Initialization
    
    private init() {
        Task {
            await loadQueue()
            await setupConnectivityObserver()
        }
    }
    
    // MARK: - Public API
    
    /// Add a request to the offline queue
    func enqueue(
        endpointPath: String,
        method: String,
        body: Data? = nil,
        priority: QueuedRequest.Priority = .normal,
        maxRetries: Int = 3
    ) async {
        let request = QueuedRequest(
            id: UUID(),
            endpointPath: endpointPath,
            method: method,
            body: body,
            createdAt: Date(),
            priority: priority,
            maxRetries: maxRetries,
            retryCount: 0
        )
        
        // Maintain queue size limit
        if queue.count >= maxQueueSize {
            // Remove oldest low-priority items first
            if let index = queue.firstIndex(where: { $0.priority == .low }) {
                queue.remove(at: index)
            } else {
                queue.removeFirst()
            }
        }
        
        queue.append(request)
        queue.sort { $0.priority > $1.priority } // Higher priority first
        saveQueue()
        
        Log.net.info("Queued request: \(endpointPath) (queue size: \(self.queue.count))")
    }
    
    /// Get current queue size
    func queueSize() -> Int {
        queue.count
    }
    
    /// Get all queued requests
    func getQueuedRequests() -> [QueuedRequest] {
        queue
    }
    
    /// Clear the entire queue
    func clearQueue() {
        queue.removeAll()
        saveQueue()
        Log.net.info("Offline queue cleared")
    }
    
    /// Remove a specific request from queue
    func remove(requestId: UUID) {
        queue.removeAll { $0.id == requestId }
        saveQueue()
    }
    
    /// Process all queued requests (called when connectivity restored)
    func processQueue() async {
        guard !isProcessing else {
            Log.net.info("⏳ Queue processing already in progress")
            return
        }
        
        guard !queue.isEmpty else {
            Log.net.info("No queued requests to process")
            return
        }
        
        isProcessing = true
        Log.net.info("Processing offline queue (\(self.queue.count) requests)...")
        
        var failedRequests: [QueuedRequest] = []
        
        for var request in queue {
            do {
                try await executeQueuedRequest(request)
                Log.net.info("Processed: \(request.endpointPath)")
            } catch {
                request.retryCount += 1
                if request.retryCount < request.maxRetries {
                    failedRequests.append(request)
                    Log.net.warning("Failed (will retry): \(request.endpointPath)")
                } else {
                    Log.net.error("Max retries exceeded: \(request.endpointPath)")
                }
            }
        }
        
        // Keep only failed requests for retry
        queue = failedRequests
        saveQueue()
        isProcessing = false
        
        Log.net.info("🏁 Queue processing complete. Remaining: \(self.queue.count)")
    }
    
    // MARK: - Private Methods
    
    private func executeQueuedRequest(_ request: QueuedRequest) async throws {
        // Create a dynamic endpoint from the queued request
        let endpoint = DynamicEndpoint(
            urlString: request.endpointPath,
            method: HTTPMethod(rawValue: request.method) ?? .post,
            body: request.body.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: AnyEncodable] }
        )
        
        // Execute via NetworkClient (ignore response for queued requests)
        let _: EmptyResponse = try await NetworkClient.shared.request(endpoint, cachePolicy: .reloadIgnoringCache)
    }
    
    private func setupConnectivityObserver() {
        // Listen for network status changes using NotificationCenter
        // Note: We use a detached task-based approach to avoid actor isolation issues
        Task { @MainActor in
            for await notification in NotificationCenter.default.notifications(named: .networkStatusChanged) {
                guard let isConnected = notification.userInfo?["isConnected"] as? Bool,
                      isConnected else { continue }
                
                // Connection restored - process queue
                await OfflineQueueManager.shared.processQueue()
            }
        }
    }
    
    // MARK: - Persistence
    
    private func saveQueue() {
        guard let data = try? JSONEncoder().encode(queue) else { return }
        UserDefaults.standard.set(data, forKey: persistenceKey)
    }
    
    private func loadQueue() {
        guard let data = UserDefaults.standard.data(forKey: persistenceKey),
              let saved = try? JSONDecoder().decode([QueuedRequest].self, from: data) else {
            return
        }
        
        // Filter out expired requests (older than 24 hours)
        let cutoff = Date().addingTimeInterval(-24 * 60 * 60)
        queue = saved.filter { $0.createdAt > cutoff }
        
        if queue.count != saved.count {
            saveQueue() // Remove expired entries
        }
    }
}

// MARK: - NetworkClient Extension
// Note: EmptyResponse is defined in Models/APIModels.swift

extension NetworkClient {
    /// Queue a request for later execution when offline
    func queueForOffline(
        _ endpoint: Endpoint,
        priority: OfflineQueueManager.QueuedRequest.Priority = .normal
    ) async {
        let bodyData = try? JSONSerialization.data(withJSONObject: endpoint.body ?? [:])
        
        await OfflineQueueManager.shared.enqueue(
            endpointPath: endpoint.path,
            method: endpoint.method.rawValue,
            body: bodyData,
            priority: priority
        )
    }
}
