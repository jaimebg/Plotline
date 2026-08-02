import Foundation

/// Response for /tv/{series_id}/season/{season_number}
struct TMDBSeasonResponse: Codable {
    let id: Int
    let name: String?
    let seasonNumber: Int
    let episodes: [TMDBEpisode]

    /// Maps the payload onto the app's episode model.
    /// Unaired and unrated episodes are kept so the UI can show the full season;
    /// the analysis engine filters them out via `hasValidRating` / `hasAired`.
    func toEpisodeMetrics() -> [EpisodeMetric] {
        episodes.map { episode in
            EpisodeMetric(
                id: episode.id,
                episodeNumber: episode.episodeNumber,
                seasonNumber: episode.seasonNumber,
                title: episode.displayTitle,
                rating: episode.voteAverage,
                voteCount: episode.voteCount,
                airDate: episode.airDate,
                stillPath: episode.stillPath
            )
        }
    }
}

struct TMDBEpisode: Codable {
    let id: Int
    let name: String?
    let episodeNumber: Int
    let seasonNumber: Int
    let airDate: String?
    let stillPath: String?
    let voteAverage: Double
    let voteCount: Int
    let overview: String?
    let runtime: Int?

    /// TMDB sometimes returns an empty name for unaired episodes.
    var displayTitle: String {
        guard let name, !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            return "Episode \(episodeNumber)"
        }
        return name
    }
}
