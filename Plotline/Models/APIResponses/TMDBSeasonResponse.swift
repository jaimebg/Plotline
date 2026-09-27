import Foundation

/// Response for /tv/{series_id}/season/{season_number}
nonisolated struct TMDBSeasonResponse: Codable {
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
                stillPath: episode.stillPath,
                directors: episode.crew.map { TMDBEpisodeCrewMember.names(in: $0, jobs: TMDBEpisodeCrewMember.directorJobs) },
                writers: episode.crew.map { TMDBEpisodeCrewMember.names(in: $0, jobs: TMDBEpisodeCrewMember.writerJobs) }
            )
        }
    }
}

nonisolated struct TMDBEpisode: Codable {
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
    /// Per-episode crew. Optional so a payload without the key still decodes.
    let crew: [TMDBEpisodeCrewMember]?

    /// TMDB sometimes returns an empty name for unaired episodes.
    var displayTitle: String {
        guard let name, !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            return "Episode \(episodeNumber)"
        }
        return name
    }
}

/// One crew credit on an episode.
nonisolated struct TMDBEpisodeCrewMember: Codable {
    let id: Int?
    let name: String?
    let job: String?

    static let directorJobs: Set<String> = ["Director"]
    static let writerJobs: Set<String> = ["Writer", "Teleplay", "Screenplay", "Story"]

    /// The distinct names credited with any of `jobs`, in credit order. A
    /// writer credited for both story and teleplay is one person, not two.
    static func names(in crew: [TMDBEpisodeCrewMember], jobs: Set<String>) -> [String] {
        var seen: Set<String> = []
        var names: [String] = []
        for member in crew {
            guard let job = member.job, jobs.contains(job),
                  let name = member.name?.trimmingCharacters(in: .whitespaces), !name.isEmpty,
                  seen.insert(name).inserted else { continue }
            names.append(name)
        }
        return names
    }
}
