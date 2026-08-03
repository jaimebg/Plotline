import Foundation

/// Reads the analysis dataset that ships inside the app bundle.
///
/// The bundled data is a **seed and a fallback, never the truth**: it exists so
/// the app has its own content on a clean install, offline, before the user has
/// done anything. Where the app can fetch something fresher from TMDB, the
/// fresh data wins.
///
/// Deliberately **not** `@Observable`: the getters below call `load()`, which
/// mutates the cache, and under observation that is a mutation during a view's
/// body evaluation. Nothing here ever changes after the first read, so there is
/// nothing for a view to observe.
///
/// Main-actor isolated: this is UI-layer data, read from view bodies, and the
/// lazy load is not internally synchronised. Isolation makes that a rule the
/// compiler enforces rather than a convention the next change can forget.
@MainActor
final class DatasetStore {
    static let shared = DatasetStore()

    private var cached: PlotlineDataset?
    private var didAttemptLoad = false
    private var index: [Int: DatasetEntry] = [:]

    private init() {}

    /// Decodes the bundled dataset, once. Returns nil when the file is missing
    /// or unreadable, which the callers treat as "no curated content" rather
    /// than as an error worth surfacing — the rest of the app still works.
    @discardableResult
    func load() -> PlotlineDataset? {
        if didAttemptLoad { return cached }
        didAttemptLoad = true

        guard let url = Bundle.main.url(forResource: "PlotlineDataset", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(PlotlineDataset.self, from: data) else {
            #if DEBUG
            print("⚠️ DatasetStore: bundled dataset missing or unreadable")
            #endif
            return nil
        }

        guard decoded.version == PlotlineDataset.currentVersion else {
            #if DEBUG
            print("⚠️ DatasetStore: dataset version \(decoded.version) is not \(PlotlineDataset.currentVersion)")
            #endif
            return nil
        }

        cached = decoded
        index = Dictionary(uniqueKeysWithValues: decoded.entries.map { ($0.tmdbId, $0) })
        return decoded
    }

    var entries: [DatasetEntry] {
        load()?.entries ?? []
    }

    var lists: [CuratedList] {
        load()?.lists ?? []
    }

    func entry(forTMDBId id: Int) -> DatasetEntry? {
        load()
        return index[id]
    }

    /// Resolves a list's ids to entries, preserving the list's order.
    func entries(for list: CuratedList) -> [DatasetEntry] {
        load()
        return list.tmdbIds.compactMap { index[$0] }
    }
}
