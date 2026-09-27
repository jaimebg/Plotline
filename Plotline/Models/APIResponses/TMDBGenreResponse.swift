import Foundation

/// Response wrapper for TMDB genre list endpoints
nonisolated struct TMDBGenreListResponse: Codable {
    let genres: [Genre]
}
