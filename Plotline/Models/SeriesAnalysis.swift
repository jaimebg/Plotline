import Foundation

/// Outcome of analysing a series' episode ratings.
///
/// The engine never emits a verdict it cannot support, so callers must handle
/// `insufficientData` explicitly rather than reading a half-filled analysis.
enum SeriesAnalysisResult: Codable, Hashable {
    case analyzed(SeriesAnalysis)
    case insufficientData(InsufficientDataReason)
}

/// Why a series could not be analysed. Surfaced so the UI can say something
/// truthful instead of showing an empty panel.
enum InsufficientDataReason: String, Codable, Hashable {
    /// Nothing has aired yet.
    case noAiredEpisodes
    /// Episodes aired, but none carries enough votes to trust.
    case noReliableEpisodes
    /// Some episodes are reliable, but too small a share of what aired.
    case tooFewReliableEpisodes
    /// A high enough share, but too few reliable episodes in absolute terms.
    /// A ratio cannot see sample size: one reliable episode out of one aired
    /// clears every share test and still supports no verdict at all.
    case notEnoughEpisodesToAnalyse
}

/// Derived analysis of a series. Every verdict carries the data that supports
/// it, so the UI can show its reasoning rather than an unexplained badge.
struct SeriesAnalysis: Codable, Hashable {
    let seasons: [SeasonSummary]
    let bestSeason: Int?
    let worstSeason: Int?
    let declinePoint: DeclinePoint?
    let consistency: Consistency
    let essentialEpisodes: [EpisodeReference]
    let skippableEpisodes: [EpisodeReference]
    let openingVerdict: OpeningVerdict?
    let endingVerdict: EndingVerdict?
    let score: PlotlineScore
    /// True when the series is still running: taken from TMDB's series status
    /// when it is known, otherwise inferred from episodes with a scheduled
    /// future air date. The ending verdict does not key off this — `false` here
    /// can mean "unknown and nothing scheduled", which is not proof of an
    /// ending; the verdict requires a series *known* to have finished.
    let isOngoing: Bool
}

/// Per-season roll-up.
struct SeasonSummary: Codable, Hashable, Identifiable {
    var id: Int { seasonNumber }

    let seasonNumber: Int
    let weightedAverage: Double
    let standardDeviation: Double
    let reliableEpisodeCount: Int
    /// How many of the season's episodes have aired, reliable or not. Paired
    /// with `reliableEpisodeCount` it states the coverage behind the average —
    /// "from 2 of 10 episodes" — so a thin season cannot pass for a full one.
    let airedEpisodeCount: Int
    let bestEpisode: EpisodeReference?
    let worstEpisode: EpisodeReference?
}

/// A pointer back to a specific episode, so a verdict can name its evidence.
struct EpisodeReference: Codable, Hashable, Identifiable {
    let id: Int
    let seasonNumber: Int
    let episodeNumber: Int
    let title: String
    let rating: Double

    var shortCode: String { "S\(seasonNumber)E\(episodeNumber)" }
}

/// The season boundary after which quality drops and stays down.
struct DeclinePoint: Codable, Hashable {
    /// Quality falls from the season after this one onward.
    let afterSeason: Int
    let averageBefore: Double
    let averageAfter: Double
    let seasonsAfter: [Int]

    var drop: Double { averageBefore - averageAfter }
}

/// How evenly a series holds its quality.
struct Consistency: Codable, Hashable {
    let rating: ConsistencyRating
    let standardDeviation: Double
    let highestRated: EpisodeReference?
    let lowestRated: EpisodeReference?
}

enum ConsistencyRating: String, Codable, Hashable {
    case verySteady
    case steady
    case uneven
    case rollercoaster
}

/// Whether the series grabs you immediately or takes a while.
struct OpeningVerdict: Codable, Hashable {
    enum Kind: String, Codable, Hashable {
        case hooksEarly
        case slowStart
        case even
    }

    let kind: Kind
    let openingAverage: Double
    let remainderAverage: Double
    let episodesConsidered: [EpisodeReference]
    /// For `slowStart`, the first season that clears the opening average by the threshold.
    let improvesAtSeason: Int?
}

/// Whether the series lands its final season or limps out.
struct EndingVerdict: Codable, Hashable {
    enum Kind: String, Codable, Hashable {
        case endsStrong
        case endsSteady
        case fadesOut
    }

    let kind: Kind
    let finalSeason: Int
    let finalSeasonAverage: Double
    let peakSeason: Int
    let peakSeasonAverage: Double
}

/// Plotline's own 0-100 score, with its three components exposed so the UI can
/// show the breakdown instead of an opaque number.
struct PlotlineScore: Codable, Hashable {
    let value: Int
    let level: Int
    let consistency: Int
    let trajectory: Int
}
