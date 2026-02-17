import Foundation

/// Static lookup for TMDB genre IDs to names — avoids network calls for genre resolution
enum GenreLookup {
    /// Combined movie + TV genre dictionary (TMDB IDs are stable)
    static let genres: [Int: String] = [
        // Movie genres
        28: "Action",
        12: "Adventure",
        16: "Animation",
        35: "Comedy",
        80: "Crime",
        99: "Documentary",
        18: "Drama",
        10751: "Family",
        14: "Fantasy",
        36: "History",
        27: "Horror",
        10402: "Music",
        9648: "Mystery",
        10749: "Romance",
        878: "Science Fiction",
        10770: "TV Movie",
        53: "Thriller",
        10752: "War",
        37: "Western",
        // TV-specific genres
        10759: "Action & Adventure",
        10762: "Kids",
        10763: "News",
        10764: "Reality",
        10765: "Sci-Fi & Fantasy",
        10766: "Soap",
        10767: "Talk",
        10768: "War & Politics",
    ]

    static func name(for id: Int) -> String? {
        genres[id]
    }
}
