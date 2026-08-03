import Foundation

/// The contract between the dataset generator and the app.
///
/// Shared by path with the generator, exactly like the analysis engine, so the
/// file the tool writes and the file the app reads can never drift apart.
///
/// The bundled dataset is a **seed and a fallback, never the truth**: when the
/// network is available, freshly fetched data wins. That keeps the app useful
/// offline and on first launch without ever asserting something stale.
struct PlotlineDataset: Codable, Hashable {
    /// Bumped when the shape changes, so the app can refuse a file it cannot read.
    let version: Int
    let entries: [DatasetEntry]
    let lists: [CuratedList]

    static let currentVersion = 1
}

struct DatasetEntry: Codable, Hashable, Identifiable {
    var id: Int { tmdbId }

    let tmdbId: Int
    let name: String
    let posterPath: String?
    let analysis: SeriesAnalysis
    /// Award names as Wikidata labels them. Empty when the title has none.
    let awards: [String]
}

/// A list derived from the analysis, not hand-written. Regenerating the dataset
/// regenerates the lists, so they cannot go stale against the data behind them.
struct CuratedList: Codable, Hashable, Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let tmdbIds: [Int]
}
