import Foundation
import Testing
@testable import Plotline

@Suite("DiskCache")
struct DiskCacheTests {
    /// Cada test usa su propio directorio para no pisarse con los demás.
    private func makeCache(maxAge: TimeInterval = 7 * 24 * 3600) -> DiskCache {
        DiskCache(name: "tests-\(UUID().uuidString)", maxAge: maxAge)
    }

    @Test("stores and retrieves a value")
    func roundTrip() async {
        let cache = makeCache()
        await cache.set([1, 2, 3], for: "numbers")
        let result: [Int]? = await cache.get(for: "numbers")
        #expect(result == [1, 2, 3])
    }

    @Test("returns nil for a key that was never written")
    func missingKey() async {
        let cache = makeCache()
        let result: [Int]? = await cache.get(for: "absent")
        #expect(result == nil)
    }

    @Test("returns nil once the entry is older than maxAge")
    func expiredEntry() async {
        // maxAge negativo: cualquier entrada está expirada en el instante siguiente.
        let cache = makeCache(maxAge: -1)
        await cache.set([1], for: "numbers")
        let result: [Int]? = await cache.get(for: "numbers")
        #expect(result == nil)
    }

    @Test("clearAll removes every entry")
    func clearAllEmptiesCache() async {
        let cache = makeCache()
        await cache.set([1], for: "a")
        await cache.set([2], for: "b")
        await cache.clearAll()
        let a: [Int]? = await cache.get(for: "a")
        let b: [Int]? = await cache.get(for: "b")
        #expect(a == nil)
        #expect(b == nil)
    }

    @Test("a second instance reads the value back from disk")
    func readsFromDiskWithAFreshInstance() async {
        // Mismo directorio, instancia distinta: la memoryCache está vacía, así que
        // el get sólo puede resolverse leyendo el fichero. Es lo que hace que los
        // episodios sobrevivan a un arranque de la app.
        let name = "tests-\(UUID().uuidString)"
        let writer = DiskCache(name: name)
        await writer.set([1, 2, 3], for: "numbers")

        let reader = DiskCache(name: name)
        let result: [Int]? = await reader.get(for: "numbers")
        #expect(result == [1, 2, 3])
    }

    @Test("keys with unsafe filesystem characters are handled")
    func sanitizesKeys() async {
        let cache = makeCache()
        await cache.set(["ok"], for: "v2/tmdb 1396:S1")
        let result: [String]? = await cache.get(for: "v2/tmdb 1396:S1")
        #expect(result == ["ok"])
    }

    // MARK: - Per-entry lifetime

    @Test("a per-entry maxAge overrides the cache default")
    func perEntryMaxAge() async {
        let cache = makeCache()
        await cache.set([1], for: "short", maxAge: -1)
        await cache.set([2], for: "long")

        let short: [Int]? = await cache.get(for: "short")
        let long: [Int]? = await cache.get(for: "long")
        #expect(short == nil)
        #expect(long == [2])
    }

    @Test("a per-entry maxAge survives a relaunch")
    func perEntryMaxAgeOnDisk() async {
        let name = "tests-\(UUID().uuidString)"
        await DiskCache(name: name).set([1], for: "short", maxAge: -1)

        let result: [Int]? = await DiskCache(name: name).get(for: "short")
        #expect(result == nil)
    }

    // MARK: - Files on disk

    private func directory(for name: String) -> URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(name, isDirectory: true)
    }

    private func files(in name: String) -> [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: directory(for: name).path)) ?? []).sorted()
    }

    /// An atomic write goes through a temporary file and a rename; nothing
    /// but the finished entry may be left in the directory.
    @Test("a write leaves exactly one file per key")
    func writesOneFilePerKey() async {
        let name = "tests-\(UUID().uuidString)"
        let cache = DiskCache(name: name)
        await cache.set([1], for: "a")
        await cache.set([2], for: "a")
        await cache.set([3], for: "b")

        #expect(files(in: name) == ["a", "b"])
        let a: [Int]? = await DiskCache(name: name).get(for: "a")
        #expect(a == [2])
    }

    @Test("pruning removes expired files and keeps fresh ones")
    func pruneExpired() async {
        let name = "tests-\(UUID().uuidString)"
        let writer = DiskCache(name: name)
        await writer.set([1], for: "stale", maxAge: -1)
        await writer.set([2], for: "fresh")

        // A fresh instance: nothing in memory, so only the files can decide.
        let removed = await DiskCache(name: name).pruneExpired()

        #expect(removed == 1)
        #expect(files(in: name) == ["fresh"])
    }

    @Test("pruning judges time against the clock it is given")
    func pruneWithClock() async {
        let name = "tests-\(UUID().uuidString)"
        let cache = DiskCache(name: name, maxAge: 3600)
        await cache.set([1], for: "hour")

        #expect(await cache.pruneExpired(now: Date()) == 0)
        #expect(await cache.pruneExpired(now: Date().addingTimeInterval(7200)) == 1)
        #expect(files(in: name).isEmpty)
    }

    // MARK: - Previous file format

    /// The format before raw bytes: the payload base64-encoded inside a JSON
    /// wrapper with its write time.
    private struct LegacyEntry: Encodable {
        let data: Data
        let timestamp: Date
    }

    private func writeLegacy(_ value: [Int], key: String, in name: String, writtenAt: Date) throws {
        let payload = try JSONEncoder().encode(value)
        let wrapper = try JSONEncoder().encode(LegacyEntry(data: payload, timestamp: writtenAt))
        let url = directory(for: name).appendingPathComponent(key)
        try wrapper.write(to: url)
        try FileManager.default.setAttributes([.modificationDate: writtenAt], ofItemAtPath: url.path)
    }

    @Test("an entry in the previous format is still read")
    func readsLegacyFormat() async throws {
        let name = "tests-\(UUID().uuidString)"
        let cache = DiskCache(name: name)
        try writeLegacy([4, 5], key: "legacy", in: name, writtenAt: Date())

        let result: [Int]? = await cache.get(for: "legacy")
        #expect(result == [4, 5])
    }

    @Test("an expired entry in the previous format is pruned")
    func prunesLegacyFormat() async throws {
        let name = "tests-\(UUID().uuidString)"
        let cache = DiskCache(name: name, maxAge: 3600)
        try writeLegacy([1], key: "old", in: name, writtenAt: Date().addingTimeInterval(-7200))
        try writeLegacy([2], key: "recent", in: name, writtenAt: Date())

        #expect(await cache.pruneExpired() == 1)
        #expect(files(in: name) == ["recent"])
    }

    @Test("an unreadable file is discarded rather than served")
    func discardsGarbage() async throws {
        let name = "tests-\(UUID().uuidString)"
        let cache = DiskCache(name: name)
        try Data("not a cache entry".utf8).write(to: directory(for: name).appendingPathComponent("junk"))

        let result: [Int]? = await cache.get(for: "junk")
        #expect(result == nil)
        #expect(files(in: name).isEmpty)
    }

    // MARK: - Memory

    @Test("the in-memory copy is bounded, and evicted entries still come back from disk")
    func memoryIsBounded() async {
        let name = "tests-\(UUID().uuidString)"
        let cache = DiskCache(name: name, memoryLimit: 3)
        for index in 0..<10 {
            await cache.set([index], for: "key\(index)")
        }

        #expect(await cache.memoryEntryCount == 3)
        let evicted: [Int]? = await cache.get(for: "key0")
        #expect(evicted == [0])
        #expect(await cache.memoryEntryCount == 3)
    }
}
