import Foundation

/// Actor-based persistent cache using FileManager.
/// Stores JSON files in Caches/<name>/ with a configurable expiration.
actor DiskCache {
    static let shared = DiskCache(name: "plotline")

    private let cacheDir: URL
    private let maxAge: TimeInterval
    private var memoryCache: [String: (data: Data, timestamp: Date)] = [:]

    init(name: String, maxAge: TimeInterval = 7 * 24 * 3600) {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        self.cacheDir = caches.appendingPathComponent(name, isDirectory: true)
        self.maxAge = maxAge
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    }

    func get<T: Decodable>(for key: String) -> T? {
        let safeKey = sanitizedKey(key)

        if let cached = memoryCache[safeKey],
           Date().timeIntervalSince(cached.timestamp) < maxAge {
            return try? JSONDecoder().decode(T.self, from: cached.data)
        }

        let fileURL = fileURL(for: safeKey)
        guard let wrapper = try? Data(contentsOf: fileURL),
              let entry = try? JSONDecoder().decode(CacheEntry.self, from: wrapper) else {
            return nil
        }

        guard Date().timeIntervalSince(entry.timestamp) < maxAge else {
            try? FileManager.default.removeItem(at: fileURL)
            return nil
        }

        memoryCache[safeKey] = (data: entry.data, timestamp: entry.timestamp)
        return try? JSONDecoder().decode(T.self, from: entry.data)
    }

    func set<T: Encodable>(_ value: T, for key: String) {
        let safeKey = sanitizedKey(key)
        guard let data = try? JSONEncoder().encode(value) else { return }

        let entry = CacheEntry(data: data, timestamp: Date())
        memoryCache[safeKey] = (data: data, timestamp: entry.timestamp)

        guard let wrapper = try? JSONEncoder().encode(entry) else { return }
        try? wrapper.write(to: fileURL(for: safeKey))
    }

    func clearAll() {
        memoryCache.removeAll()
        let files = (try? FileManager.default.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: nil)) ?? []
        for file in files {
            try? FileManager.default.removeItem(at: file)
        }
    }

    // MARK: - Private Helpers

    private func sanitizedKey(_ key: String) -> String {
        key.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? key
    }

    private func fileURL(for safeKey: String) -> URL {
        cacheDir.appendingPathComponent(safeKey)
    }
}

private struct CacheEntry: Codable {
    let data: Data
    let timestamp: Date
}
