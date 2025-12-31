import Foundation

// MARK: - Network Cache
/// In-memory and disk-based cache with TTL support
actor NetworkCache {

    static let shared = NetworkCache()

    // MARK: - Properties
    private var memoryCache: [String: CacheEntry] = [:]
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private let maxMemoryCacheSize = 50 // Maximum items in memory
    private let maxDiskCacheSize: Int64 = 100 * 1024 * 1024 // 100 MB

    // MARK: - Cache Entry
    private struct CacheEntry: Codable {
        let data: Data
        let expiresAt: Date
        let key: String

        var isExpired: Bool {
            return Date() > expiresAt
        }
    }

    // MARK: - Initialization
    private init() {
        // Setup cache directory
        let cacheDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        self.cacheDirectory = cacheDir.appendingPathComponent("NetworkCache")

        // Create directory if needed
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

        // Clean expired cache on init
        Task {
            await self.cleanExpiredCache()
        }
    }

    // MARK: - Public API

    /// Get cached value
    /// - Parameters:
    ///   - key: Cache key
    ///   - ignoreExpiry: If true, returns expired cache entries (useful for offline mode)
    func get<T: Decodable>(key: String, ignoreExpiry: Bool = false) async -> T? {
        // 1. Check memory cache first
        if let entry = memoryCache[key], (!entry.isExpired || ignoreExpiry) {
            do {
                let decoded = try JSONDecoder.lyoDecoder.decode(T.self, from: entry.data)
                return decoded
            } catch {
                print("❌ Failed to decode from memory cache: \(error)")
                memoryCache.removeValue(forKey: key)
            }
        }

        // 2. Check disk cache
        let fileURL = cacheDirectory.appendingPathComponent(key.md5Hash)

        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let entry = try JSONDecoder().decode(CacheEntry.self, from: data)

            // Check if expired (unless ignoreExpiry is true)
            if entry.isExpired && !ignoreExpiry {
                try? fileManager.removeItem(at: fileURL)
                return nil
            }

            // Add to memory cache for faster access
            memoryCache[key] = entry

            // Decode and return
            let decoded = try JSONDecoder.lyoDecoder.decode(T.self, from: entry.data)
            return decoded

        } catch {
            print("❌ Failed to read from disk cache: \(error)")
            try? fileManager.removeItem(at: fileURL)
            return nil
        }
    }

    /// Set cache value with TTL
    func set<T: Encodable>(key: String, value: T, ttl: TimeInterval) async {
        do {
            // Encode value
            let data = try JSONEncoder.lyoEncoder.encode(value)

            let entry = CacheEntry(
                data: data,
                expiresAt: Date().addingTimeInterval(ttl),
                key: key
            )

            // 1. Store in memory cache
            memoryCache[key] = entry

            // Maintain memory cache size
            if memoryCache.count > maxMemoryCacheSize {
                evictOldestMemoryCacheEntry()
            }

            // 2. Store on disk
            let fileURL = cacheDirectory.appendingPathComponent(key.md5Hash)
            let entryData = try JSONEncoder().encode(entry)
            try entryData.write(to: fileURL)

            // Maintain disk cache size
            await maintainDiskCacheSize()

        } catch {
            print("❌ Failed to cache value: \(error)")
        }
    }

    /// Clear all cache
    func clearAll() async {
        memoryCache.removeAll()

        do {
            let files = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            for file in files {
                try? fileManager.removeItem(at: file)
            }
        } catch {
            print("❌ Failed to clear disk cache: \(error)")
        }
    }

    /// Clear cache for specific key
    func remove(key: String) async {
        memoryCache.removeValue(forKey: key)

        let fileURL = cacheDirectory.appendingPathComponent(key.md5Hash)
        try? fileManager.removeItem(at: fileURL)
    }

    /// Clear expired cache entries
    func cleanExpiredCache() async {
        // Clean memory cache
        memoryCache = memoryCache.filter { !$0.value.isExpired }

        // Clean disk cache
        do {
            let files = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)

            for file in files {
                let data = try Data(contentsOf: file)
                if let entry = try? JSONDecoder().decode(CacheEntry.self, from: data), entry.isExpired {
                    try fileManager.removeItem(at: file)
                }
            }
        } catch {
            print("❌ Failed to clean expired cache: \(error)")
        }
    }

    // MARK: - Private Helpers

    private func evictOldestMemoryCacheEntry() {
        // Simple LRU: remove entry with earliest expiration
        if let oldestKey = memoryCache.min(by: { $0.value.expiresAt < $1.value.expiresAt })?.key {
            memoryCache.removeValue(forKey: oldestKey)
        }
    }

    private func maintainDiskCacheSize() async {
        do {
            let files = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey, .creationDateKey])

            // Calculate total size
            var totalSize: Int64 = 0
            var fileInfos: [(url: URL, size: Int64, date: Date)] = []

            for file in files {
                let attributes = try file.resourceValues(forKeys: [.fileSizeKey, .creationDateKey])
                let size = Int64(attributes.fileSize ?? 0)
                let date = attributes.creationDate ?? Date.distantPast

                totalSize += size
                fileInfos.append((file, size, date))
            }

            // If over limit, remove oldest files
            if totalSize > maxDiskCacheSize {
                fileInfos.sort { $0.date < $1.date }

                var removedSize: Int64 = 0
                let targetRemoval = totalSize - maxDiskCacheSize

                for fileInfo in fileInfos {
                    try fileManager.removeItem(at: fileInfo.url)
                    removedSize += fileInfo.size

                    if removedSize >= targetRemoval {
                        break
                    }
                }
            }
        } catch {
            print("❌ Failed to maintain disk cache size: \(error)")
        }
    }
}

// MARK: - String Extension for MD5

import CryptoKit

extension String {
    var md5Hash: String {
        let data = Data(self.utf8)
        let hash = Insecure.MD5.hash(data: data)
        return hash.map { String(format: "%02hhx", $0) }.joined()
    }
}
