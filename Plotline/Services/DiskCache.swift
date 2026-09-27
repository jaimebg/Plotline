import Foundation

/// Actor-based persistent cache using FileManager.
///
/// Stores one file per key in Caches/<name>/. Each file is a 12-byte header —
/// a format tag and the entry's absolute expiry — followed by the value's JSON
/// as raw bytes. The expiry lives in the header so `pruneExpired()` can judge
/// a file without reading or decoding its payload.
///
/// Files written by the previous format (a JSON wrapper holding the payload as
/// base64 plus a write timestamp) are still read, judged against this cache's
/// `maxAge`, and replaced the next time their key is written.
actor DiskCache {
    static let shared = DiskCache(name: "plotline")

    private let cacheDir: URL
    private let maxAge: TimeInterval
    private let memoryLimit: Int

    /// Recently used entries, bounded by `memoryLimit` and evicted least
    /// recently used first. The disk copy is the durable one; this only saves
    /// re-reading a file the screen asked for a moment ago.
    private var memoryCache: [String: MemoryEntry] = [:]
    private var accessClock: UInt64 = 0

    private struct MemoryEntry {
        let data: Data
        let expiresAt: Date
        var lastAccess: UInt64
    }

    /// - Parameters:
    ///   - maxAge: default lifetime of an entry; `set(_:for:maxAge:)` can
    ///     shorten or lengthen it per entry.
    ///   - memoryLimit: how many decoded-ready payloads to keep in memory.
    init(name: String, maxAge: TimeInterval = 7 * 24 * 3600, memoryLimit: Int = 64) {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        self.cacheDir = caches.appendingPathComponent(name, isDirectory: true)
        self.maxAge = maxAge
        self.memoryLimit = max(memoryLimit, 0)
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    }

    func get<T: Decodable & Sendable>(for key: String) -> T? {
        let safeKey = sanitizedKey(key)
        let now = Date()

        if let cached = memoryCache[safeKey] {
            if now < cached.expiresAt {
                touch(safeKey)
                return try? JSONDecoder().decode(T.self, from: cached.data)
            }
            memoryCache[safeKey] = nil
        }

        let fileURL = fileURL(for: safeKey)
        guard let contents = try? Data(contentsOf: fileURL) else { return nil }

        guard let entry = decodeFile(contents) else {
            // Unreadable in either format: nothing to salvage, drop it.
            try? FileManager.default.removeItem(at: fileURL)
            return nil
        }

        guard now < entry.expiresAt else {
            try? FileManager.default.removeItem(at: fileURL)
            return nil
        }

        remember(entry.payload, expiresAt: entry.expiresAt, for: safeKey)
        return try? JSONDecoder().decode(T.self, from: entry.payload)
    }

    /// - Parameter maxAge: this entry's lifetime; `nil` uses the cache's default.
    func set<T: Encodable & Sendable>(_ value: T, for key: String, maxAge: TimeInterval? = nil) {
        let safeKey = sanitizedKey(key)
        guard let payload = try? JSONEncoder().encode(value) else { return }

        let expiresAt = Date().addingTimeInterval(maxAge ?? self.maxAge)
        remember(payload, expiresAt: expiresAt, for: safeKey)

        let contents = Self.header(expiresAt: expiresAt) + payload
        let fileURL = fileURL(for: safeKey)
        do {
            // Atomic: a crash or a concurrent read mid-write must never see a
            // truncated file, which would decode as garbage.
            try contents.write(to: fileURL, options: .atomic)
        } catch {
            // The system may purge Caches/ wholesale while the app is running.
            try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
            try? contents.write(to: fileURL, options: .atomic)
        }
    }

    func clearAll() {
        memoryCache.removeAll()
        let files = (try? FileManager.default.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: nil)) ?? []
        for file in files {
            try? FileManager.default.removeItem(at: file)
        }
    }

    /// Deletes every file whose entry has expired, without decoding payloads.
    ///
    /// Without this, an expired file was only removed when its exact key was
    /// read again — which, for a series nobody reopens, is never.
    ///
    /// - Returns: how many files were removed.
    @discardableResult
    func pruneExpired(now: Date = Date()) -> Int {
        memoryCache = memoryCache.filter { now < $0.value.expiresAt }

        let keys: [URLResourceKey] = [.contentModificationDateKey, .isRegularFileKey]
        let files = (try? FileManager.default.contentsOfDirectory(
            at: cacheDir,
            includingPropertiesForKeys: keys
        )) ?? []

        var removed = 0
        for file in files {
            let values = try? file.resourceValues(forKeys: Set(keys))
            guard values?.isRegularFile ?? true else { continue }

            let expiresAt = expiry(ofFileAt: file, modifiedAt: values?.contentModificationDate)
            if expiresAt.map({ now >= $0 }) ?? true {
                try? FileManager.default.removeItem(at: file)
                removed += 1
            }
        }
        return removed
    }

    /// How many entries are held in memory. Exposed for tests.
    var memoryEntryCount: Int { memoryCache.count }

    // MARK: - File Format

    /// "PLC2": distinguishes the current format from the legacy JSON wrapper,
    /// which always starts with `{`.
    private static let magic = Data("PLC2".utf8)
    private static let headerLength = 12

    private static func header(expiresAt: Date) -> Data {
        var data = magic
        var bits = expiresAt.timeIntervalSinceReferenceDate.bitPattern.littleEndian
        withUnsafeBytes(of: &bits) { data.append(contentsOf: $0) }
        return data
    }

    private static func parseHeader(_ data: Data) -> Date? {
        guard data.count >= headerLength,
              data.prefix(magic.count) == magic else { return nil }
        var bits: UInt64 = 0
        for (index, byte) in data.dropFirst(magic.count).prefix(8).enumerated() {
            bits |= UInt64(byte) << (8 * UInt64(index))
        }
        return Date(timeIntervalSinceReferenceDate: Double(bitPattern: bits))
    }

    private func decodeFile(_ contents: Data) -> (payload: Data, expiresAt: Date)? {
        if let expiresAt = Self.parseHeader(contents) {
            return (Data(contents.dropFirst(Self.headerLength)), expiresAt)
        }
        if let legacy = try? JSONDecoder().decode(LegacyCacheEntry.self, from: contents) {
            return (legacy.data, legacy.timestamp.addingTimeInterval(maxAge))
        }
        return nil
    }

    /// Reads only the header when there is one. A legacy file has no expiry of
    /// its own, so its modification date stands in for the write timestamp it
    /// carries inside — close enough to decide what to prune.
    private func expiry(ofFileAt url: URL, modifiedAt: Date?) -> Date? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        let head = (try? handle.read(upToCount: Self.headerLength)) ?? Data()

        if let expiresAt = Self.parseHeader(head) {
            return expiresAt
        }
        return modifiedAt?.addingTimeInterval(maxAge)
    }

    // MARK: - Memory

    private func remember(_ data: Data, expiresAt: Date, for safeKey: String) {
        guard memoryLimit > 0 else { return }
        accessClock &+= 1
        memoryCache[safeKey] = MemoryEntry(data: data, expiresAt: expiresAt, lastAccess: accessClock)

        while memoryCache.count > memoryLimit,
              let oldest = memoryCache.min(by: { $0.value.lastAccess < $1.value.lastAccess })?.key {
            memoryCache[oldest] = nil
        }
    }

    private func touch(_ safeKey: String) {
        accessClock &+= 1
        memoryCache[safeKey]?.lastAccess = accessClock
    }

    // MARK: - Private Helpers

    private func sanitizedKey(_ key: String) -> String {
        key.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? key
    }

    private func fileURL(for safeKey: String) -> URL {
        cacheDir.appendingPathComponent(safeKey)
    }
}

/// The previous on-disk format: payload base64-encoded inside a JSON wrapper.
/// Read-only now; kept so existing caches survive the upgrade.
private nonisolated struct LegacyCacheEntry: Decodable {
    let data: Data
    let timestamp: Date
}
