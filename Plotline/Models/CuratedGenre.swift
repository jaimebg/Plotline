import Foundation

/// A curated genre with separate TMDB IDs for movies and TV series.
/// Ensures every genre returns results in both media types.
struct CuratedGenre: Identifiable, Hashable {
    let id: String
    let name: String
    let movieGenreId: Int
    let tvGenreId: Int

    /// Returns the correct TMDB genre ID for the given media type
    func genreId(for mediaType: GenreMediaType) -> Int {
        switch mediaType {
        case .movies: return movieGenreId
        case .series: return tvGenreId
        }
    }

    /// Curated list of 15 genres that work well for both movies and TV series
    static let all: [CuratedGenre] = [
        CuratedGenre(id: "action", name: "Action", movieGenreId: 28, tvGenreId: 10759),
        CuratedGenre(id: "animation", name: "Animation", movieGenreId: 16, tvGenreId: 16),
        CuratedGenre(id: "comedy", name: "Comedy", movieGenreId: 35, tvGenreId: 35),
        CuratedGenre(id: "crime", name: "Crime", movieGenreId: 80, tvGenreId: 80),
        CuratedGenre(id: "documentary", name: "Documentary", movieGenreId: 99, tvGenreId: 99),
        CuratedGenre(id: "drama", name: "Drama", movieGenreId: 18, tvGenreId: 18),
        CuratedGenre(id: "family", name: "Family", movieGenreId: 10751, tvGenreId: 10751),
        CuratedGenre(id: "fantasy", name: "Fantasy", movieGenreId: 14, tvGenreId: 10765),
        CuratedGenre(id: "horror", name: "Horror", movieGenreId: 27, tvGenreId: 27),
        CuratedGenre(id: "mystery", name: "Mystery", movieGenreId: 9648, tvGenreId: 9648),
        CuratedGenre(id: "romance", name: "Romance", movieGenreId: 10749, tvGenreId: 10749),
        CuratedGenre(id: "sci-fi", name: "Sci-Fi", movieGenreId: 878, tvGenreId: 10765),
        CuratedGenre(id: "thriller", name: "Thriller", movieGenreId: 53, tvGenreId: 53),
        CuratedGenre(id: "war", name: "War", movieGenreId: 10752, tvGenreId: 10768),
        CuratedGenre(id: "western", name: "Western", movieGenreId: 37, tvGenreId: 37),
    ]
}
