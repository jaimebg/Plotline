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
    /// Every seed id that did not become an entry, with why. `entries` and
    /// `skipped` together account for every id the generator was asked to
    /// fetch, so an absence can always be told apart as a data problem (an
    /// `InsufficientDataReason`) or a fetch failure, rather than leaving the
    /// reason to live only in console output.
    let skipped: [SkippedSeries]

    static let currentVersion = 1
}

/// A seed id that did not make it into `entries`, and why.
struct SkippedSeries: Codable, Hashable {
    let tmdbId: Int
    /// Absent when the series failed before its name was known, i.e. the
    /// details fetch itself failed.
    let name: String?
    /// A fixed category the app can switch on: an `InsufficientDataReason` raw
    /// value, or `"fetchFailed"`. Never free text, so adding a case here is a
    /// deliberate change to the contract rather than a surprise at the reader.
    let kind: String
    /// Optional extra context, and only ever something safe to publish — an
    /// HTTP status, say. **Never** an interpolated error: URLSession errors
    /// carry the failing URL, and the TMDB request URL carries the API key in
    /// its query string, so a raw error here would commit a live secret into a
    /// file that also ships inside the app bundle.
    let detail: String?

    /// The one category that is not an `InsufficientDataReason`.
    static let fetchFailedKind = "fetchFailed"
}

struct DatasetEntry: Codable, Hashable, Identifiable {
    var id: Int { tmdbId }

    let tmdbId: Int
    let name: String
    /// The app's `MediaType` raw value — `"tv"` for everything in this dataset.
    /// Stored as a string because this file is shared with the generator and
    /// therefore may import nothing but Foundation.
    let mediaType: String
    let overview: String
    let posterPath: String?
    let backdropPath: String?
    /// TMDB's own audience score, carried so an offline add does not persist a
    /// favourite rated 0 and quietly poison the taste profile.
    let voteAverage: Double
    let genreIds: [Int]
    let firstAirDate: String?
    let analysis: SeriesAnalysis
    /// Award names as Wikidata labels them. Empty when the title has none.
    let awards: [String]
}

/// A list derived from the analysis, not hand-written. Regenerating the dataset
/// regenerates the lists, so they cannot go stale against the data behind them.
///
/// Deliberately carries **no user-facing copy**. A title and a subtitle in a
/// data file are strings the app cannot translate, cannot restyle, and cannot
/// keep in one language with the rest of its UI. The app owns the copy, keyed
/// by `id`; the dataset owns only the membership it can prove.
struct CuratedList: Codable, Hashable, Identifiable {
    let id: String
    let tmdbIds: [Int]
}
