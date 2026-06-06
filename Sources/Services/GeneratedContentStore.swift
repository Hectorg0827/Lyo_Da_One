//
//  GeneratedContentStore.swift
//  Lyo
//
//  Persistent cache for AI-generated content (lessons, courses, blocks).
//  Ensures generated content survives between view transitions and app restarts.
//  Uses FileManager-backed JSON storage with in-memory cache for speed.
//

import Foundation
import os

// MARK: - Stored Content Entry

/// A single cached piece of generated content
struct StoredContentEntry: Codable {
    let id: String
    let courseId: String?
    let lessonId: String?
    let title: String
    let content: String                        // Raw markdown/text
    let agentBlocks: [AgentBlock]?             // Multipart agent blocks (if available)
    let a2uiComponentJSON: Data?               // Serialized component tree (legacy, unused)
    let createdAt: Date
    let lastAccessedAt: Date
    let metadata: [String: String]?
    
    /// Update the last-accessed timestamp
    func touched() -> StoredContentEntry {
        StoredContentEntry(
            id: id,
            courseId: courseId,
            lessonId: lessonId,
            title: title,
            content: content,
            agentBlocks: agentBlocks,
            a2uiComponentJSON: a2uiComponentJSON,
            createdAt: createdAt,
            lastAccessedAt: Date(),
            metadata: metadata
        )
    }
}

// MARK: - Generated Content Store

@MainActor
final class GeneratedContentStore: ObservableObject {
    static let shared = GeneratedContentStore()
    
    // MARK: - In-Memory Cache
    
    /// Content indexed by ID for O(1) lookup
    @Published private(set) var entries: [String: StoredContentEntry] = [:]
    
    // MARK: - Configuration
    
    /// Maximum entries before LRU eviction
    private let maxEntries = 100
    
    /// Maximum age before auto-purge (7 days)
    private let maxAge: TimeInterval = 7 * 24 * 60 * 60
    
    // MARK: - File Storage
    
    private let storageDirectory: URL
    private let indexFileName = "content_index.json"
    
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = .prettyPrinted
        return e
    }()
    
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
    
    // MARK: - Init
    
    private init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        storageDirectory = caches.appendingPathComponent("GeneratedContent", isDirectory: true)
        
        // Ensure directory exists
        try? FileManager.default.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
        
        // Load existing entries from disk
        loadIndex()
        
        // Purge expired entries on startup
        purgeExpired()
        
        Log.data.info("📦 GeneratedContentStore loaded \(self.entries.count) cached entries")
    }
    
    // MARK: - Public API
    
    /// Store a new piece of generated content
    func store(_ entry: StoredContentEntry) {
        entries[entry.id] = entry
        
        // Evict LRU if over capacity
        if entries.count > maxEntries {
            evictLRU()
        }
        
        saveIndex()
        Log.data.info("📦 Stored content: \(entry.id) — \(entry.title.prefix(40))")
    }
    
    /// Store content with basic parameters (convenience)
    func store(
        id: String,
        courseId: String? = nil,
        lessonId: String? = nil,
        title: String,
        content: String,
        agentBlocks: [AgentBlock]? = nil,
        metadata: [String: String]? = nil
    ) {
        let entry = StoredContentEntry(
            id: id,
            courseId: courseId,
            lessonId: lessonId,
            title: title,
            content: content,
            agentBlocks: agentBlocks,
            a2uiComponentJSON: nil,
            createdAt: Date(),
            lastAccessedAt: Date(),
            metadata: metadata
        )
        store(entry)
    }
    
    /// Retrieve content by ID, updating last-accessed timestamp
    func retrieve(id: String) -> StoredContentEntry? {
        guard let entry = entries[id] else { return nil }
        
        // Touch to update LRU
        let touched = entry.touched()
        entries[id] = touched
        
        Log.data.info("📦 Retrieved content: \(id)")
        return touched
    }
    
    /// Retrieve all entries for a given course
    func entriesForCourse(_ courseId: String) -> [StoredContentEntry] {
        entries.values
            .filter { $0.courseId == courseId }
            .sorted { $0.createdAt < $1.createdAt }
    }
    
    /// Check if content exists for a given ID
    func has(id: String) -> Bool {
        entries[id] != nil
    }
    
    /// Remove a specific entry
    func remove(id: String) {
        entries.removeValue(forKey: id)
        saveIndex()
    }
    
    /// Remove all entries for a course
    func removeCourse(_ courseId: String) {
        let idsToRemove = entries.values
            .filter { $0.courseId == courseId }
            .map(\.id)
        for id in idsToRemove {
            entries.removeValue(forKey: id)
        }
        saveIndex()
    }
    
    /// Clear all stored content
    func clearAll() {
        entries.removeAll()
        saveIndex()
        Log.data.info("📦 Content store cleared")
    }
    
    // MARK: - Persistence
    
    private var indexURL: URL {
        storageDirectory.appendingPathComponent(indexFileName)
    }
    
    private func saveIndex() {
        do {
            let data = try encoder.encode(Array(entries.values))
            try data.write(to: indexURL, options: .atomic)
        } catch {
            Log.data.error("📦 Failed to save content index: \(error.localizedDescription)")
        }
    }
    
    private func loadIndex() {
        guard FileManager.default.fileExists(atPath: indexURL.path) else { return }
        
        do {
            let data = try Data(contentsOf: indexURL)
            let loaded = try decoder.decode([StoredContentEntry].self, from: data)
            entries = Dictionary(uniqueKeysWithValues: loaded.map { ($0.id, $0) })
        } catch {
            Log.data.error("📦 Failed to load content index: \(error.localizedDescription)")
            entries = [:]
        }
    }
    
    // MARK: - LRU Eviction
    
    private func evictLRU() {
        let sorted = entries.values.sorted { $0.lastAccessedAt < $1.lastAccessedAt }
        let toEvict = sorted.prefix(entries.count - maxEntries)
        for entry in toEvict {
            entries.removeValue(forKey: entry.id)
        }
        Log.data.info("📦 Evicted \(toEvict.count) LRU entries")
    }
    
    private func purgeExpired() {
        let now = Date()
        let expired = entries.values.filter {
            now.timeIntervalSince($0.lastAccessedAt) > maxAge
        }
        for entry in expired {
            entries.removeValue(forKey: entry.id)
        }
        if !expired.isEmpty {
            saveIndex()
            Log.data.info("📦 Purged \(expired.count) expired entries")
        }
    }
}
