import Foundation

/// Response wrapper for TMDB genre list endpoints
struct TMDBGenreListResponse: Codable {
    let genres: [Genre]
}
