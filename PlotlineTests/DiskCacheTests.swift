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
}
